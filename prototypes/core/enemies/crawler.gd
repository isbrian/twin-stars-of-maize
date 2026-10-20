extends "res://enemies/enemy.gd"
# 爬行型（規格書第 5 節）：地面巡邏 → 前搖（白色圓形，可招架）→ 往前撲 → 收招（近戰空檔）。

const SIGHT_HEIGHT := 250.0  # 與玩家的高低差超過這個就看不到

var home_x := 0.0
var patrol_dir := 1


func _init() -> void:
	size = Vector2(110, 70)
	parryable = true


func _ready() -> void:
	super()
	home_x = position.x


func _max_hp() -> int:
	return tn.crawler_hp


func _telegraph_time() -> float:
	return tn.crawler_telegraph


func _recover_time() -> float:
	return tn.crawler_recover


func _damage() -> int:
	return tn.crawler_damage


func _idle(_delta: float) -> void:
	if target != null and state_time >= tn.enemy_rest and _sees_target():
		start_telegraph()
		return
	if position.x > home_x + tn.crawler_patrol_range:
		patrol_dir = -1
	elif position.x < home_x - tn.crawler_patrol_range:
		patrol_dir = 1
	facing = patrol_dir
	velocity.x = patrol_dir * tn.crawler_patrol_speed


func _sees_target() -> bool:
	var d := target.global_position - global_position
	return absf(d.x) <= tn.crawler_detect_range and absf(d.y) < SIGHT_HEIGHT


func _begin_attack() -> void:
	velocity.x = facing * tn.crawler_lunge_speed


func _attack(_delta: float) -> void:
	velocity.x = facing * tn.crawler_lunge_speed
	if state_time >= tn.crawler_lunge_time:
		_end_attack()
