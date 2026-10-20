extends Node
# Seven Macaw 狀態 → 骨架的動作（MV-SLICE-001b2b1 SLICE-b2b-7～9）。掛在 Boss 底下，每個物理幀（在 Boss 之後）：
# 面向翻轉、顏色、依 choose() 擺姿勢、依外觀換頭件（SLICE-b2b-8），再把光源放到頭骨上的光點（SLICE-b2b-7）。
# 不改 Boss 的任何招式數值；招式時間依數值表換成動作時間（同雙胞胎的 attack_time）。
# 動作時間有兩種：待機、飛行、吃果子、哀嚎、跌落是循環、用秒；
# 其餘是分段時間——前搖 0～1、出招 1～2、收招 2～3（各段依數值表的長度換算；衝刺的長度看距離，停在 1）。

const RigView := preload("res://world/rig_view.gd")
const Tint := preload("res://world/tint.gd")
const Macaw := preload("res://core/boss/seven_macaw.gd")
const Nance := preload("res://core/boss/nance_arena.gd")
const HEADS := ["head", "head_jawhurt", "head_maize", "head_blind"]  # 依 appearance：完整、下顎受傷、白玉米牙、失明
## SLICE-b2b-6：骨架站姿「軀幹、骨盆、兩腿（大腿、小腿、腳爪）」分件的不透明外框（不含頭、脖子、翅膀、尾羽），
## 面向右、相對腳底原點；Boss 的受擊框與碰撞攻擊框都用它（test_macaw_rig.test_macaw_body_matches_rig 核對 ±2 px）
const BODY := Rect2(-154, -327, 272, 327)  # MV-TUNE-003 改用分層素材重切後重量（原 -153, -317, 271, 317）
const PERCHED := 4.0  # 腳底比地面高過這個值算在樹上（兩個場地的地面 y 相同）
## 招式 → 動作；招式的 Step 第 0 個是移動階段（dive／eat_fruit／throw_fruit／false_flash 的 TRAVEL、
## throne_charge 的 REPOSITION、flail 的 CHASE）時播 fly。summon、wail、beam、stagger_pounce 沒有移動階段
const MOVE_ANIM := {
	"dive": "dive", "throne_charge": "dive", "stagger_pounce": "dive",
	"eat_fruit": "eat", "throw_fruit": "throw", "flail": "flail",
	"false_flash": "spread", "summon": "spread", "wail": "wail", "beam": "beam",
}
const TRAVELS := ["dive", "eat_fruit", "throw_fruit", "false_flash", "throne_charge", "flail"]

var boss
var rig
var clock := 0.0  # 循環動作的時間（不隨 state_time 歸零）


## 在 Boss 底下建骨架（畫在 Boss 後面：前搖輪廓、訊號、裂紋在上面）與 animator；不畫灰盒身體、第 1 段破綻時跌落
static func attach(b: Node2D) -> Node:
	var a = new()
	a.name = "MacawAnimator"
	a.boss = b
	var r := RigView.new()
	r.name = "Rig"
	r.show_behind_parent = true
	b.add_child(r)
	r.build("sevenmacaw")
	a.rig = r
	b.portrait_drawn = true
	b.set_body_rect(BODY)
	b.add_child(a)
	a._apply()
	return a


## [動作名, 時間]
func choose(b) -> Array:
	match b.state:
		Macaw.State.MOVE:
			return _move_anim(b.move_name, b.move, b.tn)
		Macaw.State.INTERRUPTED:
			return ["stagger", b.state_time]
		Macaw.State.BROKEN:
			return ["fall" if b._falling else "stagger", b.state_time]
		Macaw.State.INTRO:
			if b._intro_step != 1:  # 第 0、2 步是 fly_to（低枝、樹冠）
				return ["fly", clock]
		Macaw.State.DOWN:
			if b.appearance >= b.phase:  # 這一段的光源已拿掉＝段落結束（設局成功後 deactivate）
				return ["down", b.state_time]
	return ["idle_perch" if b.position.y < Nance.GROUND_Y - PERCHED else "idle_ground", clock]


func _move_anim(mv: String, m, tn) -> Array:
	if m.step == 0 and TRAVELS.has(mv):
		return ["fly", clock]
	var t: float = m.t
	var seg := 0.0  # 分段時間：段落起點＋該段經過的比例
	match mv:
		"dive":
			seg = _seg(m.step - 1, t, [tn.dive_telegraph, 0.0, tn.dive_rest])
		"throne_charge":
			seg = _seg(m.step - 1, t, [tn.charge_telegraph, 0.0, tn.pillar_warn + tn.pillar_active])
		"stagger_pounce":
			seg = _seg(m.step, t, [tn.pounce_telegraph, 0.0, tn.pounce_rest])
		"flail":
			seg = _seg(mini(m.step - 1, 1), t if m.step < 3 else tn.flail_active, [tn.flail_telegraph, tn.flail_active])
		"beam":
			seg = _seg(m.step, t, [tn.beam_charge, tn.beam_active, tn.beam_wobble])
		"throw_fruit":
			seg = _seg(0, t, [tn.throw_telegraph])
		"false_flash":
			seg = _seg(0, t, [tn.flash_telegraph])
		"summon":
			seg = _seg(0, t, [tn.summon_telegraph])
		_:  # 吃果子、哀嚎：循環，用秒
			seg = t
	return [MOVE_ANIM[mv], seg]


## 第 k 段經過 t 秒 → k＋比例（不到 1）；長度 0 的段（衝刺：看距離）停在段落起點
static func _seg(k: int, t: float, lengths: Array) -> float:
	var span: float = lengths[k]
	return k + (minf(t / span, 0.999) if span > 0.0 else 0.0)


func _physics_process(delta: float) -> void:
	clock += delta
	_apply()


func _apply() -> void:
	var c := choose(boss)
	pose_at(c[0], c[1])


## 擺一個動作的一格：面向、顏色、頭件、光源（測試逐格呼叫）
func pose_at(anim: String, t: float) -> void:
	var b = boss
	rig.scale.x = (1 if b.facing >= 0 else -1) * rig.faces
	rig.modulate = Tint.of(b)
	rig.pose(anim, t)
	for i in HEADS.size():
		rig.sprite(HEADS[i]).visible = i == b.appearance
	b.light.position = rig.transform * rig.point(Macaw.LIGHT_NAMES[b.phase - 1])
