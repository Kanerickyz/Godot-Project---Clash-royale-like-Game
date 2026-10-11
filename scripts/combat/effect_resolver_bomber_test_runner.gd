extends SceneTree

const EffectResolverBomberTestScript := preload(
	"res://scripts/combat/effect_resolver_bomber_test.gd"
)


func _initialize() -> void:
	var ok: bool = EffectResolverBomberTestScript.run_all()
	quit(0 if ok else 1)
