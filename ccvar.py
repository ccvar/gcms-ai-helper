#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CCVAR 简记 — Automation API helper.

读取密钥顺序：环境变量 $CCVAR_API_KEY -> sites/<slug>/site.env 中的 CCVAR_API_KEY=...（slug 由 CCVAR_SITE 或活动站决定）

安全默认：create / update 一律以「草稿」落地。除非显式传 --allow-publish
（且 API Key 本身具备 publish 权限），否则拒绝把 status 设为 published / scheduled。

用法：
  python3 ccvar.py list posts [--lang zh] [--status draft] [--q 关键词] [--slug s] [--limit N] [--offset N]
  python3 ccvar.py get posts 123
  python3 ccvar.py create posts --title "标题" --content-file body.md [--lang zh] [--excerpt ...] [--meta-desc ...] [--keywords ...] [--slug ...] [--category-id N]
  python3 ccvar.py create posts --data-file payload.json      # 完整字段自定义
  python3 ccvar.py create posts --data-stdin                  # JSON 从标准输入
  python3 ccvar.py update posts 123 --title "新标题" [--content-file body.md] [...]

资源：posts(文章) | pages(页面) | links(链接)
"""
import argparse
import json
import mimetypes
import os
import pathlib
import sys
import uuid
import urllib.error
import urllib.request
from urllib.parse import urlencode

BASE = os.environ.get("CCVAR_BASE_URL", "https://ccvar.com/api/admin/v1").rstrip("/")
# 站点有 Cloudflare 机器人防护，会拉黑默认的 urllib UA；用常见浏览器 UA 通过。
USER_AGENT = os.environ.get(
    "CCVAR_USER_AGENT",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
)
RESOURCES = ("posts", "pages", "links")
HERE = pathlib.Path(__file__).resolve().parent
PLACEHOLDERS = {"", "PASTE_YOUR_KEY_HERE", "gcms_xxx"}


def _site_cfg():
    """多站：环境变量 CCVAR_SITE 指定站点 slug，从 sites.json + 该站 key 文件解析 base_url 与 keyfile。"""
    slug = os.environ.get("CCVAR_SITE", "").strip()
    try:
        reg = json.load(open(HERE / "sites.json"))
    except Exception:
        return None
    if not slug:                       # 没指定 CCVAR_SITE 就用活动站
        slug = (reg.get("active") or "").strip()
    if not slug:
        return None
    s = next((x for x in reg.get("sites", []) if x.get("slug") == slug), None)
    if not s:
        return None
    keyfile = HERE / "sites" / slug / "site.env"   # 所有站统一，无根站特例
    return s.get("base_url", ""), keyfile


_SC = _site_cfg()
if _SC and not os.environ.get("CCVAR_BASE_URL") and _SC[0]:
    BASE = _SC[0].rstrip("/")


def load_key():
    key = os.environ.get("CCVAR_API_KEY", "").strip()
    if not key:
        envf = _SC[1] if _SC else None
        if envf and envf.exists():
            for raw in envf.read_text(encoding="utf-8").splitlines():
                line = raw.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                if k.strip() == "CCVAR_API_KEY":
                    key = v.strip().strip('"').strip("'")
                    break
    if key in PLACEHOLDERS:
        sys.exit("ERROR: 还没有可用的 API Key。请在菜单「站点管理」给该站填写，或写进 sites/<slug>/site.env：CCVAR_API_KEY=gcms_xxx")
    return key


def call(method, path, payload=None, query=None):
    url = BASE + path
    if query:
        qs = urlencode({k: v for k, v in query.items() if v not in (None, "")})
        if qs:
            url += "?" + qs
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", "Bearer " + load_key())
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json")
    req.add_header("User-Agent", USER_AGENT)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status, resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")
    except urllib.error.URLError as e:
        sys.exit(f"ERROR: 网络请求失败: {e}")


def call_multipart(path, filepath, field="file"):
    """以 multipart/form-data 上传一个文件（用于 POST /media）。"""
    fp = pathlib.Path(filepath)
    if not fp.exists():
        sys.exit(f"ERROR: 文件不存在: {filepath}")
    raw = fp.read_bytes()
    ctype = mimetypes.guess_type(str(fp))[0] or "application/octet-stream"
    boundary = "----ccvar" + uuid.uuid4().hex
    pre = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="{field}"; filename="{fp.name}"\r\n'
        f"Content-Type: {ctype}\r\n\r\n"
    ).encode("utf-8")
    body = pre + raw + f"\r\n--{boundary}--\r\n".encode("utf-8")
    req = urllib.request.Request(BASE + path, data=body, method="POST")
    req.add_header("Authorization", "Bearer " + load_key())
    req.add_header("Content-Type", "multipart/form-data; boundary=" + boundary)
    req.add_header("Accept", "application/json")
    req.add_header("User-Agent", USER_AGENT)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.status, resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")
    except urllib.error.URLError as e:
        sys.exit(f"ERROR: 网络请求失败: {e}")


def out(status, body):
    try:
        body = json.dumps(json.loads(body), ensure_ascii=False, indent=2)
    except Exception:
        pass
    print(f"HTTP {status}")
    print(body)
    if status >= 400:
        sys.exit(1)


FIELDS = (
    "title", "content", "lang", "slug", "excerpt", "meta_desc", "keywords",
    "status", "published_at", "category_id", "link_url", "author", "cover_image",
    "trans_group", "editor_mode",
)


def build_payload(args):
    payload = {}
    if getattr(args, "data_file", None):
        payload = json.loads(pathlib.Path(args.data_file).read_text(encoding="utf-8"))
    elif getattr(args, "data_stdin", False):
        payload = json.loads(sys.stdin.read())
    for field in FIELDS:
        val = getattr(args, field, None)
        if val is not None:
            payload[field] = val
    if getattr(args, "content_file", None):
        payload["content"] = pathlib.Path(args.content_file).read_text(encoding="utf-8")
    # category_id 接口要整数
    cid = payload.get("category_id")
    if isinstance(cid, str) and cid.strip():
        try:
            payload["category_id"] = int(cid)
        except ValueError:
            pass
    return payload


def guard_draft(payload, args):
    status = str(payload.get("status", "")).lower()
    if status in ("published", "scheduled") and not args.allow_publish:
        sys.exit(
            f"拒绝执行：当前为『仅草稿』安全模式，不允许 status={status}。\n"
            "如确需发布，请加 --allow-publish，且 API Key 需具备 publish 权限。"
        )


def add_content_args(sp):
    sp.add_argument("--title")
    sp.add_argument("--content")
    sp.add_argument("--content-file", dest="content_file")
    sp.add_argument("--lang")
    sp.add_argument("--slug")
    sp.add_argument("--excerpt")
    sp.add_argument("--meta-desc", dest="meta_desc")
    sp.add_argument("--keywords")
    sp.add_argument("--status")
    sp.add_argument("--published-at", dest="published_at")
    sp.add_argument("--category-id", dest="category_id")
    sp.add_argument("--trans-group", dest="trans_group")
    sp.add_argument("--editor-mode", dest="editor_mode")
    sp.add_argument("--link-url", dest="link_url")
    sp.add_argument("--author")
    sp.add_argument("--cover-image", dest="cover_image")
    sp.add_argument("--data-file", dest="data_file")
    sp.add_argument("--data-stdin", dest="data_stdin", action="store_true")
    sp.add_argument("--allow-publish", dest="allow_publish", action="store_true")


def main():
    p = argparse.ArgumentParser(description="CCVAR 简记 Automation API helper")
    sub = p.add_subparsers(dest="cmd", required=True)

    pl = sub.add_parser("list", help="列出资源")
    pl.add_argument("resource", choices=RESOURCES)
    for opt in ("--lang", "--status", "--q", "--slug", "--limit", "--offset"):
        pl.add_argument(opt)

    pg = sub.add_parser("get", help="按 ID 读取")
    pg.add_argument("resource", choices=RESOURCES)
    pg.add_argument("id")

    pc = sub.add_parser("create", help="创建（默认草稿）")
    pc.add_argument("resource", choices=RESOURCES)
    add_content_args(pc)

    pu = sub.add_parser("update", help="按 ID 更新")
    pu.add_argument("resource", choices=RESOURCES)
    pu.add_argument("id")
    add_content_args(pu)

    pcat = sub.add_parser("categories", help="列出文章/链接分类（目录）")
    pcat.add_argument("kind", nargs="?", choices=("posts", "links"), default="posts")
    pcat.add_argument("--lang", help="分类语种，如 zh/en；传 all 返回全部语种")

    sub.add_parser("languages", help="列出站点启用的语种")

    pm = sub.add_parser("media", help="上传媒体文件（图片等），返回 URL")
    pm.add_argument("file")

    ppr = sub.add_parser("preview", help="获取草稿预览（含 preview_url，不发布即可看渲染）")
    ppr.add_argument("resource", nargs="?", choices=RESOURCES, default="posts")
    ppr.add_argument("id")

    args = p.parse_args()

    if args.cmd == "list":
        q = {k: getattr(args, k) for k in ("lang", "status", "q", "slug", "limit", "offset")}
        out(*call("GET", f"/{args.resource}", query=q))
    elif args.cmd == "get":
        out(*call("GET", f"/{args.resource}/{args.id}"))
    elif args.cmd == "create":
        payload = build_payload(args)
        payload.setdefault("status", "draft")
        guard_draft(payload, args)
        if args.resource != "links" and not payload.get("title"):
            sys.exit("ERROR: 创建文章/页面需要 --title。")
        out(*call("POST", f"/{args.resource}", payload=payload))
    elif args.cmd == "update":
        payload = build_payload(args)
        guard_draft(payload, args)
        if not payload:
            sys.exit("ERROR: 没有要更新的字段。")
        out(*call("PATCH", f"/{args.resource}/{args.id}", payload=payload))
    elif args.cmd == "categories":
        out(*call("GET", f"/{args.kind}/categories", query={"lang": getattr(args, "lang", None)}))
    elif args.cmd == "languages":
        out(*call("GET", "/languages"))
    elif args.cmd == "media":
        out(*call_multipart("/media", args.file))
    elif args.cmd == "preview":
        out(*call("GET", f"/{args.resource}/{args.id}/preview"))


if __name__ == "__main__":
    main()
