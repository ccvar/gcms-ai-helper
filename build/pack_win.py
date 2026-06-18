"""组装 Windows 下载包：把 PyInstaller 产物 gcms-helper.exe 与运行所需文件拢到一个
文件夹（= 运行时项目根），写入零站点模板 / 快速开始 / 定时任务脚本，并压成 zip。

用法: python build/pack_win.py [--exe dist/gcms-helper.exe] [--out dist] [--version v1.0]
跨平台：CI 在 windows-latest 上调用；本地也能跑（缺 exe 只验证结构）。
"""
import argparse
import json
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NAME = "CCVAR撰稿助手-Windows"

QUICKSTART = """CCVAR 撰稿助手 (Windows) · 快速开始
===================================

【准备】先装好这两样（和 Mac 版同理，都是外部工具）：
  1) Python —— 到 python.org 下载安装，安装时务必勾选 "Add Python to PATH"。
     （撰稿时由 AI 调用本目录的 ccvar.py，需要它。）
  2) AI 引擎（至少一个）：
     · Claude：PowerShell 运行   irm https://claude.ai/install.ps1 | iex   安装；
       首次在终端运行一次 claude 登录（需 Claude 付费套餐）。建议再装 Git for Windows。
     · GPT(codex)：按 OpenAI 文档安装 codex，运行 codex login 用 ChatGPT 登录。

【使用】
  1) 双击 gcms-helper.exe —— 屏幕右下角系统托盘出现一个图标。
  2) 右键托盘图标 ->「设置…」：选 AI 引擎；点「添加站点」填【名称 / API 域名 / 密钥】。
     域名形如 https://你的站.com/api/admin/v1 ；密钥需含 publish 权限才能发布。
  3) 右键 ->「立刻撰稿一篇」试试；草稿会进你站点后台的「待审」。
  4) 想每天自动撰稿：双击「每日自动撰稿-注册.cmd」（默认每天 9:00；可在「任务计划程序」改）。
     不想要了就双击「每日自动撰稿-取消.cmd」。

【首次运行被拦】本程序未做数字签名，Windows SmartScreen 可能提示——
  点「更多信息」->「仍要运行」即可（只需一次）。
"""

SCHED_CMD = """@echo off
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$exe = Join-Path '%~dp0' 'gcms-helper.exe';" ^
  "$a = New-ScheduledTaskAction -Execute $exe -Argument 'draft';" ^
  "$t = New-ScheduledTaskTrigger -Daily -At 9am;" ^
  "Register-ScheduledTask -TaskName 'CCVAR-DailyDraft' -Action $a -Trigger $t -Force | Out-Null"
echo 已注册：每天 9:00 自动撰稿（任务名 CCVAR-DailyDraft）。可在「任务计划程序」里修改时间。
pause
"""

SCHED_DEL = """@echo off
chcp 65001 >nul
schtasks /Delete /TN "CCVAR-DailyDraft" /F
echo 已取消每日自动撰稿。
pause
"""


def assemble(exe_path: Path, out_dir: Path) -> Path:
    pkg = out_dir / NAME
    if pkg.exists():
        shutil.rmtree(pkg)
    pkg.mkdir(parents=True)

    # 1) 主程序 exe
    if exe_path.exists():
        shutil.copy2(exe_path, pkg / "gcms-helper.exe")
    else:
        print(f"⚠ 未找到 exe：{exe_path}（本地结构验证可忽略；CI 上必须存在）")

    # 2) API 客户端 + automation 必需文件（被提示词引用 / 被核心读取）
    shutil.copy2(ROOT / "ccvar.py", pkg / "ccvar.py")
    (pkg / "automation" / "prompts").mkdir(parents=True)
    for rel in ("prompts/claude.md", "prompts/codex.md", "daily-draft.md", "review-draft.md"):
        src = ROOT / "automation" / rel
        if src.exists():
            shutil.copy2(src, pkg / "automation" / rel)

    # 3) 零站点模板配置
    (pkg / "sites").mkdir()
    (pkg / "sites.json").write_text(
        json.dumps({"active": "", "sites": []}, ensure_ascii=False, indent=2), encoding="utf-8")
    (pkg / "config.json").write_text(json.dumps({
        "draft_hour": 9, "draft_minute": 0,
        "writer_engine": "claude", "editor_engine": "claude",
        "model": "", "editor_model": "", "codex_model": "", "ai_cmd": "",
        "auto_daily_cap": 5,
    }, ensure_ascii=False, indent=2), encoding="utf-8")

    # 4) 给小白的文档与定时任务脚本
    (pkg / "快速开始.txt").write_text(QUICKSTART, encoding="utf-8")
    (pkg / "每日自动撰稿-注册.cmd").write_text(SCHED_CMD, encoding="utf-8")
    (pkg / "每日自动撰稿-取消.cmd").write_text(SCHED_DEL, encoding="utf-8")
    return pkg


def zip_pkg(pkg: Path, out_dir: Path, version: str) -> Path:
    suffix = f"-{version}" if version else ""
    zip_path = out_dir / f"gcms-ai-helper-windows{suffix}.zip"
    if zip_path.exists():
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for p in sorted(pkg.rglob("*")):
            z.write(p, Path(NAME) / p.relative_to(pkg))
    return zip_path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exe", default=str(ROOT / "dist" / "gcms-helper.exe"))
    ap.add_argument("--out", default=str(ROOT / "dist"))
    ap.add_argument("--version", default="")
    a = ap.parse_args()

    out_dir = Path(a.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    pkg = assemble(Path(a.exe), out_dir)
    zip_path = zip_pkg(pkg, out_dir, a.version.strip())

    print(f"✅ Windows 包已生成：{zip_path}")
    print(f"   含 exe      : {(pkg / 'gcms-helper.exe').exists()}")
    print(f"   含 ccvar.py : {(pkg / 'ccvar.py').exists()}")
    print(f"   prompts     : {sorted(p.name for p in (pkg / 'automation' / 'prompts').glob('*'))}")
    print(f"   顶层文件     : {sorted(p.name for p in pkg.iterdir())}")


if __name__ == "__main__":
    main()
