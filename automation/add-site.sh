#!/bin/bash
# 添加一个站点：注册到 sites.json + 建 sites/<slug>/{site.env,config.json,topics.md,review-queue.md,drafts/}。
# 用法: add-site.sh <slug> <name> <base_url> <api_key>
set -u
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJ" || exit 1
SLUG="${1:-}"; NAME="${2:-}"; BASE="${3:-}"; KEY="${4:-}"
{ [ -z "$SLUG" ] || [ -z "$NAME" ] || [ -z "$BASE" ]; } && { echo "用法: add-site.sh <slug> <name> <base_url> <api_key>"; exit 1; }
# slug 规范化：仅小写字母数字连字符
SLUG="$(printf '%s' "$SLUG" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')"
[ -z "$SLUG" ] && { echo "ERR: slug 非法（需含 a-z0-9-）"; exit 1; }

DIR="sites/$SLUG"
mkdir -p "$DIR/drafts"
printf 'CCVAR_API_KEY=%s\n' "$KEY" > "$DIR/site.env"; chmod 600 "$DIR/site.env"
[ -f "$DIR/config.json" ] || cat > "$DIR/config.json" <<'JSON'
{
  "publish_mode": "manual",
  "veto_hours": 6,
  "auto_category": true,
  "auto_cover": false,
  "write_lang": "zh",
  "translate_langs": [],
  "lang_mode": "translate"
}
JSON
[ -f "$DIR/topics.md" ] || cat > "$DIR/topics.md" <<EOF
# $NAME · 选题库

怎么填：站上已有发布文章 → 点菜单「校准网站定位…」让 AI 自动填；
全新空站 → 照下面【示例】把「网站定位」「写作方向」改成你自己的（删掉示例行）。

## 网站定位（这网站是干嘛的 · AI 据此把握调性与受众）

（用一段话写清：写给谁看、写什么、什么调性。
示例：面向独立开发者的技术博客，聚焦 Web 全栈与工程实践，务实、带可运行代码示例。
↑ 把上面这句改成你自己的网站定位。）

## 写作方向（允许的主题范围 = 边界 · AI 只在这里面自动补题）

- **示例·后端工程**：API 设计、数据库、性能优化（照这行格式改成你的方向，每行一个）
- **示例·前端实践**：框架、构建、交互细节（不想要的方向删掉；AI 只在这些范围里补题）

## 待写队列（从上往下取；写完自动移到「已写」）


## 已写（自动追加：日期 · 标题 · 草稿ID）

EOF
[ -f "$DIR/review-queue.md" ] || printf '# 待审草稿队列\n\n' > "$DIR/review-queue.md"

python3 - "$SLUG" "$NAME" "$BASE" <<'PY'
import json, sys
slug, name, base = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open("sites.json"))
if any(s.get("slug") == slug for s in d.get("sites", [])):
    print("ERR: slug 已存在"); raise SystemExit(2)
d.setdefault("sites", []).append({"slug": slug, "name": name, "base_url": base, "enabled": True})
if not d.get("active"):          # 第一个站 → 设为活动站（修复加站后菜单不显示）
    d["active"] = slug
json.dump(d, open("sites.json", "w"), ensure_ascii=False, indent=2)
PY
[ $? -ne 0 ] && exit 2
echo "ADDED $SLUG"
CCVAR_SITE="$SLUG" bash automation/refresh-langs.sh >/dev/null 2>&1 || true   # 预热语种缓存（可能失败，不影响）
