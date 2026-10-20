extends RefCounted
# 支路 A（MV-SLICE-001c4a）：兩段荊棘，上方各兩顆下劈水晶，中間一段安全地面；下劈彈過去，盡頭是血量碎片。切片裡唯一需要下劈的地方。
# MV-TUNE-004（Brian 試玩 2026-10-16「連續性有點難」）：原本一整條 2100 的荊棘、5 顆間距 450 → 間距 380、中途可以落腳。
const Kit := preload("res://world/rooms/kit.gd")


static func data() -> Dictionary:
	return Kit.room("forest_a", 2, {
		"theme": "forest", "variant": 1,
		"doors": [Kit.door_left("to_forest_3", "forest_3", "to_forest_a")],
		"hazards": [Rect2(900, Kit.GROUND_Y - 60, 900, 60), Rect2(2100, Kit.GROUND_Y - 60, 900, 60)],
		"crystals": [Vector2(1150, 650), Vector2(1530, 650), Vector2(2350, 650), Vector2(2730, 650)],
		"fragment": {"id": "frag_a", "pos": Vector2(3450, Kit.GROUND_Y)},
	})
