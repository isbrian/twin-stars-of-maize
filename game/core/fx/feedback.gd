extends Node
# 命中回饋（規格書第 4、8 節）：命中停頓、晃鏡頭、音效（MV-SLICE-001d1a：資料表有的交給 Audio，其餘是合成佔位）。
# 停頓用真實時間計算結束點：連續命中只會延長、不會卡住（Engine.time_scale 必回到 1）。

const Sfx := preload("res://core/fx/sfx.gd")
const Tuning := preload("res://core/tuning/combat_tuning.gd")
const Sound := preload("res://core/audio/sound_table.gd")

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


## 角色動作的音效（room 與 boss_fight 共用；MV-SLICE-001d1b）：揮擊依出招當下的武器、換人依兄弟、跳躍落地翻滾、招架落空
func wire_moves(p) -> void:
	p.swung.connect(func(): play(Sound.swing_id(p.attack_weapon)))
	p.swapped.connect(func(): play(Sound.swap_id(p.twin_index)))
	p.jumped.connect(play.bind(&"mov_jump"))
	p.landed.connect(play.bind(&"mov_land"))
	p.rolled.connect(play.bind(&"mov_roll"))
	p.parry_whiffed.connect(play.bind(&"wpn_parry_miss"))


func play(sound: StringName) -> void:
	if Audio.has_sound(sound):  # MV-SLICE-001d1a：有正式檔就交給 Audio，沒有才播合成佔位
		Audio.play(sound)
		return
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
