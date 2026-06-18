"""写配置：加站 / 设密钥 / 切活动站 / 移除站 / 选引擎。
对应 automation/ 里的 add-site.sh、set-key.sh、set-active.sh、remove-site.sh、apply-global-config.sh。
全部跨平台（Windows/macOS/Linux）。"""
import json
import os
import re
import shutil

from . import core

PROJ = core.PROJ

# 新站选题库模板（与 add-site.sh 一致；__NAME__ 占位）
TOPICS_TEMPLATE = """# __NAME__ · 选题库

怎么填：站上已有发布文章 → 点菜单「校准网站定位…」让 AI 自动填；
全新空站 → 照下面【示例】把「网站定位」「写作方向」改成你自己的（删掉示例行）。

## 网站定位（这网站是干嘛的 · AI 据此把握调性与受众）

（用一段话写清：写给谁看、写什么、什么调性。
示例：面向独立开发者的技术博客，聚焦 Web 全栈与工程实践，务实、带可运行代码示例。
↑ 把上面这句改成你自己的网站定位。）

## 写作方向（允许的主题范围 = 边界 · AI 只在这里面自动补题）

- **示例·后端工程**：API 设计、数据库、性能优化（照这行格式改成你的方向，每行一个）
- **示例·前端实践**：框架、构建、交互细节（不想要的方向删掉；AI 只在这些范围里补题）

## 待写队列（从上往下取；写完自动移到「已写」）


## 已写（自动追加：日期 · 标题 · 草稿ID）

"""


def _write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)


def _write_keyfile(slug, key):
    env = core.site_dir(slug) / "site.env"
    env.parent.mkdir(parents=True, exist_ok=True)
    with open(env, "w", encoding="utf-8") as f:
        f.write(f"CCVAR_API_KEY={key}\n")
    try:
        os.chmod(env, 0o600)  # Unix 生效；Windows 忽略
    except Exception:
        pass


def normalize_slug(s: str) -> str:
    return re.sub(r"[^a-z0-9-]", "", (s or "").lower())


def add_site(slug: str, name: str, base_url: str, key: str = ""):
    slug = normalize_slug(slug)
    if not slug:
        return False, "slug 非法（需含 a-z0-9-）"
    if not name or not base_url:
        return False, "名称 / API 域名不能为空"
    reg = core.registry()
    if any(s.get("slug") == slug for s in reg.get("sites", [])):
        return False, "该 slug 已存在"

    d = core.site_dir(slug)
    (d / "drafts").mkdir(parents=True, exist_ok=True)
    _write_keyfile(slug, key)
    cfg = d / "config.json"
    if not cfg.exists():
        _write_json(cfg, {
            "publish_mode": "manual", "veto_hours": 6,
            "auto_category": True, "auto_cover": False,
            "write_lang": "zh", "translate_langs": [], "lang_mode": "translate",
        })
    topics = d / "topics.md"
    if not topics.exists():
        topics.write_text(TOPICS_TEMPLATE.replace("__NAME__", name), encoding="utf-8")
    rq = d / "review-queue.md"
    if not rq.exists():
        rq.write_text("# 待审草稿队列\n\n", encoding="utf-8")

    reg.setdefault("sites", []).append(
        {"slug": slug, "name": name, "base_url": base_url, "enabled": True})
    if not reg.get("active"):
        reg["active"] = slug
    _write_json(PROJ / "sites.json", reg)
    return True, f"已添加站点「{name}」（{slug}）"


def set_key(slug: str, key: str):
    if not core.site_dir(slug).exists():
        return False, "站点不存在"
    _write_keyfile(slug, key)
    return True, "密钥已更新"


def set_active(slug: str):
    reg = core.registry()
    if not any(s.get("slug") == slug for s in reg.get("sites", [])):
        return False, "站点不存在"
    reg["active"] = slug
    _write_json(PROJ / "sites.json", reg)
    return True, f"活动站点 = {slug}"


def remove_site(slug: str, delete_files: bool = False):
    reg = core.registry()
    sites = reg.get("sites", [])
    if not any(s.get("slug") == slug for s in sites):
        return False, "站点不存在"
    reg["sites"] = [s for s in sites if s.get("slug") != slug]
    if reg.get("active") == slug:
        reg["active"] = reg["sites"][0]["slug"] if reg["sites"] else ""
    _write_json(PROJ / "sites.json", reg)
    if delete_files:
        shutil.rmtree(core.site_dir(slug), ignore_errors=True)
    return True, f"已移除站点 {slug}"


def set_engines(writer_engine=None, editor_engine=None,
                writer_model=None, editor_model=None, codex_model=None):
    gc = core.global_config()
    if writer_engine:
        gc["writer_engine"] = writer_engine
    if editor_engine:
        gc["editor_engine"] = editor_engine
    if writer_model is not None:
        gc["model"] = writer_model
    if editor_model is not None:
        gc["editor_model"] = editor_model
    if codex_model is not None:
        gc["codex_model"] = codex_model
    _write_json(PROJ / "config.json", gc)
    return True, "引擎设置已保存"
