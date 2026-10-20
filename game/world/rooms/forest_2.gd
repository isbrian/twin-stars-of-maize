extends RefCounted
# 森林 2（MV-SLICE-001c4a 改寫）：篝火；第一顆下劈水晶在主路上（底下是地面），靠近時出下劈提示。
# MV-SLICE-001c4b 的鎖：右端高台上的門是通往森林 5 的捷徑，木障擋在門前（破開設 shortcut_25）。
const Kit := preload("res://world/rooms/kit.gd")

const LEDGE_Y := 600.0


static func data() -> Dictionary:
	return Kit.room("forest_2", 3, {
		"theme": "forest", "variant": 1,
		"doors": [Kit.door_left("to_forest_1", "forest_1", "to_forest_2"), Kit.door_branch(3, "to_forest_5", "forest_5", "to_forest_2", LEDGE_Y), Kit.door_right_under(3, "to_forest_3", "forest_3", "to_forest_2", LEDGE_Y)],
		"solids": [Kit.ledge(3, LEDGE_Y, 600.0)],
		"barriers": [Kit.barrier(5400, LEDGE_Y, "shortcut_25")],
		"rest": {"pos": Vector2(1000, Kit.GROUND_Y)},
		"crystals": [Vector2(2700, 640)],
		"hint_at": {"id": "pogo", "rect": Rect2(2200, 500, 350, 400)},
		"platforms": [Rect2(3300, 600, 360, 30)],
		"enemies": [{"kind": "crawler", "pos": Vector2(3900, Kit.GROUND_Y)}, {"kind": "flyer", "pos": Vector2(4800, Kit.GROUND_Y - 450)}],
	})
