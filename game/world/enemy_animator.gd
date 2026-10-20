extends Node
# 敵人狀態 → 爬行型、飛行型骨架的動作（MV-SLICE-001b2b1）。掛在敵人底下（敵人被釋放時一起釋放），
# 每個物理幀（在敵人之後）：面向翻轉、顏色、依 choose() 擺姿勢。
# 不改敵人的任何狀態：判定框與數值照舊（SLICE-b2b-10）。前搖、攻擊、收招、硬直的長度由敵人與數值表決定，
# 動作檔的非循環動作播完停在最後一格。

const RigView := preload("res://world/rig_view.gd")
const Tint := preload("res://world/tint.gd")
const Enemy := preload("res://core/enemies/enemy.gd")
const ANIM := {
	Enemy.State.TELEGRAPH: "telegraph",
	Enemy.State.ATTACK: "attack",
	Enemy.State.RECOVER: "recover",
	Enemy.State.STAGGER: "stagger",
}

const THUD_DEG := 8.0  # 反光型擋下時反光面往後一震（MV-SLICE-001c4c2）

var enemy
var rig
var clock := 0.0  # 待機循環的時間（不隨 state_time 歸零，循環不會每次回到第一格）


## 在敵人底下建骨架（畫在敵人後面：程式畫的前搖訊號、硬直色塊在上面）與 animator；不畫灰盒身體
static func attach(e: Node2D, char_id: String) -> Node:
	var a = new()
	a.name = "EnemyAnimator"
	a.enemy = e
	var r := RigView.new()
	r.name = "Rig"
	r.show_behind_parent = true
	e.add_child(r)
	r.build(char_id)
	a.rig = r
	e.portrait_drawn = true
	e.add_child(a)
	a._apply()
	return a


## [動作名, 時間]；死亡當幀（隨後就釋放）照待機
func choose(e) -> Array:
	if "turn_left" in e and e.turn_left > 0.0:  # 反光型轉身（MV-SLICE-001c4c2）
		return ["turn", e.tn.reflector_turn_time - e.turn_left]
	if ANIM.has(e.state):
		return [ANIM[e.state], e.state_time]
	return ["idle", clock]


func _physics_process(delta: float) -> void:
	clock += delta
	_apply()


## 畫面朝向：反光型轉身過半時先朝向玩家那一側（轉完邏輯朝向也是玩家那一側）；其他照 facing
func display_facing(e) -> int:
	if "turn_left" in e and e.turn_left > 0.0 and e.turn_left < e.tn.reflector_turn_time / 2.0:
		if e.target != null and is_instance_valid(e.target):
			return 1 if e.target.global_position.x >= e.global_position.x else -1
		return -e.facing
	return e.facing


func _apply() -> void:
	var e = enemy
	rig.scale.x = (1 if display_facing(e) >= 0 else -1) * rig.faces
	rig.modulate = Tint.of(e)
	var c := choose(e)
	rig.pose(c[0], c[1])
	if "spark_left" in e:  # 反光型：擋下一震（疊在動作角度上，每幀重擺姿勢所以不累積）、光點跟著反光面
		if e.spark_left > 0.0:
			rig.bone("mirror").rotation += deg_to_rad(THUD_DEG)
			rig._sync()  # 分件在 Parts 底下（rig_view._flatten），改骨頭後要同步分件才會動（c4c2 最終審查）
		e.glow_at = rig.transform * rig.point("glow")
