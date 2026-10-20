extends "res://tests/base_test.gd"
# 從 prototypes/core/tests/self_test.gd 搬來（MV-SLICE-001a Task 1）。

# ---- MV-PROTO-002 Task 9：HUD、佔位音效 ----

func test_p2_sfx_complete() -> void:
	var bank := Sfx.build_all()
	for s in [&"swap", &"parry", &"double_jump", &"tool_out", &"chop", &"barrier_break", &"thud"]:
		check(bank.has(s) and bank[s].data.size() > 0, "缺少或空白的佔位音效 %s" % s)


func test_hud_twin_lines() -> void:
	var w := make_world()
	var p = await make_player(w)
	var hud = Hud.new()
	hud.player = p
	w.add_child(hud)
	var lines: PackedStringArray = hud.twin_lines()
	check(lines.size() == 2 and lines[0].contains("胡納普") and lines[0].contains("斧頭") and lines[1].contains("希巴拉克") and lines[1].contains("球具"), "HUD 兩行應顯示兩兄弟與武器，實際 %s" % [lines])
	p.set_weapon(Weapons.Weapon.STICK)
	check(hud.twin_lines()[0].contains("掘棒"), "改武器後 HUD 應更新")
	await free_world(w)


# ---- MV-PROTO-003 Task 9：文字卡、開頭選單、HUD ----

func test_card_ignores_confirm_before_min_time() -> void:
	var c = TextCard.new()
	add_child(c)
	var closed := []
	c.closed.connect(func(): closed.append(true))
	c.show_card(CardText.CARDS["arm"])
	check(c.visible, "顯示文字卡")
	c.confirm()
	check(c.visible and closed.is_empty(), "顯示不到 0.5 秒時不接受確認（避免狂按攻擊直接跳過）")
	await frames(35)
	c.confirm()
	c.confirm()
	check(not c.visible and closed.size() == 1, "0.5 秒後確認關閉，只發一次")
	c.queue_free()
	await frames(1)


func test_card_texts_complete_without_gameplay_hints() -> void:
	for k in ["arm", "couple", "toothache", "teeth", "death", "awaken", "clear"]:
		check(CardText.CARDS.has(k) and not String(CardText.CARDS[k]).is_empty(), "缺文字卡 %s" % k)
	for k in CardText.CARDS:
		for word in ["破綻", "設局", "光源", "微亮", "最亮", "吹箭", "背對", "二段跳", "弱點"]:
			check(not String(CardText.CARDS[k]).contains(word), "文字卡 %s 不應提示玩法（%s）" % [k, word])


func test_hud_armless_and_boss_fields() -> void:
	var w := make_world()
	var p = await make_player(w)
	var hud = Hud.new()
	hud.player = p
	add_child(hud)
	p.twins[0].weapon_enabled = false
	check(hud.twin_lines()[0] == "胡納普　—", "斷臂時武器欄顯示「—」，實際 %s" % hud.twin_lines()[0])
	hud.boss_name = CardText.BOSS_NAME
	hud.boss_segments = 2
	hud.boss_gauge = 0.5
	hud.show_hint = false
	await frames(2)
	hud.queue_free()
	await free_world(w)


func test_fight_starts_at_tree_rest() -> void:
	var f = await make_fight()
	check(f.stage == BossFight.Stage.APPROACH and f.phase == 1, "從第 1 段的接近開始")
	check(f.player.position.distance_to(Nance.REST) < 50.0, "角色在樹下篝火")
	check(not f.nance.gate_closed and not f.palace.gate_closed, "兩個入口一開始都打開")
	check(f.boss.position.is_equal_approx(Nance.CANOPY) and f.boss.state == Macaw.State.DOWN, "Boss 停在樹冠、不出招")
	check(FileAccess.file_exists(f.log.path_base + ".jsonl"), "開戰就建立日誌")
	await free_fight(f)


func test_fight_entry_closes_gate_and_plays_intro() -> void:
	var f = await make_fight()
	f.player.position = Vector2(Nance.ENTRY_X + 50.0, Nance.GROUND_Y)
	await frames(3)
	check(f.nance.gate_closed and f.stage == BossFight.Stage.INTRO and f.player_locked, "進場：入口關上、開場、角色不能操作")
	check(f.hud.boss_name == "", "開場時還沒有名字與血條")
	var lit: bool = await wait_until(func(): return f.boss.light.state == Light.State.GLOW, 90)
	check(lit and f.boss.position.distance_to(Nance.PERCH) < 4.0, "開場：降到低枝、下顎微亮")
	var fought: bool = await wait_until(func(): return f.stage == BossFight.Stage.FIGHT, 400)
	check(fought and not f.player_locked and f.hud.boss_name == CardText.BOSS_NAME, "開場後開打、名字與血條出現")
	check(f.boss.position.is_equal_approx(Nance.CANOPY), "開場結束回到樹冠")
	check(log_types(f) == ["attempt_start"], "開打記 attempt_start，實際 %s" % [log_types(f)])
	await free_fight(f)


func test_fight_summons_fill_to_cap() -> void:
	var f = await make_fight(1)
	f.fill_summons(1)
	f.fill_summons(1)
	await frames(2)
	check(count_of(f.world, Crawler) == 1 and count_of(f.world, Flyer) == 1, "第 1 段各補到 1 隻、不重複")
	f.fill_summons(2)
	await frames(2)
	check(count_of(f.world, Crawler) == 2 and count_of(f.world, Flyer) == 2 and f.boss.summons.size() == 4, "第 3 段各補到 2 隻")
	await free_fight(f)


func test_fight_gauge_full_swaps_to_hunahpu() -> void:
	var f = await make_fight(1)
	f.player.swap_twin()
	await frames(1)
	f.debug_fill_gauge()
	await frames(2)
	check(f.player.twin_index == 0 and f.boss.state == Macaw.State.BROKEN, "破綻滿：自動換成 Hunahpu、Boss 硬直")
	check(log_types(f).has("gauge_full"), "記 gauge_full")
	await free_fight(f)


func test_fight_flash_whiteouts_only_facing() -> void:
	var f = await make_fight(1)
	f.player.facing = 1
	f.boss.flashed.emit()
	check(f.whiteout.is_active() and f.player.health.hp == 5, "面向 Boss → 白茫、不扣血")
	f.whiteout.stop()
	f.player.facing = -1
	f.boss.flashed.emit()
	check(not f.whiteout.is_active(), "背對 → 沒事")
	check(log_types(f).count("whiteout") == 1, "白茫記一次")
	await free_fight(f)


func test_fight_card_freezes_world() -> void:
	var f = await make_fight(1)
	var p = f.player
	p.intent.move_x = 1.0
	f.show_card("arm")
	var x: float = p.position.x
	await frames(10)
	check(f.world.process_mode == Node.PROCESS_MODE_DISABLED and is_equal_approx(p.position.x, x), "文字卡顯示時戰場暫停")
	f.card.confirm()
	await frames(10)
	check(f.world.process_mode == Node.PROCESS_MODE_INHERIT and p.position.x > x, "關閉後恢復")
	await free_fight(f)


func test_fight_background_darkens_per_light() -> void:
	for i in 3:
		check(BossFight.BG_LEVELS[i + 1].get_luminance() < BossFight.BG_LEVELS[i].get_luminance(), "背景每一階都更暗（%d → %d）" % [i, i + 1])
	var f = await make_fight(3)
	check(f.lights_removed == 2 and f.background_color() == BossFight.BG_LEVELS[2], "第 3 段是戰鬥中最暗的一階")
	await free_fight(f)


func test_retry_table_and_rest_points() -> void:
	check(BossFight.retry_phase(1, false) == 1 and BossFight.retry_phase(1, true) == 1, "死在第 1 段 → 第 1 段")
	check(BossFight.retry_phase(2, false) == 2 and BossFight.retry_phase(2, true) == 2, "死在第 2 段 → 第 2 段")
	check(BossFight.retry_phase(3, false) == 2, "死在第 3 段、預設 → 第 2 段")
	check(BossFight.retry_phase(3, true) == 3, "死在第 3 段、段落保留 → 第 3 段")
	check(BossFight.rest_point(1) == Nance.REST and BossFight.rest_point(2) == Palace.REST and BossFight.rest_point(3) == Palace.REST, "篝火位置")


func test_setup_phase1_goes_to_path_and_palace() -> void:
	var f = await make_fight(1)
	var p = f.player
	f.fill_summons(1)
	await setup_now(f)
	check(await next_card(f, "arm"), "第 1 段設局 → 斷臂文字卡")
	check(await next_card(f, "couple"), "接著請老夫婦同行")
	check(f.stage == BossFight.Stage.APPROACH and f.phase == 2 and f.lights_removed == 1, "進入小路、下一段是第 2 段")
	check(p.position.distance_to(Palace.PATH_START) < 50.0 and f.couple_following, "在小路起點、老夫婦跟著")
	check(not p.twins[0].weapon_enabled and not p.abilities_enabled, "Hunahpu 斷臂、能力仍停用")
	check(f.boss.summons.is_empty() and count_of(f.world, Crawler) == 0, "設局清空召喚的造物")
	p.position = Vector2(Palace.ENTRY_X + 50.0, Palace.GROUND_Y)
	await wait_until(func(): return f.card.visible, 10)
	check(await next_card(f, "toothache"), "第一次進宮殿 → 牙痛文字卡")
	check(f.stage == BossFight.Stage.FIGHT and f.palace.gate_closed and f.boss.phase == 2, "第 2 段開打、入口關上")
	await free_fight(f)


func test_setup_phase2_and_3_then_awaken() -> void:
	var f = await make_fight(2)
	var p = f.player
	await setup_now(f)
	check(await next_card(f, "teeth"), "第 2 段設局 → 換牙文字卡")
	check(f.stage == BossFight.Stage.FIGHT and f.phase == 3 and f.boss.phase == 3, "直接進第 3 段")
	check(log_types(f).count("attempt_start") == 2, "第 3 段開打也記 attempt_start")
	await setup_now(f)
	check(await next_card(f, "death"), "第 3 段設局 → 死亡文字卡")
	check(await next_card(f, "awaken"), "接著取回手臂、覺醒")
	check(f.stage == BossFight.Stage.EXIT and f.lights_removed == 3, "進入結尾出口")
	check(p.twins[0].weapon_enabled and p.abilities_enabled, "Hunahpu 武器恢復、兩項能力解鎖")
	check(not f.boss.visible, "Boss 已倒下")
	check(f.hud.notice == BossFight.EXIT_HINT_BARRIER, "覺醒後先提示破木障，實際「%s」" % f.hud.notice)
	await free_fight(f)


## MV-SLICE-001c2c：提示做到才換，不限時
func test_exit_hints_until_done() -> void:
	var f = await make_fight(4)
	check(f.hud.notice == BossFight.EXIT_HINT_BARRIER, "直接進出口：先提示破木障")
	f.palace.barrier.break_apart()
	await frames(2)
	check(f.hud.notice.contains("二段跳"), "木障碎了：二段跳提示")
	await frames(7 * 60)
	check(f.hud.notice.contains("二段跳"), "7 秒後仍在")
	await free_fight(f)


func test_death_returns_to_rest_by_table() -> void:
	var f = await make_fight(3)
	await kill_player(f, "beam")
	check(f.phase == 2 and f.lights_removed == 1 and f.stage == BossFight.Stage.APPROACH, "死在第 3 段（預設）→ 第 2 段")
	check(f.player.position.distance_to(Palace.REST) < 50.0 and f.player.health.hp == 5, "回宮殿篝火、血量補滿")
	check(not f.palace.gate_closed, "入口重新打開")
	var last: Dictionary = f.log.events[f.log.events.size() - 1]
	check(last.type == "death" and last.phase == 3 and last.by == "beam", "日誌記下死在第 3 段、死因 beam，實際 %s" % [last])
	await free_fight(f)
	f = await make_fight(0)
	f.keep_phase = true
	f.start_at(3)
	await frames(2)
	await kill_player(f, "beam")
	check(f.phase == 3 and f.lights_removed == 2, "段落保留開 → 仍從第 3 段")
	f.player.position = Vector2(Palace.ENTRY_X + 50.0, Palace.GROUND_Y)
	await frames(3)
	check(f.stage == BossFight.Stage.FIGHT and not f.card.visible and f.boss.phase == 3, "重試直接開打第 3 段，不再顯示文字卡")
	await free_fight(f)


func test_reset_area_keeps_phase_without_death() -> void:
	var f = await make_fight(3)
	f.reset_area()
	await frames(2)
	check(f.phase == 3 and f.stage == BossFight.Stage.APPROACH, "F10：同一段重來，不退回第 2 段")
	check(f.player.position.distance_to(Palace.REST) < 50.0, "回宮殿篝火")
	check(not log_types(f).has("death"), "F10 不記死亡")
	await free_fight(f)


func test_retry_skips_intro() -> void:
	var f = await make_fight()
	f.player.position = Vector2(Nance.ENTRY_X + 50.0, Nance.GROUND_Y)
	await wait_until(func(): return f.stage == BossFight.Stage.FIGHT, 400)
	await kill_player(f, "dive")
	check(f.player.position.distance_to(Nance.REST) < 50.0, "死在第 1 段 → 樹下篝火")
	f.player.position = Vector2(Nance.ENTRY_X + 50.0, Nance.GROUND_Y)
	await frames(3)
	check(f.stage == BossFight.Stage.FIGHT, "重試跳過開場")
	await free_fight(f)


func test_death_during_break_resets_boss() -> void:
	var f = await make_fight(1)
	f.player.swap_twin()
	f.debug_fill_gauge()
	await frames(2)
	await kill_player(f, "dive")
	check(f.boss.state == Macaw.State.DOWN and f.boss.light.state == Light.State.OFF and f.boss.gauge.value == 0, "重試：Boss 回到該段開頭、光源熄滅、破綻 0")
	check(f.player.twin_index == 0, "回到 Hunahpu")
	await free_fight(f)


func test_exit_robot_uses_new_abilities() -> void:
	var f = await make_fight(4)
	var p = f.player
	p.facing = 1
	await drive(p, [{"frames": 1, "swap": true}, {"frames": 25}, {"frames": 1, "dart": true}])
	var broke: bool = await wait_until(func(): return f.palace.barrier.is_broken, 150)
	check(broke, "覺醒後 Xbalanque 的工具能砍開出口木障")
	await drive(p, [{"frames": 1, "swap": true}, {"frames": 25}])
	p.intent.move_x = 1.0
	await wait_until(func(): return p.position.x >= Palace.EXIT_LEDGE.position.x - 150.0, 120)
	await drive(p, CLIMB)
	var done: bool = await wait_until(func(): return f.card.visible, 30)
	check(done and f.stage == BossFight.Stage.DONE and f.card.text == CardText.CARDS["clear"], "Hunahpu 二段跳上出口 → 通關文字卡")
	check(FileAccess.file_exists(f.log.path_base + ".md") and log_types(f).back() == "clear", "通關寫入摘要")
	await free_fight(f)


func test_fight_quit_writes_summary() -> void:
	var f = await make_fight(1)
	var base: String = f.log.path_base
	f.queue_free()
	await frames(2)
	check(FileAccess.file_exists(base + ".md"), "中途離開也寫摘要")
	var lines := FileAccess.get_file_as_string(base + ".jsonl").strip_edges().split("\n")
	var last = JSON.parse_string(lines[lines.size() - 1])
	check(last != null and last.type == "quit", "最後一筆是 quit")
	remove_test_logs()

