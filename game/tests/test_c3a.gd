extends "res://tests/base_test.gd"
# MV-SLICE-001c3a：地面事件演出（地面房間的過場、收工、動物復原、交換、咬繩、天亮）。

const GameStateScr := preload("res://state/game_state.gd")
const RoomFlow := preload("res://world/room_flow.gd")
const EventRunner := preload("res://events/event_runner.gd")
const Index := preload("res://world/rooms/index.gd")
const GameWorld := preload("res://world/game_world.gd")
const TEST_SAVE := "user://test_c3a_slot.json"
const FieldAnimals := preload("res://world/cutscene/field_animals.gd")
const RatDeal := preload("res://world/cutscene/rat_deal.gd")

const ALL_DONE := ["tools_obtained", "field_cleared", "night_seen", "rat_caught", "gear_dropped", "gear_obtained"]


## 測試用的小段落：等 secs 秒，記下演出中的狀態
class Probe extends RefCounted:
	var secs := 0.3
	var seen := {}
	var ended_with = null

	func play(cs) -> void:
		await cs.wait(secs)
		var r = cs.host.room
		seen = {"player_visible": r.player.visible, "room_mode": r.process_mode, "cs_camera": cs.camera.is_current()}

	func end_state(host) -> void:
		ended_with = host


## 地面房間＋事件；回傳 [flow, runner, gs]
func setup(room: String, flags := []) -> Array:
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.tn.card_min_time = 0.0
	gs.reset_new_game()
	gs.set_flag("intro_seen")
	for f in flags:
		gs.set_flag(f)
	var flow = RoomFlow.new()
	flow.gs = gs
	flow.tn = gs.tn
	flow.rooms = Index.ROOMS
	flow.fade_time = 0.0
	flow.save_path = TEST_SAVE
	add_child(flow)
	var runner = EventRunner.new()
	runner.flow = flow
	runner.gs = gs
	runner.hud = Control.new()
	add_child(runner)
	runner.add_child(runner.hud)
	flow.start(room)
	await wait_until(func(): return not flow.is_busy(), 30)
	flow.current.player.scripted = true
	await frames(2)
	return [flow, runner, gs]


func teardown(s: Array) -> void:
	Engine.time_scale = 1.0
	s[1].queue_free()
	s[0].queue_free()
	await frames(2)
	s[2].free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func test_ground_cutscene_hides_player_and_freezes_room() -> void:
	var s: Array = await setup("field", ALL_DONE)
	var probe := Probe.new()
	await s[1].play([probe])
	check(probe.seen.get("player_visible") == false, "演出中真正的玩家藏起來")
	check(probe.seen.get("room_mode") == Node.PROCESS_MODE_DISABLED, "演出中房間凍結")
	check(probe.seen.get("cs_camera") == true, "演出中用過場的鏡頭")
	check(probe.ended_with != null and probe.ended_with.room == s[0].current, "end_state 拿到地面舞台（room＝目前房間）")
	await teardown(s)


func test_ground_handover_restores_room() -> void:
	var s: Array = await setup("field", ALL_DONE)
	var r = s[0].current
	await s[1].play([Probe.new()])
	await frames(30)  # 黑邊收完
	check(r.player.visible and r.process_mode == Node.PROCESS_MODE_INHERIT, "交還後玩家可見、房間解凍")
	check(r.camera.is_current(), "交還後鏡頭回到房間")
	check(is_equal_approx(s[1].hud.modulate.a, 1.0), "HUD 透明度回到 1（%.2f）" % s[1].hud.modulate.a)
	check(not s[1].cutscene_running(), "演出已結束")
	var x0: float = r.player.position.x
	r.player.intent.move_x = 1.0
	await frames(10)
	check(r.player.position.x > x0 + 1.0, "交還後可以操作")
	await teardown(s)


func test_ground_cutscene_skip() -> void:
	var s: Array = await setup("field", ALL_DONE)
	var probe := Probe.new()
	probe.secs = 30.0
	var done := [false]
	var run := func():
		await s[1].play([probe])
		done[0] = true
	run.call()
	await wait_until(func(): return s[1].cutscene_running(), 30)
	s[1].cutscene.skipped = true
	var ok: bool = await wait_until(func(): return done[0], 120)
	check(ok and probe.ended_with != null, "跳過後 run 回來、end_state 有呼叫")
	await teardown(s)


func test_ground_cutscene_blocks_pause_and_hints() -> void:
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.tn.card_min_time = 0.0
	var w = GameWorld.new()
	w.gs = gs
	w.save_path = TEST_SAVE
	w.fade_time = 0.0
	add_child(w)
	w.dev_start("field")
	for f in ALL_DONE:
		gs.set_flag(f)
	gs.set_flag("intro_seen")
	await wait_until(func(): return not w.flow.is_busy() and w.flow.current != null, 60)
	var probe := Probe.new()
	probe.secs = 1.0
	w.runner.play([probe])
	await wait_until(func(): return w.runner.cutscene_running(), 30)
	await frames(5)
	check(not w.hints.visible, "演出中按鍵提示不顯示")
	check(get_tree().get_first_node_in_group(&"cutscene") != null, "演出中在 cutscene 群組（暫停選單據此不開）")
	await wait_until(func(): return not w.runner.cutscene_running(), 180)
	w.queue_free()
	await frames(2)
	gs.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func test_boss_host_unchanged() -> void:
	var src: String = FileAccess.get_file_as_string("res://core/boss/boss_fight.gd")
	check(src.contains("cutscene.host = self"), "Boss 戰把自己交給過場的 host")
	var cs_src: String = FileAccess.get_file_as_string("res://world/cutscene/cutscene.gd")
	check(not cs_src.contains("fight"), "cutscene.gd 不再用 fight")


# ---- Task 2：田地（收工、動物復原、夜晚） ----

func props_of(s: Array, kind: String) -> Array:
	var out: Array = []
	for c in s[0].current.get_children():
		if c.get("kind") == kind and not c.is_queued_for_deletion():
			out.append(c)
	return out


func clear_field(s: Array) -> void:
	var p = s[0].current.player
	for b in props_of(s, "bush"):
		if b.get("decor") == true:
			continue
		p.attack_weapon = Weapons.Weapon.AXE
		b.hurtbox.receive(4, p, &"melee")
		await frames(1)
	for c in props_of(s, "clod"):
		p.attack_weapon = Weapons.Weapon.STICK
		c.hurtbox.receive(4, p, &"melee")
		await frames(1)


## 等過場開始，看完（scale 倍速）或跳過；回傳演出經過的秒數（cs._t，倍速不影響）
func finish(s: Array, skip: bool, scale := 8.0) -> float:
	if not await wait_until(func(): return s[1].cutscene_running(), 120):
		return -1.0
	var cs = s[1].cutscene
	var t0: float = cs._t
	if skip:
		cs.skipped = true
	else:
		Engine.time_scale = scale
	await wait_until(func(): return not cs.running, 3000)
	Engine.time_scale = 1.0
	await frames(3)
	return cs._t - t0


func is_night(s: Array) -> bool:
	return s[0].current.scenery.night


func check_night_field(s: Array, what: String) -> void:
	var r = s[0].current
	check(s[2].has_flag("field_cleared") and s[2].has_flag("night_seen"), what + "：field_cleared、night_seen")
	check(is_night(s), what + "：田地是夜晚")
	var bushes := props_of(s, "bush").filter(func(b): return b.modulate.a > 0.99)
	var clods := props_of(s, "clod").filter(func(c): return c.modulate.a > 0.99)
	check(bushes.size() == 3 and clods.size() == 3, what + "：灌木 3、土塊 3 長回來（%d、%d）" % [bushes.size(), clods.size()])
	check(props_of(s, "bush").all(func(b): return b.position.x > 1000.0), what + "：田左半的演出灌木沒留下")
	var rats := props_of(s, "rat")
	check(rats.size() == 1 and absf(rats[0].position.x - r.data.size.x / 2.0) < 5.0 and rats[0].modulate.a > 0.99, what + "：老鼠在田中央")
	check(r.player.visible and r.process_mode == Node.PROCESS_MODE_INHERIT, what + "：交還操作")


## 交還時玩家接在替身最後的位置（離老鼠 BACK，不會一交還就嚇跑牠）
func check_handover_spot(s: Array, what: String) -> void:
	var r = s[0].current
	check(absf(r.player.position.x - (r.data.size.x / 2.0 - FieldAnimals.BACK)) < 5.0, what + "：玩家接在替身最後的位置（%.0f）" % r.player.position.x)


func test_field_clear_plays_dusk_and_animals() -> void:
	var s: Array = await setup("field", ["tools_obtained"])
	await clear_field(s)
	var t: float = await finish(s, false)
	check(t > 0.0, "清完 6 個就開始過場")
	check_night_field(s, "看完")
	check_handover_spot(s, "看完")
	await teardown(s)


func test_field_clear_skip_same_state() -> void:
	var s: Array = await setup("field", ["tools_obtained"])
	await clear_field(s)
	await finish(s, true)
	check_night_field(s, "跳過")
	check_handover_spot(s, "跳過")
	await teardown(s)


func test_field_reentry_skips_animals() -> void:
	var s: Array = await setup("field", ["tools_obtained", "field_cleared", "night_seen"])
	await frames(10)
	check(not s[1].cutscene_running(), "看過動物復原：不重播")
	check_night_field(s, "再進田地")
	var rat = props_of(s, "rat")[0]
	var p = s[0].current.player
	p.position = Vector2(rat.position.x + 150, 900)
	var x0: float = rat.position.x
	await frames(10)
	check(rat.position.x < x0 - 5.0, "靠近時老鼠會跑")
	await teardown(s)


func test_field_cutscene_lengths() -> void:
	var s: Array = await setup("field", ["tools_obtained", "field_cleared"])
	var animals: float = await finish(s, false, 1.0)
	check_night_field(s, "沒看過動物復原就先播")
	check(animals >= 12.0 and animals <= 28.0, "動物復原 12～28 秒（%.1f）" % animals)
	await teardown(s)
	s = await setup("field", ["tools_obtained"])
	await clear_field(s)
	var both: float = await finish(s, false, 1.0)
	var dusk := both - animals
	check(dusk >= 12.0 and dusk <= 28.0, "收工 12～28 秒（%.1f）" % dusk)
	await teardown(s)


func test_decor_bushes_only_during_dusk() -> void:
	var s: Array = await setup("field", ["tools_obtained"])
	var early := props_of(s, "bush").filter(func(b): return b.position.x < 1000.0)
	check(early.is_empty(), "清田時田左半沒有打不到的演出灌木（最終審查：斧頭旁的灌木砍不動）（%d）" % early.size())
	await clear_field(s)
	await wait_until(func(): return s[1].cutscene_running(), 30)
	await frames(3)
	var decor: Array = []
	for c in s[1].cutscene.get_node("Cast").get_children():
		if c.get("kind") == "bush":
			decor.append(c)
	check(decor.size() == 4 and decor.all(func(b): return b.hurtbox == null), "收工過場才放 4 叢演出灌木、打不到（%d）" % decor.size())
	await finish(s, true)
	await teardown(s)


# ---- Task 3：交換、咬繩、天亮 ----

## 把老鼠趕到左邊牆角（同 test_events）
func corner_rat(s: Array) -> void:
	var rat = props_of(s, "rat")[0]
	var p = s[0].current.player
	p.position = Vector2(rat.position.x + 200, 900)
	p.scripted = true
	p.intent.move_x = -1.0
	await wait_until(func(): return s[1].cutscene_running(), 600)
	p.intent.move_x = 0.0


func check_after_deal(s: Array, what: String) -> void:
	check(s[2].has_flag("rat_caught"), what + "：rat_caught")
	check(props_of(s, "rat").is_empty() and props_of(s, "net").is_empty(), what + "：田裡沒有老鼠與網子")
	check(is_night(s), what + "：田地維持夜晚")
	check(absf(s[0].current.player.position.x - (110.0 + RatDeal.STAND)) < 15.0, what + "：玩家接在替身最後的位置（%.0f）" % s[0].current.player.position.x)


func test_rat_deal_cutscene() -> void:
	for skip in [false, true]:
		var s: Array = await setup("field", ["tools_obtained", "field_cleared", "night_seen"])
		await corner_rat(s)
		var t: float = await finish(s, skip)
		s[0].current.player.intent.move_x = 0.0
		check(t >= 0.0, "網子罩住後開始交換的過場")
		check_after_deal(s, "跳過" if skip else "看完")
		await teardown(s)


func pick_gear(s: Array) -> void:
	var p = s[0].current.player
	p.position = s[0].current.pickups[0].position
	p.velocity = Vector2.ZERO
	await frames(2)
	p.scripted = true
	p.intent.interact_pressed = true
	await frames(2)


func test_gear_rope_then_pickup() -> void:
	for skip in [false, true]:
		var s: Array = await setup("home", ["tools_obtained", "field_cleared", "night_seen", "rat_caught"])
		var gs = s[2]
		var r = s[0].current
		check(r.scenery.night and r.npc_asleep, "抓到老鼠後的祖母家：夜晚、祖母睡著")
		check(await finish(s, skip) >= 0.0, "進門就播咬繩")
		check(gs.has_flag("gear_dropped") and r.pickups.size() == 1, "球具掉在地上可撿（gear_dropped）")
		check(not gs.has_flag("gear_obtained"), "還沒撿就沒有 gear_obtained")
		await pick_gear(s)
		check(await finish(s, skip) >= 0.0, "撿起球具後播天亮")
		check(gs.has_flag("gear_obtained") and not r.scenery.night and not r.npc_asleep, "天亮：gear_obtained、白天、祖母醒著")
		check(gs.weapons_owned.has(Weapons.Weapon.BALLGEAR) and gs.skill_slots[0] == "rat", "拿到球具與老鼠技能")
		await teardown(s)


func test_gear_left_on_floor_survives_reentry() -> void:
	var s: Array = await setup("home", ["tools_obtained", "field_cleared", "night_seen", "rat_caught"])
	await finish(s, true)
	s[0].goto("field", "to_home")
	await wait_until(func(): return s[0].current.data.id == "field" and not s[0].is_busy(), 60)
	s[0].goto("home", "to_field")
	await wait_until(func(): return s[0].current.data.id == "home" and not s[0].is_busy(), 60)
	await frames(10)
	check(not s[1].cutscene_running(), "球具已掉下：再進門不重播咬繩")
	check(s[0].current.pickups.size() == 1, "地上的球具還在、只有一個（%d）" % s[0].current.pickups.size())
	await teardown(s)


func test_asleep_grandmother_no_shop() -> void:
	var s: Array = await setup("home", ["tools_obtained", "field_cleared", "night_seen", "rat_caught"])
	await finish(s, true)
	var r = s[0].current
	r.player.position = Vector2(r.data.npc.pos.x, 900)
	await frames(2)
	check(r.interact_target() != "npc", "祖母睡著：互動不開兌換")
	await pick_gear(s)
	await finish(s, true)
	r.player.position = Vector2(r.data.npc.pos.x, 900)
	await frames(2)
	check(r.interact_target() == "npc", "天亮後可以兌換")
	await teardown(s)


func test_day_after_gear() -> void:
	for room in ["field", "home"]:
		var s: Array = await setup(room, ALL_DONE)
		await frames(10)
		var r = s[0].current
		check(not r.scenery.night and not s[1].cutscene_running(), room + "：拿到球具後白天、沒有過場")
		if room == "home":
			check(not r.npc_asleep, "祖母醒著")
		await teardown(s)


func test_deal_and_rope_lengths() -> void:
	var s: Array = await setup("field", ["tools_obtained", "field_cleared", "night_seen"])
	await corner_rat(s)
	var deal: float = await finish(s, false, 1.0)
	check(deal >= 12.0 and deal <= 28.0, "交換 12～28 秒（%.1f）" % deal)
	await teardown(s)
	s = await setup("home", ["tools_obtained", "field_cleared", "night_seen", "rat_caught"])
	var rope: float = await finish(s, false, 1.0)
	check(rope >= 12.0 and rope <= 28.0, "咬繩 12～28 秒（%.1f）" % rope)
	await pick_gear(s)
	var morning: float = await finish(s, false, 1.0)
	check(morning >= 4.0 and morning <= 10.0, "天亮 4～10 秒（%.1f）" % morning)
	await teardown(s)


# ---- Task 4：錄影用的開發畫面 ----

func test_cutscene_view_accepts_ground_names() -> void:
	var names: Array = preload("res://world/cutscene_view.gd").NAMES
	check(["field", "deal", "rope", "morning"].all(func(n): return names.has(n)), "--cutscene 也接受地面段落 field、deal、rope、morning")


# ---- 試玩修正：進房間就播的過場 ----

## 進房間的同一幀就凍結房間：角色的物理體還沒進物理空間，引擎印 body->get_space() is null（Brian 試玩紀錄）。要先跑過一個物理幀
func test_entry_cutscene_waits_a_physics_frame() -> void:
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.tn.card_min_time = 0.0
	gs.reset_new_game()
	for f in ["intro_seen", "tools_obtained", "field_cleared", "night_seen", "rat_caught"]:
		gs.set_flag(f)
	var flow = RoomFlow.new()
	flow.gs = gs
	flow.tn = gs.tn
	flow.rooms = Index.ROOMS
	flow.fade_time = 0.0
	flow.save_path = TEST_SAVE
	add_child(flow)
	var runner = EventRunner.new()
	runner.flow = flow
	runner.gs = gs
	add_child(runner)
	var at := {}
	flow.room_changed.connect(func(_id): at["mode_on_entry"] = flow.current.process_mode)  # 事件排程先接這個訊號，這時它已經處理完
	flow.start("home")
	var started: bool = await wait_until(func(): return runner.cutscene_running(), 120)
	check(started, "進門播咬繩")
	check(at.get("mode_on_entry") == Node.PROCESS_MODE_INHERIT, "進房間的那一幀還沒凍結房間（%s）" % at.get("mode_on_entry"))
	runner.cutscene.skipped = true
	await wait_until(func(): return not runner.cutscene_running(), 120)
	await teardown([flow, runner, gs])


# ---- MV-SLICE-001d1b：地面過場的動作音效 ----

func _cnt(id: StringName) -> int:
	return Audio.play_count.get(id, 0)


func test_ground_cutscene_sounds() -> void:
	var ids := [&"cs_animals_run", &"cs_bush_regrow", &"cs_lunge", &"abl_tool_chop", &"abl_tool_dig"]
	var before := {}
	for id in ids:
		before[id] = _cnt(id)
	var s: Array = await setup("field", ["tools_obtained"])
	await clear_field(s)
	await finish(s, false)  # 收工
	await finish(s, false)  # 動物復原
	for id in ids:
		check(_cnt(id) > before[id], "收工＋動物復原：%s 有播" % id)
	await teardown(s)
	var deal_ids := [&"cs_net_drop", &"cs_food_place"]
	for id in deal_ids:
		before[id] = _cnt(id)
	s = await setup("field", ["tools_obtained", "field_cleared", "night_seen"])
	await corner_rat(s)
	await finish(s, false)
	s[0].current.player.intent.move_x = 0.0
	for id in deal_ids:
		check(_cnt(id) > before[id], "交換：%s 有播" % id)
	await teardown(s)
	var rope_ids := [&"cs_rat_climb", &"cs_rat_gnaw", &"cs_rope_snap"]
	for id in rope_ids:
		before[id] = _cnt(id)
	s = await setup("home", ["tools_obtained", "field_cleared", "night_seen", "rat_caught"])
	await finish(s, false)
	for id in rope_ids:
		check(_cnt(id) > before[id], "咬繩：%s 有播" % id)
	await teardown(s)


func test_skipped_cutscene_is_quiet() -> void:
	var ids := [&"cs_animals_run", &"cs_bush_regrow", &"cs_lunge", &"abl_tool_chop", &"abl_tool_dig"]
	var before := {}
	for id in ids:
		before[id] = _cnt(id)
	var s: Array = await setup("field", ["tools_obtained"])
	await clear_field(s)
	await finish(s, true)
	await finish(s, true)
	for id in ids:
		check(_cnt(id) == before[id], "跳過：%s 不放" % id)
	await teardown(s)
