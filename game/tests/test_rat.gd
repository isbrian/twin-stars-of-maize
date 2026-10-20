extends "res://tests/base_test.gd"
# MV-SLICE-001a Task 8：老鼠的鑽地突襲（規格 SLICE-a3、SLICE-a11）。

const GameStateScr := preload("res://state/game_state.gd")
const Loadout := preload("res://state/loadout.gd")
const Rat := preload("res://core/player/rat.gd")
const RatTarget := preload("res://core/player/rat_target.gd")


func make_gs():
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	gs.give_skill("rat")
	return gs


func rat_player(w: Node2D, gs) -> Node:
	var p = Loadout.make_player(gs, gs.tn)
	p.scripted = true
	w.add_child(p)
	await frames(3)
	return p


func rats_in(w: Node) -> int:
	return count_of(w, Rat)


func test_rat_target_ground_only() -> void:
	var w := make_world()
	var near = await make_enemy(w, Crawler, Vector2(300, 0))
	var fly = await make_enemy(w, Flyer, Vector2(250, -350))
	var behind = await make_enemy(w, Crawler, Vector2(-300, 0))
	var far = await make_enemy(w, Crawler, Vector2(900, 0))
	for e in [near, fly, behind, far]:
		e.set_physics_process(false)
	var all := [near, fly, behind, far]
	check(RatTarget.pick(Vector2.ZERO, 1, all, 700.0, 40.0) == near, "選面前最近的地面敵人")
	check(RatTarget.pick(Vector2.ZERO, 1, [fly, behind, far], 700.0, 40.0) == null, "飛行型、身後、超出 700 的都不選")
	check(RatTarget.pick(Vector2.ZERO, -1, all, 700.0, 40.0) == behind, "面向左時選左邊的")
	await free_world(w)


func test_rat_hits_crawler_and_stuns() -> void:
	var w := make_world()
	var gs = make_gs()
	var p = await rat_player(w, gs)
	var e = await make_enemy(w, Crawler, Vector2(400, 0))
	p.intent.skill_1_pressed = true
	var hit: bool = await wait_until(func(): return e.health.hp == e.tn.crawler_hp - gs.tn.rat_damage, 60)
	check(hit, "咬一口：傷害 3，實際血量 %d" % e.health.hp)
	check(e.state == Enemy.State.STAGGER, "短硬直")
	check(gs.skill_res == 2, "耗 1 格")
	await frames(2)
	check(rats_in(w) == 0, "咬完老鼠消失")
	await free_world(w)
	gs.free()


func test_rat_interrupts_telegraph_like_dart() -> void:
	var w := make_world()
	var gs = make_gs()
	var p = await rat_player(w, gs)
	var e = await make_enemy(w, Crawler, Vector2(300, 0))
	var got := [false]
	e.interrupted.connect(func(_e): got[0] = true)
	e.start_telegraph()
	p.intent.skill_1_pressed = true
	await wait_until(func(): return got[0], 40)
	check(got[0] and e.state == Enemy.State.STAGGER, "前搖中被咬 → 打斷（同吹箭）")
	await free_world(w)
	gs.free()


func test_rat_no_target_returns_and_costs() -> void:
	var w := make_world()
	var gs = make_gs()
	var p = await rat_player(w, gs)
	p.intent.skill_1_pressed = true
	await frames(2)
	check(rats_in(w) == 1 and gs.skill_res == 2, "沒有目標也發動、資源照扣")
	var gone: bool = await wait_until(func(): return rats_in(w) == 0, 180)
	check(gone, "往前鑽 700 後回來消失")
	await free_world(w)
	gs.free()


func test_rat_needs_resource() -> void:
	var w := make_world()
	var gs = make_gs()
	gs.skill_res = 0
	var p = await rat_player(w, gs)
	var denied := [false]
	p.get_node("SkillUser").denied.connect(func(): denied[0] = true)
	p.intent.skill_1_pressed = true
	await frames(2)
	check(rats_in(w) == 0 and gs.skill_res == 0 and denied[0], "資源 0 時不發動、資源不變、發出 denied")
	await free_world(w)
	gs.free()


func test_rat_needs_skill_in_slot_and_ground() -> void:
	var w := make_world()
	var gs = make_gs()
	gs.skill_slots = ["", ""]
	var p = await rat_player(w, gs)
	p.intent.skill_1_pressed = true
	await frames(2)
	check(rats_in(w) == 0 and gs.skill_res == 3, "槽裡沒有老鼠時不發動")
	gs.skill_slots = ["rat", ""]
	p.intent.jump_pressed = true
	p.intent.jump_held = true
	await frames(8)
	p.intent.skill_1_pressed = true
	await frames(2)
	check(rats_in(w) == 0 and gs.skill_res == 3, "空中不發動、不扣資源")
	await free_world(w)
	gs.free()


func test_rat_target_dies_midway() -> void:
	var w := make_world()
	var gs = make_gs()
	var p = await rat_player(w, gs)
	var e = await make_enemy(w, Crawler, Vector2(650, 0))
	e.set_physics_process(false)
	p.intent.skill_1_pressed = true
	await frames(3)
	check(rats_in(w) == 1, "老鼠出發")
	e.kill()
	var gone: bool = await wait_until(func(): return rats_in(w) == 0, 30)
	check(gone and gs.skill_res == 2, "目標途中死掉 → 老鼠消失、資源只扣 1")
	await free_world(w)
	gs.free()


func test_rat_counts_for_boss_gauge() -> void:
	var s: Array = await boss_setup(2)
	var p = s[1]
	var b = s[2]
	check(b.is_in_group("enemy"), "Seven Macaw 在 enemy 群組（老鼠找得到）")
	b.start_move("flail")
	await wait_until(func(): return b.move != null and b.move.telegraphing, 120)
	var facing := 1 if b.global_position.x > p.global_position.x else -1
	var target = RatTarget.pick(p.global_position, facing, get_tree().get_nodes_in_group("enemy"), p.tn.rat_range, p.tn.rat_max_dy)
	check(target == b, "地面上的 Seven Macaw 是地面目標")
	var r = Rat.new()
	r.tn = p.tn
	s[0].add_child(r)
	r.launch(p.global_position, facing, b, p)
	var ok: bool = await wait_until(func(): return b.state == Macaw.State.INTERRUPTED, 40)
	check(ok and b.gauge.value == p.tn.gauge_dart_interrupt, "前搖中被咬 → 打斷、破綻 +10（同吹箭打斷）")
	await free_world(s[0])


func test_hud_shows_skill_resource_and_flash() -> void:
	var gs = make_gs()
	gs.skill_res = 2
	var hud = Hud.new()
	hud.gs = gs
	check(hud.skill_line() == "老鼠　●●○", "技能資源 3 格，實際「%s」" % hud.skill_line())
	check(not hud.skill_flashing(), "平常不閃")
	hud.flash_skill()
	check(hud.skill_flashing(), "資源不足時閃一下")
	hud.free()
	gs.free()
