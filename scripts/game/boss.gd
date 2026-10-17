class_name Boss
extends Enemy
## Unique map boss. Defeat emits boss_defeated for win flow.


signal boss_defeated(boss: Boss)


func _die() -> void:
	if is_dead:
		return
	boss_defeated.emit(self)
	# Boss does not drop gold via Enemy path intentionally for clearer win UX.
	is_dead = true
	died.emit(self)
	collision_layer = 0
	collision_mask = 0
	hide()
	queue_free()
