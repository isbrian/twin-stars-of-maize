extends Node2D
# 擲出的 nance 果（規格書第 3 節）：直線飛行的拋射物，可招架；招架成功擊碎果子、破綻 +15。
# 命中角色或落地就消失。

const Hitbox := preload("res://core/combat/hitbox.gd")
const L := preload("res://core/combat/layers.gd")
const MAX_TRAVEL := 2400.0
const TEX: Texture2D = preload("res://art/prop/prop_nance_fruit.png")

var tn
var boss: Node
var direction := Vector2.LEFT
var ground_y := 900.0
var parryable := true
var move_name := "throw_fruit"
var traveled := 0.0
var hitbox: Hitbox
var _frames := 0


func _ready() -> void:
	hitbox = Hitbox.new()
	hitbox.configure(Vector2(40, 40), Vector2.ZERO, L.PLAYER_HURT)
	add_child(hitbox)


func _physics_process(delta: float) -> void:
	_frames += 1
	if _frames == 3:  # 判定框要在啟用前至少 2 個物理幀設定
		hitbox.start()
	for hb in hitbox.collect():
		hb.receive(1, self, &"enemy")  # 被招架時 parried() 已經處理
		queue_free()
		return
	var step: Vector2 = direction * tn.fruit_speed * delta
	position += step
	traveled += step.length()
	if global_position.y >= ground_y or traveled >= MAX_TRAVEL:
		queue_free()
	queue_redraw()


func parried() -> void:
	if is_instance_valid(boss):
		boss.add_gauge(tn.gauge_parry)
	Audio.play(&"boss_sm_fruit_break")  # 果子被擊碎（MV-SLICE-001d1a）
	queue_free()


func _draw() -> void:
	draw_texture(TEX, -TEX.get_size() / 2.0)  # MV-SLICE-001b1：nance 果（36 px，同原本的圓）
