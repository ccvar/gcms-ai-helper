"""命令行入口：python -m gcms_helper <子命令>

  sites                 列出站点（* = 当前活动站）
  draft [--dry-run]     给当前活动站撰稿一篇草稿（--dry-run 只打印不真跑）
  config                打印当前生效的关键配置
  version               版本
"""
import argparse
import re
import sys

from . import __version__, core


def cmd_sites(_args) -> int:
    sites = core.list_sites()
    if not sites:
        print("（还没有站点。请在 sites.json 注册，或用 App 的「站点管理」添加。）")
        return 0
    for slug, name, base, active in sites:
        print(f"{'*' if active else ' '} {slug:<12} {name:<16} {base}")
    return 0


def cmd_config(_args) -> int:
    slug = core.active_slug()
    if not slug:
        print("没有活动站点。")
        return 1
    weng, wmodel = core.engine_for("writer")
    eeng, emodel = core.engine_for("editor")
    print(f"活动站点    : {slug}")
    print(f"写作引擎    : {weng} {('/' + wmodel) if wmodel else ''}")
    print(f"审核引擎    : {eeng} {('/' + emodel) if emodel else ''}")
    print(f"发布模式    : {core.scfg(slug, 'publish_mode', 'manual')}")
    print(f"写作语种    : {core.scfg(slug, 'write_lang', 'zh')}")
    print(f"目标字数    : {core.scfg(slug, 'target_words', '默认 1500-2200')}")
    print(f"自动归类/配图: {core.scfg(slug, 'auto_category', True)} / {core.scfg(slug, 'auto_cover', False)}")
    print(f"Python 解释器: {core.py_exe()}")
    return 0


def _queue_open_count(slug: str) -> int:
    q = core.site_dir(slug) / "review-queue.md"
    try:
        return len(re.findall(r'(?m)^- \[ \]', q.read_text(encoding="utf-8")))
    except Exception:
        return 0


def cmd_draft(args) -> int:
    slug = core.active_slug()
    if not slug:
        print("没有活动站点，请先添加/选择一个站点。")
        return 1
    prompt = core.build_draft_prompt(slug)
    if args.dry_run:
        eng, model, full, argv = core.build_engine_command("writer", prompt)
        print(f"[dry-run] 站点={slug} 引擎={eng} 模型={model or '默认'}")
        print("[dry-run] ---- 提示词 ----")
        print(prompt)
        print(f"[dry-run] ---- 将执行 {argv[0]}（{len(argv)} 参数），此处不真跑 ----")
        return 0
    before = _queue_open_count(slug)
    print(f"▶ 给「{slug}」撰稿中…（引擎：{core.engine_for('writer')[0]}）")
    rc = core.run_engine("writer", prompt, slug=slug)
    after = _queue_open_count(slug)
    if after > before:
        q = core.site_dir(slug) / "review-queue.md"
        last = [l for l in q.read_text(encoding="utf-8").splitlines() if l.startswith("- [ ]")]
        nid = ""
        if last:
            m = re.search(r'#(\d+)', last[-1])
            nid = m.group(1) if m else ""
        print(f"✅ 新草稿 #{nid}，去「待审」查看。")
    else:
        print("（本次未检测到新增草稿，查看引擎输出/日志。）" if rc == 0 else f"（引擎退出码 {rc}）")
    return rc


def main(argv=None) -> int:
    raw = sys.argv[1:] if argv is None else list(argv)
    # GUI 模式：--settings 开设置窗口，--tray 开托盘；冻结(.exe)无参数默认开托盘
    if "--settings" in raw:
        from . import settings_ui
        settings_ui.main()
        return 0
    if "--tray" in raw or (getattr(sys, "frozen", False) and not raw):
        from . import tray
        tray.main()
        return 0

    p = argparse.ArgumentParser(prog="gcms_helper", description="跨平台内容运营核心")
    sub = p.add_subparsers(dest="cmd")
    sub.add_parser("sites", help="列出站点")
    d = sub.add_parser("draft", help="撰稿一篇草稿")
    d.add_argument("--dry-run", action="store_true", help="只打印将执行的内容，不真跑模型")
    sub.add_parser("config", help="打印当前配置")
    sub.add_parser("version", help="版本")

    args = p.parse_args(argv)
    if args.cmd == "sites":
        return cmd_sites(args)
    if args.cmd == "draft":
        return cmd_draft(args)
    if args.cmd == "config":
        return cmd_config(args)
    if args.cmd == "version":
        print(f"gcms_helper {__version__}")
        return 0
    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
