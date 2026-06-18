"""设置窗口（tkinter·标准库·跨平台）。独立进程运行：python -m gcms_helper.settings_ui

提供新手最少需要的配置：AI 引擎选择、站点的增加/选活动/删除/改密钥。
引擎的登录（claude setup-token / codex login）仍在终端完成，这里给出提示。
"""
import tkinter as tk
from tkinter import messagebox, ttk

from . import core, manage

ENGINES = ["claude", "codex"]


class SettingsApp:
    def __init__(self, root: tk.Tk):
        self.root = root
        root.title("CCVAR 撰稿助手 · 设置")
        root.geometry("520x560")
        root.minsize(480, 520)

        pad = {"padx": 12, "pady": 6}

        # ——— AI 引擎 ———
        eng = ttk.LabelFrame(root, text="AI 引擎")
        eng.pack(fill="x", **pad)
        gc = core.global_config()
        self.writer = tk.StringVar(value=gc.get("writer_engine", "claude") or "claude")
        self.editor = tk.StringVar(value=gc.get("editor_engine", "claude") or "claude")
        row = ttk.Frame(eng); row.pack(fill="x", padx=10, pady=8)
        ttk.Label(row, text="写作引擎").grid(row=0, column=0, sticky="w")
        ttk.Combobox(row, textvariable=self.writer, values=ENGINES, state="readonly",
                     width=12).grid(row=0, column=1, padx=8)
        ttk.Label(row, text="审核引擎").grid(row=0, column=2, sticky="w", padx=(16, 0))
        ttk.Combobox(row, textvariable=self.editor, values=ENGINES, state="readonly",
                     width=12).grid(row=0, column=3, padx=8)
        ttk.Button(row, text="保存引擎", command=self.save_engines).grid(row=0, column=4, padx=8)
        ttk.Label(eng, text="登录：Claude 用终端 claude setup-token；GPT 用终端 codex login。",
                  foreground="#888").pack(anchor="w", padx=10, pady=(0, 8))

        # ——— 站点 ———
        sf = ttk.LabelFrame(root, text="站点")
        sf.pack(fill="both", expand=True, **pad)
        self.listbox = tk.Listbox(sf, height=6)
        self.listbox.pack(fill="both", expand=True, padx=10, pady=8)
        btns = ttk.Frame(sf); btns.pack(fill="x", padx=10, pady=(0, 8))
        ttk.Button(btns, text="设为活动站", command=self.make_active).pack(side="left")
        ttk.Button(btns, text="改密钥", command=self.change_key).pack(side="left", padx=6)
        ttk.Button(btns, text="删除", command=self.delete_site).pack(side="left")

        # ——— 添加站点 ———
        af = ttk.LabelFrame(root, text="添加站点")
        af.pack(fill="x", **pad)
        grid = ttk.Frame(af); grid.pack(fill="x", padx=10, pady=8)
        self.e_name = self._field(grid, "名称", 0)
        self.e_base = self._field(grid, "API 域名", 1, hint="https://你的站.com/api/admin/v1")
        self.e_key = self._field(grid, "API 密钥", 2, show="•")
        ttk.Button(af, text="添加", command=self.add_site).pack(anchor="e", padx=10, pady=(0, 10))

        self.refresh()

    def _field(self, parent, label, r, hint="", show=""):
        ttk.Label(parent, text=label, width=8).grid(row=r, column=0, sticky="w", pady=3)
        var = tk.StringVar()
        ent = ttk.Entry(parent, textvariable=var, width=44, show=show)
        ent.grid(row=r, column=1, sticky="we", pady=3)
        parent.columnconfigure(1, weight=1)
        if hint:
            ent.insert(0, "")
            ttk.Label(parent, text=hint, foreground="#aaa").grid(row=r, column=2, sticky="w", padx=6)
        return var

    # ---------- 数据 ----------
    def refresh(self):
        self.listbox.delete(0, tk.END)
        self._slugs = []
        for slug, name, base, active in core.list_sites():
            mark = "● " if active else "  "
            self.listbox.insert(tk.END, f"{mark}{slug}  ·  {name}  ·  {base}")
            self._slugs.append(slug)

    def _selected_slug(self):
        sel = self.listbox.curselection()
        if not sel:
            messagebox.showinfo("提示", "请先在列表里选中一个站点。")
            return None
        return self._slugs[sel[0]]

    # ---------- 动作 ----------
    def save_engines(self):
        ok, msg = manage.set_engines(writer_engine=self.writer.get(), editor_engine=self.editor.get())
        messagebox.showinfo("引擎", msg if ok else f"失败：{msg}")

    def make_active(self):
        slug = self._selected_slug()
        if not slug:
            return
        ok, msg = manage.set_active(slug)
        self.refresh()
        messagebox.showinfo("活动站", msg if ok else f"失败：{msg}")

    def change_key(self):
        slug = self._selected_slug()
        if not slug:
            return
        win = tk.Toplevel(self.root)
        win.title(f"改密钥 · {slug}")
        win.geometry("420x120")
        ttk.Label(win, text="新的 API 密钥").pack(anchor="w", padx=12, pady=(12, 2))
        var = tk.StringVar()
        ttk.Entry(win, textvariable=var, width=46, show="•").pack(padx=12)

        def do():
            ok, msg = manage.set_key(slug, var.get().strip())
            win.destroy()
            messagebox.showinfo("密钥", msg if ok else f"失败：{msg}")
        ttk.Button(win, text="保存", command=do).pack(anchor="e", padx=12, pady=10)

    def delete_site(self):
        slug = self._selected_slug()
        if not slug:
            return
        if not messagebox.askyesno("删除站点", f"确定删除站点「{slug}」及其本地数据？此操作不可撤销。"):
            return
        ok, msg = manage.remove_site(slug, delete_files=True)
        self.refresh()
        messagebox.showinfo("删除", msg if ok else f"失败：{msg}")

    def add_site(self):
        name = self.e_name.get().strip()
        base = self.e_base.get().strip()
        key = self.e_key.get().strip()
        slug = manage.normalize_slug(name) or "site"
        # 若同名 slug 已存在，自动加序号
        existing = {s for s in getattr(self, "_slugs", [])}
        s, i = slug, 2
        while s in existing:
            s = f"{slug}{i}"; i += 1
        ok, msg = manage.add_site(s, name, base, key)
        if ok:
            self.e_name.set(""); self.e_base.set(""); self.e_key.set("")
            self.refresh()
        messagebox.showinfo("添加站点", msg if ok else f"失败：{msg}")


def main():
    root = tk.Tk()
    SettingsApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
