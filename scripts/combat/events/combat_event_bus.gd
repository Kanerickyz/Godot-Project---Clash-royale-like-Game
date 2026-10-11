class_name CombatEventBus
extends Node

signal combat_event(event_type: StringName, payload: CombatEventPayload)


func emit_event(event_type: StringName, payload: CombatEventPayload) -> void:
	payload.event_type = event_type
	combat_event.emit(event_type, payload)
