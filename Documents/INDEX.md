# 文档索引

> Godot 4.6 · 誓约军地城（Skull Horde 系统对齐）· 中世纪奇幻 · harness 与美术素材保留

## 快速导航

| 文档 | 说明 |
|------|------|
| [GAME_VISION.md](./GAME_VISION.md) | 愿景、主循环、系统清单 |
| [Features/run_floors_and_victory.md](./Features/run_floors_and_victory.md) | 一局流程、楼层、胜负 |
| [Features/combat_threat_revive.md](./Features/combat_threat_revive.md) | 层内战斗、威胁、复活队列 |
| [Features/economy_shop_merge.md](./Features/economy_shop_merge.md) | 达克特、层间招兵、三合一 |
| [Features/oaths_and_bonds.md](./Features/oaths_and_bonds.md) | 誓约 / 羁绊 |
| [Features/corpus_and_relics.md](./Features/corpus_and_relics.md) | 尸骸与遗物商店 |
| [Features/meta_progress.md](./Features/meta_progress.md) | 永久成长边界 |
| [Features/delivery_phases.md](./Features/delivery_phases.md) | Phase A–G 分期与验收切片 |
| [Content/unit_roster.md](./Content/unit_roster.md) | 兵种中世纪命名 ↔ 现有贴图 |
| [DEVELOPMENT_WORKFLOW.md](./DEVELOPMENT_WORKFLOW.md) | Agent 职责、纵切片、L0–L5、轻量/完全验收 |
| [WEB_DEPLOY.md](./WEB_DEPLOY.md) | GitHub Pages 浏览器试玩 |
| [../AGENTS.md](../AGENTS.md) | 项目级工作规则 |
| [../CONTRIBUTING.md](../CONTRIBUTING.md) | Git / GDScript / 验收规范 |

## 设计文档约定

| 路径 | 用途 |
|------|------|
| `Documents/GAME_VISION.md` | 愿景与主循环 |
| `Documents/Features/` | 功能规格 |
| `Documents/Content/` | 内容库 / 花名册 |
| `Documents/archive/pre-skull-horde/` | **已废止**的小队游走原型规格（仅历史对照） |

书写遵守 [DEVELOPMENT_WORKFLOW.md](./DEVELOPMENT_WORKFLOW.md)「养成规范」：**当前不做的默认不写进规格**；全量对齐范围以愿景系统清单 + [delivery_phases.md](./Features/delivery_phases.md) 为准。

## 仓库结构（当前）

```
├── .cursor/agents|skills|rules
├── Documents/                    # 愿景 + Features + Content + 工作流
├── assets/ / art_source/         # 美术素材（paper_cutout 兵种优先）
├── resources/                    # 单位等数值资源（实现后）
├── scenes/main/main.tscn         # 主场景（As-Is 仍为旧原型）
├── scripts/                      # 玩法与烟测
├── tools/run_light_verify.sh
├── export_presets.cfg
└── .github/workflows/deploy-web.yml
```
