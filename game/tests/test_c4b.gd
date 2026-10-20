extends "res://tests/base_test.gd"
# MV-SLICE-001c4b：覺醒後回頭開路（房間木障、左側高台、通過性檢查、三個鎖與捷徑）。

const GameStateScr := preload("res://state/game_state.gd")
const RoomScr := preload("res://world/room.gd")
const TestB := preload("res://world/rooms/_test_b.gd")
const Save := preload("res://state/save.gd")
const TEST_SAVE := "user://test_c4b_slot.json"
const BARRIER_RECT := Rect2(1500, 500, 60, 400)


func make_gs():
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	return gs


func build_room(d: Dictionary, gs) -> Node:
	var r = RoomScr.new()
	add_child(r)
	r.build(d, gs, gs.tn)
	r.player.scripted = true
	await frames(3)
	return r


func free_room(r) -> void:
	r.queue_free()
	await frames(1)


## 測試房間 B：清掉敵人與閘門，放一道木障；玩家在 (1200, 900) 面向右
func barrier_room_data(flag := "") -> Dictionary:
	var d: Dictionary = TestB.data()
	d.enemies = []
	d.gates = []
	var b := {"rect": BARRIER_RECT}
	if flag != "":
		b.flag = flag
	d.barriers = [b]
	return d


# ---- Task 1：房間木障 ----

func test_room_barriers_built() -> void:
	var gs = make_gs()
	var r = await build_room(barrier_room_data(), gs)
	var bs: Array = r.get("barriers") if r.get("barriers") != null else []
	check(bs.size() == 1 and bs[0] is StaticBody2D and not bs[0].is_broken, "建出 1 道木障、未破（%d）" % bs.size())
	await free_room(r)
	gs.free()


## 讓希巴拉克在 (1200, 900) 朝右射一發飛鏢
func xbalanque_shoot(r) -> void:
	r.player.position = Vector2(1200, 900)
	r.player.velocity = Vector2.ZERO
	if r.player.twin_index == 0:
		r.player.swap_twin()
	await frames(25)
	r.player.intent.dart_pressed = true


func test_barrier_needs_awakening() -> void:
	var gs = make_gs()
	var r = await build_room(barrier_room_data(), gs)
	var bs: Array = r.get("barriers") if r.get("barriers") != null else []
	if bs.is_empty():
		check(false, "有木障")
		await free_room(r)
		gs.free()
		return
	var thuds := [0]
	bs[0].thudded.connect(func(): thuds[0] += 1)
	await xbalanque_shoot(r)
	await frames(120)
	check(not is_instance_valid(r.player.tool) and not bs[0].is_broken and thuds[0] > 0, "覺醒前：只有悶響、不派工具、不破（悶響 %d）" % thuds[0])
	await free_room(r)
	gs.awakened = true
	r = await build_room(barrier_room_data(), gs)
	await xbalanque_shoot(r)
	var broke: bool = await wait_until(func(): return r.barriers[0].is_broken, 120)
	check(broke, "覺醒後：工具砍碎木障")
	await free_room(r)
	gs.free()


func test_flagged_barrier_sets_flag_and_stays_open() -> void:
	var gs = make_gs()
	var r = await build_room(barrier_room_data("shortcut_t"), gs)
	var bs: Array = r.get("barriers") if r.get("barriers") != null else []
	if bs.is_empty():
		check(false, "有木障")
		await free_room(r)
		gs.free()
		return
	bs[0].break_apart()
	await frames(1)
	check(gs.has_flag("shortcut_t"), "破開時設旗標")
	await free_room(r)
	r = await build_room(barrier_room_data("shortcut_t"), gs)
	check(r.barriers.is_empty(), "旗標設了：重建不再有木障")
	await free_room(r)
	gs.free()


func test_unflagged_barrier_rebuilt() -> void:
	var gs = make_gs()
	var r = await build_room(barrier_room_data(), gs)
	var bs: Array = r.get("barriers") if r.get("barriers") != null else []
	if bs.is_empty():
		check(false, "有木障")
		await free_room(r)
		gs.free()
		return
	bs[0].break_apart()
	await free_room(r)
	r = await build_room(barrier_room_data(), gs)
	check(r.barriers.size() == 1 and not r.barriers[0].is_broken, "沒有旗標：重建時立回")
	await free_room(r)
	gs.free()


func test_barrier_art_in_themed_room() -> void:
	var gs = make_gs()
	var d := barrier_room_data()
	d.theme = "forest"
	var r = await build_room(d, gs)
	var bs: Array = r.get("barriers") if r.get("barriers") != null else []
	check(bs.size() == 1 and bs[0].art and bs[0].has_node("Art"), "森林房間的木障掛素材")
	await free_room(r)
	gs.free()


# ---- Task 2：左側高台、牆加高、可調的通過性檢查 ----

const Kit := preload("res://world/rooms/kit.gd")
const RoomCheck := preload("res://world/room_check.gd")


func test_kit_left_versions() -> void:
	check(Kit.ledge_left(600, 600) == Rect2(0, 600, 600, 30), "左高台 Rect2(0, 600, 600, 30)")
	var high: Dictionary = Kit.door_branch_left("to_x", "x", "to_y", 600)
	check(high.rect == Rect2(0, 300, 70, 300) and high.spawn == Vector2(220, 600) and high.get("branch", false), "左高門：在高台上、出生點在高台、小路標（%s）" % [high])
	var under: Dictionary = Kit.door_left_under("to_z", "z", "to_w", 600)
	check(under.rect == Rect2(0, 640, 70, 260) and under.spawn == Vector2(220, Kit.GROUND_Y), "主路左門只到高台底下（%s）" % [under.rect])
	var d := Kit.room("_t", 1, {"solids": [Kit.ledge_left(600, 600)], "doors": [high, under]})
	check(RoomCheck.errors(d).is_empty(), "人造房間沒有錯：%s" % RoomCheck.errors(d))


func test_walls_reach_top() -> void:
	var f: Array = Kit.frame(3)
	check(f[1].position.y == Kit.TOP and f[1].end.y == 1300.0 and f[2].position.y == Kit.TOP and f[2].end.y == 1300.0, "左右牆從 TOP 到 1300（%s、%s）" % [f[1], f[2]])
	var b: Dictionary = Kit.barrier(250, 300, "f")
	check(b.rect == Rect2(250, -1000, 60, 1300) and b.flag == "f", "木障從 TOP 到高台頂面（%s）" % [b])
	check(not Kit.barrier(250, 300).has("flag"), "沒給旗標就沒有 flag 鍵")


## 人造房間：地面整片、平台在 x0～x0+300、高 h 上方
func step_room(x0: float, h: float) -> Dictionary:
	return Kit.room("_t", 1, {"platforms": [Rect2(x0, Kit.GROUND_Y - h, 300, 30)], "solids": []})


func test_walk_errors_reach_params() -> void:
	var g := Kit.GROUND_Y
	var from := Vector2(200, g)
	var r600 := step_room(900, 600)
	var to600 := Vector2(1000, g - 600)
	check(not RoomCheck.walk_errors(r600, from, to600).is_empty(), "高 600：預設單跳不通")
	check(not RoomCheck.walk_errors(r600, from, to600, RoomCheck.SINGLE_REACH_RISE, RoomCheck.SINGLE_REACH_GAP).is_empty(), "高 600：保守單跳也不通")
	check(RoomCheck.walk_errors(r600, from, to600, RoomCheck.MAX_RISE_DOUBLE, RoomCheck.MAX_GAP).is_empty(), "高 600：二段跳通")
	check(not RoomCheck.walk_errors(step_room(900, 700), from, Vector2(1000, g - 700), RoomCheck.MAX_RISE_DOUBLE, RoomCheck.MAX_GAP).is_empty(), "高 700：二段跳不通")
	check(RoomCheck.walk_errors(step_room(900, 420), from, Vector2(1000, g - 420), RoomCheck.SINGLE_REACH_RISE, RoomCheck.SINGLE_REACH_GAP).is_empty(), "高 420：保守判斷算可能到得了")


# ---- Task 3：三個鎖與捷徑 ----

const Index := preload("res://world/rooms/index.gd")
const GameWorld := preload("res://world/game_world.gd")
const LOCKS := {"forest_1": "frag_e", "forest_4": "frag_f"}
const POGO_CLEAR := 1300.0  # 鎖高台水平這麼遠內不放飛行型與水晶（下劈飛行型會繞過）


func room_data(id: String) -> Dictionary:
	return Index.ROOMS[id].data()


## 主路的左門（不是支路門、在房間左半）
func main_left_door(d: Dictionary) -> Dictionary:
	return d.doors.filter(func(door): return not door.get("branch", false) and door.spawn.x < d.size.x / 2.0)[0]


func main_right_door(d: Dictionary) -> Dictionary:
	return d.doors.filter(func(door): return not door.get("branch", false) and door.spawn.x > d.size.x / 2.0)[0]


func door_of(d: Dictionary, id: String) -> Dictionary:
	for door in d.doors:
		if door.id == id:
			return door
	return {}


## pos 站在哪塊地形上（沒有時回空 Rect2）
func ground_under(d: Dictionary, pos: Vector2) -> Rect2:
	for r in d.solids + d.platforms:
		if pos.x >= r.position.x and pos.x <= r.end.x and absf(pos.y - r.position.y) <= 2.0:
			return r
	return Rect2()


func test_lock_ledges_need_double_jump() -> void:
	for id in LOCKS:
		var d := room_data(id)
		if d.get("fragment", {}).get("id", "") != LOCKS[id]:
			check(false, "%s 有碎片 %s" % [id, LOCKS[id]])
			continue
		var from: Vector2 = main_left_door(d).spawn
		var to: Vector2 = d.fragment.pos
		check(Kit.GROUND_Y - to.y >= 560.0, "%s 的鎖高台離地約 600（%d）" % [id, Kit.GROUND_Y - to.y])
		check(not RoomCheck.walk_errors(d, from, to, RoomCheck.SINGLE_REACH_RISE, RoomCheck.SINGLE_REACH_GAP).is_empty(), "%s 單跳到不了 %s" % [id, LOCKS[id]])
		var errs := RoomCheck.walk_errors(d, from, to, RoomCheck.MAX_RISE_DOUBLE, RoomCheck.MAX_GAP)
		check(errs.is_empty(), "%s 二段跳到得了 %s：%s" % [id, LOCKS[id], errs])


func test_shortcut_ledges_single_jump() -> void:
	var f2 := room_data("forest_2")
	var f5 := room_data("forest_5")
	var a := door_of(f2, "to_forest_5")
	var b := door_of(f5, "to_forest_2")
	if a.is_empty() or b.is_empty():
		check(false, "有捷徑的兩扇門")
		return
	var e2 := RoomCheck.walk_errors(f2, main_left_door(f2).spawn, a.spawn)
	var e5 := RoomCheck.walk_errors(f5, main_right_door(f5).spawn, b.spawn)
	check(e2.is_empty() and e5.is_empty(), "捷徑兩頭的高台單跳上得去：%s %s" % [e2, e5])


func test_locks_clear_of_pogo_lifts() -> void:
	for id in LOCKS:
		var d := room_data(id)
		if not d.has("fragment"):
			check(false, "%s 有碎片" % id)
			continue
		var ledge := ground_under(d, d.fragment.pos)
		var xs: Array = d.get("crystals", []).map(func(c): return c.x)
		for e in d.enemies:
			if e.kind == "flyer":
				xs.append(e.pos.x)
		for x in xs:
			var dx: float = maxf(0.0, maxf(ledge.position.x - x, x - ledge.end.x))
			check(dx >= POGO_CLEAR, "%s：x %d 的飛行型或水晶離鎖高台 %s 至少 %d（%d）" % [id, x, ledge, POGO_CLEAR, dx])


func test_shortcut_doors_and_barriers() -> void:
	var f2 := room_data("forest_2")
	var f5 := room_data("forest_5")
	var a := door_of(f2, "to_forest_5")
	var b := door_of(f5, "to_forest_2")
	if a.is_empty() or b.is_empty():
		check(false, "有捷徑的兩扇門")
		return
	check(a.to_room == "forest_5" and a.to_door == "to_forest_2" and b.to_room == "forest_2" and b.to_door == "to_forest_5", "兩扇門互指")
	check(a.get("branch", false) and b.get("branch", false), "捷徑門用小路標")
	for pair in [[f2, a, true], [f5, b, false]]:
		var d: Dictionary = pair[0]
		var door: Dictionary = pair[1]
		var bs: Array = d.get("barriers", [])
		var ledge := ground_under(d, door.spawn)
		check(bs.size() == 1 and bs[0].get("flag", "") == "shortcut_25", "%s 有 1 道捷徑木障" % d.id)
		if bs.size() != 1:
			continue
		var r: Rect2 = bs[0].rect
		check(absf(r.end.y - ledge.position.y) < 0.5 and r.position.y <= Kit.TOP, "%s 木障從 TOP 到高台頂面（%s）" % [d.id, r])
		var between: bool = (r.position.x >= ledge.position.x and r.end.x <= door.spawn.x) if pair[2] else (r.position.x >= door.spawn.x and r.end.x <= ledge.end.x)
		check(between, "%s 木障在高台開口與出生點之間（%s、出生點 %s、高台 %s）" % [d.id, r, door.spawn, ledge])
		for other in d.doors:
			check(not other.rect.grow(1.0).has_point(door.spawn), "%s 捷徑出生點不在門 %s 裡" % [d.id, other.id])
	for id in Index.ROOMS:
		for bar in Index.ROOMS[id].data().get("barriers", []):
			check(bar.rect.position.y <= Kit.TOP, "%s 的木障頂端 ≤ TOP（%s）" % [id, bar.rect])


func test_shortcut_flag_opens_both_sides() -> void:
	var gs = make_gs()
	for flagged in [false, true]:
		if flagged:
			gs.set_flag("shortcut_25")
		for id in ["forest_2", "forest_5"]:
			var r = await build_room(room_data(id), gs)
			check(r.barriers.size() == (0 if flagged else 1), "%s：旗標 %s → 木障 %d" % [id, flagged, r.barriers.size()])
			await free_room(r)
	gs.free()


func test_forest_4_barrier_rebuilt() -> void:
	var gs = make_gs()
	var r = await build_room(room_data("forest_4"), gs)
	if r.barriers.size() != 1:
		check(false, "森林 4 有 1 道木障（%d）" % r.barriers.size())
		await free_room(r)
		gs.free()
		return
	r.barriers[0].break_apart()
	await free_room(r)
	r = await build_room(room_data("forest_4"), gs)
	check(r.barriers.size() == 1 and not r.barriers[0].is_broken, "破開後重建：立回")
	await free_room(r)
	gs.stashes_taken["frag_f"] = true
	r = await build_room(room_data("forest_4"), gs)
	check(r.barriers.size() == 1 and r.fragment_pickup == null, "碎片拿過：木障仍立著、碎片不在")
	await free_room(r)
	gs.free()


func make_game_world(gs) -> Node:
	var w = GameWorld.new()
	w.gs = gs
	w.save_path = TEST_SAVE
	w.fade_time = 0.0
	add_child(w)
	return w


func test_shortcut_flag_saved() -> void:
	var gs = make_gs()
	gs.tn.card_min_time = 0.0
	gs.set_flag("intro_seen")
	gs.awakened = true
	var w = make_game_world(gs)
	w.flow.start("forest_5", false)
	await wait_until(func(): return not w.flow.is_busy() and w.flow.current != null, 60)
	var bs: Array = w.flow.current.get("barriers") if w.flow.current.get("barriers") != null else []
	if bs.is_empty():
		check(false, "森林 5 有木障")
		w.queue_free()
		await frames(2)
		gs.free()
		return
	bs[0].break_apart()
	await frames(1)
	w.flow.rest_here()
	await frames(2)
	check(Save.read(TEST_SAVE).get("flags", {}).has("shortcut_25"), "休息後存檔有 shortcut_25")
	w.queue_free()
	await frames(2)
	var gs2 = make_gs()
	var w2 = make_game_world(gs2)
	check(w2.continue_game(), "讀得到")
	await wait_until(func(): return not w2.flow.is_busy() and w2.flow.current != null, 60)
	check(w2.flow.current_id == "forest_5" and w2.flow.current.barriers.is_empty(), "讀檔回森林 5：沒有木障")
	w2.queue_free()
	await frames(2)
	gs.free()
	gs2.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


## 最終審查：森林房間也要有二段跳與工具的音效（同 Boss 段落）
func test_room_wires_awakened_ability_sounds() -> void:
	var gs = make_gs()
	gs.awakened = true
	var r = await build_room(barrier_room_data(), gs)
	var to_feedback := func(sig: Signal) -> bool:
		return sig.get_connections().any(func(c): return c.callable.get_object() == r.feedback or c.callable.get_object() == r)
	check(to_feedback.call(r.player.double_jumped), "二段跳接了音效")
	check(to_feedback.call(r.player.tool_sent), "工具派出接了音效")
	await free_room(r)
	gs.free()
