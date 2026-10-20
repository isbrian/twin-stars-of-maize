extends Node
# 換房（MV-SLICE-001a Task 4）：淡出 → 把血量寫回 GameState → 釋放舊房 → 建新房 → 角色站到對應的門 → 淡入。
# 換房進行中再收到 goto 一律忽略（Review Focus 2）。

const Sound := preload("res://core/audio/sound_table.gd")
const Tuning := preload("res://core/tuning/combat_tuning.gd")
const RoomScr := preload("res://world/room.gd")
const Loadout := preload("res://state/loadout.gd")
const Save := preload("res://state/save.gd")
const BossFight := preload("res://core/boss/boss_fight.gd")
const Ending := preload("res://world/ending.gd")

const Index := preload("res://world/rooms/index.gd")

signal room_changed(id: String)
signal ended  # 切片結尾的文字卡按掉 → 回主選單

var gs
var tn: Tuning = Tune.data
var rooms := {}  # 房間 id → 資料腳本（有 static data()）
var current: Node
var current_id := ""
var fade_time := 0.25
var save_path := Save.PATH  # 自測改成 user://test_*.json
var _busy := false
var _death_pending := false  # 換房途中死亡：換完再處理
var _fade: ColorRect


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


## 不經過門：角色站在房間的休息點（開新遊戲、繼續、死亡回點）
func start(room_id: String, store := true) -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0)
	_swap(room_id, "", store)
	await _fade_to(0.0)
	_busy = false
	_after_transition()


func goto(room_id: String, door_id: String) -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0)
	_swap(room_id, door_id)
	await _fade_to(0.0)
	_busy = false
	_after_transition()


func is_busy() -> bool:
	return _busy


## room_id 可以是房間 id 或 Boss 段落的篝火 id（start 時）
func _swap(room_id: String, door_id: String, store := true) -> void:
	if is_instance_valid(current):
		if store and current.get("player") != null:
			Loadout.store(current.player, gs)
		remove_child(current)
		current.queue_free()
	var id: String = Index.CAMPS.get(room_id, room_id)
	var d: Dictionary = rooms[id].data()
	# MV-SLICE-001d1a：依房間 theme 換環境音；結尾靜音（Brian 2026-10-20）
	Audio.set_ambience(&"" if d.get("kind", "") == "ending" else Sound.THEME_AMBIENCE.get(d.get("theme", ""), &"amb_01"))
	var r: Node
	match d.get("kind", ""):
		"boss":
			r = BossFight.new()
			r.tn = tn
			r.gs = gs
			r.save_path = save_path
			add_child(r)
			if door_id == "":
				r.begin_at_rest(room_id)
			else:
				r.begin_from_forest()  # 覺醒後從森林回來：小路起點（MV-SLICE-001c4b）
			r.left_exit.connect(goto.bind(d.left_room, d.left_door))
			r.finished.connect(start.bind("exit"))
		"ending":
			r = Ending.new()
			r.tn = tn
			add_child(r)
			r.done.connect(ended.emit)
		_:
			r = RoomScr.new()
			add_child(r)
			r.build(d, gs, tn)
			if door_id != "":
				r.player.position = r.spawn_point(door_id)
				r.camera.reset_smoothing()
			r.door_entered.connect(_on_door)
			r.interacted.connect(_on_interacted)
			r.player_died.connect(_on_died)
	current = r
	current_id = id
	room_changed.emit(id)


func _on_door(door_id: String) -> void:
	for door in current.data.doors:
		if door.id == door_id:
			goto(door.to_room, door.to_door)
			return


## 休息（SLICE-a10）：回滿、敵人重生、存檔；角色留在休息點
func _on_interacted(kind: String) -> void:
	if kind == "rest":
		rest_here()


func rest_here() -> void:
	if _busy:
		return
	gs.rest(current.data.id)
	Save.write(gs.to_dict(), save_path)
	start(current.data.id, false)


## 死亡：回到最後休息的地點，血量、治療次數回滿（同休息但不存檔）；可可豆不變
func _on_died() -> void:
	if _busy:
		_death_pending = true
		return
	gs.rest(gs.last_rest)
	start(gs.last_rest, false)


func _after_transition() -> void:
	if _death_pending:
		_death_pending = false
		_on_died()


func _fade_to(a: float) -> void:
	if fade_time <= 0.0:  # 自測：不淡入淡出，但仍等一幀——門與死亡是在物理回呼裡觸發的，當下不能建碰撞形狀
		_fade.color.a = a
		await get_tree().process_frame
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", a, fade_time)
	await tw.finished
