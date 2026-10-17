class_name Boss
extends Enemy
## Unique map boss. Defeat emits boss_defeated for win flow.


signal boss_defeated(boss: Boss)


func _die() -> void:
	if is_dead:
		return
	boss_defeated.emit(self)
	# Skip gold drop; play shared death tween via Combatant.
	is_dead = true
	died.emit(self)
	collision_layer = 0
	collision_mask = 0
	combat_enabled = false
	velocity = Vector2.ZERO
	_play_death_anim()
