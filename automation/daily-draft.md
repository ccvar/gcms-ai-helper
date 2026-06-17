# 每日自动撰稿 · Runbook

> 定时任务每天早上 8:00 触发，执行本文件的步骤。全程处于 **仅草稿** 安全模式：只创建 draft，绝不发布。

工作目录：`/Users/apple/work/test.ccvar`

## 步骤

1. **避免撞题**：先看现有内容，拿到已有标题：
   ```bash
   python3 ccvar.py list posts --limit 100
   ```
   再读 `topics.md` 的「已写」和「待写队列」。

2. **选题**：
   - 「待写队列」非空 → 取最上面一条作为今天的选题。
   - 队列为空 → 在「写作方向」范围内生成 3 个新选题，追加到「待写队列」（避开已写/已发布过的标题），再取第一条。

3. **写作**：用站点既有的技术风格写一篇中文 Markdown 文章，约 1500–2200 字：
   - 技术向、具体、有代码示例、有取舍判断，不注水。
   - 标题清晰；正文不重复标题。
   - 先把正文写入 `drafts/<slug>.md`，再用 `--content-file` 传入（避免转义）。

4. **选目录 + 创建草稿**（务必 draft）：
   （启用「自动归类」时）先看目录，按主题选最贴切的一个：
   ```bash
   python3 ccvar.py categories     # 1=工程 2=SEO 3=设计 4=工具 5=思考
   ```
   再创建（`--category-id` 换成你选的数字；未启用归类就省略该行）：
   ```bash
   python3 ccvar.py create posts \
     --title "<标题>" --content-file drafts/<slug>.md \
     --lang zh --slug "<英文-kebab-slug>" \
     --category-id <目录数字> \
     --excerpt "<1–2 句摘要>" \
     --meta-desc "<SEO 描述>" \
     --keywords "<逗号分隔关键词>"
   ```
   记下返回的草稿 `id`。

5. **更新选题库**：把今天的选题从「待写队列」删除，按格式追加到 `topics.md` 的「已写」：
   `- <日期> · <标题> · #<id>`

6. **登记待审**：把一行追加到 `review-queue.md`：
   `- [ ] <日期> · #<id> · <标题> · /zh/posts/<slug>`

7. **回报**：一句话总结今天撰稿了什么、草稿 ID，并提醒到后台审核发布。

## 红线

- 只创建 `draft`。除非人工明确要求，绝不设 `published` / `scheduled`。
- 改已有内容前，先用 `list ... --q 关键词` 查准 ID，不靠标题猜。
- 密钥只从 `.ccvar.env` 读取，绝不写进文章、日志或提交记录。
