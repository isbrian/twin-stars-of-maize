extends "res://tests/base_test.gd"
# MV-SLICE-001a Task 4：房間資料、通用房間、換房。

const GameStateScr := preload("res://state/game_state.gd")
const RoomScr := preload("res://world/room.gd")
const RoomFlow := preload("res://world/room_flow.gd")
const RoomCheck := preload("res://world/room_check.gd")
const TestA := preload("res://world/rooms/_test_a.gd")
const TestB := preload("res://world/rooms/_test_b.gd")


func make_gs():
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	return gs


func make_flow(gs) -> Node:
	var f = RoomFlow.new()
	f.gs = gs
	f.tn = gs.tn
	f.rooms = {"_test_a": TestA, "_test_b": TestB}
	f.fade_time = 0.0
	add_child(f)
	return f


func build_room(d: Dictionary, gs) -> Node:
	var r = RoomScr.new()
	add_child(r)
	r.build(d, gs, gs.tn)
	r.player.scripted = true
	await frames(3)
	return r


func test_room_check_catches_floating_spawn() -> void:
	var d: Dictionary = TestA.data()
	d.doors[0].spawn = Vector2(1700, 500)
	check(not RoomCheck.errors(d).is_empty(), "門的出生點在空中應報錯")
	d.doors[0].spawn = Vector2(1880, 900)
	check(not RoomCheck.errors(d).is_empty(), "出生點在自己的門裡（一進來又出去）應報錯")
	d.doors[0].spawn = Vector2(1700, 900)
	check(RoomCheck.errors(d).is_empty(), "修正後沒有錯：%s" % RoomCheck.errors(d))
	var b: Dictionary = TestB.data()
	b.enemies.append({"kind": "crawler", "pos": Vector2(950, 300)})
	check(not RoomCheck.errors(b).is_empty(), "爬行型在空中應報錯")
	b.enemies[-1].pos = Vector2(950, 640)
	check(RoomCheck.errors(b).is_empty(), "站在單向平台上可以：%s" % RoomCheck.errors(b))
	b.enemies.append({"kind": "flyer", "pos": Vector2(950, 300)})
	check(RoomCheck.errors(b).is_empty(), "飛行型不檢查")


func test_link_check_requires_return_door() -> void:
	check(RoomCheck.link_errors({"_test_a": TestA, "_test_b": TestB}).is_empty(), "A、B 的門互相指回")
	check(not RoomCheck.link_errors({"_test_a": TestA}).is_empty(), "目的地房間不存在應報錯")


func test_build_creates_solids_enemies_and_skips_defeated() -> void:
	var gs = make_gs()
	var r = await build_room(TestB.data(), gs)
	check(r.enemies.size() == 1 and r.enemies[0].is_in_group("enemy"), "生成一隻敵人並加入 enemy 群組")
	check(r.player.is_on_floor(), "角色站在地形上")
	r.enemies[0].kill()
	await frames(2)
	check(gs.defeated.get("_test_b", []) == [0], "打倒記在 GameState.defeated")
	r.queue_free()
	await frames(1)
	r = await build_room(TestB.data(), gs)
	check(r.enemies.is_empty(), "打倒過的敵人重建時不生成（休息前不重生）")
	r.queue_free()
	await frames(1)
	gs.free()


func test_gate_hidden_after_flag() -> void:
	var gs = make_gs()
	var r = await build_room(TestB.data(), gs)
	check(r.gates.size() == 1, "旗標未設時有門擋著")
	r.queue_free()
	await frames(1)
	gs.set_flag("open_b")
	r = await build_room(TestB.data(), gs)
	check(r.gates.is_empty(), "旗標設了以後不生成")
	r.queue_free()
	await frames(1)
	gs.free()


func test_goto_places_player_at_door_spawn_and_keeps_hp() -> void:
	var gs = make_gs()
	var f = make_flow(gs)
	f.start("_test_a")
	await frames(3)
	check(f.current.data.id == "_test_a" and f.current.player.position == Vector2(400, 900), "start 站在休息點")
	f.current.player.health.hp = 2
	f.current.player.scripted = true
	f.current.player.position = Vector2(1700, 900)
	f.current.player.intent.move_x = 1.0
	var moved: bool = await wait_until(func(): return f.current.data.id == "_test_b", 90)
	check(moved, "走進右門換到 _test_b")
	await frames(2)
	check(f.current.player.position.distance_to(Vector2(220, 900)) < 30.0, "站在 _test_b 左門的出生點，實際 %s" % f.current.player.position)
	check(f.current.player.health.hp == 2, "血量跟著過去")
	f.queue_free()
	await frames(1)
	gs.free()


func test_goto_ignored_while_transitioning() -> void:
	var gs = make_gs()
	var f = make_flow(gs)
	f.fade_time = 0.1
	f.start("_test_a")
	await wait_until(func(): return not f.is_busy(), 60)
	var changes := [0]
	f.room_changed.connect(func(_id): changes[0] += 1)
	f.goto("_test_b", "west")
	f.goto("_test_a", "east")
	await frames(40)
	check(changes[0] == 1 and f.current.data.id == "_test_b", "換房進行中的第二次 goto 被忽略，實際 %d 次、在 %s" % [changes[0], f.current.data.id])
	f.queue_free()
	await frames(1)
	gs.free()
