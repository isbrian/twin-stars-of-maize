extends RefCounted
# 田地（規格房間 #3）：開墾田地、入夜抓老鼠。右門回祖母家。
const Kit := preload("res://world/rooms/kit.gd")


static func data() -> Dictionary:
	return Kit.room("field", 2, {
		"theme": "field",
		"doors": [Kit.door_right(2, "to_home", "home", "to_field")],
		"pickups": [{"id": "axe", "item": "axe", "pos": Vector2(900, Kit.GROUND_Y)}, {"id": "stick", "item": "stick", "pos": Vector2(1250, Kit.GROUND_Y)}],
		"decor_bushes": [Vector2(350, Kit.GROUND_Y), Vector2(500, Kit.GROUND_Y), Vector2(650, Kit.GROUND_Y), Vector2(800, Kit.GROUND_Y)],  # 收工過場裡工具自己清掉的另一半田（MV-SLICE-001c3a）
		"props": [
			{"id": "bush_1", "kind": "bush", "pos": Vector2(1900, Kit.GROUND_Y)},
			{"id": "clod_1", "kind": "clod", "pos": Vector2(2100, Kit.GROUND_Y)},
			{"id": "bush_2", "kind": "bush", "pos": Vector2(2300, Kit.GROUND_Y)},
			{"id": "clod_2", "kind": "clod", "pos": Vector2(2500, Kit.GROUND_Y)},
			{"id": "bush_3", "kind": "bush", "pos": Vector2(2700, Kit.GROUND_Y)},
			{"id": "clod_3", "kind": "clod", "pos": Vector2(2900, Kit.GROUND_Y)},
		],
	})
