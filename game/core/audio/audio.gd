extends Node
# 全域聲音（autoload Audio，MV-SLICE-001d1a）：匯流排、短音效、環境音、距離層、配樂。
# 混音優先序（AUDIO_SPEC 第 7 節）：前兆走 Tell，Music／Amb 的壓縮器以 Tell 為 sidechain（前兆一響就被壓低）。
# ponytail: native: AudioEffectCompressor.sidechain | upgrade if: 壓低不明顯，改成前兆時用 tween 降 Music／Amb
# 匯流排用程式建（專案全是程式驅動，不另存 bus layout .tres）。headless 自測讀 last_played／play_count 等狀態。

const Sound := preload("res://core/audio/sound_table.gd")
const SFX_PLAYERS := 12
const TELL_PLAYERS := 2  # 前兆專用（MV-SLICE-001d1b）：一般音效再多也截不到前兆
const POS_PLAYERS := 12  # 依距離衰減的播放器（敵人的移動、攻擊、光束）
const POS_MAX_DISTANCE := 2000.0
const POS_THROTTLE := 0.1  # 同一種移動聲的最短間隔（秒）
const GROUP_GLASS := &"audio_glass"  # 房間裡活著的假光造物（Boss 段落召喚的不進來）
const GROUP_DANGER := &"audio_danger"  # 地上荊棘
## 距離層：[群組, 音檔 id, 最大音量的距離, 歸零的距離]
const LAYERS := {&"glass": [GROUP_GLASS, &"amb_01_glass", 300.0, 900.0], &"danger": [GROUP_DANGER, &"voc_danger_loop", 150.0, 600.0]}
const SILENT_DB := -80.0

var last_played := {}  # id → 最後一次的檔案路徑
var play_count := {}  # id → 次數
var _cache := {}
var _players: Array = []
var _next := 0
var ambience := &""  # 目前的環境音 id
var music := &""  # 目前的配樂 id（Task 4）
var listener: Node2D  # 距離層的聽者（角色）；每次用前檢查是否還有效
var floor_source: Callable  # 目前的房間或 Boss 戰的 floor_material_at(pos)；沒設時一律是土（MV-SLICE-001d1b）
var _amb_now: AudioStreamPlayer  # 目前的環境音播放器；舊的淡出後自己釋放
var _layers := {}  # 層名 → AudioStreamPlayer
var _layer_db := {}  # 層名 → 這一幀算出的音量
var _music_now: AudioStreamPlayer
var _tell_at := {}  # 前兆 id → 上次播放的毫秒
var _tell_players: Array = []
var _tell_next := 0
var _players_2d: Array = []
var _next_2d := 0
var _pos_at := {}  # play_at 的 id → 上次播放的毫秒（只對 *_move 節流）


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in SFX_PLAYERS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for i in TELL_PLAYERS:
		var tp := AudioStreamPlayer.new()
		tp.bus = &"Tell"
		add_child(tp)
		_tell_players.append(tp)
	for i in POS_PLAYERS:
		var pp := AudioStreamPlayer2D.new()
		pp.max_distance = POS_MAX_DISTANCE
		add_child(pp)
		_players_2d.append(pp)
	for name in LAYERS:
		var lp := _make_loop(LAYERS[name][1])
		lp.volume_db = SILENT_DB
		lp.play()
		_layers[name] = lp
		_layer_db[name] = SILENT_DB


func _process(_delta: float) -> void:
	for name in LAYERS:
		var l: Array = LAYERS[name]
		var d := _nearest(l[0])
		var t := clampf((l[3] - d) / (l[3] - l[2]), 0.0, 1.0)
		var db := linear_to_db(t * db_to_linear(Sound.LAYER_MAX_DB)) if t > 0.0 else SILENT_DB
		_layer_db[name] = db
		_layers[name].volume_db = db


## 聽者到群組裡最近一個來源的距離；荊棘有 rect（世界座標）就量到矩形邊緣
func _nearest(group: StringName) -> float:
	if not is_instance_valid(listener) or not listener.is_inside_tree():
		return INF
	var at := listener.global_position
	var best := INF
	for n in get_tree().get_nodes_in_group(group):
		if n.is_queued_for_deletion() or not n is Node2D:
			continue
		var r = n.get("rect")
		var d: float
		if r is Rect2:
			d = (Vector2(maxf(absf(at.x - r.get_center().x) - r.size.x / 2.0, 0.0), maxf(absf(at.y - r.get_center().y) - r.size.y / 2.0, 0.0))).length()
		else:
			d = at.distance_to(n.global_position)
		best = minf(best, d)
	return best


## 腳下地面：&"dirt" 或 &"hard"
func floor_at(pos: Vector2) -> StringName:
	return floor_source.call(pos) if floor_source.is_valid() else &"dirt"


static func step_id(char_name: String, floor: StringName) -> StringName:
	return StringName("mov_step_%s_%s" % [floor, char_name])


func layer_db(layer: StringName) -> float:
	return _layer_db.get(layer, SILENT_DB)


## 換環境音：同 id 不動；不同就交叉淡化；&"" 全部淡出
func set_ambience(id: StringName) -> void:
	if id == ambience:
		return
	ambience = id
	_fade_out(_amb_now, Sound.AMB_FADE)
	_amb_now = null
	if id == &"":
		return
	_amb_now = _make_loop(id)
	_amb_now.volume_linear = 0.0
	_amb_now.play()
	_tween().tween_property(_amb_now, "volume_linear", db_to_linear(Sound.SOUNDS[id].db), Sound.AMB_FADE)


func ambience_player() -> AudioStreamPlayer:
	return _amb_now


func ambience_players_playing() -> int:
	return get_children().filter(func(p): return p is AudioStreamPlayer and p.get_meta(&"amb", false) and p.playing and not p.is_queued_for_deletion()).size()


## 回主選單：環境音、配樂淡出
func stop_all() -> void:
	set_ambience(&"")
	stop_music()


## 配樂：淡入、從頭播（換曲時舊的淡出）
func play_music(id: StringName) -> void:
	_fade_out(_music_now, Sound.MUSIC_OUT)
	music = id
	play_count[id] = play_count.get(id, 0) + 1
	_music_now = _make_loop(id)
	_music_now.volume_linear = 0.0
	_music_now.play()
	if not Sound.SOUNDS[id].loop:  # 不循環的（MUS-S01）放完就清掉
		var p := _music_now
		p.finished.connect(func():
			if _music_now == p:
				_music_now = null
				music = &""
			p.queue_free())
	_tween().tween_property(_music_now, "volume_linear", db_to_linear(Sound.SOUNDS[id].db), Sound.MUSIC_IN)


func stop_music() -> void:
	_fade_out(_music_now, Sound.MUSIC_OUT)
	_music_now = null
	music = &""


func _make_loop(id: StringName) -> AudioStreamPlayer:
	var e: Dictionary = Sound.SOUNDS[id]
	var p := AudioStreamPlayer.new()
	p.stream = _load(e.files[0], e.loop)
	p.bus = e.bus
	p.set_meta(&"amb", e.bus == "Amb" and not LAYERS.values().any(func(l): return l[1] == id))
	add_child(p)
	return p


func _fade_out(p, time: float) -> void:
	if not is_instance_valid(p) or p.is_queued_for_deletion():
		return
	var tw := _tween()
	tw.tween_property(p, "volume_linear", 0.0, time)
	tw.tween_callback(p.queue_free)


func _tween() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)  # 命中停頓（time_scale 0）時照樣淡化


func _setup_buses() -> void:
	if AudioServer.get_bus_effect_count(0) == 0:  # Master：Boss 戰音效、前兆、配樂疊加時不削峰
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = Sound.MASTER_CEILING_DB
		AudioServer.add_bus_effect(0, lim)
	for b in ["Music", "Amb", "Sfx", "Tell"]:
		if AudioServer.get_bus_index(b) >= 0:
			continue
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, b)
		AudioServer.set_bus_send(i, &"Master")
		AudioServer.set_bus_volume_db(i, Sound.BUS_DB[b])
		if b == "Music" or b == "Amb":
			var c := AudioEffectCompressor.new()
			c.sidechain = &"Tell"
			c.threshold = Sound.DUCK_THRESHOLD_DB
			c.ratio = Sound.DUCK_RATIO
			c.attack_us = 5000.0
			c.release_ms = 300.0
			AudioServer.add_bus_effect(i, c)


func has_sound(id: StringName) -> bool:
	return Sound.SOUNDS.has(id)


## 播一次短音效；回傳選到的檔案（沒有這個 id 回 ""）。變體不連續重複同一個。
func play(id: StringName) -> String:
	if not has_sound(id):
		return ""
	var e: Dictionary = Sound.SOUNDS[id]
	var path := _pick(id, e.files)
	var p: AudioStreamPlayer
	if e.bus == "Tell":
		p = _tell_players[_tell_next]
		_tell_next = (_tell_next + 1) % _tell_players.size()
	else:
		p = _players[_next]
		_next = (_next + 1) % _players.size()
	p.stream = _load(path, false)
	p.bus = e.bus
	p.volume_db = e.db
	p.play()
	last_played[id] = path
	play_count[id] = play_count.get(id, 0) + 1
	return path


## 在世界座標 pos 播一次（依距離衰減、有左右聲道）；*_move 同一種 POS_THROTTLE 秒內只播一次。只收位置，不碰呼叫者節點
func play_at(id: StringName, pos: Vector2) -> String:
	if not has_sound(id):
		return ""
	if String(id).ends_with("_move"):
		var now := Time.get_ticks_msec()
		if now - _pos_at.get(id, -100000) < int(POS_THROTTLE * 1000.0):
			return ""
		_pos_at[id] = now
	var e: Dictionary = Sound.SOUNDS[id]
	var path := _pick(id, e.files)
	var p: AudioStreamPlayer2D = _players_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _players_2d.size()
	p.stream = _load(path, false)
	p.bus = e.bus
	p.volume_db = e.db
	p.global_position = pos
	p.play()
	last_played[id] = path
	play_count[id] = play_count.get(id, 0) + 1
	return path


## 結束時停掉所有播放器、清快取（不留「resources still in use」）
func _exit_tree() -> void:
	for c in get_children():
		if c is AudioStreamPlayer or c is AudioStreamPlayer2D:
			c.stop()
			c.stream = null
	_cache.clear()


## 前兆（Tell 匯流排）：同一種在 TELL_THROTTLE 秒內只播一次；回傳是否有播
func play_tell(parryable: bool) -> bool:
	var id := &"tell_parry" if parryable else &"tell_heavy"
	var now := Time.get_ticks_msec()
	if now - _tell_at.get(id, -100000) < int(Sound.TELL_THROTTLE * 1000.0):
		return false
	_tell_at[id] = now
	play(id)
	return true


func _pick(id: StringName, files: Array) -> String:
	if files.size() == 1:
		return files[0]
	var choices := files.filter(func(f): return f != last_played.get(id, ""))
	return choices[randi() % choices.size()]


func _load(path: String, loop: bool) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path)
	var s: AudioStream = _cache[path]
	if s is AudioStreamOggVorbis:
		s.loop = loop
	return s
