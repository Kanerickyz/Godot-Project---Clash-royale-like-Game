# 文档索引

> 空白 Godot 4.6 工程 · harness / agent 工作流已保留 · 美术素材在 `assets/`、`art_source/`

## 快速导航

| 文档 | 说明 |
|------|------|
| [DEVELOPMENT_WORKFLOW.md](./DEVELOPMENT_WORKFLOW.md) | Agent 职责、纵切片流程、L0–L5、**轻量/完全验收** |
| [../AGENTS.md](../AGENTS.md) | 项目级工作规则 |
| [../CONTRIBUTING.md](../CONTRIBUTING.md) | Git / GDScript / 验收规范 |

## 设计文档约定

玩法规格落盘时使用：

| 路径 | 用途 |
|------|------|
| `Documents/GAME_VISION.md` | 愿景与主循环（按需新建） |
| `Documents/Features/` | 功能规格（按需新建） |
| `Documents/Content/` | 内容库 / 花名册（按需新建） |

当前仓库已清空旧游戏设计文档；新规格按 [DEVELOPMENT_WORKFLOW.md](./DEVELOPMENT_WORKFLOW.md)「养成规范」书写。

## 仓库结构（当前）

```
├── .cursor/agents|skills|rules   # Agent 角色与技能
├── Documents/                    # 工作流 + 未来规格
├── assets/ / art_source/         # 美术素材（已保留）
├── scenes/main/main.tscn         # 空白主场景
├── scripts/core/                 # 加载烟测 runner
└── tools/run_light_verify.sh     # 轻量验收入口
```
