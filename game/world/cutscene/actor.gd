extends Node2D
# 過場的骨架替身（MV-SLICE-001c2a）：演出時真正的角色藏起來，腳本操作這些替身。
# play(動作)：循環動作一直繞；單次動作停在最後一格。facing 翻骨架（faces＝基準圖面向）。
# Seven Macaw 只顯示完整的頭；add_light() 掛一個假光源（給 c1 的 LightFx 讀 state），每幀放到骨架的光點上。

const TwinAnimator := preload("res://world/twin_animator.gd")
const RigView := preload("res://world/rig_view.gd")
const MacawAnimator := preload("res://world/macaw_animator.gd")
const LightFx := preload("res://world/fx/light_fx.gd")
const MacawGlints := preload("res://world/fx/macaw_glints.gd")

const IDLE := {"sevenmacaw": "idle_ground"}  # 其餘角色是 idle

## LightFx 只讀 state 與 fx_drawn
class FakeLight extends Node2D:
	var state := 0
	var fx_drawn := false

var cid := ""
var rig: Node2D
var anim := ""
var t := 0.0
var rate := 1.0  # 播放速度；負＝倒著播（收翅；c2b）。play() 換動作時回到 1
var light: Node2D
var light_point := "jaw"
var held: Node2D  # 叼著的東西（每幀放到 held_point）
var held_point := "jaw"
var facing := 1:
	set(v):
		facing = v
		if rig != null:
			rig.scale.x = v * rig.faces
			if held != null:  # 手上的東西同一格跟著翻（MV-SLICE-001c3b：尾巴原本慢一格）
				held.position = rig.transform * rig.point(held_point)


static func make(char_id: String) -> Node2D:
	var a = new()
	a.cid = char_id
	a.rig = RigView.new()
	a.rig.name = "Rig"  # MacawGlints 找 Rig（c2b）
	a.add_child(a.rig)
	a.rig.build(char_id)
	if char_id == "sevenmacaw":
		for i in MacawAnimator.HEADS.size():
			a.rig.sprite(MacawAnimator.HEADS[i]).visible = i == 0
	a.facing = 1
	a.play(a.idle_anim())
	return a


## Seven Macaw：只顯示第 i 種頭（MacawAnimator.HEADS）
func set_head(i: int) -> void:
	for k in MacawAnimator.HEADS.size():
		rig.sprite(MacawAnimator.HEADS[k]).visible = k == i


## 叼著 node（加成子節點，每幀放到骨架的光點 point）；release() 放開並回傳
func hold(node: Node2D, point := "jaw") -> void:
	held = node
	held_point = point
	add_child(node)
	_pose()


func release() -> Node2D:
	var n := held
	held = null
	if n != null:
		remove_child(n)
	return n


## 身體框（MacawGlints 的全身光暈用）：Seven Macaw 同 MacawAnimator.BODY、依面向翻；其他角色沒有
func faced_body() -> Rect2:
	if cid != "sevenmacaw":
		return Rect2()
	var r: Rect2 = MacawAnimator.BODY
	return r if facing > 0 else Rect2(-r.end.x, r.position.y, r.size.x, r.size.y)


## 掛上 c1 的身上光點（死亡演出的熄滅用）
func add_glints() -> Node2D:
	return MacawGlints.attach(self)


func idle_anim() -> String:
	return IDLE.get(cid, "idle")


func _anim(n: String) -> Dictionary:
	return RigView.anims_at(rig.anims_path).anims[n]


func anim_length(n: String) -> float:
	var data := RigView.anims_at(rig.anims_path)
	var a: Dictionary = data.anims[n]
	return a.get("length", a.frames[-1].t + 1.0 / data.fps)


func is_loop(n: String) -> bool:
	return _anim(n).get("loop", false)


func play(n: String) -> void:
	anim = n
	t = 0.0
	rate = 1.0
	_pose()


## 目前擺的是動作的第幾秒（循環繞回、單次停在最後一格）
func pose_time() -> float:
	var L := anim_length(anim)
	return fmod(t, L) if is_loop(anim) else clampf(t, 0.0, L - 0.0001)


func set_black(on: bool) -> void:
	modulate = Color.BLACK if on else Color.WHITE


func add_light() -> Node2D:
	light = FakeLight.new()
	add_child(light)
	LightFx.attach(light)
	_pose()
	return light


func _process(delta: float) -> void:
	t += delta * rate
	if cid in TwinAnimator.CHARS and (anim == "walk" or anim == "run") and rate > 0.0:  # 過場只有雙胞胎有腳步（SLICE-d1b-5）
		var data := RigView.anims_at(rig.anims_path)
		TwinAnimator.play_steps(cid, data.anims[anim], data.fps, t - delta * rate, t, global_position)
	_pose()


func _pose() -> void:
	rig.pose(anim, pose_time())
	if light != null:
		light.position = rig.transform * rig.point(light_point)
	if held != null:
		held.position = rig.transform * rig.point(held_point)
