extends "res://tests/base_test.gd"
# 從 prototypes/core/tests/self_test.gd 搬來（MV-SLICE-001a Task 1）。

# ---- MV-PROTO-003 Task 1：數值、角色開關、按鍵 ----

func test_p3_tuning_defaults() -> void:
	var t := fresh_tuning()
	check(t.gauge_max == 100 and t.gauge_melee == 8 and t.gauge_parry == 15 and t.gauge_dart_interrupt == 10 and t.gauge_glow_hit == 12, "破綻量 100／8／15／10／12")
	check(is_equal_approx(t.boss_stagger_time, 4.0) and t.gauge_miss_reset == 50, "硬直 4 秒、錯過退回 50")
	check(is_equal_approx(t.boss_interrupt_stagger, 0.6), "吹箭打斷硬直 0.6")
	check(is_equal_approx(t.whiteout_in, 0.3) and is_equal_approx(t.whiteout_hold, 1.4) and is_equal_approx(t.whiteout_out, 0.3), "白茫 0.3／1.4／0.3")
	check(t.phase1_cycle == ["summon", "throw_fruit", "eat_fruit", "throw_fruit", "eat_fruit", "false_flash", "dive"], "第 1 段循環：假光閃耀後緊接俯衝（白茫時看不到前搖）")
	check(t.phase2_cycle == ["flail", "wail", "throne_charge", "wail"], "第 2 段循環")
	check(t.phase3_cycle == ["summon", "stagger_pounce", "beam", "stagger_pounce", "beam"], "第 3 段循環")
	check(t.summon_cap_p1 == 1 and t.summon_cap_p3 == 2 and t.pillar_count == 3, "召喚上限 1／2、反光柱 3 道")
	check(Tune.table(t).contains("| Boss | gauge_max | 100 |"), "數值表應有 Boss 群組")


func test_armless_hunahpu_cannot_attack_but_darts() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.twins[0].weapon_enabled = false
	p.intent.attack_pressed = true
	await frames(2)
	check(p.state == Player.State.FREE, "武器槽停用時攻擊鍵無效")
	p.intent.dart_pressed = true
	await frames(1)
	check(count_darts(w) == 1, "武器槽停用時吹箭照常")
	p.swap_twin()
	await frames(1)
	p.intent.attack_pressed = true
	await frames(2)
	check(p.state == Player.State.PARRY, "Xbalanque 的攻擊照常（球具招架）")
	await free_world(w)


func test_abilities_disabled_blocks_double_jump_and_tool() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.abilities_enabled = false
	p.intent.jump_pressed = true
	p.intent.jump_held = true
	await frames(10)
	p.intent.jump_pressed = true
	await frames(1)
	check(not p.air_jump_used, "能力停用時不能二段跳")
	p.intent.jump_held = false
	await wait_until(func(): return p.is_on_floor(), 120)
	var b = make_barrier(w)
	p.swap_twin()
	await frames(25)
	p.intent.dart_pressed = true
	await frames(30)
	check(not is_instance_valid(p.tool) and not b.is_broken, "能力停用時 Xbalanque 的飛鏢不會派出工具")
	p.abilities_enabled = true
	await frames(25)
	p.intent.dart_pressed = true
	var broke: bool = await wait_until(func(): return b.is_broken, 120)
	check(broke, "能力開啟後照常派工具")
	await free_world(w)


func test_force_twin_ignores_cooldown_and_keeps_roll() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.swap_twin()
	check(p.swap_cooldown_left > 0.0, "前提：剛換完人、冷卻中")
	p.force_twin(0)
	check(p.twin_index == 0, "強制換人不受冷卻限制")
	p.swap_twin()
	p.intent.roll_pressed = true
	await frames(2)
	p.force_twin(0)
	check(p.twin_index == 0 and p.state == Player.State.ROLL, "翻滾中強制換人不打斷翻滾")
	await free_world(w)


func test_last_hurt_source_recorded() -> void:
	var w := make_world()
	var p = await make_player(w)
	var src := Node2D.new()
	w.add_child(src)
	p.hurtbox.receive(1, src, &"enemy")
	check(p.last_hurt_source == src, "應記下最後打中角色的來源")
	await free_world(w)


# ---- MV-PROTO-003 Task 2：破綻條、光源、飛鏢打光源 ----

func test_break_gauge_rules() -> void:
	var g = BreakGauge.new()
	check(not g.add(8, 100) and g.value == 8, "近戰 +8")
	g.add(15, 100)
	g.add(10, 100)
	g.add(12, 100)
	check(g.value == 45, "各來源累加應為 45，實際 %d" % g.value)
	g.value = 95
	check(g.add(8, 100), "加到上限應回傳滿")
	check(g.value == 100, "不超過上限")
	check(not g.add(8, 100) and g.value == 100, "滿了之後不累積、不再回傳滿")
	g.miss(50)
	check(g.value == 50, "錯過退回 50")
	g.clear()
	check(g.value == 0, "換段歸 0")


func test_light_effect_table() -> void:
	check(Light.effect(Light.State.OFF, true) == Light.Effect.NONE, "熄滅：沒有效果")
	check(Light.effect(Light.State.GLOW, false) == Light.Effect.GLOW_HIT, "微亮：誰的箭都算微亮命中")
	check(Light.effect(Light.State.BRIGHT, true) == Light.Effect.SETUP, "最亮＋Hunahpu 的箭：設局")
	check(Light.effect(Light.State.BRIGHT, false) == Light.Effect.NONE, "最亮＋Xbalanque 的箭：沒有效果")


func test_dart_passes_off_light_to_body() -> void:
	var w := make_world()
	var p = await make_player(w)
	var a := make_fake_boss(w, 600.0)
	await frames(2)
	p.intent.dart_pressed = true
	await frames(25)
	check(a[2] == [["body", &"dart"]], "熄滅的光源不擋飛鏢，打到身體，實際 %s" % [a[2]])
	await free_world(w)


func test_dart_hits_glowing_light_before_body() -> void:
	var w := make_world()
	var p = await make_player(w)
	var a := make_fake_boss(w, 600.0)
	a[1].set_state(Light.State.GLOW)
	await frames(2)
	p.intent.dart_pressed = true
	await frames(25)
	check(a[2] == [["light", true]], "微亮的光源比身體先被打到，且 Hunahpu 的箭能觸發設局，實際 %s" % [a[2]])
	await free_world(w)


func test_dart_setup_flag_decided_at_fire() -> void:
	var w := make_world()
	var p = await make_player(w)
	var a := make_fake_boss(w, 900.0)
	a[1].set_state(Light.State.BRIGHT)
	p.swap_twin()
	await frames(25)
	p.intent.dart_pressed = true
	await frames(1)
	p.swap_twin()
	await frames(30)
	check(p.twin_index == 0, "前提：飛行中已換回 Hunahpu")
	check(a[2] == [["light", false]], "Xbalanque 射出的箭飛行中換人，仍不能觸發設局，實際 %s" % [a[2]])
	await free_world(w)


func test_melee_cannot_hit_light() -> void:
	var w := make_world()
	var p = await make_player(w)
	var a := make_fake_boss(w, 150.0)
	a[1].set_state(Light.State.GLOW)
	await frames(2)
	p.intent.attack_pressed = true
	await frames(20)
	check(a[2] == [["body", &"melee"]], "近戰只打到身體、打不到光源，實際 %s" % [a[2]])
	await free_world(w)


# ---- MV-PROTO-003 Task 3：場地 ----

## 從高台左緣前 150 px 起跑 → 跳 → 空中再按跳（同 test_explore_ledge1_needs_double_jump）
func test_nance_canopy_out_of_melee_reach() -> void:
	var t := fresh_tuning()
	var reach := t.jump_height + Player.SIZE.y + maxf(t.axe_up_box.y, t.stick_up_box.y)
	var canopy := Nance.GROUND_Y - Nance.CANOPY.y
	check(canopy > reach, "樹冠（離地 %.0f）應高於近戰最高點 %.0f" % [canopy, reach])


func test_nance_branch_single_jump() -> void:
	var s: Array = await arena_setup(Nance, Vector2(Nance.BRANCH.position.x - 150.0, Nance.GROUND_Y))
	var p = s[2]
	p.abilities_enabled = false
	p.intent.move_x = 1.0
	p.intent.jump_pressed = true
	p.intent.jump_held = true
	await frames(30)
	p.intent.move_x = 0.0
	await frames(30)
	check(p.is_on_floor() and absf(p.position.y - Nance.BRANCH.position.y) < 2.0, "單跳應能站上低枝，實際 %s" % p.position)
	await free_world(s[0])


func test_arena_gate_blocks_after_close() -> void:
	var s: Array = await arena_setup(Nance, Vector2(Nance.LEFT + 200.0, Nance.GROUND_Y))
	s[1].close_gate()
	await frames(2)
	var p = s[2]
	p.intent.move_x = -1.0
	await frames(40)
	check(p.position.x > Nance.LEFT + 40.0, "入口關上後走不回去，實際 x=%.0f" % p.position.x)
	s[1].open_gate()
	await frames(40)
	check(p.position.x < Nance.LEFT, "打開後可以通過，實際 x=%.0f" % p.position.x)
	await free_world(s[0])


func test_palace_barrier_is_right_wall() -> void:
	var s: Array = await arena_setup(Palace, Vector2(Palace.RIGHT - 300.0, Palace.GROUND_Y))
	var p = s[2]
	p.intent.move_x = 1.0
	await frames(40)
	check(p.position.x < Palace.BARRIER.position.x, "出口木障擋住通道，實際 x=%.0f" % p.position.x)
	check(not s[1].barrier.is_broken, "木障一開始完好")
	await free_world(s[0])


func test_palace_exit_needs_double_jump() -> void:
	var start := Vector2(Palace.EXIT_LEDGE.position.x - 150.0, Palace.GROUND_Y)
	var s: Array = await arena_setup(Palace, start)
	var p = s[2]
	p.abilities_enabled = false
	await drive(p, CLIMB)
	check(not Palace.on_exit(p.position), "能力停用時上不了出口高台，實際 %s" % p.position)
	p.position = start
	p.velocity = Vector2.ZERO
	p.abilities_enabled = true
	await frames(3)
	await drive(p, CLIMB)
	check(Palace.on_exit(p.position), "二段跳應能上出口高台，實際 %s" % p.position)
	await free_world(s[0])


func test_pillar_positions() -> void:
	var xs: Array = Palace.pillar_xs(3, 14800.0)
	check(xs.size() == 3 and is_equal_approx(xs[0], 14800.0), "3 道、第一道在角色位置")
	check(is_equal_approx(xs[1], Palace.LEFT + 640.0) and is_equal_approx(xs[2], Palace.LEFT + 1280.0), "其餘在固定位置，實際 %s" % [xs])


# ---- MV-PROTO-003 Task 4：Boss 主體、召喚、擲果 ----

func test_cycle_next_rules() -> void:
	var known := {"summon": 1, "a": 1, "b": 1}
	var c: Array[String] = ["summon", "a", "b"]
	check(Macaw.next_in_cycle(c, 0, false, known) == ["summon", 1], "沒有造物時照順序出召喚")
	check(Macaw.next_in_cycle(c, 0, true, known) == ["a", 2], "場上有造物時跳過召喚")
	check(Macaw.next_in_cycle(c, 2, true, known) == ["b", 0], "到尾回到開頭")
	check(Macaw.next_in_cycle(["typo", "a"], 0, false, known) == ["a", 0], "未知名稱跳過")
	check(Macaw.next_in_cycle(["typo"], 0, false, known)[0] == "", "整圈都出不了招回傳空字串")
	check(Macaw.next_in_cycle([], 0, false, known)[0] == "", "空循環回傳空字串")


func test_boss_cycle_runs_in_order() -> void:
	var s: Array = await boss_setup(1)
	var b = s[2]
	var names := []
	b.move_started.connect(func(n): names.append(n))
	b.cycle_enabled = true
	b.begin_phase(1)
	await frames(150)
	check(names.size() >= 2 and names[0] == "summon" and names[1] == "throw_fruit", "第 1 段依循環先召喚再擲果，實際 %s" % [names])
	await free_world(s[0])


func test_boss_phase_home_and_light_position() -> void:
	var s: Array = await boss_setup(2)
	var b = s[2]
	check(b.position.is_equal_approx(Palace.HOME), "第 2 段從宮殿的起始位置開始")
	check(b.facing == -1, "面向角色（在左邊）")
	check(b.light.position.is_equal_approx(Macaw.LIGHT_OFFSETS[1] * Vector2(-1, 1)), "光源在玉牙的位置，實際 %s" % b.light.position)
	check(b.light.state == Light.State.OFF, "換段後光源熄滅")
	await free_world(s[0])


func test_boss_gauge_from_melee_only_when_damaging() -> void:
	var s: Array = await boss_setup(1)
	var b = s[2]
	b.hurtbox.receive(4, s[1], &"melee")
	check(b.gauge.value == 8, "近戰命中 +8，實際 %d" % b.gauge.value)
	b.hurtbox.receive(0, s[1], &"melee")
	check(b.gauge.value == 8, "傷害 0 的近戰不累積")
	b.hurtbox.receive(1, null, &"dart")
	check(b.gauge.value == 8, "不在前搖時射中身體不累積")
	check(b.phase == 1, "近戰與吹箭不會打掉血條")
	await free_world(s[0])


func test_boss_break_stagger_and_miss() -> void:
	var s: Array = await boss_setup(1)
	var b = s[2]
	var got := []
	b.gauge_filled.connect(func(): got.append("full"))
	b.window_missed.connect(func(): got.append("miss"))
	b.add_gauge(100)
	check(b.state == Macaw.State.BROKEN and b.light.state == Light.State.BRIGHT, "滿了 → 硬直、光源最亮")
	b.hurtbox.receive(4, s[1], &"melee")
	check(b.gauge.value == 100, "硬直中命中不累積")
	await frames(228)
	check(b.state == Macaw.State.BROKEN, "硬直應持續 4 秒")
	await frames(20)
	check(b.state != Macaw.State.BROKEN and b.gauge.value == 50 and b.light.state == Light.State.OFF, "錯過 → 破綻 50、熄滅、恢復行動")
	check(got == ["full", "miss"], "訊號順序，實際 %s" % [got])
	await free_world(s[0])


func test_boss_setup_only_by_setup_dart_on_bright() -> void:
	var s: Array = await boss_setup(1)
	var b = s[2]
	var got := []
	b.setup_succeeded.connect(func(ph): got.append(ph))
	var x := fake_dart(false)
	var h := fake_dart(true)
	b.light.receive(1, h, &"dart")
	check(got.is_empty(), "熄滅時射中沒有效果")
	b.add_gauge(100)
	b.light.receive(1, x, &"dart")
	check(got.is_empty() and b.state == Macaw.State.BROKEN, "最亮時 Xbalanque 的箭沒有效果")
	b.light.receive(1, h, &"dart")
	check(got == [1] and b.state == Macaw.State.DOWN, "最亮時 Hunahpu 的箭 → 設局成功、Boss 停止行動")
	x.free()
	h.free()
	await free_world(s[0])


func test_boss_summon_cap_and_not_interruptible() -> void:
	var caps := []
	for ph in [1, 3]:
		var s: Array = await boss_setup(ph)
		var b = s[2]
		b.summon_requested.connect(func(cap): caps.append(cap))
		b.start_move("summon")
		await frames(5)
		b.hurtbox.receive(1, null, &"dart")
		check(b.state == Macaw.State.MOVE, "召喚的前搖不能用射身體打斷")
		await wait_until(func(): return caps.size() == (1 if ph == 1 else 2), 60)
		await free_world(s[0])
	check(caps == [1, 2], "召喚上限：第 1 段 1、第 3 段 2，實際 %s" % [caps])


func test_throw_fruit_interrupt_and_cooldown() -> void:
	var s: Array = await boss_setup(1)
	var b = s[2]
	b.start_move("throw_fruit")
	await wait_until(func(): return b.move != null and b.move.telegraphing, 30)
	b.hurtbox.receive(1, null, &"dart")
	check(b.state == Macaw.State.INTERRUPTED and b.gauge.value == 10, "前搖中射中身體 → 打斷、破綻 +10")
	await frames(45)
	check(count_of(s[0], Fruit) == 0, "被打斷就不擲果")
	check(b.state == Macaw.State.GAP, "0.6 秒後恢復")
	b.start_move("throw_fruit")
	await wait_until(func(): return b.move != null and b.move.telegraphing, 30)
	b.hurtbox.receive(1, null, &"dart")
	check(b.state == Macaw.State.MOVE and b.gauge.value == 10, "3 秒冷卻內再射中不打斷")
	await free_world(s[0])


func test_throw_fruit_parried_shatters() -> void:
	var s: Array = await boss_setup(1)
	var p = s[1]
	var b = s[2]
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	b.start_move("throw_fruit")
	var fruit = null
	for i in 120:
		for c in s[0].get_children():
			if c is Fruit:
				fruit = c
		if fruit != null:
			break
		await frames(1)
	check(fruit != null, "前搖結束應擲出果子")
	await wait_until(func(): return not is_instance_valid(fruit) or fruit.global_position.distance_to(p.global_position + Vector2(0, -90)) < 200.0, 120)
	p.intent.attack_pressed = true
	var gone: bool = await wait_until(func(): return not is_instance_valid(fruit), 30)
	check(gone and p.health.hp == 5, "招架成功：果子碎掉、不受傷")
	check(b.gauge.value == 15, "擋下果子破綻 +15，實際 %d" % b.gauge.value)
	check(parry_totals(p).successes == 1, "記一筆招架成功")
	await free_world(s[0])


# ---- MV-PROTO-003 Task 5：第 1 段其餘招式與白茫 ----

func test_eat_fruit_on_branch_with_jaw_glow() -> void:
	var s: Array = await boss_setup(1)
	var b = s[2]
	var names := []
	b.glow_struck.connect(func(n): names.append(n))
	b.start_move("eat_fruit")
	var lit: bool = await wait_until(func(): return b.light.state == Light.State.GLOW, 90)
	check(lit and b.position.distance_to(Nance.PERCH) < 4.0, "吃果子停在低枝、下顎微亮，實際 %s" % b.position)
	var x := fake_dart(false)
	b.light.receive(1, x, &"dart")
	check(b.move == null and b.light.state == Light.State.OFF, "微亮被射中 → 中斷、熄滅")
	check(b.gauge.value == 12 and names == ["jaw"], "微亮命中破綻 +12、記下顎")
	x.free()
	b.start_move("eat_fruit")
	await wait_until(func(): return b.light.state == Light.State.GLOW, 90)
	await frames(140)
	check(b.move != null, "吃果子持續 2.5 秒")
	await frames(15)
	check(b.move == null and b.light.state == Light.State.OFF, "2.5 秒後吃完")
	await free_world(s[0])


func test_dive_lands_at_telegraph_position() -> void:
	var s: Array = await boss_setup(1)
	var p = s[1]
	var b = s[2]
	b.start_move("dive")
	await wait_until(func(): return b.move != null and b.move.telegraphing, 30)
	var aim: Vector2 = p.global_position
	p.position.x -= 400.0
	var landed: bool = await wait_until(func(): return b.position.y >= Nance.GROUND_Y - 1.0, 120)
	check(landed and absf(b.position.x - aim.x) < 40.0, "俯衝落在前搖開始時的角色位置，實際 %s／%s" % [b.position, aim])
	await frames(60)
	check(b.move != null and b.move_name == "dive", "落地喘 1.2 秒")
	await frames(20)
	check(b.move == null, "喘完結束")
	await free_world(s[0])


func test_false_flash_facing_rule_and_not_interruptible() -> void:
	check(FalseFlash.is_facing(100.0, 1, 500.0), "Boss 在右、角色面右 → 面向")
	check(not FalseFlash.is_facing(100.0, -1, 500.0), "背對 → 沒事")
	check(FalseFlash.is_facing(500.0, -1, 500.0), "同 x 視為面向")
	var s: Array = await boss_setup(1)
	var b = s[2]
	var flashed := []
	b.flashed.connect(func(): flashed.append(true))
	b.start_move("false_flash")
	await frames(10)
	b.hurtbox.receive(1, null, &"dart")
	check(b.state == Macaw.State.MOVE, "假光閃耀不能用射身體打斷")
	await wait_until(func(): return not flashed.is_empty(), 70)
	check(flashed.size() == 1, "前搖 1 秒後閃光")
	await free_world(s[0])


func test_whiteout_curve() -> void:
	var t := fresh_tuning()
	check(is_zero_approx(Whiteout.alpha_at(0.0, t)), "開始時 0")
	check(is_equal_approx(Whiteout.alpha_at(0.3, t), Whiteout.MAX_ALPHA) and is_equal_approx(Whiteout.alpha_at(1.7, t), Whiteout.MAX_ALPHA), "0.3～1.7 秒維持")
	check(is_zero_approx(Whiteout.alpha_at(2.0, t)) and is_zero_approx(Whiteout.alpha_at(2.5, t)), "2 秒後消失")
	var prev := -1.0
	for i in 31:
		var a := Whiteout.alpha_at(i * 0.01, t)
		check(a >= prev, "淡入單調遞增（%.2f 秒）" % (i * 0.01))
		prev = a
	prev = 2.0
	for i in 31:
		var a := Whiteout.alpha_at(1.7 + i * 0.01, t)
		check(a <= prev, "淡出單調遞減（%.2f 秒）" % (1.7 + i * 0.01))
		prev = a


# ---- MV-PROTO-003 Task 6：第 2 段招式與反光柱 ----

func test_flail_approaches_and_can_be_parried() -> void:
	var s: Array = await boss_setup(2)
	var p = s[1]
	var b = s[2]
	var t = p.tn
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	b.start_move("flail")
	var ready: bool = await wait_until(func(): return b.move != null and b.move.telegraphing and b.move.t >= t.flail_telegraph - 0.1, 120)
	check(ready and absf(b.position.x - p.position.x) <= 151.0, "先走到角色身邊再前搖，實際距離 %.0f" % absf(b.position.x - p.position.x))
	check(b.parryable, "亂揮翅膀可招架")
	p.intent.attack_pressed = true
	var ok: bool = await wait_until(func(): return b.gauge.value == 15, 30)
	check(ok and p.health.hp == 5, "招架成功：破綻 +15、不受傷")
	await free_world(s[0])


func test_wail_teeth_glow() -> void:
	var s: Array = await boss_setup(2)
	var b = s[2]
	var names := []
	b.glow_struck.connect(func(n): names.append(n))
	b.start_move("wail")
	await frames(2)
	check(b.light.state == Light.State.GLOW, "哀嚎時玉牙微亮")
	var x := fake_dart(false)
	b.light.receive(1, x, &"dart")
	check(b.move == null and names == ["teeth"], "微亮被射中 → 中斷、記玉牙")
	x.free()
	await free_world(s[0])


func test_throne_charge_puts_player_between_and_drops_pillars() -> void:
	var s: Array = await boss_setup(2)
	var p = s[1]
	var b = s[2]
	p.position.x = Palace.LEFT + 900.0
	await frames(2)
	b.start_move("throne_charge")
	var ready: bool = await wait_until(func(): return b.move != null and b.move.telegraphing, 150)
	check(ready and b.position.x < p.position.x and p.position.x < Palace.THRONE_X, "前搖時角色在他與寶座之間，實際 Boss %.0f、角色 %.0f" % [b.position.x, p.position.x])
	check(not b.parryable, "撞寶座不可招架")
	var hit: bool = await wait_until(func(): return b.position.x >= Palace.THRONE_X - 1.0, 120)
	var px: float = p.position.x
	await frames(2)
	var xs := []
	for c in s[0].get_children():
		if c is Pillar:
			xs.append(c.position.x)
	check(hit and xs.size() == 3, "撞上寶座後落 3 道反光柱，實際 %s" % [xs])
	var near_player := false
	for x in xs:
		near_player = near_player or absf(x - px) < 30.0
	check(near_player, "其中一道落在角色當時的位置")
	await free_world(s[0])


func test_pillar_warns_then_hits_once() -> void:
	var w := make_world()
	var p = await make_player(w)
	var pl = Pillar.new()
	pl.tn = p.tn
	pl.position = Vector2(0, 0)
	w.add_child(pl)
	await frames(45)
	check(p.health.hp == 5, "預告 0.8 秒內不傷人")
	await frames(30)
	check(p.health.hp == 4, "光柱落下扣 1 血，實際 %d" % p.health.hp)
	await frames(10)
	check(not is_instance_valid(pl), "0.4 秒後消失")
	await free_world(w)


# ---- MV-PROTO-003 Task 7：第 3 段招式 ----

func test_stagger_pounce_parry_then_unsteady() -> void:
	var s: Array = await boss_setup(3)
	var p = s[1]
	var b = s[2]
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	b.start_move("stagger_pounce")
	await wait_until(func(): return b.move != null and b.move.telegraphing, 30)
	check(b.parryable, "失衡撲擊可招架")
	await wait_until(func(): return b.move.attacking, 60)
	await wait_until(func(): return absf(b.position.x - p.position.x) < 250.0, 60)
	p.intent.attack_pressed = true
	var ok: bool = await wait_until(func(): return b.gauge.value == 15, 30)
	check(ok and p.health.hp == 5, "招架成功：破綻 +15、不受傷")
	await frames(50)
	check(b.move_name == "stagger_pounce" and b.move != null and not b.move.attacking, "被擋下後落地不穩（近戰空檔）")
	await free_world(s[0])


func test_beam_eye_glow_interrupt_wobbles() -> void:
	var s: Array = await boss_setup(3)
	var p = s[1]
	var b = s[2]
	var names := []
	b.glow_struck.connect(func(n): names.append(n))
	b.start_move("beam")
	await frames(5)
	check(b.light.state == Light.State.GLOW and not b.parryable, "蓄力時眼睛微亮、不可招架")
	b.hurtbox.receive(1, null, &"dart")
	check(b.move != null and b.move.step == Beam.Step.CHARGE, "光束不能用射身體打斷")
	var x := fake_dart(false)
	b.light.receive(1, x, &"dart")
	x.free()
	check(b.move.step == Beam.Step.WOBBLE and names == ["eye"], "射中微亮 → 打斷、晃動")
	await frames(55)
	check(b.move != null, "晃 1.0 秒")
	await frames(10)
	check(b.move == null and p.health.hp == 5, "晃完結束、光束沒有射出")
	await free_world(s[0])


func test_beam_hits_standing_player() -> void:
	var s: Array = await boss_setup(3)
	var p = s[1]
	var b = s[2]
	b.start_move("beam")
	await frames(110)
	check(p.health.hp == 4, "沒打斷 → 光束打中站著的角色，實際 %d" % p.health.hp)
	await free_world(s[0])


func test_beam_single_jump_clears() -> void:
	var s: Array = await boss_setup(3)
	var p = s[1]
	var b = s[2]
	var t = p.tn
	b.start_move("beam")
	await wait_until(func(): return b.move != null and b.move.step == Beam.Step.CHARGE and b.move.t >= t.beam_charge - 0.1, 90)
	p.intent.jump_pressed = true
	p.intent.jump_held = true
	await frames(50)
	check(p.health.hp == 5, "單跳跳得過光束，實際 %d" % p.health.hp)
	await free_world(s[0])


# ---- MV-PROTO-003 Task 8：測試日誌 ----

func test_log_summary_math() -> void:
	var ev := [
		{"t": 0.0, "type": "attempt_start", "phase": 1, "keep": false},
		{"t": 30.0, "type": "glow_hit", "phase": 1, "light": "jaw"},
		{"t": 100.0, "type": "death", "phase": 1, "by": "dive"},
		{"t": 110.0, "type": "attempt_start", "phase": 1, "keep": false},
		{"t": 150.0, "type": "gauge_full", "phase": 1},
		{"t": 152.0, "type": "setup", "phase": 1},
		{"t": 200.0, "type": "attempt_start", "phase": 2, "keep": false},
		{"t": 330.0, "type": "quit"},
	]
	var s := FightLog.summarize(ev, 330.0)
	check(s.attempts == 2 and s.deaths == 1 and not s.cleared, "總嘗試 2（死 1 次）、未通關，實際 %s" % [s])
	check(s.phase_attempts == [2, 1, 0], "各段嘗試次數，實際 %s" % [s.phase_attempts])
	check(is_equal_approx(s.phase_time[0], 142.0) and is_equal_approx(s.phase_time[1], 130.0) and is_zero_approx(s.phase_time[2]), "各段時間 142／130／0，實際 %s" % [s.phase_time])
	check(s.stalls == [{"from": 30.0, "to": 150.0, "phase": 1}, {"from": 152.0, "to": 330.0, "phase": 2}], "超過 60 秒沒進展的區間，實際 %s" % [s.stalls])
	check(s.counts.get("glow_hit", 0) == 1 and s.counts.get("attempt_start", 0) == 3, "事件次數")


func test_log_stamp() -> void:
	check(FightLog.stamp_from({"year": 2026, "month": 10, "day": 5, "hour": 9, "minute": 3, "second": 7}) == "20261005_090307", "時間戳格式")


func test_log_safe_name() -> void:
	check(FightLog.safe_name("A01") == "A01", "一般代號不變")
	check(FightLog.safe_name("a b/c:d") == "a_b_c_d", "空白與路徑字元換成底線")
	check(FightLog.safe_name("  ") == "anon", "空白代號用 anon")


func test_log_writes_jsonl_and_summary_once() -> void:
	var lg = FightLog.new()
	check(lg.open("tester01", "20261005_120000", TEST_LOG_DIR) == OK, "能建立日誌")
	lg.add(0.0, "attempt_start", {"phase": 1, "keep": false})
	lg.add(5.0, "death", {"phase": 1, "by": "dive"})
	lg.close(9.0, "quit")
	lg.close(10.0, "quit")
	var lines := FileAccess.get_file_as_string(TEST_LOG_DIR + "/tester01_20261005_120000.jsonl").strip_edges().split("\n")
	check(lines.size() == 3, "3 筆事件（含 quit 一次），實際 %d" % lines.size())
	var last = JSON.parse_string(lines[2])
	check(last != null and last.type == "quit", "最後一筆是 quit")
	var md := FileAccess.get_file_as_string(TEST_LOG_DIR + "/tester01_20261005_120000.md")
	check(md.contains("總嘗試次數：2") and md.contains("中途離開"), "摘要寫出嘗試次數與結果")
	remove_test_logs()


# ---- MV-PROTO-003 Task 12：入口與參數 ----

func test_launch_args_parse() -> void:
	check(LaunchArgs.parse(PackedStringArray()).mode == "title", "沒有參數 → 主選單")
	check(LaunchArgs.parse(PackedStringArray(["--self-test"])).mode == "selftest", "--self-test")
	var a := LaunchArgs.parse(PackedStringArray(["--boss"]))
	check(a.mode == "boss" and a.boss_phase == 0, "--boss 直接進 Boss 段落")
	a = LaunchArgs.parse(PackedStringArray(["--boss-phase", "3"]))
	check(a.mode == "boss" and a.boss_phase == 3, "--boss-phase")
	check(LaunchArgs.parse(PackedStringArray(["--boss-phase", "9"])).boss_phase == 0, "段數超出範圍 → 從頭")
	a = LaunchArgs.parse(PackedStringArray(["--room", "forest_2"]))
	check(a.mode == "room" and a.room == "forest_2", "--room 直接進某個房間")
	check(LaunchArgs.parse(PackedStringArray(["--room"])).mode == "title", "--room 缺值 → 主選單")
	check(LaunchArgs.parse(PackedStringArray(["--demo-parry"])).mode == "title", "原型的展示模式已移除")
	check(not LaunchArgs.parse(PackedStringArray(["--tester", "A"])).has("tester"), "原型的測試代號已移除")


# ---- MV-PROTO-003 最終審查的修正 ----

func test_fight_card_min_time_from_tuning() -> void:
	check(is_equal_approx(fresh_tuning().card_min_time, 1.2), "文字卡最短顯示 1.2 秒")
	var f = BossFight.new()
	f.tn = fresh_tuning()
	f.log_dir = TEST_LOG_DIR
	f.player_scripted = true
	add_child(f)
	await frames(2)
	check(is_equal_approx(f.card.min_time, 1.2), "Boss 戰的文字卡用數值檔的最短時間")
	await free_fight(f)


func test_death_and_setup_same_frame_setup_wins() -> void:
	var f = await make_fight(2)
	var p = f.player
	f.debug_fill_gauge()
	await frames(1)
	p.health.hp = 1
	p.hurtbox.receive(1, f.boss, &"enemy")
	var h := fake_dart(true)
	f.boss.light.receive(1, h, &"dart")
	h.free()
	await frames(3)
	check(f.card.visible and f.card.text == CardText.CARDS["teeth"], "同一幀死亡又設局：設局優先，顯示換牙文字卡")
	check(p.health.hp >= 1 and not log_types(f).has("death"), "角色保住 1 血、不記死亡")
	f.card.confirm()
	await frames(2)
	check(f.stage == BossFight.Stage.FIGHT and f.phase == 3 and f.palace.gate_closed and f.lights_removed == 2, "接著正常開打第 3 段")
	await free_fight(f)


## SLICE-b2b-5：身體不擋往光源的箭——路線穿過身體、光源在身體另一側（離身體邊 20 px 外）→ 打中光源、不算打到身體
func test_dart_through_body_hits_light_behind() -> void:
	var w := make_world()
	var p = await make_player(w)
	var a := make_fake_boss(w, 600.0)
	a[1].position = Vector2(130, Intent.muzzle(Vector2.RIGHT, 1).y)
	a[1].set_state(Light.State.GLOW)
	await frames(2)
	p.intent.dart_pressed = true
	await frames(25)
	check(a[2].size() == 1 and a[2][0][0] == "light", "穿過身體打中另一側的光源（光源 1、身體 0），實際 %s" % [a[2]])
	await free_world(w)



## SLICE-b2b-5「地形擋住就停」（Task 7 修正第 1 輪，R13）：箭先打到身體，身體和另一側的光源之間有地形
## → 往後查光源的延伸停在地形，打不到光源、只打到身體（主射線先碰到身體，延伸那段才會碰到地形）
func test_dart_through_body_stops_at_terrain() -> void:
	var w := make_world()
	var p = await make_player(w)
	var a := make_fake_boss(w, 600.0)
	a[1].position = Vector2(130, Intent.muzzle(Vector2.RIGHT, 1).y)
	a[1].set_state(Light.State.GLOW)
	var wall := StaticBody2D.new()  # 身體右緣 690、光源左緣 710 之間的牆
	wall.collision_layer = L.WORLD
	wall.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(6, 400)
	cs.shape = r
	cs.position = Vector2(700, -200)
	wall.add_child(cs)
	w.add_child(wall)
	await frames(2)
	p.intent.dart_pressed = true
	await frames(25)
	check(a[2] == [["body", &"dart"]], "身體與光源之間有地形：光源 0、身體 1，實際 %s" % [a[2]])
	await free_world(w)
