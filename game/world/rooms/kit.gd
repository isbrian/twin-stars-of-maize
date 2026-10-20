extends RefCounted
# 房間資料的共用零件（MV-SLICE-001a Task 5）：一個畫面寬 1920、地面 y＝900、左右各一道牆、門在左右邊緣。

const GROUND_Y := 900.0
const SCREEN := 1920.0
const TOP := -1000.0  # 牆與木障的頂端（MV-SLICE-001c4b：森林 4 的高台二段跳到約 y −400，牆頂 −200 會被翻過去）


## 寬 screens 個畫面的房間外框：地面＋左右牆
static func frame(screens: int) -> Array:
	var w := SCREEN * screens
	return [Rect2(-100, GROUND_Y, w + 200, 400), Rect2(-100, TOP, 100, 1300 - TOP), Rect2(w, TOP, 100, 1300 - TOP)]


static func size(screens: int) -> Vector2:
	return Vector2(SCREEN * screens, 1080)


static func door_left(id: String, to_room: String, to_door: String) -> Dictionary:
	return {"id": id, "rect": Rect2(0, 600, 70, 300), "to_room": to_room, "to_door": to_door, "spawn": Vector2(220, GROUND_Y)}


## 支路的門（MV-SLICE-001c4a）：開在右端高處的實心平台（ledge）上；出生點在平台上，路標小一號
static func door_branch(screens: int, id: String, to_room: String, to_door: String, ledge_y: float) -> Dictionary:
	var w := SCREEN * screens
	return {"id": id, "rect": Rect2(w - 70, ledge_y - 300, 70, 300), "to_room": to_room, "to_door": to_door, "spawn": Vector2(w - 220, ledge_y), "branch": true}


## 右端的高處平台（實心：從底下跳不上去，只能從左邊跳上）
static func ledge(screens: int, y: float, width := 500.0) -> Rect2:
	return Rect2(SCREEN * screens - width, y, width, 30)


## 右門在高處平台底下時：門的範圍只到平台底下（站在平台上不會碰到主路的門）
static func door_right_under(screens: int, id: String, to_room: String, to_door: String, ledge_y: float) -> Dictionary:
	var d := door_right(screens, id, to_room, to_door)
	d.rect = Rect2(d.rect.position.x, ledge_y + 40, 70, GROUND_Y - ledge_y - 40)
	return d


## 左側版本（MV-SLICE-001c4b）：左端的實心高台、高台上的門、只到高台底下的主路左門
static func ledge_left(y: float, width := 500.0) -> Rect2:
	return Rect2(0, y, width, 30)


static func door_branch_left(id: String, to_room: String, to_door: String, ledge_y: float) -> Dictionary:
	return {"id": id, "rect": Rect2(0, ledge_y - 300, 70, 300), "to_room": to_room, "to_door": to_door, "spawn": Vector2(220, ledge_y), "branch": true}


static func door_left_under(id: String, to_room: String, to_door: String, ledge_y: float) -> Dictionary:
	var d := door_left(id, to_room, to_door)
	d.rect = Rect2(0, ledge_y + 40, 70, GROUND_Y - ledge_y - 40)
	return d


## 木障（MV-SLICE-001c4b）：站在高台上、從 TOP 一路擋到高台頂面；flag 非空＝破開後設旗標、不再立起
static func barrier(x: float, ledge_y: float, flag := "") -> Dictionary:
	var b := {"rect": Rect2(x, TOP, 60, ledge_y - TOP)}
	if flag != "":
		b.flag = flag
	return b


static func door_right(screens: int, id: String, to_room: String, to_door: String) -> Dictionary:
	var w := SCREEN * screens
	return {"id": id, "rect": Rect2(w - 70, 600, 70, 300), "to_room": to_room, "to_door": to_door, "spawn": Vector2(w - 220, GROUND_Y)}


## 其餘欄位的預設值；room 只寫自己有的
static func room(id: String, screens: int, extra: Dictionary) -> Dictionary:
	var d := {
		"id": id, "size": size(screens), "ground_y": GROUND_Y, "solids": frame(screens), "platforms": [],
		"doors": [], "enemies": [], "pickups": [], "props": [], "triggers": [], "gates": [],
	}
	for k in extra:
		if k == "solids":
			d.solids = d.solids + extra.solids
		else:
			d[k] = extra[k]
	return d
