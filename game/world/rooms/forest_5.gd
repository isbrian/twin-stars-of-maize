extends RefCounted
# 森林 5（MV-SLICE-001c4a 新增）：篝火；主路上方兩段平台往上，頂端是血量碎片（要往上看才發現）。
# MV-SLICE-001c4b 的鎖：左端高台上的門是通往森林 2 的捷徑，木障擋在門前（破開設 shortcut_25）。
const Kit := preload("res://world/rooms/kit.gd")

const LEDGE_Y := 600.0


static func data() -> Dictionary:
	return Kit.room("forest_5", 3, {
		"theme": "forest", "variant": 1,
		"doors": [Kit.door_left_under("to_forest_4", "forest_4", "to_forest_5", LEDGE_Y), Kit.door_branch_left("to_forest_2", "forest_2", "to_forest_5", LEDGE_Y), Kit.door_right(3, "to_forest_6", "forest_6", "to_forest_5")],
		"solids": [Kit.ledge_left(LEDGE_Y, 600.0)],
		"barriers": [Kit.barrier(300, LEDGE_Y, "shortcut_25")],
		"rest": {"pos": Vector2(900, Kit.GROUND_Y)},
		"platforms": [Rect2(3000, 620, 300, 30), Rect2(3500, 330, 300, 30)],
		"fragment": {"id": "frag_d", "pos": Vector2(3650, 330)},
		"enemies": [
			{"kind": "crawler", "pos": Vector2(2200, Kit.GROUND_Y)},
			{"kind": "flyer", "pos": Vector2(4000, Kit.GROUND_Y - 450)},
			{"kind": "crawler", "pos": Vector2(4500, Kit.GROUND_Y)},
			{"kind": "reflector", "pos": Vector2(3300, Kit.GROUND_Y)},  # MV-SLICE-001c4c1
		],
	})
