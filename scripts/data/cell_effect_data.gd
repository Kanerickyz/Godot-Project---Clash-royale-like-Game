class_name CellEffectData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_range(0, 32, 1) var damage_per_tick: int = 2
## 效果持续回合数（每回合仅在移动前结算一次站格伤害，随后递减）。
@export_range(1, 16, 1) var duration_rounds: int = 1
