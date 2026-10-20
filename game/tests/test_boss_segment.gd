extends "res://tests/base_test.gd"
# MV-SLICE-001a Task 11：Boss 段落接上 GameState 與換房流程。

const GameStateScr := preload("res://state/game_state.gd")
const RoomFlow := preload("res://world/room_flow.gd")
const EventRunner := preload("res://events/event_runner.gd")
const Index := preload("res://world/rooms/index.gd")
const TEST_SAVE := "user://test_boss_segment_slot.json"
const PROTO_TUNING := "../prototypes/core/tuning/combat_tuning.gd"  # 相對於 game/


## 拿到三樣武器、裝備 [掘棒, 球具] 的 GameState
func make_gs() -> Object:
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.tn.card_min_time = 0.0
	gs.reset_new_game()
	for w in [Weapons.Weapon.AXE, Weapons.Weapon.STICK, Weapons.Weapon.BALLGEAR]:
		gs.give_weapon(w)
	gs.equip = [Weapons.Weapon.STICK, Weapons.Weapon.BALLGEAR]
	for f in ["tools_obtained", "field_cleared", "rat_caught", "gear_obtained"]:
		gs.set_flag(f)
	return gs


func make_gs_fight(gs) -> Node:
	var f = BossFight.new()
	f.tn = gs.tn
	f.gs = gs
	f.save_path = TEST_SAVE
	f.tester = "selftest"
	f.log_dir = TEST_LOG_DIR
	f.player_scripted = true
	add_child(f)
	await frames(3)
	f.card.min_time = 0.0
	f.boss.cycle_enabled = false
	return f


## 房間流程＋事件；回傳 [flow, runner, gs]
func setup_flow(gs) -> Array:
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
	return [flow, runner, gs]


func go(s: Array, room: String, door := "") -> bool:
	if door == "":
		s[0].start(room)
	else:
		s[0].goto(room, door)
	return await wait_until(func(): return not s[0].is_busy() and s[0].current_id == ("boss" if room.ends_with("_camp") else room), 60)


func teardown(s: Array) -> void:
	s[1].queue_free()
	s[0].queue_free()
	await frames(2)
	s[2].free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func test_boss_uses_equipped_weapons() -> void:
	var gs = make_gs()
	var f = await make_gs_fight(gs)
	var p = f.player
	check(p.twins[0].weapon == Weapons.Weapon.STICK and p.twins[0].weapon_enabled, "第 1 段：胡納普拿掘棒")
	check(p.twins[1].weapon == Weapons.Weapon.BALLGEAR and p.twins[1].weapon_enabled, "希巴拉克拿球具")
	check(not p.twins[0].arm_broken, "第 1 段：胡納普沒有斷臂")
	f._retry(1)
	check(p.twins[0].weapon == Weapons.Weapon.STICK and p.twins[1].weapon == Weapons.Weapon.BALLGEAR, "死亡重試後仍是 GameState 的裝備，不是原型預設")
	f.start_at(2)
	await frames(2)
	check(not p.twins[0].weapon_enabled and p.twins[1].weapon == Weapons.Weapon.BALLGEAR, "第 2 段斷臂：胡納普沒有武器（原型規則疊在裝備上）")
	check(p.twins[0].arm_broken and not p.twins[1].arm_broken, "第 2 段：只有胡納普斷臂（骨架隱藏近側手臂，MV-SLICE-001b2a）")
	f.awakened = true
	f._apply_loadout()
	check(not p.twins[0].arm_broken and p.twins[0].weapon_enabled, "覺醒：手臂接回、拿回武器")
	await free_fight(f)
	gs.free()


func test_boss_rest_saves_with_id() -> void:
	var gs = make_gs()
	var f = await make_gs_fight(gs)
	var p = f.player
	p.position = Nance.REST
	p.health.hp = 1
	await frames(2)
	p.intent.interact_pressed = true
	await frames(3)
	check(gs.last_rest == "nance_camp", "在 nance 篝火休息：last_rest＝nance_camp（是 %s）" % gs.last_rest)
	check(FileAccess.file_exists(TEST_SAVE), "休息時存檔")
	check(p.health.hp == gs.tn.max_hp, "休息回滿血")
	await free_fight(f)
	gs.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func test_boss_left_exit_only_before_arena() -> void:
	var s: Array = setup_flow(make_gs())
	await go(s, "forest_6")
	var entered: bool = await go(s, "boss", "to_forest_6")
	check(entered, "從森林 6 的右門進 Boss 段落")
	var f = s[0].current
	f.player.scripted = true
	f.player.position = Vector2(-60, Nance.GROUND_Y)
	var back: bool = await wait_until(func(): return s[0].current_id == "forest_6" and not s[0].is_busy(), 60)
	check(back, "開打前走到最左邊：回森林 6")
	await go(s, "boss", "to_forest_6")
	f = s[0].current
	f.player.scripted = true
	f.start_at(1)
	await frames(2)
	f.player.position = Vector2(-60, Nance.GROUND_Y)
	await frames(10)
	check(s[0].current_id == "boss", "開打後不能從左邊離開")
	await teardown(s)


func test_continue_at_palace_camp() -> void:
	var gs = make_gs()
	gs.last_rest = "palace_camp"
	var s: Array = setup_flow(gs)
	var ok: bool = await go(s, "palace_camp")
	check(ok, "從宮殿篝火繼續：進 Boss 段落")
	var f = s[0].current
	check(f.phase == 2 and f.player.position.distance_to(Palace.REST) < 5.0, "第 2 段、角色在宮殿篝火（phase %d）" % f.phase)
	await teardown(s)


## 在 Boss 段落休息過、又走回森林死掉 → 回 Boss 段落的篝火（Review Focus：休息點不在房間表裡）
func test_death_outside_after_camp_rest_returns_to_camp() -> void:
	var gs = make_gs()
	gs.last_rest = "nance_camp"
	var s: Array = setup_flow(gs)
	await go(s, "forest_6")
	var p = s[0].current.player
	p.health.hp = 1
	p.hurtbox.receive(1, null, &"enemy")
	var back: bool = await wait_until(func(): return s[0].current_id == "boss" and not s[0].is_busy(), 120)
	check(back and s[0].current.phase == 1, "回 nance 樹前的篝火")
	await teardown(s)


func test_awakening_sets_gamestate() -> void:
	var gs = make_gs()
	var f = await make_gs_fight(gs)
	f.start_at(3)
	await frames(2)
	f._on_setup(3)
	await frames(2)
	for i in 4:  # 遊戲模式：死亡與覺醒是演出（MV-SLICE-001c2b、c2c），覺醒段要再跳過一次
		f.cutscene.skipped = true
		await frames(2)
	await wait_until(func(): return not f.cutscene.running, 120)
	await frames(2)
	check(gs.awakened and f.player.abilities_enabled, "覺醒寫進 GameState")
	await free_fight(f)
	gs.free()


func test_boss_finish_goes_to_exit_card() -> void:
	var s: Array = setup_flow(make_gs())
	var ended := [false]
	s[0].ended.connect(func(): ended[0] = true)
	await go(s, "boss", "to_forest_6")
	var f = s[0].current
	f.player.scripted = true
	f.start_at(4)
	f._finish()
	await frames(2)
	f.cutscene.skipped = true  # 遊戲模式：結尾是演出（MV-SLICE-001c2c），跳過
	var at_exit: bool = await wait_until(func(): return s[0].current_id == "exit" and not s[0].is_busy(), 60)
	check(at_exit, "打完走到出口 → 結尾")
	var shown: bool = await wait_until(func(): return s[0].current.card.visible, 30)
	check(shown and s[0].current.card.text.contains("垂直切片到此結束，謝謝試玩。"), "結束畫面")
	s[0].current.card.confirm()
	# MV-SLICE-001d2a：結尾卡之後是自動捲動的製作說明（含 AI 揭露），捲完才回主選單
	check(await wait_until(func(): return s[0].current.credits != null, 30), "接著是片尾的製作說明")
	s[0].current.credits.scroll = s[0].current.credits.content_height()
	check(await wait_until(func(): return ended[0], 300), "片尾捲完 → 回主選單（ended）")
	await teardown(s)


func test_boss_numbers_match_prototype() -> void:
	var path := ProjectSettings.globalize_path("res://").path_join(PROTO_TUNING).simplify_path()
	var proto_scr = load(path)
	check(proto_scr != null, "讀得到原型的 combat_tuning.gd")
	if proto_scr == null:
		return
	var proto = proto_scr.new()
	var mine = fresh_tuning()
	var in_boss := false
	var n := 0
	var diffs: Array = []
	for prop in mine.get_property_list():
		if prop.usage & PROPERTY_USAGE_GROUP:
			in_boss = prop.name == "Boss"
			continue
		if in_boss and prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			n += 1
			if mine.get(prop.name) != proto.get(prop.name):
				diffs.append(prop.name)
	check(n > 10 and diffs.is_empty(), "Boss 群組 %d 個欄位與原型一致（不一致：%s）" % [n, diffs])


# ---- MV-SLICE-001c4b：覺醒後的回程與提示 ----

## 已覺醒時從森林 6 的右門進 Boss 段落；回傳 [flow, runner, gs]
func enter_from_forest(awake: bool) -> Array:
	var gs = make_gs()
	gs.awakened = awake
	var s: Array = setup_flow(gs)
	await go(s, "forest_6")
	await go(s, "boss", "to_forest_6")
	s[0].current.player.scripted = true
	return s


func test_awakened_forest_entry_at_path_start() -> void:
	var s: Array = await enter_from_forest(true)
	var f = s[0].current
	check(f.player.position.distance_to(Palace.PATH_START) <= 2.0, "已覺醒：出生在小路起點（%s）" % f.player.position)
	check(f.awakened and f.stage == BossFight.Stage.APPROACH and f.player.abilities_enabled, "已覺醒的狀態、走路階段、能力開著")
	await teardown(s)


func test_unawakened_forest_entry_unchanged() -> void:
	var s: Array = await enter_from_forest(false)
	var f = s[0].current
	check(f.player.position.distance_to(Nance.REST) <= 2.0 and not f.awakened, "未覺醒：照舊在 nance 篝火（%s）" % f.player.position)
	await teardown(s)


func test_forest_entry_does_not_bounce_back() -> void:
	var s: Array = await enter_from_forest(true)
	await frames(30)
	check(s[0].current_id == "boss", "進來後站著不動：不會被送回森林")
	await teardown(s)


func test_awakened_path_left_exit() -> void:
	var s: Array = await enter_from_forest(true)
	s[0].current.player.position = Vector2(7850, Palace.GROUND_Y)
	var back: bool = await wait_until(func(): return s[0].current_id == "forest_6" and not s[0].is_busy(), 60)
	var spawn: Vector2 = Index.ROOMS["forest_6"].data().doors.filter(func(d): return d.id == "to_boss")[0].spawn
	check(back and s[0].current.player.position.distance_to(spawn) <= 2.0, "小路最左端 → 森林 6 的右門前")
	await teardown(s)
	var gs = make_gs()
	gs.awakened = true
	gs.last_rest = "palace_camp"
	s = setup_flow(gs)
	await go(s, "palace_camp")
	s[0].current.player.scripted = true
	s[0].current.player.position = Vector2(7850, Palace.GROUND_Y)
	back = await wait_until(func(): return s[0].current_id == "forest_6" and not s[0].is_busy(), 60)
	check(back, "讀檔回宮殿篝火後走到小路最左端：也回森林 6")
	await teardown(s)


func test_forest_entry_palace_is_exit() -> void:
	var s: Array = await enter_from_forest(true)
	var f = s[0].current
	f.player.position = Vector2(Palace.ENTRY_X + 50.0, Palace.GROUND_Y)
	var exit: bool = await wait_until(func(): return f.stage == BossFight.Stage.EXIT, 30)
	check(exit and not f.palace.barrier.is_broken and f.stage != BossFight.Stage.FIGHT, "走進宮殿：直接是出口、木障立著、不開打（stage %d）" % f.stage)
	await teardown(s)


func test_forest_hint_once() -> void:
	var s: Array = await enter_from_forest(true)
	var f = s[0].current
	await frames(2)
	check(f.hud.notice == BossFight.FOREST_HINT and s[2].has_flag("hint_forest_return"), "已覺醒進小路：顯示森林提示、記旗標（%s）" % f.hud.notice)
	await frames(int(4.2 * 60))
	check(f.hud.notice != BossFight.FOREST_HINT, "約 4 秒後消失")
	await go(s, "forest_6")
	await go(s, "boss", "to_forest_6")
	await frames(2)
	check(s[0].current.hud.notice != BossFight.FOREST_HINT, "第二次進來不再出現")
	await teardown(s)
	s = await enter_from_forest(false)
	s[0].current.player.position = Vector2(8000, Palace.GROUND_Y)
	await frames(5)
	check(s[0].current.hud.notice != BossFight.FOREST_HINT and not s[2].has_flag("hint_forest_return"), "未覺醒：不出現")
	await teardown(s)


func test_forest_hint_yields_to_exit_hint() -> void:
	var gs = make_gs()
	gs.awakened = true
	var f = await make_gs_fight(gs)
	f.start_at(4)
	await frames(2)
	f.player.position = Vector2(13000, Palace.GROUND_Y)
	await frames(2)
	check(f.hud.notice == BossFight.FOREST_HINT, "出口階段走回小路：森林提示（%s）" % f.hud.notice)
	await frames(int(4.2 * 60))
	check(f.hud.notice == BossFight.EXIT_HINT_BARRIER, "4 秒後換回出口提示（%s）" % f.hud.notice)
	await free_fight(f)
	gs.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


## 最終審查：換房途中踩到出口線（goto 被忽略）之後，換房結束仍要能回森林
func test_awakened_path_exit_retries_after_busy() -> void:
	var s: Array = await enter_from_forest(true)
	s[0]._busy = true
	s[0].current.player.position = Vector2(7850, Palace.GROUND_Y)
	await frames(10)
	s[0]._busy = false
	var back: bool = await wait_until(func(): return s[0].current_id == "forest_6" and not s[0].is_busy(), 60)
	check(back, "換房結束後仍回森林 6")
	await teardown(s)
