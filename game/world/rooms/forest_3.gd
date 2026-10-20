extends RefCounted
# 森林 3（MV-SLICE-001c4a 改寫）：高低兩層平台；藏點（10 顆可可豆）在高 380 的平台上；右端高處平台通往支路 A。
const Kit := preload("res://world/rooms/kit.gd")

const LEDGE_Y := 600.0


static func data() -> Dictionary:
	return Kit.room("forest_3", 3, {
		"theme": "forest", "variant": 2,
		"doors": [Kit.door_left("to_forest_2", "forest_2", "to_forest_3"), Kit.door_branch(3, "to_forest_a", "forest_a", "to_forest_3", LEDGE_Y), Kit.door_right_under(3, "to_forest_4", "forest_4", "to_forest_3", LEDGE_Y)],
		"solids": [Kit.ledge(3, LEDGE_Y)],
		"platforms": [Rect2(1500, 650, 300, 30), Rect2(1800, Kit.GROUND_Y - 380, 360, 30), Rect2(3200, 620, 360, 30)],
		"stash": {"id": "forest_3", "pos": Vector2(1980, Kit.GROUND_Y - 380)},
		"enemies": [
			{"kind": "crawler", "pos": Vector2(1300, Kit.GROUND_Y)},
			{"kind": "crawler", "pos": Vector2(3000, Kit.GROUND_Y)},
			{"kind": "flyer", "pos": Vector2(2400, Kit.GROUND_Y - 450)},
			{"kind": "reflector", "pos": Vector2(2000, Kit.GROUND_Y)},  # MV-SLICE-001c4c1
		],
	})
