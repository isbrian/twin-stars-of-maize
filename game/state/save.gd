extends RefCounted
# 存檔（MV-SLICE-001a 規格 SLICE-a10）：一個欄位，內容是 GameState.to_dict() 加上版本。
# 檔案不存在、不是 JSON、版本不符或缺 state 時一律當成沒有存檔（Review Focus 1）。

const GameStateScr := preload("res://state/game_state.gd")
const Index := preload("res://world/rooms/index.gd")

const VERSION := 1
const PATH := "user://slot1.json"


static func write(d: Dictionary, path := PATH) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"version": VERSION, "state": d}))
	f.close()
	return OK


static func read(path := PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var v = parsed.get("version")
	if not (v is int or v is float) or int(v) != VERSION or not parsed.get("state") is Dictionary:
		return {}
	var st: Dictionary = parsed.state
	if not GameStateScr.valid_state(st) or not (Index.ROOMS.has(st.last_rest) or Index.CAMPS.has(st.last_rest)):
		return {}
	return st


static func exists(path := PATH) -> bool:
	return not read(path).is_empty()
