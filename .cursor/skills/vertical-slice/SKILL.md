---
name: vertical-slice
description: Dispatches studio roles for a vertical slice with an L0–L5 target. Use for cross-module features, acceptance contracts, or when the user asks to follow the project workflow.
---

# vertical-slice

主代理当制作人。细则只维护在 Documents/DEVELOPMENT_WORKFLOW.md，不要把长表复制进本技能。

## 何时派

小型串行修改主代理自己做。跨模块或独立审查才派专职角色。未触达的职业不到场。同时最多三个子代理。

Cursor 角色：`.cursor/agents/<role>.md`，用 Task 委派。Customize 里看不见就不算已加载；改为手读对应文件再传合同。

## 合同

```text
角色、目标、目标等级、输入、验收、允许写入、禁止写入、依赖
返回：文件、结论、达到的等级、证据、下一级缺口、命令/退出码、风险、主代理待处理项
```

`project.godot`、共享场景、枚举由主代理写。每个文件一个写入负责人。共享 checkout 不并行改同一文件。

## 门禁

QA 给出是否达到目标等级。reviewer 只读 diff，不替代游玩。阻断退回实现。L5 只修缺陷。升级靠证据，不靠自称。
