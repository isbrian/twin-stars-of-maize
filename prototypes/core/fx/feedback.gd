extends Node
# 命中回饋（規格書第 4、8 節）：命中停頓、晃鏡頭、佔位音效。
# 停頓用真實時間計算結束點：連續命中只會延長、不會卡住（Engine.time_scale 必回到 1）。

const Sfx := preload("res://fx/sfx.gd")
const Tuning := preload("res://tuning/combat_tuning.gd")

var tn: Tuning = Tune.data
var camera: Camera2D
var _hitstop_end_ms := 0
var _shake_left := 0.0
var _bank := {}
var _players: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bank = Sfx.build_all()
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func hitstop() -> void:
	if tn.hitstop_time <= 0.0:
		return
	_hitstop_end_ms = maxi(_hitstop_end_ms, Time.get_ticks_msec() + int(tn.hitstop_time * 1000.0))
	Engine.time_scale = 0.0


func shake() -> void:
	_shake_left = tn.shake_time


func play(sound: StringName) -> void:
	if not _bank.has(sound):
		return
	for p in _players:
		if not p.playing:
			p.stream = _bank[sound]
			p.play()
			return


func _process(delta: float) -> void:
	if Engine.time_scale == 0.0 and Time.get_ticks_msec() >= _hitstop_end_ms:
		Engine.time_scale = 1.0
	if camera == null:
		return
	if _shake_left > 0.0:
		_shake_left -= delta
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * tn.shake_strength
	else:
		camera.offset = Vector2.ZERO


func _exit_tree() -> void:
	Engine.time_scale = 1.0
