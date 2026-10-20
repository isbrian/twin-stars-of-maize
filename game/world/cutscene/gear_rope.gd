extends RefCounted
# 咬繩（MV-SLICE-001c3a，SLICE-c3-9）：抓到老鼠後的夜裡進祖母家 → 祖母睡著 → 老鼠跑進來、爬上屋梁、咬斷吊著球具的繩子 → 球具落地。
# 交還後玩家自己撿（SLICE-c3-11）：end_state 就放出可撿的球具（MV-SLICE-001c3b：不再等黑邊收完、空 0.4 秒）。原典是用蚊子支開祖母（p.139～140），遊戲改成祖母睡著。

const TwinAnimator := preload("res://world/twin_animator.gd")
const Prop := preload("res://world/prop.gd")

const N1 := "祖母睡著了。"
const N2 := "老鼠爬上屋梁，咬斷了吊著球具的繩子。"
const ROPE_AT := Vector2(930, 420)  # home.gd 的 rope 道具
const RAT_RUN := 500.0
const TWIN_GAP := 90.0


static func rope_at(room) -> Vector2:
	for p in room.data.props:
		if p.kind == "rope":
			return p.pos
	return ROPE_AT


func play(cs) -> void:
	var r = cs.host.room
	var gy: float = r.data.ground_y
	var at := rope_at(r)
	var p = r.player
	var me: Node2D = cs.spawn(TwinAnimator.CHARS[p.twin_index], Vector2(p.position.x, gy))
	var other: Node2D = cs.spawn(TwinAnimator.CHARS[1 - p.twin_index], me.position - Vector2(TWIN_GAP, 0))
	me.facing = 1
	other.facing = 1
	var gear := Prop.new()
	gear.kind = "gear"
	gear.position = at
	cs.place(gear)
	await cs.narrate(N1)
	await cs.wait(1.0)
	var rat: Node2D = cs.spawn("rat", Vector2(-80.0, gy))
	await cs.walk(rat, at.x, RAT_RUN, "run")
	cs.sfx(&"cs_rat_climb")  # MV-SLICE-001d1b
	await cs.fly(rat, at + Vector2(0, 40), 1.5, "climb", false)  # 爬上屋梁（MV-SLICE-001c3b）
	rat.play("gnaw")
	cs.sfx(&"cs_rat_gnaw")
	await cs.together([cs.narrate.bind(N2), cs.wait.bind(2.0)])
	var from := gear.position
	cs.sfx(&"cs_rope_snap")  # 繩斷、球具落地
	await cs.animate(0.5, func(k: float): gear.position = from.lerp(Vector2(at.x, gy), k * k))
	await cs.wait(1.0)
	await cs.fly(rat, Vector2(at.x + 120.0, gy), 0.5, "run")
	await cs.walk(rat, r.data.size.x + 150.0, RAT_RUN, "run")
	await cs.wait(0.5)


func end_state(host) -> void:
	host.gs.set_flag("gear_dropped")
	host.room.add_pickup("gear", "gear", Vector2(rope_at(host.room).x, host.room.data.ground_y))
