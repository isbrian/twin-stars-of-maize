extends Node2D
# 假光造物碎成光點（ART-3）：灰盒用小方塊向外飛散、淡出後自行移除。

const COUNT := 14
const LIFE := 0.45

var _parts: Array = []  # 每個元素：[位置, 速度]
var _age := 0.0


func _ready() -> void:
	for i in COUNT:
		var ang := randf() * TAU
		_parts.append([Vector2.ZERO, Vector2(cos(ang), sin(ang)) * randf_range(200.0, 600.0)])


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	for p in _parts:
		p[0] += p[1] * delta
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _age / LIFE
	for p in _parts:
		draw_rect(Rect2(p[0] - Vector2(5, 5), Vector2(10, 10)), Color(1.0, 0.95, 0.7, a))
