extends Node2D
# 彈跳物（假光結晶）：懸空、站不上去、碰到不傷人；只會被攻擊判定打中，供下劈彈跳（B8）。

const Hurtbox := preload("res://combat/hurtbox.gd")
const L := preload("res://combat/layers.gd")
const SIZE := Vector2(70, 70)

var flash_left := 0.0


func _ready() -> void:
	var hb := Hurtbox.new()
	hb.setup(SIZE, Vector2.ZERO, L.POGO)
	hb.hurt.connect(_on_hit)
	add_child(hb)


func _on_hit(_amount: int, _source: Node, _kind: StringName) -> void:
	flash_left = 0.1


func _process(delta: float) -> void:
	flash_left = maxf(flash_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var h := SIZE / 2.0
	var pts := PackedVector2Array([Vector2(0, -h.y), Vector2(h.x, 0), Vector2(0, h.y), Vector2(-h.x, 0)])
	draw_colored_polygon(pts, Color.WHITE if flash_left > 0.0 else Color(0.7, 0.9, 1.0))
