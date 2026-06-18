"""系统托盘 App（pystray）。Windows 用系统托盘，macOS/Linux 用状态栏。

设计要点：
- 设置窗口走独立进程（--settings），避免 pystray 与 tkinter 抢主线程（两平台行为不同）。
- 撰稿在后台线程跑（子进程调 claude/codex），不卡界面；状态实时更新菜单。
pystray / Pillow 仅在此模块惰性导入，CLI 子命令无需它们也能用。
"""
import subprocess
import sys
import threading
import webbrowser

from . import core


def _self_cmd(*args):
    """构造"调用自身"的命令：PyInstaller 冻结后用 exe；否则用 python -m。"""
    if getattr(sys, "frozen", False):
        return [sys.executable, *args]
    return [sys.executable, "-m", "gcms_helper", *args]


def _icon_image():
    """用 Pillow 画一个简单的"内容卡片"图标（避免 SVG 依赖）。"""
    from PIL import Image, ImageDraw
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((6, 6, 58, 58), radius=12, fill=(40, 120, 240, 255))
    for i, y in enumerate((22, 32, 42)):
        w = 40 if i < 2 else 26
        d.rounded_rectangle((15, y, 15 + w, y + 5), radius=2, fill=(255, 255, 255, 255))
    return img


def _site_weburl(slug):
    rec = core.site_record(slug) or {}
    base = rec.get("base_url", "")
    return base.split("/api/")[0] if "/api/" in base else base


class TrayApp:
    def __init__(self):
        import pystray
        from pystray import Menu, MenuItem as Item
        self._pystray = pystray
        self.status = "就绪"
        self.busy = False
        menu = Menu(
            Item(lambda i: f"状态：{self.status}", None, enabled=False),
            Menu.SEPARATOR,
            Item("立刻撰稿一篇", self._on_draft),
            Item("打开站点", self._on_open_site),
            Item("设置…", self._on_settings),
            Menu.SEPARATOR,
            Item("退出", self._on_quit),
        )
        self.icon = pystray.Icon("gcms_helper", _icon_image(), "CCVAR 撰稿助手", menu=menu)

    # ---------- 菜单回调 ----------
    def _on_draft(self, icon, item):
        if self.busy:
            return
        slug = core.active_slug()
        if not slug:
            self._notify("还没有站点", "请先在「设置」里添加一个站点。")
            return
        threading.Thread(target=self._draft_worker, args=(slug,), daemon=True).start()

    def _draft_worker(self, slug):
        self.busy = True
        self._set_status("撰稿中…")
        try:
            prompt = core.build_draft_prompt(slug)
            rc = core.run_engine("writer", prompt, slug=slug)
            self._set_status("就绪")
            self._notify("撰稿完成" if rc == 0 else "撰稿出错",
                         "去「待审」查看草稿。" if rc == 0 else f"退出码 {rc}，查看日志。")
        except Exception as e:  # noqa: BLE001
            self._set_status("就绪")
            self._notify("撰稿出错", str(e))
        finally:
            self.busy = False

    def _on_open_site(self, icon, item):
        url = _site_weburl(core.active_slug())
        if url:
            webbrowser.open(url)

    def _on_settings(self, icon, item):
        try:
            subprocess.Popen(_self_cmd("--settings"))
        except Exception as e:  # noqa: BLE001
            self._notify("打不开设置", str(e))

    def _on_quit(self, icon, item):
        self.icon.stop()

    # ---------- 辅助 ----------
    def _set_status(self, s):
        self.status = s
        try:
            self.icon.update_menu()
        except Exception:
            pass

    def _notify(self, title, msg):
        try:
            self.icon.notify(msg, title)
        except Exception:
            pass

    def run(self):
        self.icon.run()


def main():
    TrayApp().run()


if __name__ == "__main__":
    main()
