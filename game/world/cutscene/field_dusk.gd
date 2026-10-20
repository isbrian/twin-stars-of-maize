extends RefCounted
# 收工（MV-SLICE-001c3a，SLICE-c3-5）：田地 6 個清完 → 兄弟倆把斧頭插在樹上、掘棒插進土裡 → 工具自己清完田的另一半（左半的演出灌木）→
# 兄弟倆拿起吹管去打獵、天色轉暗入夜。原典 p.134：斧頭、掘棒自己工作，雙胞胎只管打獵。

const TwinAnimator := preload("res://world/twin_animator.gd")
const SceneryView := preload("res://world/scenery_view.gd")
const Prop := preload("res://world/prop.gd")
const Cutscene := preload("res://world/cutscene/cutscene.gd")
const Weapons := preload("res://core/player/weapons.gd")

const N1 := "兄弟倆把斧頭插在樹上，掘棒插進土裡。"
const N2 := "斧頭自己砍樹，掘棒自己翻土。兄弟倆拿起吹管，打獵去了。"
const TWIN_GAP := 90.0
const PAN_SECS := 1.5
const DUSK_SECS := 2.0
const AXE := preload("res://art/prop/wpn_axe.png")
const STICK := preload("res://art/prop/wpn_digging_stick.png")
const TOOL_OF := {"hunahpu": Weapons.Weapon.AXE, "xbalanque": Weapons.Weapon.STICK}  # 同撿工具時的分配（斧頭給胡納普、掘棒給希巴拉克）
const LEAF := Color(0.35, 0.55, 0.2)
const SOIL := Color(0.45, 0.3, 0.18)
const SWINGS := 3

var decor: Array = []  # 田左半的演出灌木（decor Prop）：過場開始時才放（最終審查：清田時放著會讓斧頭旁出現砍不動的灌木），交還時跟替身一起釋放


static func cam_x(cs, x: float) -> float:
	return clampf(x, 960.0, cs.host.room.data.size.x - 960.0)


## 鏡頭平移到 x（y 不變）
static func pan(cs, x: float, secs: float) -> void:
	var from: Vector2 = cs.camera.position
	var to := Vector2(cam_x(cs, x), from.y)
	await cs.animate(secs, func(k: float): cs.camera.position = from.lerp(to, k))


func play(cs) -> void:
	var r = cs.host.room
	var gy: float = r.data.ground_y
	var p = r.player
	for at in r.data.decor_bushes:  # 鏡頭在田的右半，這裡放下去看不到
		var b := Prop.new()
		b.kind = "bush"
		b.decor = true
		b.position = at
		decor.append(cs.place(b))
	var me: Node2D = cs.spawn(TwinAnimator.CHARS[p.twin_index], Vector2(p.position.x, gy))
	var other: Node2D = cs.spawn(TwinAnimator.CHARS[1 - p.twin_index], me.position + Vector2(TWIN_GAP, 0))
	var edge: float = decor[decor.size() - 1].position.x + 450.0  # 演出灌木的右邊、田的中段
	await cs.together([cs.walk.bind(me, edge), cs.walk.bind(other, edge + TWIN_GAP), pan.bind(cs, edge - 300.0, absf(edge - p.position.x) / Cutscene.WALK_SPEED), cs.narrate.bind(N1)])
	me.facing = -1
	other.facing = -1
	for a in [me, other]:
		a.rig.set_weapon(TOOL_OF[a.cid])  # 手上拿著工具插下去（MV-SLICE-001c3b）
	await cs.together([cs.play.bind(me, "plant"), cs.play.bind(other, "plant")])
	for a in [me, other]:
		a.rig.set_weapon(-1)
	var axe := _tool(cs, AXE, Vector2(edge - 120.0, gy - 70.0), -0.5)
	var stick := _tool(cs, STICK, Vector2(edge - 60.0, gy - 40.0), 0.3)
	await cs.together([_work.bind(cs, axe, stick), cs.narrate.bind(N2)])
	await pan.bind(cs, edge, PAN_SECS).call()
	await cs.together([cs.play.bind(me, "dart"), cs.play.bind(other, "dart")])
	var out: float = cs.camera.position.x + 960.0 + 200.0  # 走出畫面就好（最終審查：走到田的右端要 9 秒，收工貼著 28 秒上限）
	var dusk_to: Node = r.scenery if r.scenery != null else r
	await cs.together([cs.walk.bind(me, out), cs.walk.bind(other, out + TWIN_GAP), cs.tint.bind(dusk_to, SceneryView.NIGHT, DUSK_SECS)])
	await cs.wait(0.5)


## 插在地上的工具（武器圖斜插）
static func _tool(cs, tex: Texture2D, at: Vector2, rot: float) -> Node2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.position = at
	sp.rotation = rot
	return cs.place(sp)


## 工具自己工作：鏡頭往左，工具一叢一叢飛過去、灌木淡出
func _work(cs, axe: Node2D, stick: Node2D) -> void:
	await pan(cs, decor[0].position.x, PAN_SECS)
	for i in decor.size():
		var b: Node2D = decor[decor.size() - 1 - i]
		var t: Node2D = axe if i % 2 == 0 else stick
		var from := t.position
		var to := b.position + Vector2(40, -80)
		await cs.animate(0.35, func(k: float): t.position = from.lerp(to, k))
		await chop(cs, t, b.position + Vector2(0, -50), "axe" if t == axe else "stick")
		await cs.tint(b, Color(1, 1, 1, 0), 0.4)


## 工具自己揮砍（MV-SLICE-001c3b，SLICE-c3b-6）：斧頭來回揮、掘棒上下翻，每下在 at 掉一次碎屑（葉片綠／土屑褐）；跳過時什麼都不做
static func chop(cs, tool: Node2D, at: Vector2, kind: String) -> void:
	if cs.skipped:
		return
	var rot0 := tool.rotation
	var pos0 := tool.position
	for i in SWINGS:
		await cs.animate(0.14, func(k: float):
			if kind == "axe":
				tool.rotation = rot0 + lerpf(-0.7, 0.7, k)
			else:
				tool.position = pos0 + Vector2(0, lerpf(-40.0, 10.0, k)))
		cs.place(_debris(at, LEAF if kind == "axe" else SOIL))
		cs.sfx(&"abl_tool_chop" if kind == "axe" else &"abl_tool_dig")  # MV-SLICE-001d1b
		await cs.animate(0.12, func(k: float):
			if kind == "axe":
				tool.rotation = rot0 + lerpf(0.7, -0.7, k)
			else:
				tool.position = pos0 + Vector2(0, lerpf(10.0, -40.0, k)))
	tool.rotation = rot0
	tool.position = pos0


## 一次碎屑：內建粒子（ponytail: native: CPUParticles2D | upgrade if: 要葉片形狀就換成貼圖粒子）
static func _debris(at: Vector2, c: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.amount = 12
	p.lifetime = 0.6
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 220.0
	p.gravity = Vector2(0, 600)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	p.color = c
	p.emitting = true
	return p


func end_state(host) -> void:
	host.gs.set_flag("field_cleared")
	host.runner.apply_night(host.room)
