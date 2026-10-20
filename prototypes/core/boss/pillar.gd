extends Node2D
# 寶座反光柱（第 2 段）：落點先亮 pillar_warn 秒 → 光柱持續 pillar_active 秒（不可招架）→ 消失。原點在地面。

const Hitbox := preload("res://combat/hitbox.gd")
const L := preload("res://combat/layers.gd")
const SIZE := Vector2(120, 960)

var tn
var parryable := false
var move_name := "pillars"
var t := 0.0
var hitbox: Hitbox


func _ready() -> void:
	hitbox = Hitbox.new()
	hitbox.configure(SIZE, Vector2(0, -SIZE.y / 2.0), L.PLAYER_HURT)
	add_child(hitbox)


func _physics_process(delta: float) -> void:
	t += delta
	if t >= tn.pillar_warn + tn.pillar_active:
		queue_free()
		return
	if t >= tn.pillar_warn and not hitbox.active:
		hitbox.start()
	for hb in hitbox.collect():
		hb.receive(1, self, &"enemy")
	queue_redraw()


func _draw() -> void:
	if t < tn.pillar_warn:  # 預告：地面一個亮白光點＋細線
		draw_circle(Vector2(0, -6), 26.0, Color(1, 1, 1, 0.9))
		draw_line(Vector2(0, -SIZE.y), Vector2(0, 0), Color(1, 1, 1, 0.35), 3.0)
	else:
		draw_rect(Rect2(-SIZE.x / 2.0, -SIZE.y, SIZE.x, SIZE.y), Color(1, 1, 0.92, 0.85))
