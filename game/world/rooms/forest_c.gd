extends RefCounted
# 支路 C（MV-SLICE-001c4a）：關門戰——走到房間中央兩側升起荊棘牆，3 波敵人（2、3、4 隻），清完出現血量碎片。
const Kit := preload("res://world/rooms/kit.gd")


static func data() -> Dictionary:
	return Kit.room("forest_c", 2, {
		"theme": "forest", "variant": 2,
		"doors": [Kit.door_left("to_forest_6", "forest_6", "to_forest_c")],
		"arena": {
			"rect": Rect2(700, 300, 2500, 600),
			"gates": [Rect2(520, 0, 60, Kit.GROUND_Y), Rect2(3400, 0, 60, Kit.GROUND_Y)],
			"waves": [
				[{"kind": "crawler", "pos": Vector2(1100, Kit.GROUND_Y)}, {"kind": "flyer", "pos": Vector2(2600, Kit.GROUND_Y - 450)}],
				[{"kind": "crawler", "pos": Vector2(900, Kit.GROUND_Y)}, {"kind": "crawler", "pos": Vector2(3000, Kit.GROUND_Y)}, {"kind": "flyer", "pos": Vector2(1900, Kit.GROUND_Y - 500)}],
				[{"kind": "crawler", "pos": Vector2(900, Kit.GROUND_Y)}, {"kind": "reflector", "pos": Vector2(3000, Kit.GROUND_Y)}, {"kind": "flyer", "pos": Vector2(1300, Kit.GROUND_Y - 500)}, {"kind": "flyer", "pos": Vector2(2500, Kit.GROUND_Y - 500)}],
			],
			"reward": {"id": "frag_c", "pos": Vector2(3100, Kit.GROUND_Y)},
		},
	})
