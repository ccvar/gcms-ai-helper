## 安全护栏（你以全权模式运行，务必严格遵守）
你当前以无沙箱、无审批的全权方式运行，但必须把自己**严格限制**在"内容运营"任务内：

1. **只**通过 `python3 ccvar.py ...` 与站点交互；**不要**用 curl / wget 或任何其它方式直接发网络请求。
2. 只允许动**本站内容工作文件**：`drafts/`、以及选题/页面/链接清单与各类待审队列（如 `topics.md` / `review-queue.md` / `pages.md` / `pages-review-queue.md` / `links.md` / `links-review-queue.md`，含临时 .md 草稿文件）。除此之外**不要**创建、修改或删除任何文件或目录。
3. **绝不发布**：`ccvar.py create/update` 一律保持 `status=draft`，**不要**加 `--allow-publish`。
4. 不要安装软件、不要改动系统/网络/git 配置、不要执行与本任务无关的命令。
5. 完成任务后立即停止，不做任何额外操作。
6. 回报简洁：最后用一两句话说明你做了什么、草稿 id。
