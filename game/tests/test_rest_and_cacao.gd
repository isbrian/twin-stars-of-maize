extends "res://tests/base_test.gd"
# MV-SLICE-001a Task 6：可可豆、藏點、休息與存檔、死亡回點、HUD 數字。

const GameStateScr := preload("res://state/game_state.gd")
const RoomScr := preload("res://world/room.gd")
const RoomFlow := preload("res://world/room_flow.gd")
const Save := preload("res://state/save.gd")
const TestA := preload("res://world/rooms/_test_a.gd")
const TestB := preload("res://world/rooms/_test_b.gd")
const TEST_SAVE := "user://test_rest_slot.json"


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
	f.save_path = TEST_SAVE
	add_child(f)
	return f


func build_room(d: Dictionary, gs) -> Node:
	var r = RoomScr.new()
	add_child(r)
	r.build(d, gs, gs.tn)
	r.player.scripted = true
	await frames(3)
	return r


func test_enemy_drop_in_range() -> void:
	var gs = make_gs()
	seed(12345)
	var got := {}
	for i in 12:
		gs.defeated = {}
		var before: int = gs.cacao
		var r = await build_room(TestB.data(), gs)
		r.enemies[0].kill()
		await frames(2)
		var n: int = gs.cacao - before
		check(n >= 1 and n <= 3, "一般敵人掉 1～3 顆，實際 %d" % n)
		got[n] = true
		r.queue_free()
		await frames(1)
	check(got.size() >= 2, "掉落數量有變化：%s" % [got.keys()])
	gs.free()


func test_stash_once() -> void:
	var gs = make_gs()
	var d: Dictionary = TestB.data()
	d.stash = {"id": "s1", "pos": Vector2(950, 640)}
	var r = await build_room(d, gs)
	check(r.stash != null, "藏點存在")
	r.player.position = Vector2(950, 640)
	await frames(3)
	check(gs.cacao == 10 and gs.stashes_taken.get("s1", false), "碰到就拿到 10 顆")
	await frames(2)
	check(gs.cacao == 10, "只拿一次")
	r.queue_free()
	await frames(1)
	r = await build_room(d, gs)
	check(r.stash == null, "拿過的藏點不再出現")
	r.queue_free()
	await frames(1)
	gs.free()


func test_rest_saves_and_respawns_enemies() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var gs = make_gs()
	var f = make_flow(gs)
	f.start("_test_a")
	await wait_until(func(): return not f.is_busy(), 30)
	f.current.enemies[0].kill()
	await frames(2)
	check(f.current.enemies.is_empty() and gs.defeated.has("_test_a"), "打倒一隻")
	f.current.player.health.hp = 2
	f.current.player.scripted = true
	f.current.player.intent.interact_pressed = true
	await wait_until(func(): return f.current.enemies.size() == 1, 30)
	check(f.current.enemies.size() == 1, "休息後敵人重生")
	check(f.current.player.health.hp == gs.tn.max_hp, "血量回滿")
	check(gs.last_rest == "_test_a", "記下休息地點")
	check(FileAccess.file_exists(TEST_SAVE), "休息時寫入存檔")  # _test_a 不在房間表裡，Save.exists 會當成不能用
	f.queue_free()
	await frames(1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	gs.free()


func test_interact_far_from_rest_does_nothing() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var gs = make_gs()
	var f = make_flow(gs)
	f.start("_test_a")
	await wait_until(func(): return not f.is_busy(), 30)
	f.current.player.scripted = true
	f.current.player.position = Vector2(1600, 900)
	await frames(2)
	f.current.player.intent.interact_pressed = true
	await frames(5)
	check(not Save.exists(TEST_SAVE), "離休息點很遠時互動不休息")
	f.queue_free()
	await frames(1)
	gs.free()


func test_death_returns_to_last_rest_keeping_cacao() -> void:
	var gs = make_gs()
	var f = make_flow(gs)
	gs.last_rest = "_test_a"
	f.start("_test_b")
	await wait_until(func(): return not f.is_busy(), 30)
	gs.add_cacao(30)
	f.current.player.health.hp = 1
	f.current.player.hurtbox.receive(1, null, &"enemy")
	var back: bool = await wait_until(func(): return f.current.data.id == "_test_a" and not f.is_busy(), 120)
	check(back, "死亡回到最後休息的地點")
	check(f.current.player.health.hp == gs.tn.max_hp, "血量回滿")
	check(f.current.player.health.heal_charges == gs.tn.heal_charges, "治療次數回滿")
	check(gs.cacao == 30, "可可豆不損失")
	check(f.current.player.position == Vector2(400, 900), "站在休息點")
	f.queue_free()
	await frames(1)
	gs.free()


func test_hud_shows_cacao_and_soup() -> void:
	var gs = make_gs()
	gs.add_cacao(23)
	gs.soup = 1
	var hud = Hud.new()
	hud.gs = gs
	var s: String = hud.status_line()
	check(s.contains("23") and s.contains("熱湯 1／2"), "HUD 顯示可可豆與熱湯，實際「%s」" % s)
	hud.free()
	gs.free()


func test_death_during_transition_is_handled_after() -> void:
	var gs = make_gs()
	var f = make_flow(gs)
	f.fade_time = 0.1
	gs.last_rest = "_test_a"
	f.start("_test_b")
	await wait_until(func(): return not f.is_busy(), 60)
	var old = f.current
	f.goto("_test_a", "east")
	old.player.health.hp = 1
	old.player.hurtbox.receive(1, null, &"enemy")
	await frames(2)
	var settled: bool = await wait_until(func(): return not f.is_busy() and f.current.player.health.hp == gs.tn.max_hp, 120)
	check(settled, "換房途中死亡：換完以後照常回休息點、血量回滿（不帶 0 血進新房間）")
	check(f.current.data.id == "_test_a" and f.current.player.position == Vector2(400, 900), "最後站在休息點")
	f.queue_free()
	await frames(1)
	gs.free()
