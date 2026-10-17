# 小队游走原型 · 数值备注

> 运行时以 `resources/units/*.tres` 为准。  
> 下表为早期草案，**未强制对齐**当前 `.tres`；若要以本表重调，另开数值切片。

## 当前 `.tres` 占位（实现合同）

| 资源 | 用途 |
| --- | --- |
| `captain.tres` | 开局队长 |
| `ally_spear/archer/shield.tres` | 商店固定三槽（价 15/25/40） |
| `ally_hunter/axe/musket.tres` | 宝箱三选一候选 |
| `enemy_grunt.tres` | 杂兵 |
| `boss.tres` | 同图 Boss（本体属性） |
| `boss_minion.tres` | Boss 召唤小兵（略弱于 grunt） |
| `../combat/boss_summon_charge.tres` | 冲撞/召唤/硬直循环（`BossBehaviorConfig`） |

开局金币：15（脚本 `GameController.START_GOLD`）。Boss 冲撞为主威胁，普攻仅辅压；手感未实测定稿。
