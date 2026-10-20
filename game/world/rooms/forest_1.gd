extends RefCounted
# 森林 1（MV-SLICE-001c4a 改寫）：入門戰鬥；地上一排荊棘（第一次嘗到荊棘，要跳過去）。
# MV-SLICE-001c4b 的鎖：離地 600 的高台只有二段跳上得去，上面是碎片 frag_e。
const Kit := preload("res://world/rooms/kit.gd")


static func data() -> Dictionary:
	return Kit.room("forest_1", 3, {
		"theme": "forest", "variant": 0,
		"doors": [Kit.door_left("to_yard", "yard", "to_forest"), Kit.door_right(3, "to_forest_2", "forest_2", "to_forest_1")],
		"platforms": [Rect2(3700, 640, 360, 30), Rect2(1900, 300, 300, 30)],
		"fragment": {"id": "frag_e", "pos": Vector2(2050, 300)},
		"hazards": [Rect2(2500, Kit.GROUND_Y - 60, 260, 60)],
		"enemies": [
			{"kind": "crawler", "pos": Vector2(1500, Kit.GROUND_Y)},
			{"kind": "flyer", "pos": Vector2(3600, Kit.GROUND_Y - 450)},
			{"kind": "crawler", "pos": Vector2(4700, Kit.GROUND_Y)},
		],
	})
