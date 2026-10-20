extends RefCounted
# 只給自測用的房間 A（MV-SLICE-001a Task 4）：右門通往 _test_b；休息點；一隻爬行型（Task 6 測休息重生）。


static func data() -> Dictionary:
	return {
		"id": "_test_a",
		"size": Vector2(1920, 1080),
		"ground_y": 900.0,
		"solids": [Rect2(-100, 900, 2120, 400), Rect2(-100, -200, 100, 1500), Rect2(1920, -200, 100, 1500)],
		"platforms": [],
		"doors": [{"id": "east", "rect": Rect2(1850, 600, 70, 300), "to_room": "_test_b", "to_door": "west", "spawn": Vector2(1700, 900)}],
		"rest": {"pos": Vector2(400, 900)},
		"enemies": [{"kind": "crawler", "pos": Vector2(1300, 900)}],
		"pickups": [],
		"props": [],
		"triggers": [],
		"gates": [],
		"layers": {},
	}
