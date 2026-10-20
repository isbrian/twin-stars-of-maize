extends RefCounted
# Boss 戰場地共用：矩形地形。
# ponytail: yagni: 地形用矩形資料建立 | upgrade if: 正式素材進來，改用 TileMapLayer

const L := preload("res://combat/layers.gd")

const GROUND_COLOR := Color(0.22, 0.27, 0.25)


## 加一塊實心（或單向）地形；回傳形狀，大門用它切換 disabled
static func add_solid(parent: Node, r: Rect2, one_way := false) -> CollisionShape2D:
	var body := StaticBody2D.new()
	body.collision_layer = L.WORLD
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	cs.one_way_collision = one_way
	body.add_child(cs)
	parent.add_child(body)
	return cs


## 篝火（灰盒）：地面上的小火堆
static func draw_bonfire(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_rect(Rect2(at + Vector2(-40, -12), Vector2(80, 12)), Color(0.35, 0.25, 0.18))
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-28, -12), at + Vector2(0, -80), at + Vector2(28, -12)]), Color(1.0, 0.6, 0.2))
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-12, -12), at + Vector2(0, -48), at + Vector2(12, -12)]), Color(1.0, 0.9, 0.5))
