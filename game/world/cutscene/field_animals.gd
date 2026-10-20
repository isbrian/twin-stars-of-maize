extends RefCounted
# 動物復原（MV-SLICE-001c3a，SLICE-c3-6）：夜裡森林的動物跑過田地、灌木與土塊長回來 → 兄弟倆撲上去，只抓到鹿和兔子的尾巴 →
# 剩下老鼠在田中央（交還後開始追）。原典 p.135～137；只播一次（night_seen）。動物、尾巴是 MV-ASSET-020 的正式圖（c3b）。

const TwinAnimator := preload("res://world/twin_animator.gd")
const Silhouette := preload("res://world/cutscene/silhouette.gd")
const FieldDusk := preload("res://world/cutscene/field_dusk.gd")

const N1 := "夜裡，森林的動物來了，田地又長回原樣。"
const N2 := "兄弟倆撲上去，只抓到鹿和兔子的尾巴。"
const N3 := "所以鹿和兔子的尾巴，到今天都很短。"
const N4 := "最後只剩一隻老鼠，還在田裡竄。"
const RUN_SECS := 4.0  # 動物跑過畫面
const TWIN_GAP := 90.0
const STOP := 220.0  # 動物停在最左邊灌木右邊這麼遠
const BACK := 450.0  # 最後兄弟倆退到老鼠左邊這麼遠（比老鼠逃跑的 300 遠；交還時玩家放在這裡）

var regrow: Array  # night_rat 建好、透明度 0 的灌木與土塊
var rat: Node2D  # 真正的老鼠道具（透明度 0，交還時出現）


func _init(p_regrow: Array, p_rat: Node2D) -> void:
	regrow = p_regrow
	rat = p_rat


func play(cs) -> void:
	var r = cs.host.room
	var gy: float = r.data.ground_y
	var mid: float = r.data.size.x / 2.0
	var lo: float = regrow.map(func(n): return n.position.x).min()
	var hi: float = regrow.map(func(n): return n.position.x).max()
	var view_x := (lo + hi) / 2.0
	cs.camera.position.x = FieldDusk.cam_x(cs, view_x)
	cs.camera.reset_smoothing()
	var me: Node2D = cs.spawn(TwinAnimator.CHARS[r.player.twin_index], Vector2(lo - 300.0, gy))
	var other: Node2D = cs.spawn(TwinAnimator.CHARS[1 - r.player.twin_index], me.position - Vector2(TWIN_GAP, 0))
	var deer := _animal(cs, "deer", Vector2(view_x + 1100.0, gy))
	var rabbit := _animal(cs, "rabbit", Vector2(view_x + 1300.0, gy))
	var critter := _animal(cs, "critter", Vector2(view_x + 1450.0, gy))
	var rat_a: Node2D = cs.spawn("rat", Vector2(view_x + 1550.0, gy))
	rat_a.play("run")
	rat_a.facing = -1
	var stop := lo + STOP  # 動物停在兄弟倆面前
	cs.sfx(&"cs_animals_run")  # MV-SLICE-001d1b
	cs.sfx(&"cs_bush_regrow")
	await cs.together([
		cs.narrate.bind(N1),
		_regrow.bind(cs),
		move.bind(cs, deer, Vector2(stop + 160.0, gy), RUN_SECS),
		move.bind(cs, rabbit, Vector2(stop + 30.0, gy), RUN_SECS),
		move.bind(cs, critter, Vector2(stop + 400.0, gy), RUN_SECS),
		cs.fly.bind(rat_a, Vector2(mid, gy), RUN_SECS, "run", false),
	])
	rat_a.play("idle")
	me.play("lunge")
	other.play("lunge")
	cs.sfx(&"cs_lunge")
	await cs.together([cs.narrate.bind(N2), cs.fly.bind(me, Vector2(stop - 60.0, gy), 0.4, "lunge"), cs.fly.bind(other, Vector2(stop - 150.0, gy), 0.4, "lunge")])
	_tail("tail_deer", me)
	_tail("tail_rabbit", other)
	await cs.together([cs.play.bind(me, "grab"), cs.play.bind(other, "grab")])  # 起身，近側手握著尾巴（MV-SLICE-001c3b）
	var away := lo - 1400.0  # 動物往左逃出畫面（尾巴留在兄弟倆手上）
	await cs.together([
		move.bind(cs, deer, Vector2(away, gy), 1.2),
		move.bind(cs, rabbit, Vector2(away - 100.0, gy), 1.2),
		move.bind(cs, critter, Vector2(away - 200.0, gy), 1.2),
	])
	await cs.wait(0.6)
	await cs.narrate(N3)
	await cs.together([cs.narrate.bind(N4), FieldDusk.pan.bind(cs, mid, 1.5), cs.walk.bind(me, mid - BACK), cs.walk.bind(other, mid - BACK - TWIN_GAP)])
	me.facing = 1
	other.facing = 1
	await cs.wait(0.8)


## 動物沒有骨架：移動位置加上下彈跳（MV-SLICE-001c3b；跳過時直接到位）
static func move(cs, n: Node2D, to: Vector2, secs: float) -> void:
	var from := n.position
	await cs.animate(secs, func(k: float):
		n.position = from.lerp(to, k)
		n.bounce(k))


static func _animal(cs, kind: String, at: Vector2) -> Node2D:
	var s := Silhouette.new()
	s.kind = kind
	s.position = at
	s.facing = -1
	return cs.place(s)


## 尾巴握在替身的近側手上（hand_r），跟著手動；替身交還時一起釋放
static func _tail(kind: String, twin: Node2D) -> void:
	var s := Silhouette.new()
	s.kind = kind
	twin.hold(s, "hand_r")


## 灌木與土塊依序長回來
func _regrow(cs) -> void:
	for n in regrow:
		await cs.tint(n, Color.WHITE, 0.35)
		await cs.wait(0.15)


func end_state(host) -> void:
	host.gs.set_flag("night_seen")
	for n in regrow:
		if is_instance_valid(n):
			n.modulate = Color.WHITE
	if is_instance_valid(rat):
		rat.modulate = Color.WHITE
		rat.position.x = host.room.data.size.x / 2.0
	host.player.position.x = host.room.data.size.x / 2.0 - BACK  # 接在替身最後的位置
	host.player.velocity = Vector2.ZERO
	host.runner.apply_night(host.room)
