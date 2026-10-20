extends StaticBody2D
# 木障（MV-PROTO-002 規格書第 6 節）：實心地形，擋路、擋飛鏢。
# 只有 Xbalanque 的飛鏢能標記它（由他的工具砍碎）；Hunahpu 的飛鏢、任何人的近戰只有一聲悶響。
# 碎了就一直碎著，F10 重置房間時 restore()。

const Hurtbox := preload("res://core/combat/hurtbox.gd")
const L := preload("res://core/combat/layers.gd")
const PAD := 4.0  # 受擊框每邊比實體大，飛鏢射線先碰到受擊框（計畫 D5）

signal thudded
signal broken

var rect: Rect2
var is_broken := false
var art := false  # MV-SLICE-001b1：true＝由子節點的素材呈現，不畫灰盒
var _shape := CollisionShape2D.new()
var _hurtbox: Hurtbox


## 加入場景前呼叫：rect 是世界座標的範圍
func setup(r: Rect2) -> void:
	rect = r
	position = r.get_center()
	collision_layer = L.WORLD
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = r.size
	_shape.shape = shape
	add_child(_shape)
	_hurtbox = Hurtbox.new()
	_hurtbox.setup(r.size + Vector2(PAD, PAD) * 2.0, Vector2.ZERO, L.BARRIER)
	_hurtbox.hurt.connect(_on_hurt)
	add_child(_hurtbox)


func _on_hurt(_amount: int, source: Node, kind: StringName) -> void:
	if is_broken:
		return
	if kind == &"dart" and source != null and source.get("marks_barrier") and is_instance_valid(source.shooter):
		source.shooter.send_tool(self)  # 工具已在外時沒有反應
		return
	thudded.emit()


func break_apart() -> void:
	if is_broken:
		return
	is_broken = true
	_shape.set_deferred("disabled", true)
	_hurtbox.set_deferred("collision_layer", 0)  # 射線查詢不看 monitorable，要拿掉層才不會擋飛鏢
	visible = false
	broken.emit()


func restore() -> void:
	is_broken = false
	_shape.set_deferred("disabled", false)
	_hurtbox.set_deferred("collision_layer", L.BARRIER)
	visible = true


func _draw() -> void:
	if art:
		return
	var r := Rect2(-rect.size / 2.0, rect.size)
	draw_rect(r, Color(0.5, 0.35, 0.2))
	var y := r.position.y
	while y < r.end.y:  # 斜紋：和地形一眼可分
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, minf(y + r.size.x, r.end.y)), Color(0.35, 0.22, 0.12), 4.0)
		y += 40.0
	draw_rect(r, Color(0.3, 0.2, 0.1), false, 4.0)
