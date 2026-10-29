# 无人仓系统 / Unmanned Warehouse System

> 面向无人化仓储场景的调度、控制与可视化系统。本仓库为**多人协同维护**的主副本，`main` 分支始终可运行。

**仓库地址**：<https://github.com/xiaosp1/Unmanned-Warehouse-System>
**协议**：MIT（见 [LICENSE](./LICENSE)）

---

## 0. 新人三分钟上手

```bash
git clone https://github.com/xiaosp1/Unmanned-Warehouse-System.git
cd Unmanned-Warehouse-System

# 首次配置（写本地 git 身份与协作相关设置）
powershell -ExecutionPolicy Bypass -File scripts/init-repo.ps1     # Windows
bash scripts/init-repo.sh                                          # macOS / Linux
```

然后读 [CONTRIBUTING.md](./CONTRIBUTING.md) 的七条硬规则，从项目待办里领一个任务开工。

---

## 1. 项目定位

| 项 | 内容 |
| --- | --- |
| 业务目标 | `TODO(首个提交者补充)：如"仓储出入库全流程无人化，AGV/AMR 调度 + 库位管理 + 实时可视化"` |
| 当前阶段 | `TODO：Demo / 试点 / 生产` |
| 主干分支 | `main`（受保护，仅通过 Pull Request 合入） |
| 协作方式 | Git 分支开发 + PR 评审；文档与素材同步至项目网盘 |
| 项目空间 | WorkBuddy 项目「Unmanned Warehouse System」 |

## 2. 目录结构

```
.
├─ README.md                  # 本文件：项目入口
├─ CONTRIBUTING.md            # 协作规范总入口
├─ CODEOWNERS                 # 模块责任人（决定谁必须评审）
├─ docs/                      # 设计与协作文档
│  ├─ 00-WorkBuddy多人协作落地.md
│  ├─ 01-仓库与分支规范.md
│  ├─ 02-开发环境与大文件.md
│  └─ 03-评审与合并检查表.md
├─ scripts/                   # 初始化与自检脚本
├─ src/
│  ├─ backend/                # 业务服务：库位/任务/订单/接口层
│  ├─ frontend/               # 可视化看板、管理端
│  ├─ edge/                   # 设备接入：AGV/AMR、输送线、扫码、PLC 网关
│  └─ shared/                 # 跨端共享：协议定义、数据模型、常量
├─ deploy/                    # 部署编排、环境变量样例
└─ assets/                    # 少量必要的小体积图示（大文件走网盘）
```

> 分层是**建议起点**，不是强制。确需调整时，先在 PR 里说明理由，再动手。

## 3. 快速开始

```bash
git clone <远端地址> unmanned-warehouse-system
cd unmanned-warehouse-system

# 首次进入，先跑一遍初始化（写本地 git 配置、校验环境）
# Windows / PowerShell
powershell -ExecutionPolicy Bypass -File scripts/init-repo.ps1
# macOS / Linux / Git Bash
bash scripts/init-repo.sh
```

各子模块的依赖安装与启动命令，写进对应 `src/*/README.md`：

```bash
# 示例，按实际实现替换
cd src/backend && pip install -r requirements.txt && python -m app
cd src/frontend && pnpm install && pnpm dev
```

## 4. 多人协作，先读这三件事

1. **不要直接往 `main` 推。** 一律 `feat/*`、`fix/*` 短分支 + PR。
2. **动别人的模块，先找 CODEOWNERS 里的责任人。** 评审通过再合。
3. **二进制与大数据不进 Git。** 视频、点云、模型权重、现场照片放项目网盘。

完整规则见 [CONTRIBUTING.md](./CONTRIBUTING.md)；WorkBuddy 项目侧的成员/待办/网盘怎么配，见 [docs/00-WorkBuddy多人协作落地.md](./docs/00-WorkBuddy多人协作落地.md)。

## 5. 分支与版本

| 分支 | 用途 | 生命周期 |
| --- | --- | --- |
| `main` | 随时可部署的主干 | 永久 |
| `feat/<待办号>-<简述>` | 新功能 | ≤ 5 天 |
| `fix/<待办号>-<简述>` | 缺陷修复 | ≤ 2 天 |
| `hotfix/<简述>` | 线上紧急修复，合完即打 tag | ≤ 1 天 |
| `docs/<简述>` | 仅文档改动 | ≤ 3 天 |

发布用语义化 tag：`v1.2.0`。变更记录写在 GitHub/Gitee Release 里。

## 6. 联系方式

| 角色 | 人 | 负责范围 |
| --- | --- | --- |
| 项目负责人 | `TODO` | 排期、合入决策、发布 |
| 后端 | `TODO` | `src/backend` |
| 前端/可视化 | `TODO` | `src/frontend` |
| 设备接入 | `TODO` | `src/edge` |

> 上表与 `CODEOWNERS` 必须同步维护。人走了不删，只在 WorkBuddy 项目里把成员状态置为离场。
