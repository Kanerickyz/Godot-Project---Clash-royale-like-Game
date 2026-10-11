class_name BoardPresentation
extends RefCounted

## CombatPresentation 使用的棋盘表现层契约。
## BoardScene3D 实现下列方法（单一 3D 棋盘 + Camera3D）。

static func is_valid(host: Node) -> bool:
	return host != null and host.has_method("sync_units") and host.has_method("grid_to_world")
