extends RefCounted
# 森林 4（MV-SLICE-001c4a 改寫）：荊棘與平台交錯；右端高處平台通往支路 B。
# MV-SLICE-001c4b 的鎖：左端離地 600 的高台（二段跳）上，木障擋在碎片 frag_f 前（沒有旗標，每次進房立起）；碎片與木障放在 x 450 之後，避開左上角的 HUD。
const Kit := preload("res://world/rooms/kit.gd")

const LEDGE_Y := 600.0
const LOCK_Y := 300.0


static func data() -> Dictionary:
	return Kit.room("forest_4", 3, {
		"theme": "forest", "variant": 0,
		"doors": [Kit.door_left("to_forest_3", "forest_3", "to_forest_4"), Kit.door_branch(3, "to_forest_b", "forest_b", "to_forest_4", LEDGE_Y), Kit.door_right_under(3, "to_forest_5", "forest_5", "to_forest_4", LEDGE_Y)],
		"solids": [Kit.ledge(3, LEDGE_Y), Kit.ledge_left(LOCK_Y, 1000.0)],
		"barriers": [Kit.barrier(600, LOCK_Y)],
		"fragment": {"id": "frag_f", "pos": Vector2(450, LOCK_Y)},
		"platforms": [Rect2(2500, 620, 360, 30), Rect2(3350, 600, 400, 30)],
		"hazards": [Rect2(1700, Kit.GROUND_Y - 60, 220, 60), Rect2(3400, Kit.GROUND_Y - 60, 300, 60)],
		"enemies": [
			{"kind": "crawler", "pos": Vector2(1200, Kit.GROUND_Y)},
			{"kind": "crawler", "pos": Vector2(2800, Kit.GROUND_Y)},
			{"kind": "flyer", "pos": Vector2(2400, Kit.GROUND_Y - 450)},
			{"kind": "flyer", "pos": Vector2(4300, Kit.GROUND_Y - 450)},
		],
	})
