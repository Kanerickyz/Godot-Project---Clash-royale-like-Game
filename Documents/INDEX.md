# 文档索引

> Godot 4.6 · 城际跑商沙盒（双层）· harness 与美术素材保留

## 快速导航

| 文档 | 说明 |
|------|------|
| [GAME_VISION.md](./GAME_VISION.md) | 愿景与主循环（城际跑商沙盒） |
| [Features/city_trade_sandbox.md](./Features/city_trade_sandbox.md) | 双层城池 / 跑商 / 遭遇 / 金币计分 |
| [Features/squad_roam_prototype.md](./Features/squad_roam_prototype.md) | 旧：小队游走招募原型（机制参考；主循环已替换） |
| [Features/boss_summon_charge.md](./Features/boss_summon_charge.md) | 召唤冲撞 Boss（机制参考；本愿景不做通关 Boss） |
| [Features/roguelike_map_spawn.md](./Features/roguelike_map_spawn.md) | 程序化地图与刷怪/箱（战斗层可复用思路） |
| [Features/combat_shop_spawn_polish.md](./Features/combat_shop_spawn_polish.md) | 撞飞手感 / 商店刷新 / 刷怪加速等 |
| [DEVELOPMENT_WORKFLOW.md](./DEVELOPMENT_WORKFLOW.md) | Agent 职责、纵切片流程、L0–L5、**轻量/完全验收** |
| [WEB_DEPLOY.md](./WEB_DEPLOY.md) | GitHub Pages 浏览器试玩（Actions 导出 Web） |
| [../AGENTS.md](../AGENTS.md) | 项目级工作规则 |
| [../CONTRIBUTING.md](../CONTRIBUTING.md) | Git / GDScript / 验收规范 |

## 设计文档约定

| 路径 | 用途 |
|------|------|
| `Documents/GAME_VISION.md` | 愿景与主循环 |
| `Documents/Features/` | 功能规格 |
| `Documents/Content/` | 内容库 / 花名册（按需） |

书写遵守 [DEVELOPMENT_WORKFLOW.md](./DEVELOPMENT_WORKFLOW.md)「养成规范」：**当前不做的默认不写进规格**。

## 仓库结构（当前）

```
├── .cursor/agents|skills|rules
├── Documents/                    # 愿景 + Features + 工作流
├── assets/ / art_source/         # 美术素材
├── resources/                    # 单位等数值资源（实现后）
├── scenes/main/main.tscn         # 主场景
├── scripts/                      # 玩法与烟测
├── tools/run_light_verify.sh
├── export_presets.cfg
└── .github/workflows/deploy-web.yml
```

