---
name: ccvar
description: 运营 CCVAR 简记网站（ccvar.com）的内容。当用户想在自己的站点发布、起草、修改或查询 文章(posts)、页面(pages)、链接(links) 时使用。通过 CCVAR Automation API 操作，默认只创建草稿（安全模式）。Use when publishing, drafting, editing, or looking up content on the user's CCVAR blog/CMS.
---

# CCVAR 简记 · 内容运营

帮用户通过 CCVAR Automation API 运营内容站。**当前为『仅草稿』安全模式**：只创建/修改草稿，从不直接发布——发布由用户自己在后台完成。

## 调用方式

所有 API 调用都走项目根目录的 `ccvar.py`（它从 `.ccvar.env` 读密钥、安全编码 JSON、并拦截误发布）：

```bash
python3 ccvar.py list posts --lang zh --status draft --limit 10   # 查列表
python3 ccvar.py get posts 123                                    # 看某篇
python3 ccvar.py create posts --title "标题" --content-file /tmp/body.md --lang zh
python3 ccvar.py update posts 123 --meta-desc "新的 SEO 描述"
```

正文较长或含引号/特殊字符时，**先把 Markdown 写入临时文件，再用 `--content-file` 传**，避免 shell 转义出错。需要完全自定义字段时用 `--data-file payload.json`。

## 接口速览

- 基础地址：`https://ccvar.com/api/admin/v1`
- 资源：`posts` 文章 / `pages` 页面 / `links` 链接 —— 均支持 列表 / 创建 / 读取 / 更新（**无删除**）
- 鉴权：请求头 Bearer，密钥在 `.ccvar.env`（已 gitignore，建议 chmod 600）
- 权限分档：`read` 读 · `write` 写草稿 · `publish` 发布。本模式只需 read + write

## 字段

| 字段 | 说明 |
|---|---|
| `title` | 标题，创建文章/页面时必填 |
| `content` | 正文，Markdown |
| `slug` | URL 短路径，留空按标题自动生成 |
| `excerpt` / `meta_desc` / `keywords` | 摘要 / SEO 描述 / 关键词 |
| `status` | draft / published / scheduled（本模式只用 draft） |
| `published_at` | 定时发布时必填，RFC3339 或 `2006-01-02T15:04` |
| `category_id` | 文章/链接可用；页面不支持 |
| `link_url` | 链接资源的目标地址 |
| `lang` | 语种，如 zh / en |

列表查询参数：`lang`、`status`、`q`(关键词)、`slug`、`limit`、`offset`

## 运营规则（重要）

1. **默认草稿**：创建/修改都以 `draft` 落地，绝不擅自发布；该发布时提醒用户去后台点。
2. **改之前先查 ID**：要改某篇内容，先 `list ... --q 关键词` 查到准确 ID，不要凭标题猜；多条匹配就列出来让用户确认。
3. **语种**：默认 zh；多语种内容先确认 `lang`。
4. **SEO**：建文时顺手补好 `excerpt` / `meta_desc` / `keywords`。
5. **回报**：创建草稿后，把返回的 ID 和「请到后台审核并发布」一起告诉用户。
