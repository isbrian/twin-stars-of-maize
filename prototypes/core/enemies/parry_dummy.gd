extends "res://enemies/enemy.gd"
# 招架練習對象（MV-PROTO-002 規格書第 7 節）：原地不動、不會死，每 dummy_interval 秒出一次可招架的攻擊。
# 前搖訊號與時間、傷害都和爬行型相同；因為不往前撲，攻擊判定改成面前 200 px 的方框（計畫 D3）。

const REACH := 200.0

var cycle_left := 0.0


func _init() -> void:
	size = Vector2(110, 70)
	parryable = true


func _ready() -> void:
	super()
	cycle_left = tn.dummy_interval


func _physics_process(delta: float) -> void:
	cycle_left -= delta
	super(delta)


func _telegraph_time() -> float:
	return tn.crawler_telegraph


func _recover_time() -> float:
	return tn.crawler_recover


func _damage() -> int:
	return tn.crawler_damage


func _idle(_delta: float) -> void:
	velocity.x = 0.0
	if target != null and cycle_left <= 0.0:
		cycle_left = tn.dummy_interval
		start_telegraph()


## 前搖開始時就設好判定框（判定框要在啟用前至少 2 個物理幀設定）
func start_telegraph() -> void:
	super()
	hitbox.configure(Vector2(REACH, size.y * 1.1), Vector2(facing * (size.x / 2.0 + REACH / 2.0), -size.y / 2.0), L.PLAYER_HURT)


func _begin_attack() -> void:
	velocity.x = 0.0


func _attack(_delta: float) -> void:
	velocity.x = 0.0
	if state_time >= tn.crawler_lunge_time:
		_end_attack()


## 被招架：硬直結束後重新計時（規格書第 7 節）
func parried() -> void:
	var was_attacking := state == State.ATTACK
	super()
	if was_attacking:
		cycle_left = tn.parry_stagger + tn.dummy_interval


## 不會死：受到攻擊只閃白
func _on_hurt(_amount: int, _source: Node, _kind: StringName) -> void:
	if state == State.DEAD:
		return
	flash_left = tn.enemy_flash_time


func _draw() -> void:
	draw_rect(Rect2(-6.0, -size.y - 40.0, 12.0, 40.0), Color(0.45, 0.35, 0.25))  # 頂上的木樁：和一般敵人區分
	super()
