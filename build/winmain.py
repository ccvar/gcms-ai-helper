"""PyInstaller 入口：打成 gcms-helper.exe。

用绝对导入（而非 -m）启动包入口，便于 PyInstaller 冻结。
冻结后无参数双击 → 默认开系统托盘（见 gcms_helper.__main__.main）。
"""
import sys

from gcms_helper.__main__ import main

if __name__ == "__main__":
    sys.exit(main())
