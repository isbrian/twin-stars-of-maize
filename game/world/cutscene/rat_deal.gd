extends RefCounted
# 交換（MV-SLICE-001c3a，SLICE-c3-7、8）：網子罩住老鼠 → 老鼠開口求饒、提出交換 → 兄弟倆給玉米、豆子、可可 →
# 老鼠說出球具掛在家裡的屋頂下 → 網子拿開，老鼠往祖母家跑走。遊戲改編成交換（原典是燒尾巴，MV-DESIGN-002 第 5 項）；食物見原典 p.138。

const TwinAnimator := preload("res://world/twin_animator.gd")
const Silhouette := preload("res://world/cutscene/silhouette.gd")
const Prop := preload("res://world/prop.gd")
const FieldDusk := preload("res://world/cutscene/field_dusk.gd")
const FieldAnimals := preload("res://world/cutscene/field_animals.gd")

const S1 := "別吃我！給我一頓飯，我就告訴你們一件事。"
const N1 := "兄弟倆給了牠玉米、豆子與可可。"
const S2 := "你們父親的球具，就掛在家裡的屋頂下。"
const WHO := "老鼠"
const TWIN_GAP := 90.0
const RAT_RUN := 650.0
const STAND := 200.0  # 兄弟倆站在老鼠旁這麼遠（交還時玩家放在這裡）

var rat: Node2D  # 真正的老鼠道具（網子底下）
var net: Node2D


func _init(p_rat: Node2D, p_net: Node2D) -> void:
	rat = p_rat
	net = p_net


func play(cs) -> void:
	cs.sfx(&"voc_alive")  # 老鼠登場＝活物（MV-SLICE-001d1a）
	cs.sfx(&"cs_net_drop")  # 網子罩住（MV-SLICE-001d1b）
	var r = cs.host.room
	var gy: float = r.data.ground_y
	cs.conceal(rat)
	cs.conceal(net)
	var side := _side(r)
	cs.camera.position.x = FieldDusk.cam_x(cs, rat.position.x + side * 300.0)
	cs.camera.reset_smoothing()
	var rat_a: Node2D = cs.spawn("rat", rat.position)
	rat_a.facing = int(side)
	var net_a := Prop.new()
	net_a.kind = "net"
	net_a.position = rat.position
	cs.place(net_a)
	var p = r.player
	var me: Node2D = cs.spawn(TwinAnimator.CHARS[p.twin_index], Vector2(p.position.x, gy))
	var other: Node2D = cs.spawn(TwinAnimator.CHARS[1 - p.twin_index], me.position + Vector2(side * TWIN_GAP, 0))
	var stand := rat.position.x + side * STAND
	await cs.together([cs.walk.bind(me, stand), cs.walk.bind(other, stand + side * TWIN_GAP)])
	me.facing = -int(side)
	other.facing = -int(side)
	await cs.wait(0.5)
	await _talk(cs, rat_a, S1)
	await cs.together([cs.narrate.bind(N1), _give.bind(cs, rat.position.x + side * 90.0, gy)])
	await _talk(cs, rat_a, S2)
	net_a.queue_free()
	await cs.wait(0.4)
	await cs.walk(rat_a, r.data.size.x + 200.0, RAT_RUN, "run")  # 往祖母家（右門）跑走
	await cs.wait(0.5)


## 老鼠開口：說話時播 talk（後腳站起比劃；MV-SLICE-001c3b），說完回待機
static func _talk(cs, rat_a: Node2D, text: String) -> void:
	rat_a.play("talk")
	await cs.say(WHO, text)
	rat_a.play("idle")


## 兄弟倆站在離牆遠的那一側
func _side(room) -> float:
	return 1.0 if rat.position.x < room.data.size.x / 2.0 else -1.0


## 三樣食物一個一個放到老鼠面前
func _give(cs, x: float, gy: float) -> void:
	var i := 0
	for kind in ["corn", "beans", "cacao"]:
		var s := Silhouette.new()
		s.kind = kind
		s.position = Vector2(x + (i - 1) * 40.0, gy)
		s.modulate.a = 0.0
		cs.place(s)
		cs.sfx(&"cs_food_place")
		await cs.tint(s, Color.WHITE, 0.4)
		await cs.wait(0.4)
		i += 1


func end_state(host) -> void:
	host.gs.set_flag("rat_caught")
	if is_instance_valid(rat):
		host.player.position.x = rat.position.x + _side(host.room) * STAND  # 接在替身最後的位置
		host.player.velocity = Vector2.ZERO
	for n in [rat, net]:
		if is_instance_valid(n):
			n.queue_free()
	host.runner.apply_night(host.room)
