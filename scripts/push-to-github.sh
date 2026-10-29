#!/usr/bin/env bash
# =============================================================================
# 一条命令完成推送 + 校验 + 尝试开启 main 分支保护
#
# 用法：
#   export GITHUB_TOKEN=ghp_xxx          # 必填，需要 repo 权限（经典）或 Contents+Administration 写权限（细粒度）
#   bash scripts/push-to-github.sh
#
# 说明：
#   - 用 token 推送，不写入 git config，也不落盘
#   - 推送后自动比对远端 HEAD 与本地 main 是否一致
#   - 分支保护接口需要 token 有 admin 权限；没有就只打印手工设置步骤
# =============================================================================
set -uo pipefail

OWNER="xiaosp1"
REPO="Unmanned-Warehouse-System"
BRANCH="main"
API="https://api.github.com/repos/${OWNER}/${REPO}"

step() { printf '\n\033[36m==> %s\033[0m\n' "$1"; }
ok()   { printf '    \033[32mOK\033[0m   %s\n' "$1"; }
bad()  { printf '    \033[31mFAIL\033[0m %s\n' "$1"; }
warn() { printf '    \033[33mWARN\033[0m %s\n' "$1"; }

cd "$(git rev-parse --show-toplevel)" || exit 1

# ---------------------------------------------------------------- 0. 前置检查
step "检查前置条件"
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  bad "未设置 GITHUB_TOKEN"
  cat <<'EOF'

    获取方式（选一种）：
      A. 经典 token： https://github.com/settings/tokens  → 勾选 repo
      B. 细粒度 token：https://github.com/settings/tokens?type=beta
         Repository access 选 Unmanned-Warehouse-System
         Permissions → Contents: Read and write
                       Administration: Read and write（想自动开分支保护就选）

    然后重新执行：
      export GITHUB_TOKEN=<你的token>
      bash scripts/push-to-github.sh

EOF
  exit 1
fi
ok "token 已提供（长度 ${#GITHUB_TOKEN}）"

if [[ -n "$(git status --porcelain)" ]]; then
  warn "工作区有未提交的改动，推送的仍是已提交内容"
fi

# ---------------------------------------------------------------- 1. 连通性
step "验证 token 与仓库写入权限"
CODE=$(curl -s -o /tmp/gh_repo.json -w '%{http_code}' \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        "$API")
if [[ "$CODE" != "200" ]]; then
  bad "读取仓库失败（HTTP $CODE）"
  head -c 300 /tmp/gh_repo.json; echo
  exit 1
fi
PERM=$(python3 -c "import json;d=json.load(open('/tmp/gh_repo.json'));print((d.get('permissions') or {}).get('push'))" 2>/dev/null || echo "")
if [[ "$PERM" == "True" || "$PERM" == "true" ]]; then
  ok "有 push 权限"
else
  warn "接口未返回 push 权限标记，继续尝试推送"
fi

# ---------------------------------------------------------------- 2. 推送
step "推送到 ${OWNER}/${REPO} (${BRANCH})"
BEFORE=$(curl -s -H "Authorization: Bearer ${GITHUB_TOKEN}" "$API/git/ref/heads/${BRANCH}" \
         | python3 -c "import sys,json;print(json.load(sys.stdin).get('object',{}).get('sha',''))" 2>/dev/null || echo "")
[[ -n "$BEFORE" ]] && ok "远端当前 HEAD：${BEFORE:0:7}"

git push "https://x-access-token:${GITHUB_TOKEN}@github.com/${OWNER}/${REPO}.git" "${BRANCH}:${BRANCH}"
PUSH_RC=$?

if [[ $PUSH_RC -ne 0 ]]; then
  bad "推送失败（退出码 $PUSH_RC）"
  cat <<'EOF'

    常见原因：
      - token 没有 Contents: write 权限 → 重新生成并勾选
      - token 已过期 → 重新生成
      - 网络不通 → 检查代理；或改用 SSH：git push git@github.com:owner/repo.git
      - 远端有本地没有的提交 → 先 git pull --rebase origin main

EOF
  exit $PUSH_RC
fi
ok "推送完成"

# ---------------------------------------------------------------- 3. 校验
step "校验远端与本地一致"
sleep 2
AFTER=$(curl -s -H "Authorization: Bearer ${GITHUB_TOKEN}" "$API/git/ref/heads/${BRANCH}" \
        | python3 -c "import sys,json;print(json.load(sys.stdin).get('object',{}).get('sha',''))" 2>/dev/null || echo "")
LOCAL=$(git rev-parse HEAD)
if [[ "$AFTER" == "$LOCAL" ]]; then
  ok "远端 HEAD = 本地 HEAD = ${LOCAL:0:7}"
else
  warn "远端 ${AFTER:0:7} ≠ 本地 ${LOCAL:0:7}（可能刚推送缓存未更新，稍后刷新页面确认）"
fi

# ---------------------------------------------------------------- 4. 分支保护
step "尝试开启 main 分支保护"
PROT_BODY=$(cat <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
)
PCODE=$(curl -s -o /tmp/gh_prot.json -w '%{http_code}' -X PUT \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        -d "$PROT_BODY" "$API/branches/${BRANCH}/protection")

if [[ "$PCODE" == "200" ]]; then
  ok "main 已保护：禁止直推 / 禁止 force push / 禁止删除 / 需 1 人 approve"
  warn "注意：仓库是公开的且只有一个协作者，建议到 Settings → General → Danger Zone"
  warn "      把仓库转为 Private，否则任何人都能 fork 并提交 PR"
else
  warn "自动设置失败（HTTP $PCODE），需手工设置"
  cat <<'EOF'

    手工设置（约 2 分钟）：
      1) 打开 https://github.com/xiaosp1/Unmanned-Warehouse-System/settings/branches
      2) Add branch protection rule → Branch name pattern 填 main
      3) 勾选：
         □ Require a pull request before merging
             └ Require approvals: 1
             └ Dismiss stale pull request approvals when new commits are pushed
         □ Require conversation resolution before merging
         □ Do not allow bypassing the above settings
      4) 不勾：Allow force pushes、Allow deletions
      5) Save changes

EOF
fi

step "完成"
cat <<EOF

    仓库地址：https://github.com/${OWNER}/${REPO}
    下一步  ：
      1) Settings → Collaborators 邀请成员（逐个输入 GitHub 用户名）
      2) Settings → General 决定是否转 Private
      3) 每人把 CODEOWNERS 里的占位账号换成真实用户名，提 PR 合入

EOF
