#!/usr/bin/env bash
# =============================================================================
# 把当前目录初始化为可多人协作的 Git 仓库（macOS / Linux / Git Bash）
#
# 用法：
#   bash scripts/init-repo.sh                          # 仅初始化 + 首个提交
#   bash scripts/init-repo.sh --remote git@host:o/r.git # 顺便设置 origin
#   bash scripts/init-repo.sh --branch main --no-commit
# =============================================================================
set -euo pipefail

BRANCH="main"
REMOTE=""
DO_COMMIT=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote)    REMOTE="$2"; shift 2 ;;
    --branch)    BRANCH="$2"; shift 2 ;;
    --no-commit) DO_COMMIT=0; shift ;;
    -h|--help)   sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done

step() { printf '\n\033[36m==> %s\033[0m\n' "$1"; }
say()  { printf '    %s\n' "$1"; }
warn() { printf '    \033[33m!! %s\033[0m\n' "$1"; }
fail() { printf '    \033[31mxx %s\033[0m\n' "$1" >&2; exit 1; }

# ---------------------------------------------------------------- 0. 环境
step "检查 git"
command -v git >/dev/null 2>&1 || fail "未安装 git"
say "$(git --version)"

ROOT="$(pwd)"
say "工作目录：$ROOT"

if [[ ! -f "$ROOT/.gitattributes" ]]; then
  warn "当前目录没有 .gitattributes —— 请确认在仓库根目录执行"
  read -r -p "    仍要继续？(y/N) " ans
  [[ "$ans" == "y" ]] || fail "已取消"
fi

# ---------------------------------------------------------------- 1. init
step "初始化仓库（主干分支 $BRANCH）"
if [[ -d "$ROOT/.git" ]]; then
  warn "已是 git 仓库，跳过 init，仅补齐配置"
else
  git init -b "$BRANCH" >/dev/null 2>&1 || { git init >/dev/null; git symbolic-ref HEAD "refs/heads/$BRANCH"; }
  say "已初始化"
fi

# ---------------------------------------------------------------- 2. 配置
step "写入仓库级配置"
while IFS='|' read -r k v; do
  git config "$k" "$v"
  printf '    %-22s = %s\n' "$k" "$v"
done <<'EOF'
core.autocrlf|false
core.safecrlf|warn
core.quotepath|false
core.longpaths|true
pull.rebase|true
fetch.prune|true
rebase.autoStash|true
commit.template|.gitmessage
merge.conflictStyle|zdiff3
EOF

# ---------------------------------------------------------------- 3. 身份
step "检查提交身份"
NAME="$(git config user.name || true)"
EMAIL="$(git config user.email || true)"
if [[ -z "$NAME" || -z "$EMAIL" ]]; then
  warn "未配置提交身份，无法提交。请先执行（换成你自己的）："
  printf '        git config --global user.name  "张三"\n'
  printf '        git config --global user.email "zhangsan@company.com"\n'
  exit 1
fi
say "$NAME <$EMAIL>"

# ---------------------------------------------------------------- 4. 大文件
step "扫描超大文件（> 20MB）"
BIG=$(find "$ROOT" -type f -size +20M \
        -not -path "*/.git/*" -not -path "*/node_modules/*" \
        -not -path "*/.venv/*" -not -path "*/venv/*" \
        -not -path "*/.codebuddy/*" 2>/dev/null || true)
if [[ -n "$BIG" ]]; then
  warn "发现超过 20MB 的文件，逐个确认是否需要入库："
  echo "$BIG" | head -20 | while read -r f; do
    printf '    %8s  %s\n' "$(du -h "$f" | cut -f1)" "${f#$ROOT/}"
  done
  warn "大文件建议放项目网盘；确需入库请先启用 Git LFS"
else
  say "无超大文件"
fi

# ---------------------------------------------------------------- 5. 暂存
step "暂存文件"
git add -A
STAGED=$(git diff --cached --name-only | wc -l | tr -d ' ')
say "已暂存 $STAGED 个文件"

# ---------------------------------------------------------------- 6. 敏感文件
step "检查敏感文件是否被暂存"
SUSP=$(git diff --cached --name-only | grep -E '(^|/)\.env$|(^|/)\.env\.(example)?$|\.(pem|key|p12|pfx)$|(^|/)(secrets|\.ssh)/' | grep -v '\.env\.example' || true)
if [[ -n "$SUSP" ]]; then
  warn "以下文件疑似含密钥，已被暂存："
  echo "$SUSP" | sed 's/^/    /'
  warn "不该入库的执行： git rm --cached <文件>"
else
  say "未发现敏感文件"
fi

# ---------------------------------------------------------------- 7. 提交
if [[ "$DO_COMMIT" -eq 0 ]]; then
  step "已跳过提交（--no-commit）"
elif [[ "$STAGED" -eq 0 ]]; then
  step "没有需要提交的内容"
else
  step "创建首个提交"
  git commit -q -F - <<'MSG'
chore: 初始化多人协作骨架

- 协作规范：CONTRIBUTING.md、docs/00 ~ docs/03
- 责任人机制：CODEOWNERS
- 工程约束：.gitattributes 统一换行、.gitignore 忽略生成物与敏感文件
- 提交与评审模板：.gitmessage、.github/
- 工具脚本：init-repo、pre-push-check
MSG
  say "$(git log --oneline -1)"
fi

# ---------------------------------------------------------------- 8. 远端
if [[ -n "$REMOTE" ]]; then
  step "设置远端"
  git remote remove origin 2>/dev/null || true
  git remote add origin "$REMOTE"
  say "origin = $REMOTE"
fi

# ---------------------------------------------------------------- 9. 收尾
step "完成"
cat <<EOF

    接下来：
      1) 到代码平台新建空仓库（不要勾选初始化 README）
      2) git remote add origin <地址>
         git push -u origin $BRANCH
      3) 在平台设置里保护 $BRANCH：禁止直推、要求 PR + 1 人 approve、只允许 squash
      4) 把 CODEOWNERS 里的 @xxx-placeholder 换成真实账号
      5) 去 WorkBuddy 项目里邀请成员，按 docs/00 的清单配好待办与网盘

EOF
