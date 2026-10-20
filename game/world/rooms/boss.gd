extends RefCounted
# Boss 段落（規格房間 #8～#13）：內部沿用原型 boss_fight.gd 的整條流程（實作計畫「與規格書的差異」）。
# 唯一的門是 nance 樹開打前往回走到森林 6（MV-SLICE-001c4a）。


static func data() -> Dictionary:
	return {"id": "boss", "kind": "boss", "left_room": "forest_6", "left_door": "to_boss"}
