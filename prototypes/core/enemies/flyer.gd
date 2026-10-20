extends "res://enemies/enemy.gd"
# 飛行型（規格書第 5 節）：在玩家斜上方盤旋 → 前搖（暗紫鋸齒，不可招架）
# → 朝「前搖開始時玩家的位置」俯衝 → 在地面收招（近戰空檔）→ 飛回盤旋位置。
# 玩家離出生點超過 flyer_leash_range 時不追，回出生點待命（不會追到平台段）。

const ARRIVE := 60.0  # 離盤旋點多近算就位、可以出招

var home := Vector2.ZERO
var dive_target := Vector2.ZERO
var dive_dir := Vector2.ZERO
var dived := 0.0


func _init() -> void:
	size = Vector2(90, 60)
	parryable = false


func _ready() -> void:
	super()
	home = global_position


func _max_hp() -> int:
	return tn.flyer_hp


func _telegraph_time() -> float:
	return tn.flyer_telegraph


func _recover_time() -> float:
	return tn.flyer_recover


func _damage() -> int:
	return tn.flyer_damage


func _uses_gravity() -> bool:
	return false


func _idle(_delta: float) -> void:
	if target == null:
		velocity = Vector2.ZERO
		return
	var engaged := home.distance_to(target.global_position) <= tn.flyer_leash_range
	var hover := home
	if engaged:
		var side := 1.0 if global_position.x >= target.global_position.x else -1.0
		hover = target.global_position + Vector2(side * tn.flyer_hover_offset.x, tn.flyer_hover_offset.y)
		facing = 1 if target.global_position.x >= global_position.x else -1
	velocity = (hover - global_position).limit_length(tn.flyer_hover_speed)  # 越近越慢，平滑就位
	var near := global_position.distance_to(hover) <= ARRIVE
	var in_range := global_position.distance_to(target.global_position) <= tn.flyer_detect_range
	if engaged and near and in_range and state_time >= tn.enemy_rest:
		start_telegraph()


func start_telegraph() -> void:
	dive_target = target.global_position
	super()


func _begin_attack() -> void:
	dive_dir = global_position.direction_to(dive_target)
	dived = 0.0


func _attack(delta: float) -> void:
	velocity = dive_dir * tn.flyer_dive_speed
	dived += tn.flyer_dive_speed * delta
	if is_on_floor() or dived >= tn.flyer_dive_max:
		velocity = Vector2.ZERO
		_end_attack()
