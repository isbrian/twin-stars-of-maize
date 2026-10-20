extends Area2D
# 荊棘地形（MV-SLICE-001c4a）：碰到的是玩家身體就發 touched；扣血與放回由房間處理（room.gd）。

const L := preload("res://core/combat/layers.gd")

signal touched(body: Node)

var rect := Rect2()  # 世界座標範圍（MV-SLICE-001d1a：危險聲距離層量到邊緣）


## 加入場景前呼叫：r 是世界座標的範圍
func setup(r: Rect2) -> void:
	rect = r
	position = r.get_center()
	collision_layer = 0
	collision_mask = L.PLAYER_BODY
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	add_child(cs)
	body_entered.connect(func(b): touched.emit(b))
