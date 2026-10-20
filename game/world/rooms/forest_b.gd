extends RefCounted
# 支路 B（MV-SLICE-001c4a）：地上整片荊棘，上方一段段原木（單跳搆得到），最後一段上是血量碎片。
# MV-TUNE-004（Brian 試玩 2026-10-16：失手就一直掉進荊棘）：原木寬 200 → 300、間距約 350 → 250。
const Kit := preload("res://world/rooms/kit.gd")


static func data() -> Dictionary:
	return Kit.room("forest_b", 2, {
		"theme": "forest", "variant": 0,
		"doors": [Kit.door_left("to_forest_4", "forest_4", "to_forest_b")],
		"hazards": [Rect2(800, Kit.GROUND_Y - 60, 2300, 60)],
		"platforms": [Rect2(650, 640, 300, 30), Rect2(1200, 600, 300, 30), Rect2(1750, 580, 300, 30), Rect2(2300, 600, 300, 30), Rect2(2850, 540, 320, 30)],
		"fragment": {"id": "frag_b", "pos": Vector2(3010, 540)},
		"enemies": [{"kind": "flyer", "pos": Vector2(2100, Kit.GROUND_Y - 550)}],
	})
