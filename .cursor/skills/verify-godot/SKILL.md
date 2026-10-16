---
name: verify-godot
description: Runs Godot light smoke or full SceneTree test runners and reports exit codes plus SCRIPT ERROR. Use when implementing gameplay, changing resources, or claiming L2+ done under full acceptance.
---

# verify-godot

跑项目验证时用这个技能。先确认合同**验收方式**（轻量 / 完全）。不要另起空入口假装通过。

## 入口

### 轻量验收

```bash
bash tools/run_light_verify.sh
```

仅 import + 关键场景加载烟测。通过即可交付实现；效果由用户验收。不要用本技能冒充完全验收。

### 完全验收

按改动选择现有 runner。聚合入口：

```bash
bash tools/run_verify_runners.sh
```

或单独例如：

```bash
godot --headless --path . --script res://scripts/core/project_load_smoke_test_runner.gd
```

## 报告

命令、退出码、SCRIPT/Parse Error、通过/失败项、未覆盖项。不删断言、不屏蔽错误来使检查变绿。
