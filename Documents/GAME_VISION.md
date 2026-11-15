# 游戏愿景

> 状态：**To-Be 定稿**（文档已落盘；代码仍为旧小队游走原型，未对齐）  
> 参照：《骷髅成群》(Skull Horde) 系统全量对齐  
> 主题：中世纪奇幻  
> 验收方式：**完全**（相关 runner + 按 L 级 QA/GUI）  
> 兵种美术：优先复用 `assets/sprites/paper_cutout/units/`

## 一句话

操控誓约指挥官在程序地城中漫游，随从自动作战；层内搜刮、威胁上涨、择机进门；层间用达克特招兵/刷新/三合一升阶，用尸骸换遗物；以誓约羁绊构筑军队，贯通多层直至终局或阵亡。

## 体验支柱

1. **走位与时机**：玩家只控指挥官；随从自动索敌。集合、短时强化等指令是节奏键，不是微操每个兵。
2. **搜刮 vs 威胁**：层内越拖威胁越高；宝箱/神龛/精英有收益，进门时机是核心决策。
3. **层间构筑**：商店招兵、刷新、利息、三合一升阶、卖兵整理；军队同时最多约 6 种单位类型。
4. **誓约协同**：冠军阶单位带关键词；多枚同关键词冠军触发誓约加成。
5. **复活韧性**：阵亡单位按序排队复活；指挥官受伤分摊到随从并拉长复活，逼迫走位而非硬扛。

## 主循环（一局）

```text
开局（选角；开局天赋并入 Phase G，非 G 最小集可不做）
  → 进入程序生成楼层
  → 层内：漫游清怪、开箱、神龛、精英；威胁随时间上涨；找传送门
  → 进门 → 层间商店（达克特招兵/刷新/升阶；尸骸换遗物）
  → 下一层…… 直至终局 Boss 或指挥官生命归零
  → 结算 → 永久进度（技能点 / 解锁）→ 再开一局
```

## 系统清单（对齐范围）

| 系统 | 规格文档 | 摘要 |
|------|----------|------|
| 核心循环 / 层结构 / 胜负 | [Features/run_floors_and_victory.md](./Features/run_floors_and_victory.md) | 楼层、传送门、终局、失败 |
| 层内战斗 / 威胁 / 复活 | [Features/combat_threat_revive.md](./Features/combat_threat_revive.md) | 自动战、威胁曲线、复活队列 |
| 经济 / 层间商店 / 三合一 | [Features/economy_shop_merge.md](./Features/economy_shop_merge.md) | 达克特、利息、招兵、刷新、三合一 |
| 誓约 / 羁绊 | [Features/oaths_and_bonds.md](./Features/oaths_and_bonds.md) | 关键词、冠军、誓约触发 |
| 尸骸 / 遗物 | [Features/corpus_and_relics.md](./Features/corpus_and_relics.md) | 第二货币与遗物店 |
| 永久成长边界 | [Features/meta_progress.md](./Features/meta_progress.md) | 局外技能点与解锁 |
| 兵种花名册 | [Content/unit_roster.md](./Content/unit_roster.md) | 中世纪命名 ↔ 现有贴图 |
| 分期落地 | [Features/delivery_phases.md](./Features/delivery_phases.md) | Phase A–G，每期可验收切片 |

## 包装与参照边界

- **系统**对齐 Skull Horde：死灵漫游式操作感 → 本主题下为「指挥官漫游 + 自动誓约军」；层内威胁、层间三合一商店、誓约、复活队列、双货币遗物。
- **合兵**以实战为准：**3 同种 → 老兵；3 老兵 → 冠军**。不采用与实战冲突的星级倍增合成表。
- **美术**不新做完整兵种表：映射现有剪纸单位；主题文案中世纪奇幻。
- **代码现状**（As-Is）仍是小队游走 + 同图商店/宝箱/Boss；与本文冲突处以本文为准，由实现 Phase 逐步替换。

## 养成规范

当前要对齐的系统全部写入上表与 Features；**分期**见 [delivery_phases.md](./Features/delivery_phases.md)。未列入 Phase 的内容默认不写进规格。具体数值由数值策划在资源中填空，愿景与 Features 只定功能骨架。
