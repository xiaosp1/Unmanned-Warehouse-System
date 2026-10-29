# 协作规范（CONTRIBUTING）

本文件是**入口**，只放"必须知道的那几条"。细则在 `docs/` 下，遇到争议以细则为准。

---

## 一、七条硬规则

1. **`main` 只接受 PR 合入。** 禁止直推、禁止 `push --force`。
2. **一个 PR 只做一件事。** 顺手重构请拆成独立 PR，否则评审者无法判断风险。
3. **改动别人的模块，必须拿到 CODEOWNERS 责任人的 approve。**
4. **提交前本地跑通。** 未验证的代码不进 PR，写清"怎么验的"。
5. **二进制与大数据不进 Git。** 单文件 > 20MB 一律走 Git LFS 或项目网盘。
6. **密钥、现场账号、真实客户数据不进仓库。** 用 `.env.example` 占位。
7. **分支存活不超过 5 天。** 拖长了就拆小，或先合一个可用的最小版本。

## 二、标准流程

```
拿待办 → 开分支 → 小步提交 → 自查 → 提 PR → 评审 → squash 合入 → 删分支 → 待办置完成
```

对应命令：

```bash
git switch main && git pull --rebase
git switch -c feat/WH-12-agv-task-dispatch

# ... 编码，小步提交 ...

git fetch origin && git rebase origin/main    # 提交前同步主干，冲突在自己分支解决
bash scripts/pre-push-check.sh                # 本地自检：冲突标记/大文件/疑似密钥
git push -u origin feat/WH-12-agv-task-dispatch
```

然后在代码平台上提 PR，按 `.github/pull_request_template.md` 填完整。

## 三、提交信息

格式：`<type>(<scope>): <摘要>`

```
feat(dispatch): 支持按电量阈值动态改派 AGV 任务
fix(inbound): 修复同一库位并发上架导致的库存覆盖
docs(collab): 补充分支命名与评审人配置说明
```

- `type` 取值：`feat` `fix` `docs` `style` `refactor` `perf` `test` `build` `ci` `chore`
- `scope` 用目录或模块名，小写
- 摘要用中文，一句话讲清"改完以后是什么样"，不加句号
- 正文写三段：**为什么改、改了什么、怎么验的**
- 关联待办：`Refs: WH-12`

模板已放在 `.gitmessage`，执行 `scripts/init-repo.*` 后 `git commit` 会自动带出。

## 四、评审

| 谁 | 做什么 |
| --- | --- |
| 提交者 | 自测通过、PR 描述完整、主动指定评审人、24h 内响应意见 |
| 评审人 | 24h 内给出结论；只提"必须改"和"建议改"两类，说清理由 |
| 合入者 | 确认 CI 绿、评审通过、无遗留讨论，用 **squash** 合入 |

评审关注点与合并前检查项见 [docs/03-评审与合并检查表.md](./docs/03-评审与合并检查表.md)。

## 五、分支与发布

见 [docs/01-仓库与分支规范.md](./docs/01-仓库与分支规范.md)。

## 六、环境与文件体积

见 [docs/02-开发环境与大文件.md](./docs/02-开发环境与大文件.md)。

## 七、在 WorkBuddy 项目里怎么配合

代码走 Git，**过程走项目和待办**：

- 任务从「项目待办」领，不要口头分配
- 讨论过多的问题，结论回写到 PR 或 `docs/`，别只留在聊天里
- 设计稿、现场视频、点云、验收材料放项目网盘，仓库里只留链接

详见 [docs/00-WorkBuddy多人协作落地.md](./docs/00-WorkBuddy多人协作落地.md)。
