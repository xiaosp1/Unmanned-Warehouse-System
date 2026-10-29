# GitHub 仓库设置清单

> 仓库地址：<https://github.com/xiaosp1/Unmanned-Warehouse-System>
> 前置：本地已推送代码。若还没推，先做「一、推送」。
>
> 勾选式清单，全部做完约 10 分钟。**做完之前不要让其他人往仓库提交。**

---

## 一、推送（一次性）

### 方式 A：脚本一键完成（推荐）

```bash
export GITHUB_TOKEN=<你的 token>
bash scripts/push-to-github.sh
```

脚本会：验证权限 → 推送 → 比对远端 HEAD 与本地 → 尝试开启 `main` 分支保护。没有 admin 权限就打印手工步骤。

**Token 怎么拿**：

| 类型 | 地址 | 需要勾什么 |
| --- | --- | --- |
| 经典 token | <https://github.com/settings/tokens> | `repo` |
| 细粒度 token | <https://github.com/settings/tokens?type=beta> | 仓库选 `Unmanned-Warehouse-System`；`Contents: Read and write`；想自动开保护再加 `Administration: Read and write` |

### 方式 B：手工推送

```bash
cd "D:\01-DEMO\Unmanned Warehouse System"     # 或 clone 下来的目录
git remote add origin https://github.com/xiaosp1/Unmanned-Warehouse-System.git
git push -u origin main
```

推送时会要求输入账号密码 —— **密码处必须填 token**，GitHub 已不接受账号密码。

---

## 二、分支保护（必须做）

打开 <https://github.com/xiaosp1/Unmanned-Warehouse-System/settings/branches> → `Add branch protection rule`

- [ ] Branch name pattern 填 `main`
- [ ] **Require a pull request before merging**
  - [ ] Require approvals 填 `1`
  - [ ] Dismiss stale pull request approvals when new commits are pushed
- [ ] **Require conversation resolution before merging**
- [ ] **Do not allow bypassing the above settings**（管理员也不能直推）
- [ ] 不勾 `Allow force pushes`
- [ ] 不勾 `Allow deletions`
- [ ] Save changes

> 没做这一步，"多人维护"会在第一次有人 `push -f` 时就失效。

---

## 三、合并策略

`Settings → General → Pull Requests`

- [ ] 只勾 **Allow squash merging**，取消 `Merge commit` 与 `Rebase merging`
  → 主干历史一条一个功能，回滚干净
- [ ] 勾 **Automatically delete head branches**
  → 合并后分支自动删，避免仓库里堆几十个死分支
- [ ] 勾 **Allow auto-merge**（可选，评审通过后自动合）

---

## 四、邀请协作者（必须做）

`Settings → Collaborators → Add people`，逐个输入 GitHub 用户名。

| 谁 | 权限 | 说明 |
| --- | --- | --- |
| 项目负责人 | `Maintain` 或 `Admin` | Maintain 能管 PR 与分支，但不能删仓库 |
| 技术负责人 | `Maintain` | 同上 |
| 开发 / 测试 / 现场实施 | `Write` | 能推分支、提 PR，不能改设置 |
| 外部验收 / 甲方 | `Read` | 只看，不提改动 |

- [ ] 成员全部邀请完成
- [ ] 告诉每个人：**用 token 或 SSH 推送**，不要用密码

---

## 五、可见性（强烈建议）

仓库当前是 **Public**，任何人都能 fork、看历史。

- [ ] 如果项目涉及真实业务（库区布局、设备协议、客户数据），到
      `Settings → General → Danger Zone → Change visibility` 改为 **Private**

> Public 仓库还有个隐性风险：`.env` 一旦误提交，几分钟内就会被爬虫扫走。转 Private 能把损失控制住。

---

## 六、CODEOWNERS 生效（必须做）

本仓库已有 `CODEOWNERS`，但里面是占位账号。

- [ ] 打开 <https://github.com/xiaosp1/Unmanned-Warehouse-System/blob/main/CODEOWNERS>
- [ ] 把 `@owner-placeholder` 换成你的 GitHub 用户名（`@xiaosp1`）
- [ ] `@backend-placeholder` / `@frontend-placeholder` / `@edge-placeholder` / `@docs-placeholder` 同理
- [ ] 同步更新 `README.md` 第 6 节的联系人表（两处必须一致）
- [ ] 回分支保护页面勾上 **Require review from Code Owners**

> 验证方法：随便改一个 `src/backend/` 下的文件提 PR，看是否自动请求到后端责任人评审。

---

## 七、Issue 与 PR

仓库已内置 `.github/` 模板（Bug 报告 / 需求提案 / PR 模板），推送后自动生效。

- [ ] `Settings → General → Features` 确认 Issues 已开启
- [ ] 建议开启 **Discussions** 放讨论类内容，别都塞进 Issue
- [ ] 给仓库加 Topics：`warehouse` `automation` `agv` `wms`（便于检索，也提醒自己项目定位）

---

## 八、Actions（可选，但要早点决定）

CI 是"多人维护"的第二个保险（第一个是分支保护）。最小可用配置：

- [ ] 建 `.github/workflows/ci.yml`：PR 时跑 lint + 测试
- [ ] 把 CI 设为必需检查：`Settings → Branches → main → Require status checks to pass`

> 注意：如果仓库转 Private，GitHub Actions 有免费额度限制。团队小可以先用公开仓库 + 自建 runner，或只在本地跑 `scripts/pre-push-check.sh` 兜底。

---

## 九、完成后自检

按顺序试一遍，全部通过才算配置正确：

- [ ] 直接 `git push origin main` → **被拒绝**
- [ ] 开分支 `git switch -c test/protection`，改点东西推送 → 成功
- [ ] 提 PR → 能看到模板、能请求评审人
- [ ] 未经 approve 点 Merge → **被禁用**
- [ ] approve 后 squash 合并 → 成功，源分支自动删除
- [ ] 本地 `git pull` → 拿到合并结果

---

## 十、还要做但不在 GitHub 上的事

- 在 WorkBuddy 项目里邀请成员并分配角色 → 见 [00-WorkBuddy多人协作落地.md](./00-WorkBuddy多人协作落地.md) 第 4 步
- 建项目网盘目录 → 同上第 6 步
- 把本地已有源码迁进仓库 → 见 [02-开发环境与大文件.md](./02-开发环境与大文件.md) 第 4 节
