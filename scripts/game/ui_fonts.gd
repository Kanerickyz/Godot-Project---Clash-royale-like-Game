class_name UiFonts
extends RefCounted
## Compose Latin/digits (Noto) + CJK fallback (DroidSansFallback).


const PATH_LATIN := "res://assets/fonts/NotoSans-Regular.ttf"
const PATH_CJK := "res://assets/fonts/DroidSansFallback.ttf"

static var _font: Font
static var _theme: Theme


static func get_font() -> Font:
	if _font != null:
		return _font
	var latin := load(PATH_LATIN) as Font
	var cjk := load(PATH_CJK) as Font
	if latin == null:
		push_error("UiFonts: missing Latin font %s" % PATH_LATIN)
		return null
	_font = latin.duplicate() as Font
	if cjk != null and _font != null:
		var falls: Array[Font] = []
		falls.append(cjk)
		_font.fallbacks = falls
	return _font


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	var font := get_font()
	if font != null:
		_theme.default_font = font
	_theme.default_font_size = 16
	return _theme


static func apply_to_control(control: Control) -> void:
	if control == null:
		return
	control.theme = get_theme()
