extends RefCounted
# 垂直切片的全部房間（MV-SLICE-001a Task 5）。
# 順序：田地 ↔ 祖母家 ↔ 家前空地 ↔ 森林 1～6（MV-SLICE-001c4a）↔ Boss 段落 → 出口（田地從祖母家左門進出；計畫裁定，見進度紀錄）。

const ROOMS := {
	"home": preload("res://world/rooms/home.gd"),
	"field": preload("res://world/rooms/field.gd"),
	"yard": preload("res://world/rooms/yard.gd"),
	"forest_1": preload("res://world/rooms/forest_1.gd"),
	"forest_2": preload("res://world/rooms/forest_2.gd"),
	"forest_3": preload("res://world/rooms/forest_3.gd"),
	"forest_4": preload("res://world/rooms/forest_4.gd"),
	"forest_5": preload("res://world/rooms/forest_5.gd"),
	"forest_6": preload("res://world/rooms/forest_6.gd"),
	"forest_a": preload("res://world/rooms/forest_a.gd"),
	"forest_b": preload("res://world/rooms/forest_b.gd"),
	"forest_c": preload("res://world/rooms/forest_c.gd"),
	"boss": preload("res://world/rooms/boss.gd"),
	"exit": preload("res://world/rooms/exit.gd"),
}

## Boss 段落裡的休息點 → 房間（Task 11）
const CAMPS := {"nance_camp": "boss", "palace_camp": "boss"}
