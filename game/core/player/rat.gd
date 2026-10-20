extends Node2D
# 老鼠的鑽地突襲（MV-SLICE-001a 規格 SLICE-a3）：沿地面往目標鑽，到牠腳下竄出咬一口後消失；
# 咬＝以吹箭的受擊種類打一下（沿用吹箭的打斷與 Boss「吹箭打斷」破綻），能硬直的再加短硬直。
# 沒有目標：往前鑽 rat_range 再回到角色身邊。目標途中消失：立刻消失。
# 外觀：老鼠的骨架播 run、面向移動方向（MV-SLICE-001b2b2；鑽進土裡的演出留給子專案 c）。

const Tuning := preload("res://core/tuning/combat_tuning.gd")
const NpcAnimator := preload("res://world/npc_animator.gd")

const BITE_DIST := 24.0

var tn: Tuning = Tune.data
var target: Node
var owner_body: Node2D  # 回程的終點（角色）
var _had_target := false
var _dir := 1
var _start_x := 0.0
var _returning := false
var _anim  # npc_animator.gd


func launch(from: Vector2, facing: int, p_target: Node, p_owner: Node2D = null) -> void:
	global_position = from
	target = p_target
	_had_target = p_target != null
	owner_body = p_owner
	_dir = facing
	_start_x = from.x
	_anim = NpcAnimator.attach(self, "rat")
	_anim.play("run")
	Audio.play(&"abl_rat_burrow")  # MV-SLICE-001d1b
	_anim.facing = facing


func _physics_process(delta: float) -> void:
	if _had_target:
		if not is_instance_valid(target) or not target.is_inside_tree():
			queue_free()
			return
		var dx: float = target.global_position.x - global_position.x
		if absf(dx) <= BITE_DIST:
			_bite()
			return
		global_position.x += signf(dx) * minf(tn.rat_speed * delta, absf(dx))
		_face(dx)
		return
	if not _returning:
		global_position.x += _dir * tn.rat_speed * delta
		_face(_dir)
		if absf(global_position.x - _start_x) >= tn.rat_range:
			_returning = true
		return
	var home_x: float = owner_body.global_position.x if is_instance_valid(owner_body) else _start_x
	var back: float = home_x - global_position.x
	if absf(back) <= BITE_DIST:
		queue_free()
		return
	global_position.x += signf(back) * minf(tn.rat_speed * delta, absf(back))
	_face(back)


func _bite() -> void:
	Audio.play(&"abl_rat_emerge")
	target.hurtbox.receive(tn.rat_damage, self, &"dart")
	if is_instance_valid(target) and target.has_method("stun"):
		target.stun(tn.rat_stun)
	queue_free()


func _face(dx: float) -> void:
	if dx != 0.0 and _anim != null:
		_anim.facing = 1 if dx > 0.0 else -1
