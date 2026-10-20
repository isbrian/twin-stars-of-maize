extends RefCounted
# 房間資料檢查（MV-SLICE-001a Task 4）：自測用來確認每個房間的東西都站在地形上、門都接得起來。
# 「站在地形上」＝x 落在某個 solid 或 platform 的寬度內，y 與它的頂邊相差 ≤ 2 px。


static func errors(d: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	if d.get("kind", "") != "":
		return out  # 特殊房間（boss、ending）沒有地形資料
	var tops: Array = d.solids + d.platforms
	for door in d.doors:
		if not _on_top(door.spawn, tops):
			out.append("門 %s 的出生點 %s 不在地形上" % [door.id, door.spawn])
		if door.rect.has_point(door.spawn) or door.rect.has_point(door.spawn + Vector2(0, -1)):
			out.append("門 %s 的出生點在自己的門裡" % door.id)
	for key in ["rest", "npc", "stash"]:
		if d.has(key) and not _on_top(d[key].pos, tops):
			out.append("%s 的位置 %s 不在地形上" % [key, d[key].pos])
	for p in d.get("pickups", []):
		if not _on_top(p.pos, tops):
			out.append("拾取點 %s 的位置 %s 不在地形上" % [p.id, p.pos])
	for e in d.enemies:
		if e.kind in ["crawler", "reflector"] and not _on_top(e.pos, tops):  # 反光型也站在地上（MV-SLICE-001c4c1）
			out.append("%s %s 不在地形上" % ["爬行型" if e.kind == "crawler" else "反光型", e.pos])
	if d.has("fragment") and not _on_top(d.fragment.pos, tops):  # MV-SLICE-001c4a
		out.append("碎片 %s 的位置 %s 不在地形上" % [d.fragment.id, d.fragment.pos])
	for h in d.get("hazards", []):
		for door in d.doors:
			if h.grow(2.0).has_point(door.spawn):
				out.append("荊棘 %s 蓋住門 %s 的出生點" % [h, door.id])
	return out


## 主路通過性（MV-SLICE-001c4a）：預設只靠單跳，從 from 走得到 to 嗎？（座標是腳底；不考慮水晶；c4b 起 max_rise、max_gap 可換成其他跳法的上限）
## 可站的線段＝實心與平台的頂面扣掉荊棘蓋住的部分；兩段「上升 ≤ MAX_RISE 且水平間隔 ≤ MAX_GAP」或「往下、間隔 ≤ MAX_GAP」就連通
const MAX_RISE := 340.0
const MAX_GAP := 400.0
# MV-SLICE-001c4b：鎖的高度判斷。理論單跳 400 高，比 440 高或遠過 700 一定上不去；二段跳理論 400＋300，留 60 餘裕
const SINGLE_REACH_RISE := 440.0
const SINGLE_REACH_GAP := 700.0
const MAX_RISE_DOUBLE := 640.0


static func walk_errors(d: Dictionary, from: Vector2, to: Vector2, max_rise := MAX_RISE, max_gap := MAX_GAP) -> PackedStringArray:
	var segs := _segments(d)
	var a := _seg_at(segs, from)
	var b := _seg_at(segs, to)
	if a < 0 or b < 0:
		return PackedStringArray(["起點 %s 或終點 %s 不在可站的地面上" % [from, to]])
	var seen := {a: true}
	var queue := [a]
	while not queue.is_empty():
		var i: int = queue.pop_front()
		if i == b:
			return PackedStringArray()
		for j in segs.size():
			if not seen.has(j) and _hop(segs[i], segs[j], max_rise, max_gap):
				seen[j] = true
				queue.append(j)
	return PackedStringArray(["從 %s 走不到 %s（上升 ≤ %d、間隔 ≤ %d）" % [from, to, max_rise, max_gap]])


## [x0, x1, y] 的清單
static func _segments(d: Dictionary) -> Array:
	var out := []
	for r in d.solids + d.platforms:
		var parts := [[r.position.x, r.end.x]]
		for h in d.get("hazards", []):
			if absf(h.end.y - r.position.y) > 2.0 and not (h.position.y <= r.position.y and h.end.y >= r.position.y):
				continue
			var next := []
			for p in parts:
				if h.end.x <= p[0] or h.position.x >= p[1]:
					next.append(p)
					continue
				if h.position.x > p[0]:
					next.append([p[0], h.position.x])
				if h.end.x < p[1]:
					next.append([h.end.x, p[1]])
			parts = next
		for p in parts:
			out.append([p[0], p[1], r.position.y])
	return out


static func _seg_at(segs: Array, at: Vector2) -> int:
	for i in segs.size():
		if at.x >= segs[i][0] and at.x <= segs[i][1] and absf(at.y - segs[i][2]) <= 2.0:
			return i
	return -1


static func _hop(s: Array, t: Array, max_rise: float, max_gap: float) -> bool:
	var gap: float = maxf(0.0, maxf(s[0], t[0]) - minf(s[1], t[1]))
	var rise: float = s[2] - t[2]  # 正＝往上
	return gap <= max_gap and rise <= max_rise


## all：房間 id → 資料腳本（有 static data()）。每扇門的目的地要存在，而且對方的門指回來。
static func link_errors(all: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for id in all:
		var d: Dictionary = all[id].data()
		for door in _doors(d):
			if not all.has(door.to_room):
				out.append("%s.%s → 房間 %s 不存在" % [id, door.id, door.to_room])
				continue
			var back = _find(_doors(all[door.to_room].data()), door.to_door)
			if back == null:
				out.append("%s.%s → %s.%s 不存在" % [id, door.id, door.to_room, door.to_door])
			elif back.to_room != id or back.to_door != door.id:
				out.append("%s.%s → %s.%s 沒有指回來" % [id, door.id, door.to_room, door.to_door])
	return out


static func _doors(d: Dictionary) -> Array:
	if d.get("kind", "") == "boss":
		return [{"id": "to_" + d.left_room, "to_room": d.left_room, "to_door": d.left_door}]
	return d.get("doors", [])


static func _find(doors: Array, id: String):
	for door in doors:
		if door.id == id:
			return door
	return null


static func _on_top(pos: Vector2, tops: Array) -> bool:
	for r in tops:
		if pos.x >= r.position.x and pos.x <= r.end.x and absf(pos.y - r.position.y) <= 2.0:
			return true
	return false
