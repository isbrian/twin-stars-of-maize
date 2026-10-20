extends "res://tests/base_test.gd"
# MV-SLICE-001a Task 3：把 GameState 套到角色身上（武器、血量、熱湯、技能回充）。

const GameStateScr := preload("res://state/game_state.gd")
const Loadout := preload("res://state/loadout.gd")


func make_gs():
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	return gs


## 在測試世界的地面上建一個套好 gs 的角色（由測試操控）
func loadout_player(w: Node2D, gs) -> Node:
	var p = Loadout.make_player(gs, gs.tn)
	p.scripted = true
	w.add_child(p)
	await frames(3)
	return p


func test_no_weapon_cannot_attack_but_can_dart() -> void:
	var w := make_world()
	var gs = make_gs()
	var p = await loadout_player(w, gs)
	p.intent.attack_pressed = true
	await frames(2)
	check(p.state != Player.State.ATTACK, "沒有武器時攻擊鍵無效")
	p.intent.dart_pressed = true
	await frames(2)
	check(count_darts(w) == 1, "吹箭照常（一開始只有吹箭；J2）")
	await free_world(w)
	gs.free()


func test_loadout_applies_equip_and_health() -> void:
	var w := make_world()
	var gs = make_gs()
	gs.give_weapon(Weapons.Weapon.STICK)
	gs.give_weapon(Weapons.Weapon.AXE)
	gs.equip = [Weapons.Weapon.STICK, Weapons.Weapon.AXE]  # 裝備頁互換過（給武器的順序照 SLICE-a6，見 test_review_fixes）
	gs.hp = 3
	gs.heal_charges = 1
	var p = await loadout_player(w, gs)
	check(p.twins[0].weapon == Weapons.Weapon.STICK and p.twins[0].weapon_enabled, "Hunahpu 掘棒")
	check(p.twins[1].weapon == Weapons.Weapon.AXE and p.twins[1].weapon_enabled, "Xbalanque 斧頭")
	check(p.health.hp == 3 and p.health.heal_charges == 1, "血量與治療次數照 GameState")
	check(not p.abilities_enabled, "還沒覺醒：二段跳與工具停用")
	p.health.hp = 2
	Loadout.store(p, gs)
	check(gs.hp == 2 and gs.heal_charges == 1, "store 寫回 GameState")
	await free_world(w)
	gs.free()


func test_heal_uses_soup_after_charges() -> void:
	var w := make_world()
	var gs = make_gs()
	gs.heal_charges = 0
	gs.soup = 1
	gs.hp = 2
	var p = await loadout_player(w, gs)
	p.intent.heal_pressed = true
	await frames(2)
	check(p.state == Player.State.HEAL, "治療次數用完後同一鍵改喝熱湯")
	check(gs.soup == 0, "扣 1 碗")
	await wait_until(func(): return p.state == Player.State.FREE, 120)
	check(p.health.hp == 2 + gs.tn.heal_amount, "回復量同治療，實際 %d" % p.health.hp)
	await free_world(w)
	gs.free()


func test_soup_not_taken_when_full_or_none() -> void:
	var w := make_world()
	var gs = make_gs()
	gs.heal_charges = 0
	gs.soup = 1
	var p = await loadout_player(w, gs)
	p.intent.heal_pressed = true
	await frames(2)
	check(p.state != Player.State.HEAL and gs.soup == 1, "滿血時不喝、熱湯不扣")
	gs.soup = 0
	p.health.hp = 2
	p.intent.heal_pressed = true
	await frames(2)
	check(p.state != Player.State.HEAL, "次數與熱湯都沒有時不進入治療")
	await free_world(w)
	gs.free()


func test_weapon_hit_recharges_skill() -> void:
	var w := make_world()
	var gs = make_gs()
	gs.give_weapon(Weapons.Weapon.AXE)
	gs.skill_res = 0
	var p = await loadout_player(w, gs)
	var e = await make_enemy(w, Crawler, Vector2(300, 0))
	e.set_physics_process(false)  # 只當靶
	p.intent.aim = Intent.aim_toward(Vector2(300, -35), p.facing)  # 爬行型要往下瞄（MV-TUNE-001）
	p.intent.dart_pressed = true
	await wait_until(func(): return e.health.hp < e.tn.crawler_hp, 30)
	check(e.health.hp < e.tn.crawler_hp and gs.skill_hits == 0, "吹箭打中不算")
	for i in 4:
		p.hit_landed.emit(e.hurtbox)
	check(gs.skill_res == 1, "近戰打中 4 次回 1 格")
	await free_world(w)
	gs.free()


func test_hud_shows_dash_without_weapon() -> void:
	var w := make_world()
	var gs = make_gs()
	gs.give_weapon(Weapons.Weapon.AXE)
	var p = await loadout_player(w, gs)
	var hud = Hud.new()
	hud.player = p
	var lines: PackedStringArray = hud.twin_lines()
	check(lines[0].contains("斧頭") and lines[1].contains("—"), "Xbalanque 還沒武器顯示「—」，實際 %s" % lines)
	hud.free()
	await free_world(w)
	gs.free()
