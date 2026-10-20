extends "res://tests/base_test.gd"
# MV-SLICE-001c2a：過場機制（world/cutscene/）與 nance 樹的三段演出。
# 只有遊戲模式（有 GameState）播演出；原型模式照舊文字卡與灰盒開場。

const GameStateScr := preload("res://state/game_state.gd")
const PauseMenu := preload("res://ui/pause_menu.gd")
const Scenery := preload("res://world/scenery.gd")
const CsPath := "res://world/cutscene/cutscene.gd"
const TEST_SAVE := "user://test_cutscene_slot.json"
const Save := preload("res://state/save.gd")


## 只 await 一段時間的假演出：記錄 end_state 被呼叫幾次
class Dummy extends RefCounted:
	var secs := 0.5
	var lines: Array = []
	var ended := 0

	func play(cs) -> void:
		for l in lines:
			await cs.narrate(l)
		await cs.wait(secs)

	func end_state(_fight) -> void:
		ended += 1


func cs_script():
	if not ResourceLoader.exists(CsPath):
		check(false, "缺 %s" % CsPath)
		return null
	return load(CsPath)


## 有 GameState 的 Boss 戰（同 test_fx.fx_fight）：回傳 [f, gs]
func cs_fight(scripted := true) -> Array:
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.tn.card_min_time = 0.0
	gs.reset_new_game()
	var f = BossFight.new()
	f.tn = gs.tn
	f.gs = gs
	f.save_path = TEST_SAVE
	f.tester = "selftest"
	f.log_dir = TEST_LOG_DIR
	f.player_scripted = scripted
	add_child(f)
	await frames(3)
	f.card.min_time = 0.0
	f.boss.cycle_enabled = false
	return [f, gs]


func end_cs_fight(s: Array) -> void:
	Engine.time_scale = 1.0
	await free_fight(s[0])
	s[1].free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


## 沒有 Boss 戰的執行器（只測 UI 與計時）
func ui_cs() -> Node:
	var scr = cs_script()
	if scr == null:
		return null
	var cs = scr.new()
	add_child(cs)
	await frames(1)
	return cs


func secs(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0 / Engine.time_scale)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func tap(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func plain(cs) -> String:
	return cs.subtitle.get_parsed_text()


# ---- Task 1：執行器 ----

func test_line_time() -> void:
	var scr = cs_script()
	if scr == null:
		return
	check(is_equal_approx(scr.line_time("好。"), 1.5), "短句至少 1.5 秒")
	check(is_equal_approx(scr.line_time("一二三四五六七八九十一二三四五六七八九十"), 2.4), "20 字＝2.4 秒")


func test_bars_and_hud_during_run() -> void:
	if cs_script() == null:
		return
	var s: Array = await cs_fight()
	var f = s[0]
	var cs = f.get("cutscene")
	check(cs != null, "遊戲模式：Boss 戰有 cutscene 執行器")
	if cs != null:
		var d := Dummy.new()
		d.secs = 1.0
		cs.run([d])
		await secs(0.6)
		var h: float = get_viewport().get_visible_rect().size.y * cs.BAR_FRAC
		check(absf(cs.bar_height() - h) <= 2.0, "黑邊高 ≈ %.0f（%.0f）" % [h, cs.bar_height()])
		check(f.hud.modulate.a <= 0.01, "HUD 隱藏")
		check(f.world.process_mode == Node.PROCESS_MODE_DISABLED, "戰場凍結")
		check(not f.player.can_process() and not f.boss.can_process(), "角色與 Boss 不處理")
		check(f.scenery.can_process(), "場景照常處理（視差、NPC）")
		check(cs.is_in_group(cs.GROUP) and cs.running, "演出中在群組、running")
		await secs(1.4)
		check(not cs.running and not cs.is_in_group(cs.GROUP), "結束後 running false、離開群組")
		check(f.world.process_mode == Node.PROCESS_MODE_INHERIT and f.hud.modulate.a >= 0.99, "戰場與 HUD 還原")
		check(cs.bar_height() <= 0.5, "黑邊收起")
		check(d.ended == 1, "end_state 呼叫一次")
	await end_cs_fight(s)


func test_say_formats_speaker() -> void:
	var cs = await ui_cs()
	if cs == null:
		return
	cs.say("奇瑪瑪特", "你帶了什麼回來？")
	await frames(2)
	check(plain(cs) == "奇瑪瑪特：你帶了什麼回來？", "台詞前面有說話者（%s）" % plain(cs))
	cs.skipped = true
	await frames(2)
	cs.skipped = false
	cs.narrate("七金剛鸚鵡大叫一聲。")
	await frames(2)
	check(plain(cs) == "七金剛鸚鵡大叫一聲。", "旁白沒有名字（%s）" % plain(cs))
	cs.skipped = true
	await frames(2)
	cs.queue_free()


func test_attack_advances_one_line_at_a_time() -> void:
	var cs = await ui_cs()
	if cs == null:
		return
	var d := Dummy.new()
	d.lines = ["第一句。", "第二句。", "第三句。"]
	d.secs = 0.0
	cs.run([d])
	await secs(0.5)
	check(plain(cs) == "第一句。", "第一句（%s）" % plain(cs))
	await tap(&"attack")
	check(plain(cs) == "第二句。", "按一下換到第二句（%s）" % plain(cs))
	await tap(&"attack")
	check(plain(cs) == "第二句。", "0.3 秒內再按不換（%s）" % plain(cs))
	cs.skipped = true
	await secs(0.6)
	cs.queue_free()


func test_skip_by_holding_pause() -> void:
	var cs = await ui_cs()
	if cs == null:
		return
	var d := Dummy.new()
	d.secs = 5.0
	cs.run([d])
	await secs(0.2)
	Input.action_press(&"pause")
	await secs(0.5)
	Input.action_release(&"pause")
	await secs(0.2)
	check(not cs.skipped and cs.running, "按住 0.5 秒放開：不跳過")
	Input.action_press(&"pause")
	await secs(1.1)
	check(cs.skipped, "按住 1 秒：跳過")
	Input.action_release(&"pause")
	await secs(0.6)
	check(not cs.running and d.ended == 1, "跳過後結束、end_state 呼叫一次")
	cs.queue_free()


func test_pause_hold_does_not_open_menu_after() -> void:
	var cs = await ui_cs()
	if cs == null:
		return
	var menu = PauseMenu.new()
	add_child(menu)
	await frames(1)
	var d := Dummy.new()
	d.secs = 5.0
	cs.run([d])
	await secs(0.2)
	Input.action_press(&"pause")
	await secs(1.1)
	check(cs.skipped and not menu.visible, "演出中按住暫停鍵：選單不開")
	await secs(0.6)
	check(not cs.running, "演出結束")
	Input.action_release(&"pause")
	await frames(3)
	check(not menu.visible and not get_tree().paused, "結束後放開：選單沒開")
	menu.queue_free()
	cs.queue_free()
	get_tree().paused = false


## 最後一段的 end_state 那一幀按下跳躍（＝交還操作那一幀按著鍵）
class JumpAtEnd extends RefCounted:
	func play(cs) -> void:
		await cs.wait(0.2)

	func end_state(_fight) -> void:
		Input.action_press(&"jump")


## 最終審查：新遊戲沒有武器，按攻擊本來就不會出手 → 改用跳躍
func test_input_not_leaking_after_cutscene() -> void:
	if cs_script() == null:
		return
	var s: Array = await cs_fight(false)
	var f = s[0]
	await frames(10)  # 站穩
	f.cutscene.run([JumpAtEnd.new()])
	await wait_cs(f.cutscene)
	var jumped := false
	for i in 6:
		await frames(1)
		jumped = jumped or f.player.velocity.y < -1.0
	Input.action_release(&"jump")
	check(not jumped, "交還操作那一幀按著跳躍：不會跳起來（vy %.0f）" % f.player.velocity.y)
	await end_cs_fight(s)


# ---- Task 2：替身、手臂道具、剪影 ----

func cs_file(n: String):
	var path := "res://world/cutscene/%s.gd" % n
	if not ResourceLoader.exists(path):
		check(false, "缺 %s" % path)
		return null
	return load(path)


## 開剪影的假演出（不結束，等外面跳過）
class SilScene extends RefCounted:
	func play(cs) -> void:
		cs.silhouette(true)
		await cs.wait(10.0)

	func end_state(_fight) -> void:
		pass


func test_actor_plays_and_holds() -> void:
	var A = cs_file("actor")
	if A == null:
		return
	var a = A.make("hunahpu")
	add_child(a)
	a.play("hurt")
	var L: float = a.anim_length("hurt")
	await secs(L + 0.2)
	check(is_equal_approx(a.pose_time(), L - 0.0001), "單次動作停在最後一格（%.3f vs %.3f）" % [a.pose_time(), L])
	a.play("run")
	var R: float = a.anim_length("run")
	await secs(R * 1.5)
	check(a.pose_time() < R, "循環動作繞回（%.3f < %.3f）" % [a.pose_time(), R])
	a.queue_free()


func test_arm_prop_only_arm() -> void:
	var P = cs_file("arm_prop")
	if P == null:
		return
	var p = P.make()
	add_child(p)
	await frames(1)
	var shown: Array = p.find_children("*", "Sprite2D", true, false).filter(func(s): return s.is_visible_in_tree())
	check(shown.size() >= 2, "至少 2 件（%d）" % shown.size())
	check(shown.all(func(s): return s.get_parent().name == "NearArm"), "只顯示近側手臂的分件")
	p.queue_free()


func test_silhouette_on_off() -> void:
	if cs_file("actor") == null:
		return
	var s: Array = await cs_fight()
	var f = s[0]
	var cs = f.cutscene
	var sc = f.scenery
	var a = cs.spawn("sevenmacaw", Nance.PERCH)
	cs.silhouette(true)
	await frames(1)
	check(f.world.modulate == Color.BLACK, "world 塗黑")
	check(is_equal_approx(sc.layer_alpha("far"), 0.35) and is_equal_approx(sc.layer_alpha("mid"), 0.6) and is_equal_approx(sc.layer_alpha("near"), 0.85), "遠景 0.35、背景 0.6、近景 0.85（%.2f %.2f %.2f）" % [sc.layer_alpha("far"), sc.layer_alpha("mid"), sc.layer_alpha("near")])
	check(a.modulate == Color.BLACK and cs.backdrop_visible(), "替身純黑、漸層底可見")
	cs.silhouette(false)
	await frames(1)
	check(f.world.modulate == Color.WHITE and is_equal_approx(sc.layer_alpha("mid"), 1.0) and a.modulate == Color.WHITE and not cs.backdrop_visible(), "關閉後還原")
	a.queue_free()
	await end_cs_fight(s)


func test_skip_restores_silhouette() -> void:
	if cs_file("actor") == null:
		return
	var s: Array = await cs_fight()
	var f = s[0]
	var cs = f.cutscene
	cs.run([SilScene.new()])
	await secs(0.5)
	check(f.world.modulate == Color.BLACK, "演出中剪影開著")
	cs.skipped = true
	await secs(0.8)
	check(not cs.running, "跳過後結束")
	check(f.world.modulate == Color.WHITE and is_equal_approx(f.scenery.layer_alpha("far"), 1.0) and not cs.backdrop_visible(), "跳過後剪影還原")
	await end_cs_fight(s)


func test_macaw_actor_light() -> void:
	var A = cs_file("actor")
	if A == null:
		return
	var a = A.make("sevenmacaw")
	add_child(a)
	var l = a.add_light()
	l.state = Light.State.GLOW
	await frames(2)
	check(l.get_node_or_null("LightFx") != null, "替身的光源有 LightFx")
	var want: Vector2 = a.rig.transform * a.rig.point("jaw")
	check(l.position.distance_to(want) <= 1.0, "光源在下顎（%s vs %s）" % [l.position, want])
	a.queue_free()


# ---- Task 3：新動作 ----

func anims_of(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)).anims


func test_cutscene_anims_present() -> void:
	var t := anims_of("res://rig/twin_anims.json")
	for n in ["crouch", "walk"]:
		check(t.has(n) and t[n].get("loop", false), "雙胞胎 %s 是循環動作" % n)
	for n in ["lunge", "knocked_down"]:
		check(t.has(n) and not t[n].get("loop", false), "雙胞胎 %s 是單次動作" % n)
	var m := anims_of("res://rig/sevenmacaw_anims.json")
	for n in ["yank", "hang"]:
		check(m.has(n) and not m[n].get("loop", false), "Seven Macaw %s 是單次動作" % n)


# ---- Task 4：開場 ----

## 角色越過 nance 入口（第一次進場）
func enter_nance(f) -> void:
	f.player.position = Vector2(Nance.ENTRY_X + 60.0, Nance.GROUND_Y)
	await frames(2)


## 等演出結束（time_scale 加速）
func wait_cs(cs, max_secs := 60.0) -> void:
	var end := Time.get_ticks_msec() + int(max_secs * 1000.0)
	while cs.running and Time.get_ticks_msec() < end:
		await get_tree().process_frame


func hold_skip(cs) -> void:
	Input.action_press(&"pause")
	await secs(1.1)
	Input.action_release(&"pause")
	await wait_cs(cs)


func opening_state(f) -> Dictionary:
	return {"player": f.player.position.round(), "twin": f.player.twin_index, "boss": f.boss.position.round(), "boss_state": f.boss.state,
		"intro_seen": f.intro_seen, "stage": f.stage, "player_visible": f.player.visible, "boss_visible": f.boss.visible}


func test_opening_plays_first_time_only() -> void:
	if cs_file("opening") == null:
		return
	var s: Array = await cs_fight()
	var f = s[0]
	await enter_nance(f)
	check(f.cutscene.running, "第一次進 nance：播開場")
	check(f.boss.state != Macaw.State.INTRO, "遊戲模式不用 play_intro")
	Engine.time_scale = 8.0
	await wait_cs(f.cutscene)
	Engine.time_scale = 1.0
	await frames(2)
	check(f.intro_seen and f.stage == BossFight.Stage.FIGHT, "開場後 intro_seen、開打（%s）" % f.stage)
	f._retry(1)
	await enter_nance(f)
	check(not f.cutscene.running and f.stage == BossFight.Stage.FIGHT, "重試再進場：不播開場")
	await end_cs_fight(s)


func test_opening_watch_equals_skip() -> void:
	if cs_file("opening") == null:
		return
	var a: Array = await cs_fight()
	await enter_nance(a[0])
	Engine.time_scale = 8.0
	await wait_cs(a[0].cutscene)
	Engine.time_scale = 1.0
	await frames(2)
	var watched := opening_state(a[0])
	await end_cs_fight(a)
	var b: Array = await cs_fight()
	await enter_nance(b[0])
	await hold_skip(b[0].cutscene)
	await frames(2)
	var skipped := opening_state(b[0])
	check(watched == skipped, "看完＝跳過（%s vs %s）" % [watched, skipped])
	check(watched.player_visible and watched.boss_visible, "結束後角色與 Boss 都看得到")
	await end_cs_fight(b)


func test_proto_keeps_play_intro() -> void:
	var f = BossFight.new()
	f.tn = fresh_tuning()
	f.log_dir = TEST_LOG_DIR
	f.player_scripted = true
	add_child(f)
	await frames(3)
	check(f.get("cutscene") == null, "原型模式沒有過場執行器")
	await enter_nance(f)
	check(f.boss.state == Macaw.State.INTRO, "原型模式照舊 play_intro")
	await free_fight(f)


# ---- Task 5：斷臂與轉場、宮殿掛著手臂 ----

## 第 1 段開打後直接設局成功（不 await：演出在背景跑）
func start_arm(f) -> void:
	f.start_at(1)
	await frames(2)
	f._on_setup(1)
	await frames(2)


func arm_state(f) -> Dictionary:
	var arm = f.scenery.get("arm_prop")
	return {"player": f.player.position.round(), "twin": f.player.twin_index, "boss": f.boss.position.round(), "boss_state": f.boss.state,
		"phase": f.phase, "lights": f.lights_removed, "arm_broken": f.player.twins[0].arm_broken, "following": f.couple_following,
		"couple_x": f.couple_x, "stage": f.stage, "hung": arm != null and arm.visible, "player_visible": f.player.visible, "boss_visible": f.boss.visible}


func test_arm_and_couple_replace_cards() -> void:
	if cs_file("arm") == null or cs_file("couple") == null:
		return
	var s: Array = await cs_fight()
	var f = s[0]
	await start_arm(f)
	check(f.cutscene.running, "設局成功：播斷臂演出")
	var card_seen := false
	Engine.time_scale = 8.0
	while f.cutscene.running:
		card_seen = card_seen or f.card.visible
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await frames(2)
	check(not card_seen, "遊戲模式不出現 arm、couple 文字卡")
	check(f.phase == 2 and f.player.twins[0].arm_broken and f.couple_following and f.stage == BossFight.Stage.APPROACH, "第 2 段、斷臂、老人跟隨、走路階段")
	check(f.player.position == Palace.PATH_START, "在小路起點（%s）" % f.player.position)
	await end_cs_fight(s)


func test_arm_watch_equals_skip() -> void:
	if cs_file("arm") == null:
		return
	var a: Array = await cs_fight()
	await start_arm(a[0])
	Engine.time_scale = 8.0
	await wait_cs(a[0].cutscene)
	Engine.time_scale = 1.0
	await frames(2)
	var watched := arm_state(a[0])
	await end_cs_fight(a)
	var b: Array = await cs_fight()
	await start_arm(b[0])
	await hold_skip(b[0].cutscene)
	await frames(2)
	var skipped := arm_state(b[0])
	check(watched == skipped, "看完＝跳過（%s vs %s）" % [watched, skipped])
	check(watched.hung and watched.player_visible and watched.boss_visible, "宮殿掛著手臂、角色與 Boss 看得到")
	await end_cs_fight(b)


func test_arm_lines_match_card() -> void:
	var Arm = cs_file("arm")
	var Couple = cs_file("couple")
	if Arm == null or Couple == null:
		return
	var arm: String = CardText.CARDS["arm"]
	for l in [Arm.N1, Arm.N2, Arm.N3, Arm.CHIMALMAT, Arm.MACAW]:
		check(arm.contains(l), "arm 卡有「%s」" % l)
	var couple: String = CardText.CARDS["couple"]
	for l in [Couple.N, Couple.HUNAHPU, Couple.XBALANQUE, Couple.ELDERS]:
		check(couple.contains(l), "couple 卡有「%s」" % l)


func test_arm_hung_after_retry_and_load() -> void:
	if cs_file("arm") == null:
		return
	var s: Array = await cs_fight()
	var f = s[0]
	await start_arm(f)
	await hold_skip(f.cutscene)
	var arm = f.scenery.get("arm_prop")
	check(arm != null and arm.visible, "斷臂後宮殿掛著手臂")
	if arm != null:
		check(arm.global_position.distance_to(f.scenery.ROPE_KNOT) <= 1.0, "在繩結上（%s）" % arm.global_position)
	f._retry(2)
	check(arm != null and arm.visible and f.player.twins[0].arm_broken, "第 2 段重試：仍掛著、仍斷臂")
	await end_cs_fight(s)
	var t: Array = await cs_fight()
	t[0].begin_at_rest("palace_camp")
	await frames(2)
	var arm2 = t[0].scenery.get("arm_prop")
	check(arm2 != null and arm2.visible, "從宮殿篝火繼續：掛著手臂")
	t[0].start_at(4)
	await frames(2)
	check(arm2 == null or not arm2.visible, "覺醒後不掛（c2c 取回）")
	await end_cs_fight(t)


func test_proto_still_shows_cards() -> void:
	var f = BossFight.new()
	f.tn = fresh_tuning()
	f.tn.card_min_time = 0.0
	f.log_dir = TEST_LOG_DIR
	f.player_scripted = true
	add_child(f)
	await frames(3)
	f.card.min_time = 0.0
	f.start_at(1)
	await frames(2)
	f._on_setup(1)
	await frames(2)
	check(await next_card(f, "arm"), "原型模式：arm 文字卡")
	check(await next_card(f, "couple"), "原型模式：couple 文字卡")
	await free_fight(f)


# ---- Task 6：--cutscene 開發畫面 ----

func test_cutscene_launch_args() -> void:
	var o := LaunchArgs.parse(PackedStringArray(["--cutscene", "arm", "--frames", "/tmp/x"]))
	check(o.mode == "cutscene" and o.get("cutscene", "") == "arm" and o.frames_dir == "/tmp/x", "--cutscene arm --frames 解析（%s）" % o)
	var path := "res://world/cutscene_view.gd"
	check(ResourceLoader.exists(path), "有 %s" % path)
	if ResourceLoader.exists(path):
		check(load(path).NAMES.slice(0, 3) == ["opening", "arm", "couple"], "c2a 的三段：opening、arm、couple（c2b 之後加宮殿三段）")



# ---- 最終審查的修正 ----

## 交還操作：真正的角色出現時替身已經移除、已換回戰鬥鏡頭；替身最後的位置＝真正角色的位置、鏡頭不跳
func test_handover_without_doubles() -> void:
	if cs_file("couple") == null:
		return
	var s: Array = await cs_fight()
	var f = s[0]
	f.start_at(1)
	await frames(2)
	load("res://world/cutscene/arm.gd").new().end_state(f)
	var cs = f.cutscene
	cs.run([load("res://world/cutscene/couple.gd").new()])
	Engine.time_scale = 8.0
	var doubled := false
	var last := {}
	var cam := Vector2.INF
	while cs.running:
		var live: Array = cs.get("_cast").get_children().filter(func(a): return not a.is_queued_for_deletion())
		if f.player.visible and not live.is_empty():
			doubled = true
		for a in live:
			if a.cid.begins_with("healer"):
				last[a.cid] = a.global_position
		if cs.camera.is_current():
			cam = cs.camera.get_screen_center_position()
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await frames(2)
	check(not doubled, "真正的角色出現時替身已移除（不會兩組同時在畫面上）")
	for i in 2:
		var real: Vector2 = f.couple[i].global_position
		var cid: String = ["healer_man", "healer_woman"][i]
		check(last.has(cid) and last[cid].distance_to(real) <= 3.0, "%s：替身最後位置＝跟隨的位置（%s vs %s）" % [cid, last.get(cid), real])
	var after: Vector2 = f.camera.get_screen_center_position()
	check(cam.distance_to(after) <= 3.0, "交還時鏡頭不跳（%s vs %s）" % [cam, after])
	await end_cs_fight(s)


# ==== MV-SLICE-001c2b ====
# ---- Task 1：機制修正 ----

class HideBoss extends RefCounted:
	func play(cs) -> void:
		await cs.wait(0.2)

	func end_state(fight) -> void:
		fight.boss.visible = false


class HideCouple extends RefCounted:
	func play(cs) -> void:
		cs.conceal(cs.host.couple[0])
		await cs.wait(0.6)

	func end_state(_fight) -> void:
		pass


func test_together_waits_for_all() -> void:
	var cs = await ui_cs()
	if cs == null or not cs.has_method("together"):
		check(false, "有 together")
		return
	var t0 := Time.get_ticks_msec()
	await cs.together([cs.wait.bind(0.3), cs.wait.bind(0.8)])
	var took := (Time.get_ticks_msec() - t0) / 1000.0
	check(took >= 0.75, "等最長的那個做完（%.2f 秒）" % took)
	cs.skipped = true
	t0 = Time.get_ticks_msec()
	await cs.together([cs.wait.bind(2.0)])
	check(Time.get_ticks_msec() - t0 < 200, "跳過時立刻 return")
	cs.queue_free()


func test_run_reentry_ignored() -> void:
	var cs = await ui_cs()
	if cs == null:
		return
	var a := Dummy.new()
	a.secs = 0.5
	var b := Dummy.new()
	cs.run([a])
	await frames(2)
	cs.run([b])
	await secs(1.2)
	check(a.ended == 1 and b.ended == 0, "執行中再 run：第二次不跑（%d、%d）" % [a.ended, b.ended])
	cs.queue_free()


func test_hud_untouched_when_idle() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	f.hud.modulate.a = 0.5
	for i in 3:  # 執行器在 _process 寫 HUD：要等 process 幀（headless 時一個 process 幀可能跑好幾個物理幀）
		await get_tree().process_frame
	check(is_equal_approx(f.hud.modulate.a, 0.5), "沒有演出時不寫 HUD 透明度（%.2f）" % f.hud.modulate.a)
	f.hud.modulate.a = 1.0
	await end_cs_fight(s)


func test_end_state_visibility_wins() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	f.cutscene.run([HideBoss.new()])
	await wait_cs(f.cutscene)
	check(not f.boss.visible, "end_state 藏起 Boss：交還後仍藏著")
	check(f.player.visible, "玩家恢復顯示")
	await end_cs_fight(s)


func test_hide_restores() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	if not f.cutscene.has_method("conceal"):
		check(false, "有 conceal")
		await end_cs_fight(s)
		return
	f.palace.couple_static = true  # 讓老夫婦顯示（_update_couple 每幀設 visible）
	await frames(2)
	f.cutscene.run([HideCouple.new()])
	await secs(0.3)
	var n = f.couple[0]
	check(n.modulate.a <= 0.01, "演出中藏起（%.2f）" % n.modulate.a)
	await wait_cs(f.cutscene)
	check(n.modulate.a >= 0.99 and n.visible, "交還後恢復")
	await end_cs_fight(s)


func test_actor_glints() -> void:
	var A = cs_file("actor")
	if A == null:
		return
	var a = A.make("sevenmacaw")
	add_child(a)
	if not a.has_method("add_glints"):
		check(false, "有 add_glints")
		a.queue_free()
		return
	var g = a.add_glints()
	await frames(2)
	check(g.lit_count() == g.NAMES.size(), "替身身上光點全亮（%d）" % g.lit_count())
	g.extinguish(0.3)
	await secs(0.5)
	check(g.lit_count() == 0, "熄滅後全熄（%d）" % g.lit_count())
	a.queue_free()


# ---- Task 2：宮殿演出的新動作 ----

func test_palace_anims_present() -> void:
	var want := {"sevenmacaw": ["bow", "collapse"], "healer_man": ["reach", "pick"], "healer_woman": ["reach", "pick"], "chimalmat": ["collapse"]}
	for c in want:
		var a := anims_of("res://rig/%s_anims.json" % c)
		for n in want[c]:
			check(a.has(n) and not a[n].get("loop", false), "%s %s 是單次動作" % [c, n])


# ---- Task 3：第 2 段開場（牙痛）----

## 從宮殿篝火出發、越過宮殿入口
func enter_palace(f) -> void:
	f.begin_at_rest("palace_camp")
	await frames(2)
	f.player.position = Vector2(Palace.ENTRY_X + 60.0, Palace.GROUND_Y)
	await frames(2)


func palace_state(f) -> Dictionary:
	return {"player": f.player.position.round(), "boss": f.boss.position.round(), "boss_state": f.boss.state, "seen": f.palace_card_seen,
		"stage": f.stage, "phase": f.phase, "boss_visible": f.boss.visible, "player_visible": f.player.visible}


func test_toothache_first_time_only() -> void:
	if cs_file("toothache") == null:
		return
	var s: Array = await cs_fight()
	var f = s[0]
	await enter_palace(f)
	check(f.cutscene.running, "第一次進宮殿：播牙痛開場")
	var card_seen := false
	Engine.time_scale = 8.0
	while f.cutscene.running:
		card_seen = card_seen or f.card.visible
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await frames(2)
	check(not card_seen, "遊戲模式不出現 toothache 卡")
	check(f.palace_card_seen and f.stage == BossFight.Stage.FIGHT and f.phase == 2, "看過、第 2 段開打")
	f._retry(2)
	f.player.position = Vector2(Palace.ENTRY_X + 60.0, Palace.GROUND_Y)
	await frames(2)
	check(not f.cutscene.running and f.stage == BossFight.Stage.FIGHT, "重試再進場：不播")
	await end_cs_fight(s)


func test_toothache_watch_equals_skip() -> void:
	if cs_file("toothache") == null:
		return
	var a: Array = await cs_fight()
	await enter_palace(a[0])
	Engine.time_scale = 8.0
	await wait_cs(a[0].cutscene)
	Engine.time_scale = 1.0
	await frames(2)
	var watched := palace_state(a[0])
	await end_cs_fight(a)
	var b: Array = await cs_fight()
	await enter_palace(b[0])
	await hold_skip(b[0].cutscene)
	await frames(2)
	var skipped := palace_state(b[0])
	check(watched == skipped, "看完＝跳過（%s vs %s）" % [watched, skipped])
	await end_cs_fight(b)


func test_toothache_lines_match_card() -> void:
	var T = cs_file("toothache")
	if T == null:
		return
	for l in [T.N1, T.N2, T.N3]:
		check(CardText.CARDS["toothache"].contains(l), "toothache 卡有「%s」" % l)


func test_proto_toothache_card() -> void:
	var f = BossFight.new()
	f.tn = fresh_tuning()
	f.tn.card_min_time = 0.0
	f.log_dir = TEST_LOG_DIR
	f.player_scripted = true
	add_child(f)
	await frames(3)
	f.card.min_time = 0.0
	await enter_palace(f)
	check(await next_card(f, "toothache"), "原型模式：toothache 文字卡")
	await free_fight(f)


func test_cutscene_view_has_toothache() -> void:
	check(load("res://world/cutscene_view.gd").NAMES.has("toothache"), "--cutscene toothache")


# ---- Task 4：換牙 ----

func start_teeth(f) -> void:
	f.start_at(2)
	await frames(2)
	f._on_setup(2)
	await frames(2)


func teeth_state(f) -> Dictionary:
	return {"player": f.player.position.round(), "boss": f.boss.position.round(), "boss_state": f.boss.state, "phase": f.phase,
		"lights": f.lights_removed, "head": f.boss.appearance, "stage": f.stage,
		"couple": [f.couple[0].modulate.a, f.couple[1].modulate.a, f.couple[0].visible, f.couple[1].visible]}


func test_teeth_replaces_card() -> void:
	if cs_file("teeth") == null:
		return
	var s: Array = await cs_fight()
	var f = s[0]
	await start_teeth(f)
	check(f.cutscene.running, "第 2 段設局成功：播換牙")
	var card_seen := false
	Engine.time_scale = 8.0
	while f.cutscene.running:
		card_seen = card_seen or f.card.visible
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await frames(2)
	check(not card_seen, "遊戲模式不出現 teeth 卡")
	check(f.phase == 3 and f.stage == BossFight.Stage.FIGHT and f.boss.appearance == 2, "第 3 段開打、白玉米牙（%d、%s、%d）" % [f.phase, f.stage, f.boss.appearance])
	await end_cs_fight(s)


func test_teeth_watch_equals_skip() -> void:
	if cs_file("teeth") == null:
		return
	var a: Array = await cs_fight()
	await start_teeth(a[0])
	Engine.time_scale = 8.0
	await wait_cs(a[0].cutscene)
	Engine.time_scale = 1.0
	await frames(2)
	var watched := teeth_state(a[0])
	await end_cs_fight(a)
	var b: Array = await cs_fight()
	await start_teeth(b[0])
	await hold_skip(b[0].cutscene)
	await frames(2)
	var skipped := teeth_state(b[0])
	check(watched == skipped, "看完＝跳過（%s vs %s）" % [watched, skipped])
	await end_cs_fight(b)


func test_teeth_hides_real_couple() -> void:
	if cs_file("teeth") == null:
		return
	var s: Array = await cs_fight()
	var f = s[0]
	await start_teeth(f)
	await secs(0.5)
	check(f.cutscene.running and f.couple.all(func(n): return n.modulate.a <= 0.01), "演出中真正的老夫婦藏起（替身在演）")
	await hold_skip(f.cutscene)
	await frames(2)
	check(f.couple.all(func(n): return n.modulate.a >= 0.99 and n.visible), "交還後老夫婦回到入口端")
	await end_cs_fight(s)


func test_teeth_lines_match_card() -> void:
	var T = cs_file("teeth")
	if T == null:
		return
	for l in [T.PLEA, T.N1, T.N2]:
		check(CardText.CARDS["teeth"].contains(l), "teeth 卡有「%s」" % l)


func test_proto_teeth_card() -> void:
	var f = BossFight.new()
	f.tn = fresh_tuning()
	f.tn.card_min_time = 0.0
	f.log_dir = TEST_LOG_DIR
	f.player_scripted = true
	add_child(f)
	await frames(3)
	f.card.min_time = 0.0
	await start_teeth(f)
	check(await next_card(f, "teeth"), "原型模式：teeth 文字卡")
	await free_fight(f)


func test_cutscene_view_has_teeth() -> void:
	check(load("res://world/cutscene_view.gd").NAMES.has("teeth"), "--cutscene teeth")


# ---- Task 5：死亡與死後的宮殿 ----

func start_death(f) -> void:
	f.start_at(3)
	await frames(2)
	f._on_setup(3)
	await frames(2)


func chimalmat_of(f) -> Node:
	return f.scenery.terrain.get_node("Chimalmat")


func death_state(f) -> Dictionary:
	var body = f.scenery.get("body_prop")
	return {"boss_visible": f.boss.visible, "lights": f.lights_removed, "scene": f.scenery.modulate, "palace": f.scenery.palace_lights.alpha,
		"body": body != null and body.visible, "chimalmat": chimalmat_of(f).visible and chimalmat_of(f).modulate.a > 0.5,
		"couple_static": f.palace.couple_static, "player": f.player.position.round()}


func test_death_replaces_card() -> void:
	if cs_file("death") == null:
		return
	var s: Array = await cs_fight()
	var f = s[0]
	await start_death(f)
	check(f.cutscene.running, "第 3 段設局成功：播死亡")
	var death_card := false
	Engine.time_scale = 8.0
	while f.cutscene.running:
		death_card = death_card or (f.card.visible and f.card.text == CardText.CARDS["death"])
		await get_tree().process_frame
	Engine.time_scale = 1.0
	check(not death_card, "遊戲模式不出現 death 卡")
	await frames(30)
	check(not f.card.visible and f.awakened, "接著是覺醒演出、不再顯示 awaken 卡（c2c）")
	await end_cs_fight(s)


func test_death_darkens_in_scene_not_before() -> void:
	if cs_file("death") == null:
		return
	var s: Array = await cs_fight()
	var f = s[0]
	await start_death(f)
	await frames(2)
	var dark2: float = Scenery.DARKNESS[2]
	check(f.scenery.modulate.is_equal_approx(Color(dark2, dark2, dark2)), "設局那一刻場景還是第 3 段的暗度（%s）" % f.scenery.modulate)
	check(is_equal_approx(f.scenery.palace_lights.alpha[2], 1.0), "最後一組假光還亮著（%.2f）" % f.scenery.palace_lights.alpha[2])
	await hold_skip(f.cutscene)
	await end_cs_fight(s)


func test_death_watch_equals_skip() -> void:
	if cs_file("death") == null:
		return
	var a: Array = await cs_fight()
	await start_death(a[0])
	Engine.time_scale = 8.0
	await wait_cs(a[0].cutscene)
	Engine.time_scale = 1.0
	await frames(2)
	var watched := death_state(a[0])
	await end_cs_fight(a)
	var b: Array = await cs_fight()
	await start_death(b[0])
	await hold_skip(b[0].cutscene)
	await frames(2)
	var skipped := death_state(b[0])
	check(watched == skipped, "看完＝跳過（%s vs %s）" % [watched, skipped])
	var dark3: float = Scenery.DARKNESS[3]
	check(skipped.scene.is_equal_approx(Color(dark3, dark3, dark3)) and skipped.palace == PackedFloat32Array([0.0, 0.0, 0.0]), "最暗、假光全滅")
	check(skipped.body and not skipped.chimalmat and not skipped.boss_visible and not skipped.couple_static, "地上有身體、奇瑪瑪特不在、Boss 藏起、老夫婦離開")
	await end_cs_fight(b)


func test_death_lines_match_card() -> void:
	var D = cs_file("death")
	if D == null:
		return
	for l in [D.N1, D.N2, D.N3, D.N4, D.N5]:
		check(CardText.CARDS["death"].contains(l), "death 卡有「%s」" % l)


func test_cutscene_view_has_death() -> void:
	check(load("res://world/cutscene_view.gd").NAMES.has("death"), "--cutscene death")


func test_dead_palace_follows_awakened() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	for p in [2, 3]:
		f.start_at(p)
		await frames(2)
		var body = f.scenery.get("body_prop")
		check((body == null or not body.visible) and chimalmat_of(f).visible, "第 %d 段：沒有身體、奇瑪瑪特在" % p)
	f.start_at(4)
	await frames(2)
	var body = f.scenery.get("body_prop")
	check(body != null and body.visible and not chimalmat_of(f).visible, "覺醒後：地上有身體、奇瑪瑪特不在")
	await end_cs_fight(s)


# ---- 最終審查（c2b）的修正：交還／替換前後要連續 ----

## 看完一段演出（time_scale 8），記錄 Seven Macaw 替身最後的位置、面向與動作
func watch_tracking_macaw(f, cs) -> Dictionary:
	var last := {}
	Engine.time_scale = 8.0
	while cs.running:
		for a in cs.get("_cast").get_children():
			if not a.is_queued_for_deletion() and a.cid == "sevenmacaw":
				last = {"pos": a.global_position, "facing": a.facing, "anim": a.anim}
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await frames(2)
	return last


func test_toothache_boss_continuous() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	await enter_palace(f)
	var last := await watch_tracking_macaw(f, f.cutscene)
	check(not last.is_empty() and last.pos.distance_to(f.boss.global_position) <= 3.0 and last.facing == f.boss.facing,
		"牙痛：交還前後 Boss 位置與面向一致（%s vs %s／%d）" % [last, f.boss.global_position, f.boss.facing])
	var boss_anim: String = f.boss.get_node("MacawAnimator").choose(f.boss)[0]
	check(not last.is_empty() and last.anim == boss_anim, "牙痛：替身收翅回待機再交還（%s vs %s）" % [last.get("anim"), boss_anim])
	await end_cs_fight(s)


func test_teeth_boss_continuous() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	await start_teeth(f)
	var last := await watch_tracking_macaw(f, f.cutscene)
	check(not last.is_empty() and last.pos.distance_to(f.boss.global_position) <= 3.0 and last.facing == f.boss.facing,
		"換牙：交還前後 Boss 位置與面向一致（%s vs %s／%d）" % [last, f.boss.global_position, f.boss.facing])
	await end_cs_fight(s)


## 奇瑪瑪特就地死去（不換替身）：亮度跟著場景、不會突然變亮，也不會跑到寶座前面
func test_chimalmat_dies_in_place() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	await start_death(f)
	var chi := chimalmat_of(f)
	var stand_in := false
	var darkened := false
	Engine.time_scale = 8.0
	while f.cutscene.running:
		for a in f.cutscene.get("_cast").get_children():
			stand_in = stand_in or a.cid == "chimalmat"
		darkened = darkened or (chi.visible and chi.modulate.r <= 0.05 and chi.modulate.a > 0.5)
		await get_tree().process_frame
	Engine.time_scale = 1.0
	check(not stand_in, "奇瑪瑪特不換替身")
	check(darkened, "真正的她在場景裡變黑")
	await end_cs_fight(s)


## 死後的身體：交還前後實際亮度一致（替身 ×0.5；場景在最暗 ×0.3，擺設要補回來）
func test_body_brightness_continuous() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	await start_death(f)
	await hold_skip(f.cutscene)
	await frames(2)
	var body = f.scenery.get("body_prop")
	var eff: float = body.modulate.r * f.scenery.modulate.r if body != null else -1.0
	check(absf(eff - f.scenery.BODY_DIM) <= 0.01, "身體實際亮度＝替身熄滅後的亮度 %.2f（%.3f）" % [f.scenery.BODY_DIM, eff])
	await end_cs_fight(s)


# ---- MV-SLICE-001c2c Task 1：機制與延後的測試補強 ----

## 宣告 skip_stop 的假演出：跳過停在它的開頭
class StopDummy extends Dummy:
	var skip_stop := true
	var played := false

	func play(cs) -> void:
		played = true
		await cs.wait(secs)


## 記錄 play 有沒有播到完
class DoneDummy extends Dummy:
	var done := false

	func play(cs) -> void:
		await cs.wait(secs)
		done = true


func test_skip_stop_resumes_scene() -> void:
	var cs = await ui_cs()
	if cs == null:
		return
	var d := Dummy.new()
	d.secs = 5.0
	var s := StopDummy.new()
	s.secs = 30.0
	cs.run([d, s])
	await secs(0.2)
	Input.action_press(&"pause")
	await secs(1.3)
	check(s.played and not cs.skipped, "跳過停在 skip_stop 段的開頭")
	await secs(1.5)
	check(not cs.skipped, "沒放開就不會再跳過")
	Input.action_release(&"pause")
	await secs(0.1)
	Input.action_press(&"pause")
	await secs(1.2)
	check(cs.skipped, "放開後再長按：跳過")
	Input.action_release(&"pause")
	await wait_cs(cs, 5.0)
	check(d.ended == 1 and s.ended == 1, "兩段的 end_state 各一次（%d、%d）" % [d.ended, s.ended])
	cs.queue_free()


func test_skip_without_stop_skips_all() -> void:
	var cs = await ui_cs()
	if cs == null:
		return
	var d := Dummy.new()
	d.secs = 5.0
	var d2 := DoneDummy.new()
	d2.secs = 5.0
	cs.run([d, d2])
	await secs(0.2)
	Input.action_press(&"pause")
	await secs(1.2)
	Input.action_release(&"pause")
	await wait_cs(cs, 5.0)
	check(not d2.done and d2.ended == 1, "沒有 skip_stop：一路跳到底")
	cs.queue_free()


func test_cast_of() -> void:
	var s: Array = await cs_fight()
	var cs = s[0].cutscene
	if not cs.has_method("cast_of"):
		check(false, "有 cast_of")
		await end_cs_fight(s)
		return
	var hu = cs.spawn("hunahpu", Vector2.ZERO)
	var xb = cs.spawn("xbalanque", Vector2.ZERO)
	check(cs.cast_of("hunahpu") == hu and cs.cast_of("xbalanque") == xb, "依 cid 取得替身")
	check(cs.cast_of("rat") == null, "沒有就回傳 null")
	hu.queue_free()
	check(cs.cast_of("hunahpu") == null, "queue_free 的不算")
	await end_cs_fight(s)


func arm_shown(a) -> bool:
	return a.rig.get("_arm").visible


func test_twin_stand_in_arm_follows_real() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	f.player.twins[0].arm_broken = true
	var a = f.cutscene.spawn("hunahpu", Vector2.ZERO)
	check(not arm_shown(a), "真的斷臂：替身沒有近側手臂")
	f.player.twins[0].arm_broken = false
	var b = f.cutscene.spawn("hunahpu", Vector2.ZERO)
	check(arm_shown(b), "沒斷臂：替身有手臂")
	a.queue_free()
	b.queue_free()
	await end_cs_fight(s)
	s = await cs_fight()
	f = s[0]
	await start_teeth(f)
	var hu = null
	for c in f.cutscene.get("_cast").get_children():
		if c.cid == "hunahpu":
			hu = c
	check(hu != null and not arm_shown(hu), "換牙演出：胡納普替身是斷臂")
	await hold_skip(f.cutscene)
	await end_cs_fight(s)


func test_until_ends_when_removed() -> void:
	var cs = await ui_cs()
	if cs == null:
		return
	var d := DoneDummy.new()
	d.secs = 30.0
	cs.run([d])
	await secs(0.2)
	remove_child(cs)
	await frames(3)
	check(d.done, "移出場景樹後等待中的指令結束")
	cs.free()


func test_show_layer_under_bars() -> void:
	var cs = await ui_cs()
	if cs == null or not cs.has_method("show_layer"):
		check(false, "有 show_layer")
		return
	var d := Dummy.new()
	d.secs = 0.3
	cs.run([d])
	var n := Control.new()
	cs.show_layer(n)
	check(n.get_index() < cs.get("_fade").get_index(), "在白幕與黑邊之下")
	await wait_cs(cs, 5.0)
	await frames(1)
	check(not is_instance_valid(n), "交還時釋放")
	cs.queue_free()


func test_fade_to_white_then_black() -> void:
	var cs = await ui_cs()
	if cs == null or not cs.has_method("fade_to_white"):
		check(false, "有 fade_to_white")
		return
	var fade: ColorRect = cs.get("_fade")
	await cs.fade_to_white(0.2)
	check(fade.color.is_equal_approx(Color(1, 1, 1, 1)), "白幕（%s）" % fade.color)
	await cs.fade_to_black(0.2)
	check(fade.color.is_equal_approx(Color(0, 0, 0, 1)), "黑幕（%s）" % fade.color)
	cs.queue_free()


func test_animate_steps_to_one() -> void:
	var cs = await ui_cs()
	if cs == null or not cs.has_method("animate"):
		check(false, "有 animate")
		return
	var ks: Array = []
	await cs.animate(0.3, func(k: float) -> void: ks.append(k))
	var rising := true
	for i in range(1, ks.size()):
		rising = rising and ks[i] >= ks[i - 1]
	check(ks.size() > 2 and is_equal_approx(ks[-1], 1.0) and rising, "k 遞增到 1（%s）" % [ks])
	ks.clear()
	cs.skipped = true
	await cs.animate(0.3, func(k: float) -> void: ks.append(k))
	check(ks == [1.0], "跳過中只收到 1.0（%s）" % [ks])
	cs.queue_free()


func test_cutscene_lines_fit_two_lines() -> void:
	var cs = await ui_cs()
	if cs == null:
		return
	var re := RegEx.create_from_string("^(N\\d+|PLEA)$")
	var n := 0
	for fn in DirAccess.get_files_at("res://world/cutscene/"):
		if not fn.ends_with(".gd"):
			continue
		var consts: Dictionary = load("res://world/cutscene/" + fn).get_script_constant_map()
		for k in consts:
			if consts[k] is String and re.search(k) != null:
				var who := "七金剛鸚鵡" if k == "PLEA" else ""
				cs.subtitle.text = ("[center][color=%s]%s：[/color]%s[/center]" % [cs.NAME_COLOR, who, consts[k]]) if who != "" else "[center]%s[/center]" % consts[k]
				await frames(1)
				check(cs.subtitle.get_line_count() <= 2, "%s %s 不超過兩行（%d）" % [fn, k, cs.subtitle.get_line_count()])
				n += 1
	check(n >= 10, "量過所有演出句子（%d 句）" % n)
	cs.queue_free()


func test_together_finishes_walk_on_early_advance() -> void:
	var s: Array = await cs_fight()
	var cs = s[0].cutscene
	var d := Dummy.new()
	d.secs = 30.0
	cs.run([d])
	await secs(0.2)
	var a = cs.spawn("hunahpu", Vector2(15000, 900))
	var goal: float = a.position.x + 300.0
	var done := [false]
	(func() -> void:
		await cs.together([cs.walk.bind(a, goal), cs.narrate.bind("短句")])
		done[0] = true).call()
	await secs(0.6)
	await tap(&"attack")
	await wait_until(func(): return done[0], 300)
	check(done[0] and is_equal_approx(a.position.x, goal), "提前換句：並行的走路仍走完（%.1f vs %.1f）" % [a.position.x, goal])
	await hold_skip(cs)
	await end_cs_fight(s)


func test_death_skip_during_fade() -> void:
	var a: Array = await cs_fight()
	await start_death(a[0])
	Engine.time_scale = 8.0
	await wait_cs(a[0].cutscene)
	Engine.time_scale = 1.0
	await frames(2)
	var watched := death_state(a[0])
	await end_cs_fight(a)
	var b: Array = await cs_fight()
	await start_death(b[0])
	var chi := chimalmat_of(b[0])
	Engine.time_scale = 8.0
	var fading: bool = await wait_until(func(): return chi.modulate.r <= 0.05 and chi.modulate.a < 0.9, 3000)
	Engine.time_scale = 1.0
	check(fading, "等到奇瑪瑪特淡出中")
	await hold_skip(b[0].cutscene)
	await frames(2)
	var skipped := death_state(b[0])
	check(watched == skipped, "淡出途中跳過＝看完（%s vs %s）" % [watched, skipped])
	await end_cs_fight(b)


# ---- MV-SLICE-001c2c Task 2：覺醒後的狀態、存檔與出口提示 ----

## 死亡演出跳過、按掉之後的卡片（Task 3 起沒有卡片），等交還完成
## 一路長按跳過（遇到 skip_stop 段就放開再按）
func skip_all(cs) -> void:
	for i in 6:
		if not cs.running:
			break
		Input.action_press(&"pause")
		await wait_until(func(): return cs.skipped or not cs.running, 200)
		Input.action_release(&"pause")
		await frames(3)
	await wait_until(func(): return not cs.running, 120)


func awaken_now(f) -> void:
	await start_death(f)
	await skip_all(f.cutscene)
	await frames(2)
	if f.card.visible:
		f.card.confirm()
		await frames(2)


func awakened_state(f) -> Dictionary:
	var body = f.scenery.get("body_prop")
	var arm = f.scenery.get("arm_prop")
	return {"boss_visible": f.boss.visible, "body": body != null and body.visible, "chimalmat": chimalmat_of(f).visible,
		"arm_hung": arm != null and arm.visible, "lights": f.lights_removed, "couple": [f.couple[0].visible, f.couple[1].visible],
		"couple_static": f.palace.couple_static, "abilities": f.player.abilities_enabled, "arm_broken": f.player.twins[0].arm_broken,
		"barrier_broken": f.palace.barrier.is_broken, "awakened": f.awakened}


func test_awakening_saves() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	f.player.health.hp = 1
	await awaken_now(f)
	var st: Dictionary = Save.read(TEST_SAVE)
	check(not st.is_empty() and st.awakened and st.last_rest == "palace_camp", "覺醒交還時存檔（%s）" % [st.get("awakened"), ])
	check(not st.is_empty() and st.hp == f.tn.max_hp and st.heal_charges == f.tn.heal_charges, "存檔時補滿")
	check(f.player.twin_index == 1 and f.stage == f.Stage.EXIT, "換成希巴拉克、出口階段")
	check(f.hud.notice == "已存檔", "已存檔提示（%s）" % f.hud.notice)
	await secs(2.2)
	check(f.hud.notice == f.EXIT_HINT_BARRIER if "EXIT_HINT_BARRIER" in f else false, "之後是破木障提示（%s）" % f.hud.notice)
	await end_cs_fight(s)


func test_awakening_keeps_xbalanque() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	await start_death(f)
	if f.player.twin_index == 0:
		f.player.swap_twin()
	while f.cutscene.running:
		await hold_skip(f.cutscene)
	await frames(2)
	if f.card.visible:
		f.card.confirm()
		await frames(2)
	check(f.player.twin_index == 1, "設局後已是希巴拉克：不換回胡納普")
	await end_cs_fight(s)


func test_exit_hints_follow_progress() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	f.start_at(4)
	await frames(2)
	var hint1 = f.get("EXIT_HINT_BARRIER")
	check(hint1 != null and f.hud.notice == hint1, "先提示破木障（%s）" % f.hud.notice)
	await secs(7.0)
	check(hint1 != null and f.hud.notice == hint1, "7 秒後仍在")
	f.palace.barrier.break_apart()
	await frames(2)
	check(f.hud.notice == f.EXIT_HINT, "木障碎了：二段跳提示")
	await secs(7.0)
	check(f.hud.notice == f.EXIT_HINT, "7 秒後仍在")
	await end_cs_fight(s)


func load_awakened(f, gs) -> void:
	gs.awakened = true
	f.begin_at_rest("palace_camp")
	await frames(3)


func test_load_awakened_palace() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	await load_awakened(f, s[1])
	var st := awakened_state(f)
	check(not st.boss_visible and st.body and not st.chimalmat and not st.arm_hung and st.lights == 3, "覺醒後的宮殿（%s）" % st)
	check(st.couple == [false, false] and st.abilities and not st.arm_broken and not st.barrier_broken, "老夫婦不在、能力開、手臂在、木障立著（%s）" % st)
	check(f.stage == f.Stage.APPROACH, "在篝火走路階段")
	f.player.position = Vector2(Palace.ENTRY_X + 100.0, Palace.GROUND_Y)
	await frames(3)
	check(f.stage == f.Stage.EXIT and not f.palace.gate_closed, "進宮殿：出口階段、不關閘門")
	check(not f.cutscene.running and not f.card.visible and not f.boss.visible, "不播牙痛、不開打")
	await end_cs_fight(s)


func test_start_at_4_matches_load() -> void:
	var a: Array = await cs_fight()
	await load_awakened(a[0], a[1])
	var loaded := awakened_state(a[0])
	await end_cs_fight(a)
	var b: Array = await cs_fight()
	b[0].start_at(4)
	await frames(3)
	var debug := awakened_state(b[0])
	check(loaded == debug, "start_at(4)＝讀檔（%s vs %s）" % [loaded, debug])
	check(debug.couple == [false, false], "start_at(4) 沒有老夫婦")
	await end_cs_fight(b)


func test_reset_area_keeps_awakened() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	await load_awakened(f, s[1])
	f.reset_area()
	await frames(3)
	var st := awakened_state(f)
	check(st.awakened and not st.boss_visible and st.body, "F10 後仍是覺醒後的宮殿（%s）" % st)
	await end_cs_fight(s)


func test_proto_awaken_no_save() -> void:
	var f = BossFight.new()
	f.tn = fresh_tuning()
	f.tn.card_min_time = 0.0
	f.tester = "selftest"
	f.log_dir = TEST_LOG_DIR
	f.player_scripted = true
	f.save_path = TEST_SAVE
	add_child(f)
	await frames(3)
	f.card.min_time = 0.0
	f.boss.cycle_enabled = false
	f.start_at(3)
	await frames(2)
	f._on_setup(3)
	var texts: Array = []
	for i in 2:
		await wait_until(func(): return f.card.visible, 120)
		texts.append(f.card.text)
		f.card.confirm()
		await frames(2)
	check(texts.size() == 2 and texts[1] == CardText.CARDS["awaken"], "原型：death、awaken 兩張卡")
	check(f.stage == f.Stage.EXIT and not FileAccess.file_exists(TEST_SAVE), "出口階段、沒有寫檔")
	await free_fight(f)



# ---- MV-SLICE-001c2c Task 3：覺醒演出——取回手臂與裝回 ----

func awaken_state(f) -> Dictionary:
	var arm = f.scenery.get("arm_prop")
	var st: Dictionary = Save.read(TEST_SAVE)
	return {"awakened": f.awakened, "twin": f.player.twin_index, "arm_broken": f.player.twins[0].arm_broken,
		"arm_hung": arm != null and arm.visible, "abilities": f.player.abilities_enabled, "stage": f.stage,
		"saved": st.get("awakened", false), "boss_visible": f.boss.visible}


func test_awaken_replaces_card() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	await start_death(f)
	var card := false
	Engine.time_scale = 8.0
	while f.cutscene.running:
		card = card or f.card.visible
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await frames(30)
	card = card or f.card.visible
	check(not card, "沒有文字卡")
	check(f.awakened and f.stage == f.Stage.EXIT and Save.read(TEST_SAVE).get("awakened", false), "覺醒、出口、已存檔")
	await end_cs_fight(s)


func test_death_skip_stops_at_awaken() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	await start_death(f)
	var cs = f.cutscene
	Input.action_press(&"pause")
	await wait_until(func(): return cs.skipped, 200)
	var resumed: bool = await wait_until(func(): return not cs.skipped and cs.running, 200)
	check(resumed, "死亡段跳過後，覺醒段從開頭播")
	var hu = cs.cast_of("hunahpu")
	check(hu != null and not hu.rig.get("_arm").visible, "接著用死亡段的胡納普替身（斷臂）")
	await secs(1.5)
	check(not cs.skipped, "沒放開不會再跳過")
	Input.action_release(&"pause")
	await skip_all(cs)
	await end_cs_fight(s)


func test_awaken_watch_equals_skip() -> void:
	var a: Array = await cs_fight()
	await start_death(a[0])
	Engine.time_scale = 8.0
	await wait_cs(a[0].cutscene)
	Engine.time_scale = 1.0
	await frames(2)
	var watched := awaken_state(a[0])
	await end_cs_fight(a)
	var b: Array = await cs_fight()
	await awaken_now(b[0])
	var skipped := awaken_state(b[0])
	check(watched == skipped, "看完＝跳過（%s vs %s）" % [watched, skipped])
	check(skipped.awakened and not skipped.arm_broken and not skipped.arm_hung and skipped.twin == 1 and skipped.saved, "覺醒結果（%s）" % skipped)
	await end_cs_fight(b)


func test_awaken_skip_mid_silhouette() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	await start_death(f)
	var cs = f.cutscene
	Engine.time_scale = 8.0
	var sil: bool = await wait_until(func(): return cs.backdrop_visible(), 4000)
	Engine.time_scale = 1.0
	check(sil, "等到剪影")
	await skip_all(cs)
	await frames(2)
	check(f.world.modulate == Color.WHITE and not cs.backdrop_visible(), "剪影還原")
	check(not f.player.twins[0].arm_broken, "胡納普有手臂")
	await end_cs_fight(s)


func test_awaken_arm_taken_and_mended() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	await start_death(f)
	var cs = f.cutscene
	var taken := false
	var black_ok := true
	var saw_sil := false
	var mended := false
	Engine.time_scale = 4.0
	while cs.running:
		var hu = cs.cast_of("hunahpu")
		var arm = f.scenery.get("arm_prop")
		if hu != null and hu.held != null and (arm == null or not arm.visible):
			taken = true
		if cs.backdrop_visible():
			saw_sil = true
			for c in cs.get("_cast").get_children():
				if not c.is_queued_for_deletion() and c.visible:
					black_ok = black_ok and c.modulate == Color.BLACK
		if hu != null and taken and hu.held == null and hu.rig.get("_arm").visible:
			mended = true
		await get_tree().process_frame
	Engine.time_scale = 1.0
	check(taken, "胡納普取下手臂（拿在手上、繩上沒有）")
	check(saw_sil and black_ok, "裝回時是剪影、替身全黑")
	check(mended, "裝回：手臂可見、道具收掉")
	await end_cs_fight(s)


func test_awaken_lines_match_card() -> void:
	var A = cs_file("awaken")
	if A == null:
		return
	var first: String = CardText.CARDS["awaken"].split("\n\n")[0]
	check(A.N1 + A.N2 == first, "取回、裝回兩句＝awaken 卡第一句（%s）" % first)


func test_cutscene_view_has_awaken() -> void:
	check(load("res://world/cutscene_view.gd").NAMES.has("awaken"), "--cutscene awaken")


## 宮殿裡的剪影：後牆半透明時，後面的小路區段不能透出來（剪影不震動，區段範圍不加震動邊距）
func test_palace_silhouette_hides_path() -> void:
	var s: Array = await cs_fight()
	var sv = s[0].scenery
	var cx: float = Palace.VIEW.get_center().x
	sv.set_silhouette(true)
	sv.update_region(cx)
	check(not sv.regions["boss_path"].visible and sv.regions["boss_palace"].visible, "剪影時鏡頭在宮殿：小路區段藏起")
	sv.set_silhouette(false)
	sv.update_region(cx)
	check(sv.regions["boss_path"].visible, "平常照舊（含震動邊距）")
	await end_cs_fight(s)


## 覺醒交還：真正的玩家（希巴拉克）站在替身最後的位置、同面向
func test_awaken_twin_continuous() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	await start_death(f)
	var last := {}
	Engine.time_scale = 8.0
	while f.cutscene.running:
		var xb = f.cutscene.cast_of("xbalanque")
		if xb != null:
			last = {"pos": xb.global_position, "facing": xb.facing}
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await frames(2)
	check(not last.is_empty() and absf(last.pos.x - f.player.position.x) <= 3.0 and last.facing == f.player.facing,
		"交還前後希巴拉克位置、面向一致（%s vs %s／%d）" % [last, f.player.position, f.player.facing])
	await end_cs_fight(s)


# ---- MV-SLICE-001c2c Task 4：閃回與能力名 ----

const FB_PATH := "res://world/cutscene/flashback.gd"


func flashbacks_in(cs) -> Array:
	var out := []
	if ResourceLoader.exists(FB_PATH):
		for n in cs.get("_ui").get_children():
			if not n.is_queued_for_deletion() and n.get_script() == load(FB_PATH):
				out.append(n)
	return out


func test_flashback_set() -> void:
	var F = cs_file("flashback")
	if F == null:
		return
	var fb: Control = F.make()
	add_child(fb)
	var texs := {}
	var shared := true
	for n in fb.find_children("*", "TextureRect", true, false):
		if n.texture is Texture2D and n.texture.resource_path != "":
			var k: String = n.texture.resource_path.get_file()
			texs[k] = texs.get(k, 0) + 1
			shared = shared and n.use_parent_material
	check(texs.get("bg_field_mid_01.png", 0) == 1 and texs.get("prop_field_bush.png", 0) == 2 and texs.get("prop_field_clod.png", 0) == 2, "田地背景、2 灌木、2 土塊（%s）" % texs)
	check(texs.get("wpn_axe.png", 0) == 1 and texs.get("wpn_digging_stick.png", 0) == 1, "斧頭、掘棒")
	check(fb.material is ShaderMaterial and shared, "暖褐 shader 掛在根節點、貼圖共用")
	fb.queue_free()


func test_awaken_shows_flashback_then_removes() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	await start_death(f)
	var cs = f.cutscene
	var fade: ColorRect = cs.get("_fade")
	var seen := false
	var white := false
	var titles := []
	var epithets := []
	Engine.time_scale = 6.0
	while cs.running:
		seen = seen or not flashbacks_in(cs).is_empty()
		white = white or (fade.color.r > 0.9 and fade.color.a > 0.5)
		if cs.title_label.modulate.a > 0.5 and not titles.has(cs.title_label.text):
			titles.append(cs.title_label.text)
			epithets.append(cs.epithet_label.text)
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await frames(2)
	check(seen and white, "演出中有閃回布景與白幕")
	check(flashbacks_in(cs).is_empty() and fade.color.a == 0.0, "交還後布景移除、白幕收掉")
	check(titles == ["讓工具自己動", "二段跳"] and epithets == ["希巴拉克覺醒", "胡納普覺醒"], "能力名（%s／%s）" % [titles, epithets])
	await end_cs_fight(s)


func test_flashback_skip_clears() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	await start_death(f)
	var cs = f.cutscene
	Engine.time_scale = 6.0
	var shown: bool = await wait_until(func(): return not flashbacks_in(cs).is_empty(), 4000)
	Engine.time_scale = 1.0
	check(shown, "等到閃回")
	await skip_all(cs)
	await frames(2)
	check(flashbacks_in(cs).is_empty() and cs.get("_fade").color.a == 0.0, "跳過：布景與白幕都清掉")
	await end_cs_fight(s)


func test_awaken_flashback_lines() -> void:
	var A = cs_file("awaken")
	if A == null:
		return
	var c: Dictionary = A.get_script_constant_map()
	check(c.get("N3") == "希巴拉克想起開墾田地的那一天：" and c.get("N4") == "斧頭自己砍倒了樹，掘棒自己翻開了土。", "閃回兩句")


# ---- MV-SLICE-001c2c Task 5：結尾與結束畫面 ----

const END_TEXT := "垂直切片到此結束，謝謝試玩。"  # MV-SLICE-001d2a：製作資訊與 AI 揭露搬到製作說明（test_d2a.test_credits_text_discloses）


func onto_ledge(f) -> void:
	f.player.velocity = Vector2.ZERO
	f.player.position = Vector2(Palace.EXIT_LEDGE.position.x + 200.0, Palace.EXIT_LEDGE.position.y)
	await frames(3)


func test_finale_plays_on_ledge() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	var done := [false]
	f.finished.connect(func(): done[0] = true)
	f.start_at(4)
	await frames(2)
	await onto_ledge(f)
	check(f.cutscene.running, "走上高台：播結尾演出")
	var card := false
	Engine.time_scale = 8.0
	while f.cutscene.running:
		card = card or f.card.visible
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await frames(2)
	check(not card and done[0], "沒有 clear 卡、結束後 finished")
	await end_cs_fight(s)


func finale_black(skip: bool) -> Array:
	var s: Array = await cs_fight()
	var f = s[0]
	var fade: ColorRect = f.cutscene.get("_fade")
	var at_finish := [Color(0, 0, 0, 0)]
	f.finished.connect(func(): at_finish[0] = fade.color)
	f.start_at(4)
	await frames(2)
	await onto_ledge(f)
	if skip:
		await skip_all(f.cutscene)
	else:
		Engine.time_scale = 8.0
		await wait_cs(f.cutscene)
		Engine.time_scale = 1.0
	var after := true
	for i in 3:
		await frames(1)
		after = after and fade.color == Color.BLACK
	await end_cs_fight(s)
	return [at_finish[0], after]


func test_finale_keeps_black() -> void:
	for skip in [false, true]:
		var r: Array = await finale_black(skip)
		check(r[0] == Color.BLACK and r[1], "%s：finished 時與之後都是黑畫面（%s）" % ["跳過" if skip else "看完", r[0]])


func test_finale_leaves_save_awakened() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	await awaken_now(f)
	await onto_ledge(f)
	await skip_all(f.cutscene)
	var st: Dictionary = Save.read(TEST_SAVE)
	check(st.get("awakened", false) and st.get("last_rest", "") == "palace_camp", "結尾不改存檔（%s）" % [st.get("last_rest")])
	await end_cs_fight(s)
	s = await cs_fight()
	f = s[0]
	await load_awakened(f, s[1])
	f.player.position = Vector2(Palace.ENTRY_X + 100.0, Palace.GROUND_Y)
	await frames(3)
	await onto_ledge(f)
	check(f.cutscene.running, "讀檔後再走上高台：再播一次結尾")
	await skip_all(f.cutscene)
	await end_cs_fight(s)


func test_finale_line() -> void:
	var F = cs_file("finale")
	if F == null:
		return
	check(F.N1 == "七金剛鸚鵡的驕傲被拿走了。", "結尾旁白")


func test_end_screen_text() -> void:
	check(load("res://world/ending.gd").TEXT == END_TEXT, "結束畫面文字")


func test_proto_clear_card() -> void:
	var f = BossFight.new()
	f.tn = fresh_tuning()
	f.tn.card_min_time = 0.0
	f.tester = "selftest"
	f.log_dir = TEST_LOG_DIR
	f.player_scripted = true
	add_child(f)
	await frames(3)
	f.start_at(4)
	f._finish()
	check(await wait_until(func(): return f.card.visible and f.card.text == CardText.CARDS["clear"], 30), "原型：照舊 clear 卡")
	f.card.confirm()
	await free_fight(f)


func test_cutscene_view_has_finale() -> void:
	check(load("res://world/cutscene_view.gd").NAMES.has("finale"), "--cutscene finale")


# ---- MV-SLICE-001c2c 最終審查的修正 ----

## 死亡一開始就跳過：覺醒段開始時舞台已是死亡的結果（他倒下、光點熄滅、老人離開、奇瑪瑪特不在、最暗）
func test_death_skip_settles_stage() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	await start_death(f)
	var cs = f.cutscene
	Input.action_press(&"pause")
	await wait_until(func(): return cs.skipped, 200)
	await wait_until(func(): return not cs.skipped and cs.running, 200)
	Input.action_release(&"pause")
	await frames(2)  # 光點熄滅在下一個物理幀生效
	var macaw = cs.cast_of("sevenmacaw")
	check(cs.cast_of("healer_man") == null and cs.cast_of("healer_woman") == null, "老人已離開")
	check(macaw != null and macaw.anim == "collapse" and macaw.pose_time() >= macaw.anim_length("collapse") - 0.01, "他倒在地上（%s）" % [macaw.anim if macaw != null else null])
	var g = macaw.find_children("*", "", false, false).filter(func(n): return n.has_method("lit_count")) if macaw != null else []
	check(not g.is_empty() and g[0].lit_count() == 0, "身上光點已熄滅")
	check(chimalmat_of(f).modulate.a == 0.0, "奇瑪瑪特不在")
	var d3: float = Scenery.DARKNESS[3]
	check(f.scenery.modulate.is_equal_approx(Color(d3, d3, d3)), "場景最暗（%s）" % f.scenery.modulate)
	await skip_all(cs)
	await end_cs_fight(s)


## 覺醒後閘門開著：往左走回小路，鏡頭仍跟著角色
func test_exit_camera_follows_left() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	f.start_at(4)
	await frames(2)
	f.player.position = Vector2(14684, Palace.GROUND_Y)  # 覺醒交還的位置：鏡頭仍限制在宮殿（交還不跳）
	f.player.velocity = Vector2.ZERO
	f.camera.reset_smoothing()
	await frames(5)
	check(f.camera.get_screen_center_position().x >= Palace.LEFT + 959.0, "在宮殿裡：鏡頭左界仍是宮殿入口（%.0f）" % f.camera.get_screen_center_position().x)
	f.player.position = Vector2(13500, Palace.GROUND_Y)
	f.player.velocity = Vector2.ZERO
	f.camera.reset_smoothing()
	await frames(5)
	var cx: float = f.camera.get_screen_center_position().x
	check(absf(cx - f.player.position.x) < 960.0, "鏡頭看得到角色（中心 %.0f、角色 %.0f）" % [cx, f.player.position.x])
	await end_cs_fight(s)


# ---- MV-SLICE-001d1b：Boss 過場的動作音效 ----

func _cnt(id: StringName) -> int:
	return Audio.play_count.get(id, 0)


func _snap(ids: Array) -> Dictionary:
	var d := {}
	for id in ids:
		d[id] = _cnt(id)
	return d


func _check_grew(before: Dictionary, what: String) -> void:
	for id in before:
		check(_cnt(id) > before[id], "%s：%s 有播" % [what, id])


func test_boss_cutscene_sounds() -> void:
	var s: Array = await cs_fight()
	var f = s[0]
	var b := _snap([&"cs_grass_crouch"])
	await enter_nance(f)
	Engine.time_scale = 8.0
	await wait_cs(f.cutscene)
	Engine.time_scale = 1.0
	_check_grew(b, "開場")
	await end_cs_fight(s)
	s = await cs_fight()
	f = s[0]
	b = _snap([&"cs_macaw_fall", &"cs_wing_wrench", &"cs_sit_fall"])
	await start_arm(f)
	Engine.time_scale = 8.0
	await wait_cs(f.cutscene)
	Engine.time_scale = 1.0
	_check_grew(b, "斷臂")
	await end_cs_fight(s)
	s = await cs_fight()
	f = s[0]
	b = _snap([&"cs_teeth_swap"])
	await start_teeth(f)
	Engine.time_scale = 8.0
	await wait_cs(f.cutscene)
	Engine.time_scale = 1.0
	_check_grew(b, "換牙")
	await end_cs_fight(s)
	s = await cs_fight()
	f = s[0]
	b = _snap([&"cs_gem_pluck", &"cs_jewels_gather", &"cs_arm_restore"])
	await start_death(f)
	Engine.time_scale = 8.0
	while f.cutscene.running:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_check_grew(b, "死亡＋覺醒")
	await end_cs_fight(s)
