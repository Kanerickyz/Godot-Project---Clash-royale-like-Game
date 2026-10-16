---
name: implement
description: Implements an already-agreed design in code, resources, or editor plugins by dispatching the needed studio subagents. Use when the user asks to implement from design docs or prior conversation consensus.
---

# implement

主代理当制作人与集成人。设计已定 → 按范围拉实现角色落地；细则只维护在 Documents/DEVELOPMENT_WORKFLOW.md，不要把长表复制进本技能。

与其它技能分工：

| 技能 | 用途 |
| --- | --- |
| `design-brainstorm` | 玩法未定；只聊设计，不改代码/资源 |
| **`implement`（本技能）** | 设计稿 / 上文共识已定；改代码、`resources/`、或 `addons/` 编辑器 |
| `vertical-slice` | 跨模块完整纵切片（含设计核对 → 实现 → QA/审查），带明确 L0–L5 目标 |

## 何时用

- 用户说「按设计稿 / Features / 上文共识实现」
- 规格已落盘或对话里已拍板且范围清楚
- 改动落在脚本、场景、`.tres`、或编辑器插件

## 何时不用 / 先改道

- 玩法意图未定、与愿景冲突未对齐 → 先用 `design-brainstorm`，**不要**边猜边写代码
- 用户要完整 L 级制片流程（设计→实现→QA→审查一条龙）→ 用 `vertical-slice`
- 仅验证已有改动 → `verify-godot` / `gui-acceptance`

## 开工前门禁

1. **验收方式**：用户未指定则先问（轻量 | 完全），写入合同。见 DEVELOPMENT_WORKFLOW「验收方式」。
2. **锚定设计输入**（主代理整理后传给子代理，勿假设子代理见过上文）：
   - 对话中的【用户新共识】/ 已拍板条目
   - 对应 `Documents/` 规格（若有）
   - As-Is 与 To-Be 差异（文档定稿 ≠ 代码已对齐）
3. **范围一句话**：玩家可观察变化 + 允许写入的模块；当前不做的不实现、不扩写规格。
4. 目标等级：用户指定则写入；未指定时轻量默认按「实现完成 + 加载烟测」交付，不自称 L3+；完全模式再定 L2–L5。

## 派谁（按触达，不到场的不派）

- 程序：`gameplay-engineer`
- 表现资产：`technical-artist`（风格听 `game-artist`）
- 数值资源：`balance-designer`
- 音频：`audio-designer`
- UI 结构争议：先 `ui-designer`（只读）再程序

同时最多三个子代理。`project.godot`、共享场景与枚举由主代理写。

## 出口

- 轻量：`bash tools/run_light_verify.sh` + 交付注明效果未代验
- 完全：相关 runner + 按合同派 QA/审查
