extends RefCounted
# 祖母家（規格房間 #1）：休息點兼兌換；開場在這裡醒來；屋梁下吊著球具（球具事件）。左門通田地、右門通家前空地。
const Kit := preload("res://world/rooms/kit.gd")


static func data() -> Dictionary:
	return Kit.room("home", 1, {
		"theme": "home",
		"floor": "hard",  # 屋內夯實地板：腳步用硬地（MV-SLICE-001d1b）
		"doors": [Kit.door_left("to_field", "field", "to_home"), Kit.door_right(1, "to_yard", "yard", "to_home")],
		"rest": {"pos": Vector2(700, Kit.GROUND_Y)},
		"npc": {"kind": "grandmother", "pos": Vector2(1150, Kit.GROUND_Y)},
		"props": [{"id": "rope", "kind": "rope", "pos": Vector2(930, 420)}],
	})
