extends CharacterBody2D
# 灰盒角色：A/D 移動、Space 跳躍、按住 F 聆聽（聆聽時只能慢走、不能跳，見 CORE_GAMEPLAY.md 議題 10）

const SPEED := 260.0
const LISTEN_SPEED_RATIO := 0.35
const JUMP_VELOCITY := -520.0
const GRAVITY := 1400.0

var listening := false
var force_listen := false  # 截圖驗證用


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 64)
	shape.shape = rect
	shape.position = Vector2(0, -32)
	add_child(shape)


func _physics_process(delta: float) -> void:
	listening = force_listen or Input.is_action_pressed("listen")
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif Input.is_action_just_pressed("jump") and not listening:
		velocity.y = JUMP_VELOCITY
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = dir * SPEED * (LISTEN_SPEED_RATIO if listening else 1.0)
	move_and_slide()


func _draw() -> void:
	draw_rect(Rect2(-16, -64, 32, 64), Color(0.9, 0.75, 0.3))
