# 文档索引

> Godot 4.6 · 小队游走招募原型 · harness 与美术素材保留

## 快速导航

| 文档 | 说明 |
|------|------|
| [GAME_VISION.md](./GAME_VISION.md) | 愿景与主循环 |
| [Features/squad_roam_prototype.md](./Features/squad_roam_prototype.md) | 小队游走招募原型规格 |
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

