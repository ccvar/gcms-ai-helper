# gcms-ai-helper · CCVAR 撰稿助手

一个常驻 macOS 菜单栏的小工具：让 **Claude Code** 或 **OpenAI Codex** 通过 GCMS/CCVAR 站点的 Automation API，帮你**撰稿 → 审核 → 发布**内容。原生 AppKit 实现，点开菜单即用，无需记命令。

> 默认安全：未选择发布模式前**只生成草稿**，由你手动发布；站点密钥不入库。

## 功能

- **双引擎**：写作/审核可分别选 Claude Code（`claude`）或 OpenAI Codex（`codex`），在「全局设置」里的指示灯一键登录。
- **双模型流水线**：性价比模型出初稿 →「主编」模型审核、润色、给结论评分（✓荐发 / ⚠需你看 / ✗不建议）。
- **三种内容类型**：文章（posts）、页面（pages）、链接（links），各自独立配置。
- **三种发布模式**（每类型可分别设）：
  - **手动**：只撰稿，进「待审」等你发；
  - **半自动**：审核打分后到点自动发，期间可改可撤；
  - **全自动**：过审后留一个「否决窗口」，期间没拦截就自动发（受每日上限保护）。
- **多站点**：在「站点管理」里增删多个站点，每站独立密钥与配置，随时切换。
- **多语种**：用一种语言撰写，自动翻译为其它语种发布。
- **增强项**：自动归类、自动配图（封面）。
- **预览**：在线预览（接口支持时）/ 本地预览。

## 环境要求

- macOS 11 及以上。
- AI 引擎（按需，至少一个）：
  - Claude Code CLI —— 命令 `claude`；
  - OpenAI Codex CLI —— `npm install -g @openai/codex`，命令 `codex`。
  - 两者都能在 app 的「全局设置」里点指示灯登录/安装。
- 一个 GCMS/CCVAR 站点，并在其后台创建一条 **read + write** 权限的 Automation API 密钥。
- 从源码构建还需 Swift 工具链（`swiftc`，随 Xcode / Command Line Tools 提供）。

## 构建

```bash
# 编译菜单栏 app
swiftc build/menubar.swift -o build/CCVARHelper

# 打包成 .app（示例）
APP="CCVAR撰稿助手.app"
mkdir -p "$APP/Contents/MacOS"
cp build/CCVARHelper "$APP/Contents/MacOS/CCVARHelper"
cp build/Info.plist  "$APP/Contents/Info.plist"
codesign --force --deep -s - "$APP"   # 本地自签名
open "$APP"                            # 菜单栏出现图标
```

## 快速开始

1. 打开 app，菜单栏右上角出现图标，点开。
2. **站点管理 → 添加站点**：填站点名、`base_url`（形如 `https://你的域名/api/admin/v1`）、粘贴 API 密钥。
3. **全局设置**：选写作/审核引擎，点对应指示灯登录 `claude` 或 `codex`。
4. 点 **立刻撰稿一篇** 试跑；草稿进「待审」，你确认后发布。

更详细的图文说明见 `docs/help.html`（app 内「使用帮助」）。

## 安全

- 站点 API 密钥保存在 `sites/<slug>/site.env`，已被 `.gitignore` 排除，**不会进入仓库**。
- 工具默认只创建草稿；只有你显式选择「半自动 / 全自动」后才会自动发布。

## 目录结构

| 路径 | 说明 |
| --- | --- |
| `build/` | 菜单栏 app 源码（Swift / AppKit） |
| `automation/` | 自动化脚本：撰稿、审核、发布、翻译、配图、多站管理 |
| `ccvar.py` | Automation API 的命令行封装（list/get/create/update…） |
| `docs/help.html` | 使用帮助 |
| `assets/` | 图标与品牌 logo |
| `sites/` | 各站点配置（运行时生成；密钥文件不入库） |
| `config.json` | 全局配置（引擎/模型/时间/上限/语种缓存） |

本仓库**不内置任何站点**——克隆后在 app 里添加你自己的站点即可。
