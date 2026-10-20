extends RefCounted
# 一幀的操作意圖。實體輸入由 read_from_input() 填入；--self-test 與展示模式直接填欄位。
# 「按下」類欄位只維持一幀，player 在每幀結尾呼叫 clear_presses()。

const MUZZLE := Vector2(0, -45)  # 吹箭口相對腳底的位置：腰部高度，朝面向射時打得到地面上的爬行型（受擊框高 70）
const DIR_THRESHOLD := 0.6  # 上攻／下劈要推得夠明確（原始強度），避免跑動中搖桿稍微偏上就變上攻

var move_x := 0.0  # -1、0、1（類比搖桿也數位化成全速，HK 手感）
var up := false
var down := false
var jump_pressed := false
var jump_held := false
var roll_pressed := false
var attack_pressed := false
var heal_pressed := false
var dart_pressed := false
var swap_pressed := false
var aim := Vector2.ZERO  # 零向量＝朝面向


func read_from_input(who: Node2D) -> void:
	move_x = signf(Input.get_axis("move_left", "move_right"))
	up = Input.get_action_raw_strength("look_up") >= DIR_THRESHOLD
	down = Input.get_action_raw_strength("look_down") >= DIR_THRESHOLD
	jump_pressed = Input.is_action_just_pressed("jump")
	jump_held = Input.is_action_pressed("jump")
	roll_pressed = Input.is_action_just_pressed("roll")
	attack_pressed = Input.is_action_just_pressed("attack")
	heal_pressed = Input.is_action_just_pressed("heal")
	dart_pressed = Input.is_action_just_pressed("dart")
	swap_pressed = Input.is_action_just_pressed("swap")
	aim = _read_aim(who)


func _read_aim(who: Node2D) -> Vector2:
	if InputSetup.uses_mouse():
		return (who.get_global_mouse_position() - (who.global_position + MUZZLE)).normalized()
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	return stick.normalized() if stick.length() > Tune.data.aim_deadzone else Vector2.ZERO


func clear_presses() -> void:
	jump_pressed = false
	roll_pressed = false
	attack_pressed = false
	heal_pressed = false
	dart_pressed = false
	swap_pressed = false
