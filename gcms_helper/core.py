"""核心逻辑：定位项目根、读配置、引擎分发、撰稿提示词构建。全部跨平台。"""
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

# 项目根：
#  · 开发/源码运行 → 本包的上一级（与 ccvar.py / sites.json 同级）
#  · PyInstaller 冻结成 .exe → exe 所在目录（用户在此放 ccvar.py / sites.json / sites/ …，
#    与 macOS 端「App 所在目录即项目根」一致）
if getattr(sys, "frozen", False):
    PROJ = Path(sys.executable).resolve().parent
else:
    PROJ = Path(__file__).resolve().parent.parent


# ---------- python 解释器（Windows 多为 python，Unix 多为 python3） ----------
def py_exe() -> str:
    """模型在命令里调用 ccvar.py 时用的解释器名：Windows 偏好 python，Unix 偏好 python3。"""
    cands = ("python", "py", "python3") if os.name == "nt" else ("python3", "python")
    for cand in cands:
        if shutil.which(cand):
            return cand
    return "python3"


# ---------- 配置读取 ----------
def _load_json(path: Path, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return default


def global_config() -> dict:
    return _load_json(PROJ / "config.json", {})


def registry() -> dict:
    return _load_json(PROJ / "sites.json", {"active": "", "sites": []})


def active_slug() -> str:
    return (os.environ.get("CCVAR_SITE") or registry().get("active") or "").strip()


def site_record(slug: str):
    return next((s for s in registry().get("sites", []) if s.get("slug") == slug), None)


def list_sites():
    """[(slug, name, base_url, is_active), ...]"""
    act = active_slug()
    out = []
    for s in registry().get("sites", []):
        out.append((s.get("slug", ""), s.get("name", ""), s.get("base_url", ""), s.get("slug") == act))
    return out


def site_dir(slug: str) -> Path:
    return PROJ / "sites" / slug


def site_config(slug: str) -> dict:
    return _load_json(site_dir(slug) / "config.json", {})


def scfg(slug: str, key: str, default=None):
    """先读本站 config，再回退全局 config，最后默认值。"""
    sc = site_config(slug)
    if key in sc:
        return sc[key]
    gc = global_config()
    return gc.get(key, default)


def _truthy(v) -> bool:
    return str(v).strip().lower() in ("true", "1", "yes", "on")


# ---------- 引擎分发（对应 automation/agent.sh） ----------
def engine_for(role: str):
    """返回 (engine, model)。role: writer | editor。"""
    gc = global_config()
    if role == "editor":
        eng = gc.get("editor_engine") or "claude"
        model = gc.get("editor_model", "") if eng == "claude" else gc.get("codex_model", "")
    else:
        eng = gc.get("writer_engine") or "claude"
        model = gc.get("model", "") if eng == "claude" else gc.get("codex_model", "")
    return eng, (model or "")


def _guardrail(engine: str) -> str:
    p = PROJ / "automation" / "prompts" / f"{engine}.md"
    try:
        return p.read_text(encoding="utf-8")
    except Exception:
        return ""


def build_engine_command(role: str, prompt: str):
    """对应 agent.sh：拼护栏 + 组装 claude/codex 命令。返回 (engine, model, full_prompt, argv)。"""
    eng, model = engine_for(role)
    guard = _guardrail(eng)
    full = prompt + (("\n\n" + guard) if guard else "")
    if eng == "codex":
        argv = ["codex", "exec", "--dangerously-bypass-approvals-and-sandbox",
                "--skip-git-repo-check", "-C", str(PROJ),
                "-c", "shell_environment_policy.inherit=all"]
        if model:
            argv += ["-m", model]
        argv += [full]
    else:
        argv = ["claude"]
        if model:
            argv += ["--model", model]
        pyx = py_exe()
        argv += ["-p", full, "--permission-mode", "default",
                 "--allowedTools", f"Bash({pyx} ccvar.py:*)", "Read", "Write", "Edit",
                 "Bash(ls:*)", "Bash(grep:*)", "Bash(wc:*)", "Bash(find:*)",
                 "--output-format", "text"]
    return eng, model, full, argv


# ---------- 撰稿提示词（对应 run-daily.sh 的 PROMPT 构建） ----------
def build_draft_prompt(slug: str) -> str:
    rec = site_record(slug) or {}
    name = rec.get("name") or slug
    topics = f"sites/{slug}/topics.md"
    queue = f"sites/{slug}/review-queue.md"
    pyx = py_exe()

    tw = scfg(slug, "target_words", "")
    try:
        length = f"约 {int(tw)} 字" if tw and int(tw) > 0 else "1500-2200 字"
    except (TypeError, ValueError):
        length = "1500-2200 字"
    code = "、有代码示例" if _truthy(scfg(slug, "include_code", True)) else ""

    prompt = (
        f"你现在在 CCVAR 内容运营工作区（当前目录），当前站点：{name}。"
        f"请严格按 automation/daily-draft.md 的步骤，为今天撰稿一篇技术草稿："
        f"先读本站选题库 {topics} 顶部的「网站定位」把握调性与受众，"
        f"并用 {pyx} ccvar.py list posts 避免撞题；"
        f"从 {topics} 的「待写队列」选题（队列空了就在「写作方向」范围内自己拟题），"
        f"写一篇 {length}、技术向{code}的 Markdown 文章，"
        f"用 {pyx} ccvar.py create posts 创建为 draft（务必 draft，绝不发布），"
        f"再更新 {topics} 与 {queue}，最后一句话回报草稿 ID 与标题。"
    )
    if _truthy(scfg(slug, "auto_category", True)):
        prompt += (f" 另外，请先运行 {pyx} ccvar.py categories 查看目录，"
                   f"按文章主题选最贴切的一个，create 时带上 --category-id <对应数字>。")
    else:
        prompt += " 本次不归类，create 不要带 --category-id。"

    wlang = scfg(slug, "write_lang", "zh") or "zh"
    if wlang != "zh":
        prompt += (f" 重要：本次写作语种={wlang}，请用该语种撰写全文，"
                   f"create 时务必 --lang {wlang}。")
    return prompt


# ---------- 运行引擎 ----------
def run_engine(role: str, prompt: str, slug: str = None, dry_run: bool = False):
    """执行引擎命令。dry_run 只打印不真跑（对应 AGENT_DRYRUN=1）。返回退出码。"""
    eng, model, full, argv = build_engine_command(role, prompt)
    if dry_run:
        print(f"[dry-run] role={role} engine={eng} model={model or '<默认>'}")
        print(f"[dry-run] 命令: {argv[0]} {argv[1] if len(argv) > 1 else ''} … （共 {len(argv)} 个参数）")
        return 0
    env = dict(os.environ)
    if slug:
        env["CCVAR_SITE"] = slug
    # codex 的 OpenAI Key（若有）
    if eng == "codex":
        env_file = PROJ / ".openai.env"
        if env_file.exists():
            for line in env_file.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if line.startswith("OPENAI_API_KEY=") and "=" in line:
                    env["OPENAI_API_KEY"] = line.split("=", 1)[1]
    try:
        return subprocess.call(argv, cwd=str(PROJ), env=env)
    except FileNotFoundError:
        sys.stderr.write(f"⚠ 找不到引擎命令 “{argv[0]}”，请先安装/登录该 CLI。\n")
        return 127
