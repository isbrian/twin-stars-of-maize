extends RefCounted
# 一幀的操作意圖。實體輸入由 read_from_input() 填入；--self-test 與展示模式直接填欄位。
# 「按下」類欄位只維持一幀，player 在每幀結尾呼叫 clear_presses()。

# 吹管口（MV-TUNE-001）：吹射姿勢的雙臂整組轉到瞄準角度（world/rig_view.gd overlay_dart），吹管口繞著遠側肩膀轉。
# 面向右、相對腳底：吹管口＝肩膀＋REACH 轉到瞄準角度；兩兄弟、跑跳各姿勢最多差 8 px（test_twin_animator 核對）。
# 常數寫在這裡、不在執行時讀骨架：core 不依賴 world，沒有骨架的角色照樣能射。
const BLOWGUN_SHOULDER := Vector2(-22, -132)
const BLOWGUN_REACH := Vector2(127, -20)  # 吹管口在瞄準方向前 127、軸線偏 20（吹管握在手上，不穿過肩膀）
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
var interact_pressed := false  # MV-SLICE-001a：休息、兌換、撿東西
var skill_1_pressed := false  # MV-SLICE-001a：動物技能槽 1、2
var skill_2_pressed := false
var aim := Vector2.ZERO  # 零向量＝朝面向

static var muted_physics_frame := -1  # MV-SLICE-001a：選單剛開關的那個物理幀不讀「按下」（ui/menu_input.gd）


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
	interact_pressed = Input.is_action_just_pressed("interact")
	skill_1_pressed = Input.is_action_just_pressed("skill_1")
	skill_2_pressed = Input.is_action_just_pressed("skill_2")
	if Engine.get_physics_frames() == muted_physics_frame:
		clear_presses()
	aim = _read_aim(who)


## 朝 aim（單位向量）射時，吹管口相對腳底的位置；面向左時鏡像
static func muzzle(aim: Vector2, facing: int) -> Vector2:
	var m := BLOWGUN_SHOULDER + BLOWGUN_REACH.rotated(Vector2(aim.x * facing, aim.y).angle())
	return Vector2(m.x * facing, m.y)


## 瞄準 rel（相對腳底的點）的方向：從吹管口出發的直線正好通過 rel（吹管軸線偏離肩膀，不能直接用肩膀到 rel 的方向）
static func aim_toward(rel: Vector2, facing: int) -> Vector2:
	var d := Vector2(rel.x * facing, rel.y) - BLOWGUN_SHOULDER
	var along := sqrt(maxf(d.length_squared() - BLOWGUN_REACH.y * BLOWGUN_REACH.y, 0.0))
	var a := Vector2.from_angle(d.angle() - atan2(BLOWGUN_REACH.y, along))
	return Vector2(a.x * facing, a.y)


## 手把左搖桿的吹箭方向（Brian 試玩 2026-10-12）：吸到最近的 45°（8 方向，邊跑邊瞄也穩）；
## 死區內或只推左右＝零向量（朝面向）；站在地上推正下＝朝面向斜下（正下會射進腳邊的地板）
static func left_stick_aim(stick: Vector2, facing: int, on_floor: bool) -> Vector2:
	if stick.length() <= Tune.data.aim_deadzone:
		return Vector2.ZERO
	var a := Vector2.from_angle(snappedf(stick.angle(), PI / 4.0))
	if absf(a.y) < 0.01:
		return Vector2.ZERO
	if on_floor and a.is_equal_approx(Vector2.DOWN):
		return Vector2(facing, 1).normalized()
	return a


func _read_aim(who: Node2D) -> Vector2:
	var facing: int = who.facing if "facing" in who else 1  # who 不一定是角色（test_player 用空的 Node2D 測搖桿）
	if InputSetup.uses_mouse():
		return aim_toward(who.get_global_mouse_position() - who.global_position, facing)
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > Tune.data.aim_deadzone:  # 右搖桿優先：精準角度
		return stick.normalized()
	var on_floor: bool = who.is_on_floor() if who is CharacterBody2D else true
	return left_stick_aim(Input.get_vector("move_left", "move_right", "look_up", "look_down"), facing, on_floor)


func clear_presses() -> void:
	jump_pressed = false
	roll_pressed = false
	attack_pressed = false
	heal_pressed = false
	dart_pressed = false
	swap_pressed = false
	interact_pressed = false
	skill_1_pressed = false
	skill_2_pressed = false
