extends RefCounted
# 森林 6（MV-SLICE-001c4a 新增）：綜合（水晶、荊棘、敵人）；右端高處平台通往支路 C；右門進 Boss 段落（nance 樹前的篝火）。
const Kit := preload("res://world/rooms/kit.gd")

const LEDGE_Y := 600.0


static func data() -> Dictionary:
	return Kit.room("forest_6", 3, {
		"theme": "forest", "variant": 2,
		"doors": [Kit.door_left("to_forest_5", "forest_5", "to_forest_6"), Kit.door_branch(3, "to_forest_c", "forest_c", "to_forest_6", LEDGE_Y), Kit.door_right_under(3, "to_boss", "boss", "to_forest_6", LEDGE_Y)],
		"solids": [Kit.ledge(3, LEDGE_Y)],
		"crystals": [Vector2(2200, 640)],
		"platforms": [Rect2(3500, 620, 360, 30)],
		"hazards": [Rect2(3000, Kit.GROUND_Y - 60, 300, 60), Rect2(4100, Kit.GROUND_Y - 60, 240, 60)],
		"enemies": [
			{"kind": "crawler", "pos": Vector2(1500, Kit.GROUND_Y)},
			{"kind": "flyer", "pos": Vector2(2600, Kit.GROUND_Y - 450)},
			{"kind": "crawler", "pos": Vector2(3700, Kit.GROUND_Y)},
			{"kind": "flyer", "pos": Vector2(4700, Kit.GROUND_Y - 450)},
			{"kind": "reflector", "pos": Vector2(2700, Kit.GROUND_Y)},  # MV-SLICE-001c4c1
		],
	})
