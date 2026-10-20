extends "res://tests/base_test.gd"
# MV-SLICE-001a Task 5：地面房間資料（祖母家到森林、Boss 段落、出口）。

const RoomCheck := preload("res://world/room_check.gd")
const Index := preload("res://world/rooms/index.gd")

const FORESTS := ["forest_1", "forest_2", "forest_3", "forest_4", "forest_5", "forest_6"]  # 主路（MV-SLICE-001c4a）


func test_ground_rooms_pass_room_check() -> void:
	for id in Index.ROOMS:
		var errs := RoomCheck.errors(Index.ROOMS[id].data())
		check(errs.is_empty(), "%s：%s" % [id, errs])


func test_ground_rooms_link() -> void:
	var errs := RoomCheck.link_errors(Index.ROOMS)
	check(errs.is_empty(), "門都要接得起來：%s" % errs)


func test_enemy_counts_per_room() -> void:
	for id in FORESTS:
		var kinds: Array = Index.ROOMS[id].data().enemies.map(func(e): return e.kind)
		var n: int = kinds.size() - kinds.count("reflector")
		check(n >= 1 and n <= 4 and kinds.count("reflector") <= 1, "%s 爬行＋飛行 1～4 隻、反光型 ≤ 1（%s）" % [id, kinds])  # 反光型加在現有敵人之外（MV-SLICE-001c4c1）
	for id in ["home", "yard", "field"]:
		check(Index.ROOMS[id].data().enemies.is_empty(), "%s 沒有敵人" % id)


func test_stash_reachable_by_single_jump() -> void:
	var d: Dictionary = Index.ROOMS["forest_3"].data()
	check(d.has("stash"), "森林 3 有藏點")
	var height: float = d.ground_y - d.stash.pos.y
	check(height > 0.0 and height <= fresh_tuning().jump_height, "藏點要跳上高處、單跳上得去，高度 %s" % height)


func test_rest_points() -> void:
	check(Index.ROOMS["home"].data().has("rest") and Index.ROOMS["home"].data().has("npc"), "祖母家是休息點，有祖母")
	check(Index.ROOMS["forest_2"].data().has("rest") and Index.ROOMS["forest_5"].data().has("rest"), "森林 2、森林 5 有篝火")
	for id in ["yard", "field", "forest_1", "forest_3", "forest_4", "forest_6"]:
		check(not Index.ROOMS[id].data().has("rest"), "%s 沒有休息點" % id)


func test_thorns_gate_on_forest_road() -> void:
	var gates: Array = Index.ROOMS["yard"].data().gates
	check(gates.size() == 1 and gates[0].until_flag == "gear_obtained", "家前空地的荊棘要等球具")


func test_all_rooms_reachable_from_home() -> void:
	var seen := {"home": true}
	var queue := ["home"]
	while not queue.is_empty():
		var id: String = queue.pop_front()
		for door in RoomCheck._doors(Index.ROOMS[id].data()):
			if not seen.has(door.to_room):
				seen[door.to_room] = true
				queue.append(door.to_room)
	for id in Index.ROOMS:
		if Index.ROOMS[id].data().get("kind", "") != "ending":
			check(seen.has(id), "從祖母家走得到 %s" % id)
