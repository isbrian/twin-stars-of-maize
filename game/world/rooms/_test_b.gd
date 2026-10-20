extends RefCounted
# 只給自測用的房間 B（MV-SLICE-001a Task 4）：左門回 _test_a；一隻爬行型；一道旗標門。


static func data() -> Dictionary:
	return {
		"id": "_test_b",
		"size": Vector2(1920, 1080),
		"ground_y": 900.0,
		"solids": [Rect2(-100, 900, 2120, 400), Rect2(-100, -200, 100, 1500), Rect2(1920, -200, 100, 1500)],
		"platforms": [Rect2(800, 640, 300, 30)],
		"doors": [{"id": "west", "rect": Rect2(0, 600, 70, 300), "to_room": "_test_a", "to_door": "east", "spawn": Vector2(220, 900)}],
		"enemies": [{"kind": "crawler", "pos": Vector2(1400, 900)}],
		"pickups": [],
		"props": [],
		"triggers": [],
		"gates": [{"rect": Rect2(1100, 600, 60, 300), "until_flag": "open_b"}],
		"layers": {},
	}
