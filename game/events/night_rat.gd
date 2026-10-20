extends Node
# 入夜抓老鼠（MV-SLICE-001a 規格「事件」；MV-SLICE-001c3a 改成過場）：田地入夜、灌木與土塊回來（背景）、老鼠在田中央；
# 沒看過時先播動物復原（剛清完田地時接在收工後面一起播）。角色靠近（< 300）老鼠就往反方向跑；被逼到左右牆角時網子罩住（不傷害）→ 交換的過場 → rat_caught。
# 中途死亡：事件節點跟著房間釋放、旗標沒設，下次進田地重來（看過動物復原就不重播）。

const Prop := preload("res://world/prop.gd")
const FieldAnimals := preload("res://world/cutscene/field_animals.gd")
const RatDeal := preload("res://world/cutscene/rat_deal.gd")

const FLEE_DIST := 300.0
const WALL_MARGIN := 110.0
const FLEE_SPEED := 1.1  # ×跑速；比角色快一點，角色超不過去才能把牠趕到牆角

var runner
var room
var gs
var rat: Node2D
var prelude: Array = []  # 接在動物復原前面一起播的段落（剛清完田地時的收工；MV-SLICE-001c3a）
var _active := false


func _ready() -> void:
	var seen: bool = gs.has_flag("night_seen")
	var regrow: Array = []
	for p in room.data.props:
		if p.kind == "bush" or p.kind == "clod":
			var n := Prop.new()
			n.kind = p.kind
			n.decor = true  # 只是背景（MV-SLICE-001a）：打不到
			n.position = p.pos
			n.z_index = -1
			if not seen:
				n.modulate.a = 0.0  # 動物復原時長出來
			room.add_child(n)
			regrow.append(n)
	rat = Prop.new()
	rat.kind = "rat"
	rat.position = Vector2(room.data.size.x / 2.0, room.data.ground_y)
	if not seen:
		rat.modulate.a = 0.0  # 動物復原的替身先演，交還時換回真的
	room.add_child(rat)
	if not seen or not prelude.is_empty():
		await runner.play(prelude + ([] if seen else [FieldAnimals.new(regrow, rat)]))
		if not is_inside_tree():
			return
	_active = true


func _physics_process(delta: float) -> void:
	if not _active or not is_instance_valid(room.player):
		return
	var d: float = rat.position.x - room.player.global_position.x
	if absf(d) >= FLEE_DIST:
		return
	var dir := 1.0 if d >= 0.0 else -1.0
	rat.position.x = clampf(rat.position.x + dir * gs.tn.run_speed * FLEE_SPEED * delta, WALL_MARGIN - 10.0, room.data.size.x - WALL_MARGIN + 10.0)
	if rat.position.x <= WALL_MARGIN or rat.position.x >= room.data.size.x - WALL_MARGIN:
		_catch()


func _catch() -> void:
	_active = false
	rat.rest()  # MV-SLICE-001b2b2：網子底下待著
	var net := Prop.new()
	net.kind = "net"
	net.position = rat.position
	room.add_child(net)
	await runner.play([RatDeal.new(rat, net)])  # end_state 設 rat_caught、移除老鼠與網子；田地維持夜晚
