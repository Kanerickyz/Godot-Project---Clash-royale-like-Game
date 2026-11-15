class_name UnitDefinition
extends Resource
## Numeric + presentation definition for a combat unit. Runtime code must duplicate().


@export var id: StringName = &""
@export var display_name: String = "Unit"
@export var max_hp: int = 100
@export var attack_damage: int = 10
@export var attack_interval: float = 0.8
@export var attack_range: float = 80.0
@export var move_speed: float = 160.0
@export var sprite: Texture2D
@export var sprite_scale: float = 0.22
@export var gold_drop_min: int = 0
@export var gold_drop_max: int = 0
@export_group("Shop")
## Shop shelf price in ducats. 0 = use ShopEconomyConfig rarity_prices[rarity_tier].
@export var shop_price: int = 0
## 1=common, 2=uncommon, 3=rare. Old resources default to 1.
@export var rarity_tier: int = 1
