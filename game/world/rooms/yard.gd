extends RefCounted
# 家前空地（規格房間 #2）：遠景是球場；往森林的路被荊棘擋住，拿到球具後消失。左門回祖母家。
const Kit := preload("res://world/rooms/kit.gd")


static func data() -> Dictionary:
	return Kit.room("yard", 2, {
		"theme": "yard",
		"doors": [Kit.door_left("to_home", "home", "to_yard"), Kit.door_right(2, "to_forest", "forest_1", "to_yard")],
		"gates": [{"rect": Rect2(3300, -200, 120, 1100), "until_flag": "gear_obtained"}],  # 擋到頂：原本 340 高跳得過去（手把驗收第 1 輪）
	})
