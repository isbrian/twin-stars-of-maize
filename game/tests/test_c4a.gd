extends "res://tests/base_test.gd"
# MV-SLICE-001c4a：森林加大加深與血量碎片（碎片、荊棘、下劈水晶、關門戰、房間檢查、森林房間）。

const GameStateScr := preload("res://state/game_state.gd")
const RoomScr := preload("res://world/room.gd")
const TestB := preload("res://world/rooms/_test_b.gd")
const FloatText := preload("res://world/float_text.gd")
const Save := preload("res://state/save.gd")
const TEST_SAVE := "user://test_c4a_slot.json"


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


func floats_of(r) -> Array:
	return r.get_children().filter(func(n): return n is FloatText).map(func(n): return n.text)


# ---- Task 1：血量碎片與血量上限 ----

func test_max_hp_from_fragments() -> void:
	var gs = make_gs()
	if not gs.has_method("max_hp_now"):
		check(false, "有 max_hp_now")
		gs.free()
		return
	var want := [5, 5, 6, 6, 7]
	for n in 5:
		gs.stashes_taken = {"forest_3": true}
		for i in n:
			gs.stashes_taken["frag_%d" % i] = true
		check(gs.fragments() == n and gs.max_hp_now() == want[n], "%d 片 → 上限 %d（%d）" % [n, want[n], gs.max_hp_now()])
	gs.free()


func test_fragment_pickup_rules() -> void:
	var gs = make_gs()
	var d: Dictionary = TestB.data()
	d.fragment = {"id": "frag_x", "pos": Vector2(950, 640)}
	var r = await build_room(d, gs)
	r.player.position = Vector2(950, 640)
	await frames(3)
	check(gs.stashes_taken.get("frag_x", false) and r.player.health.max_hp == 5, "第 1 片：記下、上限仍 5")
	check(floats_of(r).has("血量碎片 1/2"), "提示 血量碎片 1/2（%s）" % [floats_of(r)])
	r.queue_free()
	await frames(1)
	d.fragment = {"id": "frag_y", "pos": Vector2(950, 640)}
	r = await build_room(d, gs)
	r.player.health.hp = 2
	r.player.position = Vector2(950, 640)
	await frames(3)
	check(r.player.health.max_hp == 6 and r.player.health.hp == 6 and gs.hp == 6, "第 2 片：上限 6、補滿（%d／%d）" % [r.player.health.hp, r.player.health.max_hp])
	check(floats_of(r).has("血量上限 +1"), "提示 血量上限 +1")
	r.queue_free()
	await frames(1)
	r = await build_room(d, gs)
	check(r.get("fragment_pickup") == null, "拿過的碎片不再出現")
	r.queue_free()
	await frames(1)
	gs.free()


func test_rest_fills_to_fragment_max() -> void:
	var gs = make_gs()
	for id in ["frag_a", "frag_b", "frag_c"]:
		gs.stashes_taken[id] = true
	gs.hp = 1
	gs.rest("forest_2")
	check(gs.hp == 6, "3 片時休息補到 6（%d）" % gs.hp)
	var hud = load("res://ui/hud.gd").new()
	hud.gs = gs
	check(hud.has_method("half_heart") and hud.half_heart(), "奇數片：HUD 有半格")
	hud.free()
	gs.free()


func test_old_save_without_fragments_loads() -> void:
	var gs = make_gs()
	var d: Dictionary = gs.to_dict()
	d.stashes_taken = {"forest_3": true}
	var gs2 = make_gs()
	check(GameStateScr.valid_state(d) and gs2.from_dict(d), "舊存檔讀得到")
	check(gs2.has_method("max_hp_now") and gs2.max_hp_now() == 5, "沒有碎片：上限 5")
	gs.free()
	gs2.free()


func test_boss_retry_keeps_fragment_max_hp() -> void:
	var gs = make_gs()
	gs.stashes_taken["frag_a"] = true
	gs.stashes_taken["frag_b"] = true
	var f = BossFight.new()
	f.tn = gs.tn
	f.gs = gs
	f.save_path = TEST_SAVE
	f.tester = "selftest"
	f.log_dir = TEST_LOG_DIR
	f.player_scripted = true
	add_child(f)
	await frames(3)
	f._retry(1)
	await frames(2)
	check(f.player.health.max_hp == 6 and f.player.health.hp == 6, "Boss 段落重試：上限仍 6（%d）" % f.player.health.max_hp)
	await free_fight(f)
	gs.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


# ---- Task 2：荊棘地形 ----

const HAZARD := Rect2(1300, 860, 300, 40)  # 地面上一排荊棘（地面 y 900）


func hazard_room(gs) -> Node:
	var d: Dictionary = TestB.data()
	d.enemies = []
	d.gates = []
	d.hazards = [HAZARD]
	return await build_room(d, gs)


func stand_at(r, at: Vector2, secs := 0.3) -> void:
	r.player.velocity = Vector2.ZERO
	r.player.position = at
	await frames(int(secs * 60))


func test_hazard_damages_and_returns() -> void:
	var gs = make_gs()
	var r = await hazard_room(gs)
	await stand_at(r, Vector2(500, 900))
	var hp0: int = r.player.health.hp
	r.player.position = Vector2(1450, 890)
	await frames(45)
	check(r.player.health.hp == hp0 - 1, "扣 1 格（%d → %d）" % [hp0, r.player.health.hp])
	check(r.player.position.distance_to(Vector2(500, 900)) <= 2.0, "回到最後站穩的地面（%s）" % r.player.position)
	r.queue_free()
	await frames(1)
	gs.free()


func test_hazard_no_double_damage_in_invuln() -> void:
	var gs = make_gs()
	var r = await hazard_room(gs)
	await stand_at(r, Vector2(500, 900))
	r.player.health.take_damage(1, 5.0)
	var hp0: int = r.player.health.hp
	r.player.position = Vector2(1450, 890)
	await frames(45)
	check(r.player.health.hp == hp0, "無敵中不扣血")
	check(r.player.position.distance_to(Vector2(500, 900)) <= 2.0, "仍被放回")
	r.queue_free()
	await frames(1)
	gs.free()


func test_hazard_can_kill() -> void:
	var gs = make_gs()
	var r = await hazard_room(gs)
	await stand_at(r, Vector2(500, 900))
	var died := [false]
	r.player_died.connect(func(): died[0] = true)
	r.player.health.hp = 1
	r.player.position = Vector2(1450, 890)
	await frames(10)
	check(died[0], "扣到 0：死亡")
	r.queue_free()
	await frames(1)
	gs.free()


func test_safe_ground_never_near_hazard() -> void:
	var gs = make_gs()
	var r = await hazard_room(gs)
	await stand_at(r, Vector2(500, 900))
	await stand_at(r, Vector2(HAZARD.position.x - 40.0, 900))  # 離荊棘 40 px：不算安全點
	r.player.position = Vector2(1450, 890)
	await frames(45)
	var gap: float = HAZARD.position.x - r.player.position.x
	check(gap >= 80.0 and r.player.is_on_floor(), "放回的位置離荊棘 ≥ 80 px、站在地面上（%.0f）" % gap)
	r.queue_free()
	await frames(1)
	gs.free()


func test_hazard_art_placed() -> void:
	var gs = make_gs()
	var d: Dictionary = TestB.data()
	d.enemies = []
	d.hazards = [HAZARD]
	d.theme = "forest"
	var r = await build_room(d, gs)
	var hits: Array = r.scenery.piece_rects().filter(func(p): return p.kind == "hazard")
	check(hits.size() == 1 and hits[0].rect == HAZARD, "荊棘外觀蓋住矩形（%s）" % [hits])
	r.queue_free()
	await frames(1)
	gs.free()


# ---- Task 3：下劈水晶與下劈提示 ----

const GameWorld := preload("res://world/game_world.gd")
const TestHint := preload("res://world/rooms/_test_hint.gd")


func test_crystals_built() -> void:
	var gs = make_gs()
	var d: Dictionary = TestB.data()
	d.enemies = []
	d.crystals = [Vector2(600, 500), Vector2(1500, 600)]
	var r = await build_room(d, gs)
	var got: Array = r.get_children().filter(func(n): return n is PogoCrystal).map(func(n): return n.position)
	check(got == [Vector2(600, 500), Vector2(1500, 600)], "2 顆水晶在資料的位置（%s）" % [got])
	r.queue_free()
	await frames(1)
	gs.free()


func test_pogo_bounce_signal() -> void:
	var gs = make_gs()
	var d: Dictionary = TestB.data()
	d.enemies = []
	d.crystals = [Vector2(1500, 600)]
	gs.weapons_owned = [Weapons.Weapon.AXE]  # 新遊戲沒有武器，攻擊不會發動
	gs.equip = [Weapons.Weapon.AXE, -1]
	var r = await build_room(d, gs)
	if not r.player.has_signal("pogo_bounced"):
		check(false, "玩家有 pogo_bounced 訊號")
		r.queue_free()
		gs.free()
		return
	var got := [false]
	r.player.pogo_bounced.connect(func(): got[0] = true)
	r.player.position = Vector2(1500, 400)
	r.player.velocity = Vector2.ZERO
	await frames(2)  # 先離地（按下那一幀要已經在空中，才是下劈）
	r.player.intent.down = true
	r.player.intent.attack_pressed = true
	var bounced: bool = await wait_until(func(): return got[0], 30)
	check(bounced and r.player.velocity.y < 0.0, "下劈打中水晶：彈起並發 pogo_bounced")
	r.queue_free()
	await frames(1)
	gs.free()


func test_pogo_hint_flow() -> void:
	var gs = make_gs()
	gs.tn.card_min_time = 0.0
	var w = GameWorld.new()
	w.gs = gs
	w.save_path = TEST_SAVE
	w.fade_time = 0.0
	add_child(w)
	var rooms: Dictionary = w.flow.rooms.duplicate()
	rooms["_test_hint"] = TestHint
	w.flow.rooms = rooms
	w.flow.start("_test_hint", false)
	await wait_until(func(): return not w.flow.is_busy() and w.flow.current != null, 60)
	var r = w.flow.current
	r.player.scripted = true
	r.player.position = Vector2(1250, 900)
	await frames(5)
	check(w.hints.current == "pogo", "走進提示區：出現下劈提示（%s）" % w.hints.current)
	if r.player.has_signal("pogo_bounced"):
		r.player.pogo_bounced.emit()
	await frames(2)
	check(gs.hints_seen.get("pogo", false) and w.hints.current != "pogo", "彈起一次：提示消失、記進存檔")
	w.queue_free()
	await frames(2)
	gs.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


# ---- Task 4：關門戰 ----

func arena_data() -> Dictionary:
	var d: Dictionary = TestB.data()
	d.enemies = []
	d.gates = []
	d.arena = {
		"rect": Rect2(400, 500, 1100, 400),
		"gates": [Rect2(300, 300, 60, 600), Rect2(1560, 300, 60, 600)],
		"waves": [
			[{"kind": "crawler", "pos": Vector2(700, 900)}, {"kind": "flyer", "pos": Vector2(1200, 500)}],
			[{"kind": "crawler", "pos": Vector2(600, 900)}, {"kind": "crawler", "pos": Vector2(1300, 900)}, {"kind": "flyer", "pos": Vector2(900, 450)}],
			[{"kind": "crawler", "pos": Vector2(600, 900)}, {"kind": "crawler", "pos": Vector2(1300, 900)}, {"kind": "flyer", "pos": Vector2(800, 450)}, {"kind": "flyer", "pos": Vector2(1100, 450)}],
		],
		"reward": {"id": "frag_t", "pos": Vector2(950, 900)},
	}
	return d


func live_enemies(r) -> Array:
	return r.enemies.filter(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion())


func kill_all(r) -> void:
	for e in live_enemies(r):
		e.kill()
	await frames(2)


func test_arena_waves_and_reward() -> void:
	var gs = make_gs()
	var r = await build_room(arena_data(), gs)
	var a = r.get("arena")
	check(a != null and a.wave == -1, "關門戰建好、未開始")
	if a == null:
		r.queue_free()
		gs.free()
		return
	r.player.position = Vector2(950, 900)
	await frames(3)
	check(a.wave == 0 and live_enemies(r).size() == 2 and r.gates.size() == 2, "走進去：關門、第 1 波 2 隻（%d）" % live_enemies(r).size())
	var sizes := []
	for w in [1, 2]:
		await kill_all(r)
		await secs_wait(1.2)
		sizes.append(live_enemies(r).size())
	check(sizes == [3, 4], "第 2、3 波 3、4 隻（%s）" % [sizes])
	r.player.position = Vector2(600, 900)  # 離開獎勵的位置，碎片出現時不會馬上被撿走
	await kill_all(r)
	await secs_wait(1.2)
	check(r.gates.is_empty() and r.fragment_pickup != null, "清完：開門、碎片出現")
	r.queue_free()
	await frames(1)
	gs.free()


func secs_wait(t: float) -> void:
	await frames(int(t * 60))


func test_arena_not_retriggered_after_reward() -> void:
	var gs = make_gs()
	gs.stashes_taken["frag_t"] = true
	var r = await build_room(arena_data(), gs)
	r.player.position = Vector2(950, 900)
	await frames(3)
	check(r.get("arena") == null and r.gates.is_empty() and live_enemies(r).is_empty(), "碎片拿過：不觸發")
	r.queue_free()
	await frames(1)
	gs.free()


func test_arena_resets_after_reload() -> void:
	var gs = make_gs()
	var r = await build_room(arena_data(), gs)
	r.player.position = Vector2(950, 900)
	await frames(3)
	await kill_all(r)
	await secs_wait(1.2)
	r.queue_free()
	await frames(1)
	r = await build_room(arena_data(), gs)
	var a = r.get("arena")
	check(a != null and a.wave == -1 and live_enemies(r).is_empty() and r.fragment_pickup == null, "重建房間：未開始、沒有敵人、碎片不在")
	r.queue_free()
	await frames(1)
	gs.free()


func test_arena_enemies_not_in_defeated() -> void:
	var gs = make_gs()
	var r = await build_room(arena_data(), gs)
	r.player.position = Vector2(950, 900)
	await frames(3)
	for i in 3:
		await kill_all(r)
		await secs_wait(1.2)
	check(not gs.defeated.has("_test_b"), "關門戰的敵人不記進 defeated（%s）" % [gs.defeated])
	r.queue_free()
	await frames(1)
	gs.free()


# ---- Task 5：房間檢查工具與支路路標 ----

const RoomCheck := preload("res://world/room_check.gd")
const Kit := preload("res://world/rooms/kit.gd")


## 人造房間：地面 0～800、平台在 x0～x0+300、高 h 上方，終點在平台上
func step_room(x0: float, h: float) -> Dictionary:
	return Kit.room("_t", 1, {"platforms": [Rect2(x0, Kit.GROUND_Y - h, 300, 30)], "solids": []})


func test_walk_errors_rise_and_gap() -> void:
	var g := Kit.GROUND_Y
	check(RoomCheck.walk_errors(step_room(900, 300), Vector2(200, g), Vector2(1000, g - 300)).is_empty(), "高 300：走得到")
	check(not RoomCheck.walk_errors(step_room(900, 380), Vector2(200, g), Vector2(1000, g - 380)).is_empty(), "高 380：走不到")
	# 坑：地面拆成兩段，中間空 gap
	for case in [[350.0, true], [450.0, false]]:
		var d := Kit.room("_t", 1, {})
		d.solids = [Rect2(-100, g, 800, 400), Rect2(700 + case[0], g, 2000, 400)]
		var ok: bool = RoomCheck.walk_errors(d, Vector2(200, g), Vector2(1700, g)).is_empty()
		check(ok == case[1], "坑寬 %d：%s" % [case[0], "走得到" if case[1] else "走不到"])
	var d2 := Kit.room("_t", 1, {})
	d2.hazards = [Rect2(600, g - 40, 600, 40)]
	check(not RoomCheck.walk_errors(d2, Vector2(200, g), Vector2(1600, g)).is_empty(), "荊棘蓋住的地面（寬 600）不能站：走不到")


func test_fragment_on_terrain_checked() -> void:
	var d := Kit.room("_t", 1, {"fragment": {"id": "frag_x", "pos": Vector2(900, 500)}})
	check(Array(RoomCheck.errors(d)).any(func(e): return e.contains("碎片")), "懸空的碎片要報錯")


func test_hazard_over_spawn_checked() -> void:
	var d := Kit.room("_t", 1, {"doors": [Kit.door_left("w", "x", "e")], "hazards": [Rect2(150, Kit.GROUND_Y - 40, 200, 40)]})
	check(Array(RoomCheck.errors(d)).any(func(e): return e.contains("荊棘")), "荊棘蓋住出生點要報錯")


func test_branch_waymark_smaller() -> void:
	var gs = make_gs()
	var d: Dictionary = TestB.data()
	d.enemies = []
	d.theme = "forest"
	d.doors = [d.doors[0], {"id": "side", "rect": Rect2(1850, 300, 70, 300), "to_room": "_test_a", "to_door": "east", "spawn": Vector2(1700, 640), "branch": true}]
	var r = await build_room(d, gs)
	var marks: Array = r.scenery.piece_rects().filter(func(p): return p.kind == "waymark")
	check(marks.size() == 2 and is_equal_approx(marks[1].rect.size.y / marks[0].rect.size.y, 0.7), "支路路標約 0.7 倍（%s）" % [marks.map(func(m): return m.rect.size)])
	r.queue_free()
	await frames(1)
	gs.free()


# ---- Task 6：主路 6 間 ----

const Index := preload("res://world/rooms/index.gd")
const MAIN := ["forest_1", "forest_2", "forest_3", "forest_4", "forest_5", "forest_6"]


## 主路的門：不是支路、出生點在地面
func main_doors(d: Dictionary) -> Array:
	return d.doors.filter(func(door): return not door.get("branch", false))


func right_main_door(d: Dictionary) -> Dictionary:
	var best := {}
	for door in main_doors(d):
		if door.spawn.x > d.size.x / 2.0:
			best = door
	return best


func test_main_path_walkable() -> void:
	for id in MAIN:
		if not Index.ROOMS.has(id):
			check(false, "有 %s" % id)
			continue
		var d: Dictionary = Index.ROOMS[id].data()
		var left: Dictionary = main_doors(d).filter(func(door): return door.spawn.x < d.size.x / 2.0)[0]
		var errs := RoomCheck.walk_errors(d, left.spawn, right_main_door(d).spawn)
		check(errs.is_empty(), "%s 主路只靠單跳走得完：%s" % [id, errs])
		check(d.size.x == Kit.SCREEN * 3, "%s 3 個畫面寬" % id)


func test_main_path_order() -> void:
	var path := []
	var id := "yard"
	for i in 8:
		var door: Dictionary = right_main_door(Index.ROOMS[id].data())
		id = door.to_room
		path.append(id)
		if id == "boss":
			break
	check(path == MAIN + ["boss"], "主路順序（%s）" % [path])


func test_forest_rest_points() -> void:
	var rests := []
	for id in Index.ROOMS:
		if id.begins_with("forest") and Index.ROOMS[id].data().has("rest"):
			rests.append(id)
	rests.sort()
	check(rests == ["forest_2", "forest_5"], "篝火在森林 2、森林 5（%s）" % [rests])
	if not Index.ROOMS.has("forest_5"):
		return
	var gs = make_gs()
	gs.tn.card_min_time = 0.0
	gs.set_flag("intro_seen")
	var w = GameWorld.new()
	w.gs = gs
	w.save_path = TEST_SAVE
	w.fade_time = 0.0
	add_child(w)
	w.flow.start("forest_5", false)
	await wait_until(func(): return not w.flow.is_busy() and w.flow.current != null, 60)
	w.flow.rest_here()
	await frames(2)
	check(Save.read(TEST_SAVE).get("last_rest", "") == "forest_5", "森林 5 休息後存檔")
	w.queue_free()
	await frames(2)
	var gs2 = make_gs()
	var w2 = GameWorld.new()
	w2.gs = gs2
	w2.save_path = TEST_SAVE
	w2.fade_time = 0.0
	add_child(w2)
	check(w2.continue_game(), "讀得到")
	await wait_until(func(): return not w2.flow.is_busy() and w2.flow.current != null, 60)
	check(w2.flow.current_id == "forest_5", "讀檔回到森林 5")
	w2.queue_free()
	await frames(2)
	gs.free()
	gs2.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func test_first_crystal_teaches_on_safe_ground() -> void:
	var d: Dictionary = Index.ROOMS["forest_2"].data()
	check(d.get("crystals", []).size() >= 1 and d.has("hint_at") and d.hint_at.id == "pogo", "森林 2 有水晶與下劈提示")
	if d.get("crystals", []).is_empty():
		return
	var c: Vector2 = d.crystals[0]
	var under := RoomCheck.walk_errors(d, d.doors[0].spawn, Vector2(c.x, Kit.GROUND_Y))
	check(under.is_empty() and d.hint_at.rect.end.x <= c.x, "水晶底下是走得到的地面、提示區在水晶前")


## 右端的高處平台（薄的實心）要有外觀，不能是隱形的
func test_ledges_have_art() -> void:
	var gs = make_gs()
	for id in ["forest_2", "forest_3", "forest_4", "forest_5", "forest_6"]:
		var d: Dictionary = Index.ROOMS[id].data()
		var thin: Array = d.solids.filter(func(r): return r.size.y <= 40.0)
		var r = await build_room(d, gs)
		var arts: Array = r.scenery.piece_rects().filter(func(p): return p.kind == "platform")
		for t in thin:
			check(arts.any(func(p): return p.rect.position.is_equal_approx(t.position) and absf(p.rect.size.x - t.size.x) < 1.0), "%s 的高台 %s 有外觀" % [id, t])
		r.queue_free()
		await frames(1)
	gs.free()


# ---- Task 7：支路 3 間 ----

const BRANCHES := {"forest_a": "forest_3", "forest_b": "forest_4", "forest_c": "forest_6"}


## MV-SLICE-001c4b 起 6 片：c4a 的 4 片＋森林 1、4 的鎖後各 1 片
func test_fragments_total() -> void:
	var ids := []
	for id in Index.ROOMS:
		var d: Dictionary = Index.ROOMS[id].data()
		if d.has("fragment"):
			ids.append(d.fragment.id)
		if d.has("arena"):
			ids.append(d.arena.reward.id)
	ids.sort()
	check(ids == ["frag_a", "frag_b", "frag_c", "frag_d", "frag_e", "frag_f"], "全切片正好 6 片（%s）" % [ids])
	var gs = make_gs()
	for id in ids:
		gs.stashes_taken[id] = true
	check(gs.max_hp_now() == 8, "6 片全拿：上限 8（%d）" % gs.max_hp_now())
	gs.free()


func test_branches_are_dead_ends() -> void:
	for b in BRANCHES:
		if not Index.ROOMS.has(b):
			check(false, "有 %s" % b)
			continue
		var d: Dictionary = Index.ROOMS[b].data()
		check(d.doors.size() == 1 and d.doors[0].to_room == BRANCHES[b], "%s 只有一扇門、回 %s" % [b, BRANCHES[b]])
		var main: Dictionary = Index.ROOMS[BRANCHES[b]].data()
		var back: Array = main.doors.filter(func(door): return door.to_room == b)
		check(back.size() == 1 and back[0].get("branch", false), "%s 通往 %s 的門是支路門" % [BRANCHES[b], b])


func test_branch_b_walkable() -> void:
	if not Index.ROOMS.has("forest_b"):
		check(false, "有 forest_b")
		return
	var d: Dictionary = Index.ROOMS["forest_b"].data()
	var errs := RoomCheck.walk_errors(d, d.doors[0].spawn, d.fragment.pos)
	check(errs.is_empty(), "支路 B 只靠單跳走得到碎片：%s" % errs)
	var a: Dictionary = Index.ROOMS["forest_a"].data() if Index.ROOMS.has("forest_a") else {}
	if not a.is_empty():
		check(not RoomCheck.walk_errors(a, a.doors[0].spawn, a.fragment.pos).is_empty() and a.get("crystals", []).size() >= 3, "支路 A 要靠下劈水晶")


func test_branch_return_spawn_on_ledge() -> void:
	for b in BRANCHES:
		var main: Dictionary = Index.ROOMS[BRANCHES[b]].data()
		var back: Array = main.doors.filter(func(door): return door.to_room == b)
		if back.is_empty():
			check(false, "%s 有支路門" % BRANCHES[b])
			continue
		var spawn: Vector2 = back[0].spawn
		check(spawn.y < Kit.GROUND_Y - 100.0 and RoomCheck.errors(main).is_empty(), "%s 回來的出生點在高處平台上（%s）" % [BRANCHES[b], spawn])
		for door in main.doors:
			check(not door.rect.grow(1.0).has_point(spawn), "%s 回來的出生點不在門 %s 裡" % [BRANCHES[b], door.id])


func test_all_forest_reachable() -> void:
	var seen := {"yard": true}
	var queue := ["yard"]
	while not queue.is_empty():
		var id: String = queue.pop_front()
		for door in RoomCheck._doors(Index.ROOMS[id].data()):
			if Index.ROOMS.has(door.to_room) and not seen.has(door.to_room):
				seen[door.to_room] = true
				queue.append(door.to_room)
	for id in MAIN + BRANCHES.keys():
		check(seen.has(id), "從家前空地走得到 %s" % id)


# ---- 最終審查的修正 ----

## C1：按著方向鍵碰荊棘——放回後不會滑回荊棘；還在荊棘裡就再處理一次
func test_hazard_held_direction_no_slip_back() -> void:
	var gs = make_gs()
	var r = await hazard_room(gs)
	await stand_at(r, Vector2(HAZARD.position.x - 200.0, 900))
	r.player.intent.move_x = 1.0
	var hp0: int = r.player.health.hp
	await frames(60)
	var x: float = r.player.position.x
	check(r.player.health.hp == hp0 - 1, "按著右鍵走進荊棘：扣 1 格")
	check(x + 30.0 <= HAZARD.position.x or r.player.health.hp < hp0 - 1, "放回後不會滑回荊棘裡又不受傷（x %.0f）" % x)
	r.queue_free()
	await frames(1)
	gs.free()


## I1：已有別的提示在畫面上時，房間的提示區提示要插到最前面
func test_room_hint_jumps_queue() -> void:
	var gs = make_gs()
	gs.tn.card_min_time = 0.0
	var w = GameWorld.new()
	w.gs = gs
	w.save_path = TEST_SAVE
	w.fade_time = 0.0
	add_child(w)
	var rooms: Dictionary = w.flow.rooms.duplicate()
	rooms["_test_hint"] = TestHint
	w.flow.rooms = rooms
	w.flow.start("_test_hint", false)
	await wait_until(func(): return not w.flow.is_busy() and w.flow.current != null, 60)
	w.hints.request("heal")
	var r = w.flow.current
	r.player.scripted = true
	r.player.position = Vector2(1250, 900)
	await frames(5)
	check(w.hints.current == "pogo", "已有治療提示：下劈提示仍立刻出現（%s）" % w.hints.current)
	w.queue_free()
	await frames(2)
	gs.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


## I2：不經過門進房（--room、F10、截圖）時，出生在地面上，不是支路的高台
func test_default_spawn_on_ground() -> void:
	var gs = make_gs()
	for id in ["forest_3", "forest_4", "forest_6"]:
		var r = await build_room(Index.ROOMS[id].data(), gs)
		check(absf(r.player.position.y - Kit.GROUND_Y) < 2.0 and r.player.position.x < Kit.SCREEN, "%s 預設出生在左邊地面（%s）" % [id, r.player.position])
		r.queue_free()
		await frames(1)
	gs.free()
