@tool
class_name BoardThemeConfig
extends Resource

@export_group("Checkerboard")
@export var color_light: Color = Color(0.878, 0.878, 0.878, 1.0) # #E0E0E0
@export var color_dark: Color = Color(0.549, 0.549, 0.549, 1.0) # #8C8C8C
@export var color_blocked: Color = Color(0.400, 0.400, 0.400, 1.0) # #666666
@export var blocked_modulate: Color = Color(0.82, 0.82, 0.82, 1.0)

@export_group("Terrain")
@export var color_grass_light: Color = Color(0.486, 0.702, 0.259, 1.0) # #7CB342
@export var color_grass_dark: Color = Color(0.333, 0.545, 0.184, 1.0) # #558B2F
@export var color_jungle: Color = Color(0.180, 0.490, 0.196, 1.0) # #2E7D32
@export var color_lake: Color = Color(0.098, 0.463, 0.824, 1.0) # #1976D2
@export var color_shore: Color = Color(1.0, 0.878, 0.510, 1.0) # #FFE082
@export var color_rock: Color = Color(0.471, 0.565, 0.612, 1.0) # #78909C
@export var color_dense_jungle: Color = Color(0.106, 0.369, 0.125, 1.0) # #1B5E20

@export_group("Frame")
@export var color_frame: Color = Color(0.451, 0.451, 0.451, 1.0) # #737373
@export var frame_padding: float = 2.0
@export var frame_width: float = 2.0

@export_group("Cell Border")
@export_range(0.0, 0.5, 0.01) var border_darken_amount: float = 0.14
@export_range(0.0, 0.5, 0.01) var blocked_border_darken_amount: float = 0.12

@export_group("Highlights")
@export var color_hover_tint: Color = Color(1.0, 1.0, 1.0, 0.12)
@export var color_placeable_tint: Color = Color(0.659, 0.902, 0.690, 0.18)
@export var color_invalid_tint: Color = Color(0.95, 0.45, 0.45, 0.22)
@export var color_attack_tint: Color = Color(0.95, 0.25, 0.25, 0.35)
@export var color_attack_range_tint: Color = Color(0.95, 0.55, 0.15, 0.28)

@export_group("Cell Effects")
@export var color_burn_overlay: Color = Color(0.95, 0.35, 0.12, 1.0)
@export_range(0.0, 1.0, 0.01) var burn_overlay_strength: float = 0.45
