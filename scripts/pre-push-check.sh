#!/usr/bin/env bash
# =============================================================================
# 推送前自检：冲突标记 / 超大文件 / 疑似密钥 / 调试残留 / 提交信息
# 只读检查，不修改任何文件。退出码非 0 表示有问题。
#
# 用法：bash scripts/pre-push-check.sh
# =============================================================================
set -uo pipefail

FAIL=0
step() { printf '\n\033[36m==> %s\033[0m\n' "$1"; }
ok()   { printf '    \033[32mOK\033[0m   %s\n' "$1"; }
bad()  { printf '    \033[31mFAIL\033[0m %s\n' "$1"; FAIL=1; }
warn() { printf '    \033[33mWARN\033[0m %s\n' "$1"; }

# 待检文件：优先比对 origin/main，没有就全量已跟踪文件
if git rev-parse --verify origin/main >/dev/null 2>&1; then
  BASE="$(git merge-base HEAD origin/main)"
  FILES=$(git diff --name-only --diff-filter=ACMR "$BASE"...HEAD)
  SCOPE="相对 origin/main 的改动"
else
  FILES=$(git ls-files)
  SCOPE="全部已跟踪文件（未找到 origin/main，可能还没推送过）"
fi

if [[ -z "$FILES" ]]; then
  echo "没有待检查的改动。"
  exit 0
fi

echo "检查范围：$SCOPE"

# ---------------------------------------------------------------- 1. 冲突标记
step "冲突标记"
HITS=$(echo "$FILES" | while read -r f; do
  [[ -f "$f" ]] || continue
  case "$f" in *.png|*.jpg|*.jpeg|*.gif|*.ico|*.pdf|*.zip|*.onnx|*.pt) continue ;; esac
  grep -Iq . "$f" 2>/dev/null || continue
  grep -nE '^(<<<<<<< |=======$|>>>>>>> )' "$f" 2>/dev/null | head -3 | sed "s|^|    $f:|"
done)
if [[ -n "$HITS" ]]; then
  bad "存在未解决的冲突标记："
  echo "$HITS"
else
  ok "无"
fi

# ---------------------------------------------------------------- 2. 超大文件
step "文件体积（上限 20MB）"
BIG=$(echo "$FILES" | while read -r f; do
  [[ -f "$f" ]] || continue
  SZ=$(wc -c < "$f" 2>/dev/null || echo 0)
  if [[ "$SZ" -gt 20971520 ]]; then
    printf '    %s  %s\n' "$(du -h "$f" | cut -f1)" "$f"
  fi
done)
if [[ -n "$BIG" ]]; then
  bad "以下文件超过 20MB，请改用 Git LFS 或项目网盘："
  echo "$BIG"
else
  ok "无"
fi

# ---------------------------------------------------------------- 3. 疑似密钥
step "疑似密钥与凭据"
SECRETS=$(echo "$FILES" | while read -r f; do
  [[ -f "$f" ]] || continue
  case "$f" in
    *.png|*.jpg|*.jpeg|*.gif|*.pdf|*.zip|*.onnx|*.pt|*.xlsx|*.docx|*.pptx) continue ;;
    *.env.example) continue ;;
  esac
  # 私钥只认完整 PEM 头（带五连横线），避免文档里提到关键词就误报
  grep -InE \
    -e '-----BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY-----' \
    -e 'AKID[0-9A-Za-z]{16,}' \
    -e 'sk-[A-Za-z0-9]{20,}' \
    -e 'ghp_[A-Za-z0-9]{20,}' \
    -e 'xox[baprs]-[A-Za-z0-9-]{10,}' \
    -e '(password|passwd|pwd|token|secret|api[_-]?key)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}' \
    "$f" 2>/dev/null | head -3 | sed "s|^|    $f:|"
done)
if [[ -n "$SECRETS" ]]; then
  bad "发现疑似密钥，请确认后再推："
  echo "$SECRETS"
else
  ok "无"
fi

# ---------------------------------------------------------------- 4. 敏感文件入库
step "敏感文件是否被跟踪"
TRACKED_BAD=$(echo "$FILES" | grep -E '(^|/)\.env$|(^|/)\.env\.(local|production|prod|dev)$|\.(pem|key|p12|pfx)$|(^|/)(secrets|\.ssh)/' || true)
if [[ -n "$TRACKED_BAD" ]]; then
  bad "以下敏感文件已被 git 跟踪："
  echo "$TRACKED_BAD" | sed 's/^/    /'
  echo "    移除： git rm --cached <文件>  →  轮换密钥  →  再考虑清历史"
else
  ok "无"
fi

# ---------------------------------------------------------------- 5. 调试残留
step "调试残留"
DEBUG=$(echo "$FILES" | while read -r f; do
  [[ -f "$f" ]] || continue
  case "$f" in
    *.md|*.png|*.jpg|*.pdf|*.lock|*lock.json|*lock.yaml|pnpm-lock.yaml|package-lock.json) continue ;;
    # 自检脚本自身含有这些关键字，跳过
    scripts/pre-push-check.*) continue ;;
  esac
  grep -InE '^[^#]*\b(console\.(log|debug)|debugger;|pdb\.set_trace\(\)|breakpoint\(\)|\.only\()' "$f" 2>/dev/null \
    | head -3 | sed "s|^|    $f:|"
done)
if [[ -n "$DEBUG" ]]; then
  warn "发现可能的调试残留（确认后再推）："
  echo "$DEBUG"
else
  ok "无"
fi

# ---------------------------------------------------------------- 6. 提交信息
step "最近提交信息格式"
LAST=$(git log -1 --pretty=%s 2>/dev/null || echo "")
if [[ -z "$LAST" ]]; then
  warn "还没有提交"
elif echo "$LAST" | grep -qE '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9_/-]+\))?: .+'; then
  ok "$LAST"
else
  bad "不符合 <type>(<scope>): <摘要> —— $LAST"
fi

# ---------------------------------------------------------------- 汇总
echo
if [[ "$FAIL" -ne 0 ]]; then
  printf '\033[31m自检未通过，先处理上面的 FAIL 项。\033[0m\n'
  exit 1
fi
printf '\033[32m自检通过，可以推送。\033[0m\n'
