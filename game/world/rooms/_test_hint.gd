extends RefCounted
# 只給自測用的房間（MV-SLICE-001c4a）：一顆下劈水晶、水晶前的下劈提示區。


static func data() -> Dictionary:
	var d: Dictionary = preload("res://world/rooms/_test_b.gd").data()
	d.id = "_test_hint"
	d.enemies = []
	d.gates = []
	d.crystals = [Vector2(1500, 600)]
	d.hint_at = {"id": "pogo", "rect": Rect2(1100, 500, 300, 400)}
	return d
