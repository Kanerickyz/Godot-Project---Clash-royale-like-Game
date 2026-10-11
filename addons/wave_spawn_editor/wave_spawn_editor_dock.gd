@tool
extends Control

const WAVE_SCRIPT := preload("res://scripts/data/wave_data.gd")

@onready var _path_edit: LineEdit = %PathEdit
@onready var _spawn_count_spin: SpinBox = %SpawnCountSpin
@onready var _gold_spin: SpinBox = %GoldSpin
@onready var _status_label: Label = %StatusLabel

var _wave: WaveData
var _wave_path: String = ""


func _ready() -> void:
	if Engine.is_editor_hint():
		_set_status("运行时从商店角色池随机组合敌人，开战 tick 0 一次性刷齐。")


func _on_load_pressed() -> void:
	var path := _path_edit.text.strip_edges()
	if not path.begins_with("res://"):
		path = "res://" + path
	if not ResourceLoader.exists(path):
		_set_status("找不到资源：%s" % path)
		return
	var wave: WaveData = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as WaveData
	if wave == null:
		_set_status("不是 WaveData 资源")
		return
	if wave.get_script() == null:
		_set_status("WaveData 脚本未加载，请检查 wave_data.gd")
		return
	_wave = wave
	_wave_path = path
	_spawn_count_spin.value = wave.spawn_count
	_gold_spin.value = wave.wave_gold_reward
	_set_status("已加载 %s" % path)


func _on_save_pressed() -> void:
	if _wave == null or _wave_path.is_empty():
		_set_status("请先加载 WaveData")
		return
	_wave.spawn_count = int(_spawn_count_spin.value)
	_wave.wave_gold_reward = int(_gold_spin.value)
	var err := ResourceSaver.save(_wave, _wave_path)
	if err != OK:
		_set_status("保存失败：错误码 %d" % err)
	else:
		_set_status("已保存到 %s" % _wave_path)


func _set_status(text: String) -> void:
	if _status_label:
		_status_label.text = text
