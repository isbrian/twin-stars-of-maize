extends "res://tests/base_test.gd"
# MV-SLICE-001a Task 10：開墾田地、入夜抓老鼠、球具掉下、荊棘。

const GameStateScr := preload("res://state/game_state.gd")
const RoomFlow := preload("res://world/room_flow.gd")
const EventRunner := preload("res://events/event_runner.gd")
const Index := preload("res://world/rooms/index.gd")
const TEST_SAVE := "user://test_events_slot.json"


## 地面房間＋事件；文字卡不必等 1.2 秒；回傳 [flow, runner, gs]
func setup(room: String, flags := []) -> Array:
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.tn.card_min_time = 0.0
	gs.reset_new_game()
	gs.set_flag("intro_seen")  # 開場旁白另有測試（test_guidance）
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
	add_child(runner)
	flow.start(room)
	await wait_until(func(): return not flow.is_busy(), 30)
	flow.current.player.scripted = true
	await frames(2)
	return [flow, runner, gs]


func teardown(s: Array) -> void:
	s[1].queue_free()
	s[0].queue_free()
	await frames(2)
	s[2].free()


func player_of(s: Array):
	return s[0].current.player


## 站到某個位置按互動鍵
func interact_at(s: Array, at: Vector2) -> void:
	var p = player_of(s)
	p.position = at
	p.velocity = Vector2.ZERO
	await frames(2)
	p.scripted = true
	p.intent.interact_pressed = true
	await frames(2)


## 有文字卡就按掉，回傳卡上的字
func pass_card(s: Array) -> String:
	await wait_until(func(): return s[1].card.visible, 30)
	var t: String = s[1].card.text
	s[1].card.confirm()
	await frames(2)
	return t


func props_of(s: Array, kind: String) -> Array:
	var out: Array = []
	for c in s[0].current.get_children():
		if c.get("kind") == kind and not c.is_queued_for_deletion() and c.get("decor") != true:  # 演出用、背景的不算（MV-SLICE-001c3a）
			out.append(c)
	return out


## 以指定武器的近戰打一下道具
func melee(s: Array, prop: Node, w: int) -> void:
	var p = player_of(s)
	p.attack_weapon = w
	prop.hurtbox.receive(4, p, &"melee")
	await frames(1)


func clear_field(s: Array) -> void:
	for b in props_of(s, "bush"):
		if b.hurtbox != null:  # 田左半的演出灌木打不到（MV-SLICE-001c3a）
			await melee(s, b, Weapons.Weapon.AXE)
	for c in props_of(s, "clod"):
		await melee(s, c, Weapons.Weapon.STICK)


func test_field_needs_both_tools_and_six_clears() -> void:
	var s: Array = await setup("field")
	var gs = s[2]
	await interact_at(s, Vector2(900, 900))
	check(gs.weapons_owned == [Weapons.Weapon.AXE] and gs.equip == [Weapons.Weapon.AXE, -1], "撿到斧頭給 Hunahpu")
	check(player_of(s).twins[0].weapon_enabled, "角色立刻拿到斧頭")
	check(not gs.has_flag("tools_obtained"), "只有一把還不算")
	await interact_at(s, Vector2(1250, 900))
	check(gs.equip == [Weapons.Weapon.AXE, Weapons.Weapon.STICK] and gs.has_flag("tools_obtained"), "撿到掘棒給 Xbalanque、tools_obtained")
	check(props_of(s, "bush").size() == 3 and props_of(s, "clod").size() == 3, "灌木 3、土塊 3")
	await clear_field(s)
	await wait_until(func(): return s[1].cutscene_running(), 30)
	s[1].cutscene.skipped = true  # 收工過場（MV-SLICE-001c3a）的 end_state 設旗標
	await wait_until(func(): return not s[1].cutscene_running(), 120)
	check(gs.has_flag("field_cleared"), "6 個都清掉 → field_cleared")
	await teardown(s)


func test_bush_only_axe_clod_only_stick() -> void:
	var s: Array = await setup("field", ["tools_obtained"])
	var bush = props_of(s, "bush")[0]
	var clod = props_of(s, "clod")[0]
	await melee(s, bush, Weapons.Weapon.STICK)
	await melee(s, clod, Weapons.Weapon.AXE)
	check(props_of(s, "bush").size() == 3 and props_of(s, "clod").size() == 3, "灌木不吃掘棒、土塊不吃斧頭")
	await melee(s, bush, Weapons.Weapon.AXE)
	await melee(s, clod, Weapons.Weapon.STICK)
	check(props_of(s, "bush").size() == 2 and props_of(s, "clod").size() == 2, "灌木吃斧頭、土塊吃掘棒")
	await teardown(s)


func test_night_cutscene_starts_after_clear() -> void:
	var s: Array = await setup("field", ["tools_obtained"])
	await clear_field(s)
	var started: bool = await wait_until(func(): return s[1].cutscene_running(), 30)
	check(started, "清完立刻開始收工的過場（MV-SLICE-001c3a；不再等 3 秒跳卡）")
	s[1].cutscene.skipped = true
	await wait_until(func(): return not s[1].cutscene_running(), 120)
	check(s[2].has_flag("field_cleared") and s[0].current.scenery.night, "跳過後 field_cleared、入夜")
	await teardown(s)


func test_rat_flees_and_net_at_wall_sets_flag() -> void:
	var s: Array = await setup("field", ["tools_obtained", "field_cleared", "night_seen"])
	check(s[0].current.scenery.night, "進田地時已清完就是夜晚（MV-SLICE-001c3a：看過動物復原，不重播）")
	var rats := props_of(s, "rat")
	check(rats.size() == 1, "田裡有老鼠")
	var rat = rats[0]
	var p = player_of(s)
	p.position = Vector2(rat.position.x + 200, 900)
	p.scripted = true
	p.intent.move_x = -1.0
	var caught: bool = await wait_until(func(): return s[1].cutscene_running(), 400)
	check(caught and rat.position.x < 200, "老鼠往反方向跑、被逼到牆角後網子罩住，老鼠在 %.0f" % rat.position.x)
	s[1].cutscene.skipped = true  # 交換的過場（MV-SLICE-001c3a）
	await wait_until(func(): return not s[1].cutscene_running(), 120)
	check(s[2].has_flag("rat_caught"), "交換的過場、rat_caught")
	await teardown(s)


func test_gear_event_only_after_rat() -> void:
	var s: Array = await setup("home", ["tools_obtained", "field_cleared"])
	await frames(10)
	check(not s[1].card.visible and not s[1].cutscene_running(), "還沒抓到老鼠時祖母家沒有事件")
	await teardown(s)
	s = await setup("home", ["tools_obtained", "field_cleared", "rat_caught"])
	var gs = s[2]
	gs.give_weapon(Weapons.Weapon.AXE)
	gs.give_weapon(Weapons.Weapon.STICK)
	check(await wait_until(func(): return s[1].cutscene_running(), 30), "咬繩的過場（MV-SLICE-001c3a；祕密已在田裡說了）")
	s[1].cutscene.skipped = true
	var gear = await wait_until(func(): return s[0].current.pickups.size() == 1, 120)
	check(gear, "球具掉到地上變成拾取點")
	var at: Vector2 = s[0].current.pickups[0].position
	await interact_at(s, at)
	check(gs.weapons_owned.has(Weapons.Weapon.BALLGEAR) and gs.skill_slots[0] == "rat", "拿到球具與老鼠技能")
	await wait_until(func(): return not s[1].cutscene_running(), 120)  # 咬繩的黑邊收完（球具一交還就能撿，MV-SLICE-001c3b）
	await wait_until(func(): return s[1].cutscene_running(), 30)
	s[1].cutscene.skipped = true
	await wait_until(func(): return not s[1].cutscene_running(), 120)
	check(gs.has_flag("gear_obtained"), "天亮的過場、gear_obtained")
	await teardown(s)


func test_thorns_block_until_gear() -> void:
	var s: Array = await setup("yard")
	check(s[0].current.gates.size() == 1, "拿到球具前荊棘擋路")
	await teardown(s)
	s = await setup("yard", ["gear_obtained"])
	check(s[0].current.gates.is_empty(), "拿到球具後荊棘不在")
	await teardown(s)


func test_death_mid_event_restarts_it() -> void:
	var s: Array = await setup("field", ["tools_obtained", "field_cleared", "night_seen"])
	var p = player_of(s)
	p.health.hp = 1
	p.hurtbox.receive(1, null, &"enemy")
	var home: bool = await wait_until(func(): return s[0].current.data.id == "home" and not s[0].is_busy(), 120)
	check(home and not s[2].has_flag("rat_caught"), "抓老鼠途中死亡：回祖母家、rat_caught 未設")
	s[0].goto("field", "to_home")
	await wait_until(func(): return s[0].current.data.id == "field" and not s[0].is_busy(), 60)
	await frames(5)
	var rats := props_of(s, "rat")
	check(rats.size() == 1 and s[0].current.scenery.night and not s[2].has_flag("rat_caught"), "再進田地事件重新開始（夜裡、老鼠在）")
	await teardown(s)
