class_name RoamChest
extends StaticBody2D
## Attackable chest with HP; opens a three-pick recruit UI when destroyed.


signal opened(chest: RoamChest, choices: Array)

@export var max_hp: int = 60

var current_hp: int = 60
var is_dead: bool = false
var choices: Array[UnitDefinition] = []

var _sprite: Sprite2D
var _hp_bg: ColorRect
var _hp_fill: ColorRect
var _label: Label


func configure(p_max_hp: int, p_choices: Array[UnitDefinition], texture: Texture2D = null) -> void:
	max_hp = p_max_hp
	current_hp = p_max_hp
	choices.clear()
	for c in p_choices:
		if c != null:
			choices.append(c.duplicate(true) as UnitDefinition)
	_ensure_visuals()
	if texture != null:
		_sprite.texture = texture
		_sprite.scale = Vector2(0.35, 0.35)
	_update_hp_bar()
	add_to_group(&"chests")
	add_to_group(Combatant.GROUP_ATTACKABLE)
	collision_layer = 4
	collision_mask = 0


func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	current_hp = maxi(0, current_hp - amount)
	_update_hp_bar()
	if current_hp <= 0:
		_open()


func _open() -> void:
	if is_dead:
		return
	is_dead = true
	opened.emit(self, choices.duplicate())
	hide()
	collision_layer = 0
	queue_free()


func _ensure_visuals() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		_sprite.centered = true
		# Brown crate placeholder if no texture.
		var img := Image.create(48, 40, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.55, 0.35, 0.18, 1.0))
		_sprite.texture = ImageTexture.create_from_image(img)
		add_child(_sprite)
	if _label == null:
		_label = Label.new()
		_label.text = "宝箱"
		_label.position = Vector2(-18, -48)
		_label.add_theme_font_size_override("font_size", 12)
		add_child(_label)
	if _hp_bg == null:
		_hp_bg = ColorRect.new()
		_hp_bg.size = Vector2(40, 5)
		_hp_bg.position = Vector2(-20, -34)
		_hp_bg.color = Color(0.15, 0.15, 0.15, 0.85)
		add_child(_hp_bg)
		_hp_fill = ColorRect.new()
		_hp_fill.size = Vector2(40, 5)
		_hp_fill.color = Color(0.95, 0.75, 0.2, 1.0)
		_hp_bg.add_child(_hp_fill)
	if get_node_or_null("CollisionShape2D") == null:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(36, 30)
		shape.shape = rect
		add_child(shape)


func _update_hp_bar() -> void:
	if _hp_fill == null:
		return
	var ratio := 0.0 if max_hp <= 0 else float(current_hp) / float(max_hp)
	_hp_fill.size.x = 40.0 * clampf(ratio, 0.0, 1.0)
