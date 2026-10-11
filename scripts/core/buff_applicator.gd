class_name BuffApplicator
extends RefCounted


static func apply_on_attach(entry: DeckEntry, buff: BuffCardData) -> void:
	if entry == null or buff == null:
		return
	match buff.effect_type:
		BuffCardData.EffectType.PERMANENT_ATTACK:
			entry.bonus_attack += buff.value
		BuffCardData.EffectType.PERMANENT_MAX_HP:
			entry.bonus_max_hp += buff.value
		BuffCardData.EffectType.CANNOT_MOVE:
			entry.rule_flags["cannot_move"] = true
		BuffCardData.EffectType.DEATH_GOLD:
			pass
