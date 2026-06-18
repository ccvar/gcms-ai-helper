"""gcms_helper —— 跨平台（macOS / Windows / Linux）内容运营核心。

复用项目根目录的 ccvar.py（Automation API 客户端，纯标准库）、sites.json、
sites/<slug>/config.json、automation/prompts/*.md，把原 bash 编排改写为 Python，
让同一套撰稿/审核/发布逻辑能在 Windows 上运行（Mac 端仍可用原生 App + bash）。
"""
__version__ = "0.1.0"
