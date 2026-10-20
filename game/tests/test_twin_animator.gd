extends "res://tests/base_test.gd"
# MV-SLICE-001b2a：玩家狀態 → 雙胞胎骨架的動作（world/twin_animator.gd）。

const State := preload("res://core/player/player.gd").State
const Dir := preload("res://core/player/player.gd").AttackDir
const Phase := preload("res://core/player/player.gd").Phase


## 測試世界＋由測試操控的角色＋兩副骨架與 animator；twin_animator.gd 不存在時 [w, p, null]
func rig_setup() -> Array:
	var w := make_world()
	var p = await make_player(w)
	var scr = load("res://world/twin_animator.gd")
	var a = scr.attach(p) if scr != null else null
	await frames(1)
	return [w, p, a]



func test_choose_by_state() -> void:
	var s := await rig_setup()
	var p = s[1]
	var a = s[2]
	check(a != null, "twin_animator.gd 存在")
	if a == null:
		await free_world(s[0])
		return
	check(a.choose(p)[0] == "idle", "地面靜止 → idle（%s）" % a.choose(p)[0])
	p.velocity.x = 300.0
	check(a.choose(p)[0] == "run", "地面移動 → run")
	p.velocity = Vector2.ZERO
	var cases := [
		[State.ROLL, -1, 0, "roll"], [State.HURT, -1, 0, "hurt"], [State.HEAL, -1, 0, "heal"],
		[State.ATTACK, Weapons.Weapon.AXE, Dir.SIDE, "attack_axe_side"], [State.ATTACK, Weapons.Weapon.AXE, Dir.UP, "attack_axe_up"],
		[State.ATTACK, Weapons.Weapon.AXE, Dir.DOWN, "attack_axe_down"], [State.ATTACK, Weapons.Weapon.STICK, Dir.SIDE, "attack_stick_side"],
		[State.ATTACK, Weapons.Weapon.STICK, Dir.UP, "attack_stick_up"], [State.ATTACK, Weapons.Weapon.STICK, Dir.DOWN, "attack_stick_down"],
		[State.ATTACK, Weapons.Weapon.BALLGEAR, Dir.SIDE, "parry_side"], [State.ATTACK, Weapons.Weapon.BALLGEAR, Dir.UP, "parry_up"],
		[State.ATTACK, Weapons.Weapon.BALLGEAR, Dir.DOWN, "ballgear_down"],
		[State.PARRY, Weapons.Weapon.BALLGEAR, Dir.SIDE, "parry_side"], [State.PARRY, Weapons.Weapon.BALLGEAR, Dir.UP, "parry_up"],
	]
	for c in cases:
		p.state = c[0]
		p.state_time = 0.0
		if c[1] != -1:
			p.attack_weapon = c[1]
		p.attack_dir = c[2]
		check(a.choose(p)[0] == c[3], "狀態 %s 武器 %s 方向 %s → %s（%s）" % [c[0], c[1], c[2], c[3], a.choose(p)[0]])
	p.state = State.FREE
	p.parry_ring_left = 0.2
	check(a.choose(p)[0] == "parry_success", "招架成功的光環期間 → parry_success")
	p.parry_ring_left = 0.0
	p.position.y -= 400.0
	await frames(1)
	p.velocity.y = -200.0
	check(a.choose(p)[0] == "jump_up", "空中上升 → jump_up")
	p.velocity.y = 200.0
	check(a.choose(p)[0] == "fall", "空中下落 → fall")
	await free_world(s[0])


func test_attack_time_follows_tuning() -> void:
	var scr = load("res://world/twin_animator.gd")
	check(scr != null, "twin_animator.gd 存在")
	if scr == null:
		return
	var s := await rig_setup()
	var p = s[1]
	p.tn.axe_startup *= 2.0
	p.state = State.ATTACK
	p.attack_weapon = Weapons.Weapon.AXE
	p.state_time = p.tn.axe_startup * 0.5
	check(is_equal_approx(scr.attack_time(p), 0.5), "出招段一半 → 0.5（%.3f）" % scr.attack_time(p))
	p.state_time = p.tn.axe_startup + p.tn.axe_active * 0.5
	check(is_equal_approx(scr.attack_time(p), 1.5), "判定段一半 → 1.5（%.3f）" % scr.attack_time(p))
	p.state_time = p.tn.axe_startup + p.tn.axe_active + p.tn.axe_recovery * 0.5
	check(is_equal_approx(scr.attack_time(p), 2.5), "收招段一半 → 2.5（%.3f）" % scr.attack_time(p))
	p.state = State.PARRY
	p.state_time = p.tn.parry_window * 0.5
	check(is_equal_approx(scr.attack_time(p), 1.5), "招架窗口一半 → 1.5（%.3f）" % scr.attack_time(p))
	await free_world(s[0])


## Review Focus 1：換人打斷攻擊（含破綻滿時的 force_twin）
func test_force_swap_mid_attack() -> void:
	var s := await rig_setup()
	var p = s[1]
	var a = s[2]
	check(a != null, "twin_animator.gd 存在")
	if a == null:
		await free_world(s[0])
		return
	p.intent.attack_pressed = true
	check(await wait_until(func(): return p.state == State.ATTACK and p.attack_phase == Phase.ACTIVE, 30), "攻擊進入判定段")
	p.force_twin(1)
	await frames(1)
	check(not a.rigs[0].visible and a.rigs[1].visible, "換人後只有 Xbalanque 的骨架可見")
	check(not String(a.choose(p)[0]).begins_with("attack"), "新上場的人不卡在攻擊姿勢（%s）" % a.choose(p)[0])
	await free_world(s[0])


func head_turn(r: Node2D) -> float:
	return rad_to_deg(wrapf(r.bone("head").rotation - r.bone("head").rest.get_rotation(), -PI, PI))


## Review Focus 3：朝背後瞄準的吹射
func test_dart_overlay_behind() -> void:
	var s := await rig_setup()
	var p = s[1]
	var a = s[2]
	check(a != null, "twin_animator.gd 存在")
	if a == null:
		await free_world(s[0])
		return
	p.facing = 1
	p.intent.aim = Vector2.LEFT
	p.intent.dart_pressed = true
	await frames(3)
	var r = a.rigs[p.twin_index]
	var world_dir: Vector2 = r.bone("forearm_r").get_global_transform().x.normalized()
	check(absf(world_dir.angle_to(Vector2.LEFT)) <= deg_to_rad(10.0), "近側前臂朝瞄準方向（正左）±10°（%s）" % world_dir)
	check(absf(head_turn(r)) <= 45.0, "頭轉動 ≤ 45°（%.0f°）" % head_turn(r))
	check(p.facing == 1 and r.scale.x > 0.0, "面向不因吹射改變")
	check(r.sprite("wpn_blowgun").is_visible_in_tree(), "吹射時吹箭可見")
	await frames(int(0.5 * Engine.physics_ticks_per_second))
	check(r.sprite("wpn_blowgun").is_visible_in_tree(), "0.5 秒時還舉著吹管（最後一發後舉 0.6 秒，Brian 試玩 2026-10-11）")
	await frames(int(0.2 * Engine.physics_ticks_per_second))
	check(not r.sprite("wpn_blowgun").is_visible_in_tree(), "0.7 秒後吹箭收起")
	var main: Array = a.choose(p)
	var f: Dictionary = r.frame_at(main[0], main[1])
	var want_ua: float = r.bone("upperarm_r").rest.get_rotation() + deg_to_rad(f.bones.get("upperarm_r", 0.0))
	check(is_equal_approx(r.bone("upperarm_r").rotation, want_ua), "0.7 秒後手臂回到主動作 %s" % main[0])
	await free_world(s[0])


func test_dart_overlay_keeps_legs() -> void:
	var s := await rig_setup()
	var p = s[1]
	var a = s[2]
	check(a != null, "twin_animator.gd 存在")
	if a == null:
		await free_world(s[0])
		return
	p.intent.move_x = 1.0
	await frames(10)
	p.intent.dart_pressed = true
	await frames(2)
	var r = a.rigs[p.twin_index]
	var main: Array = a.choose(p)
	check(main[0] == "run", "邊跑邊射：主動作仍是 run（%s）" % main[0])
	var f: Dictionary = r.frame_at("run", main[1])
	for b in ["thigh_r", "shin_r", "thigh_l", "shin_l"]:
		var want: float = r.bone(b).rest.get_rotation() + deg_to_rad(f.bones.get(b, 0.0))
		check(is_equal_approx(r.bone(b).rotation, want), "邊跑邊射：%s 照跑步影格" % b)
	check(r.sprite("wpn_blowgun").is_visible_in_tree() and not r.sprite("wpn_axe").is_visible_in_tree(), "吹射時近側手扶吹管、斧頭收起")
	await free_world(s[0])


## Review Focus 4：斷臂（arm_broken）中換人再換回、覺醒當下手臂回來；沒有武器（weapon_enabled false）不等於斷臂
func test_broken_arm_follows_arm_broken() -> void:
	var s := await rig_setup()
	var p = s[1]
	var a = s[2]
	check(a != null, "twin_animator.gd 存在")
	if a == null:
		await free_world(s[0])
		return
	var r0 = a.rigs[0]
	p.twins[0].weapon_enabled = false
	await frames(1)
	check(r0.sprite("upperarm_r").is_visible_in_tree() and not r0.sprite("wpn_axe").is_visible_in_tree(), "還沒有武器：手臂在、沒有武器")
	p.twins[0].arm_broken = true
	await frames(1)
	check(not r0.sprite("upperarm_r").is_visible_in_tree() and not r0.sprite("wpn_axe").is_visible_in_tree(), "斷臂：近側手臂與武器隱藏")
	p.force_twin(1)
	await frames(2)
	p.force_twin(0)
	await frames(2)
	check(not r0.sprite("upperarm_r").is_visible_in_tree(), "換到 Xbalanque 再換回仍是斷臂")
	check(a.rigs[1].sprite("upperarm_r").visible, "Xbalanque 的手臂不受影響")
	p.twins[0].arm_broken = false
	p.twins[0].weapon_enabled = true
	await frames(1)
	check(r0.sprite("upperarm_r").is_visible_in_tree() and r0.sprite("wpn_axe").is_visible_in_tree(), "覺醒：下一幀手臂與斧頭回來")
	await free_world(s[0])


## Review Focus 5：空中攻擊與落地
func test_air_attack_no_run_legs() -> void:
	var s := await rig_setup()
	var p = s[1]
	var a = s[2]
	check(a != null, "twin_animator.gd 存在")
	if a == null:
		await free_world(s[0])
		return
	p.intent.jump_pressed = true
	p.intent.jump_held = true
	await frames(8)
	p.intent.move_x = 1.0
	p.intent.attack_pressed = true
	await frames(1)
	check(p.state == State.ATTACK and not p.is_on_floor(), "空中出招")
	check(a.choose(p)[0] == "attack_axe_side", "空中側攻 → 攻擊動作（%s）" % a.choose(p)[0])
	p.intent.move_x = 0.0
	p.intent.jump_held = false
	check(await wait_until(func(): return p.is_on_floor() and p.state == State.FREE, 120), "落地")
	check(a.choose(p)[0] == "land", "落地那幀之後播 land（%s）" % a.choose(p)[0])
	await free_world(s[0])


func test_short_anims_interruptible() -> void:
	var s := await rig_setup()
	var p = s[1]
	var a = s[2]
	check(a != null, "twin_animator.gd 存在")
	if a == null:
		await free_world(s[0])
		return
	p.force_twin(1)
	await frames(1)
	check(a.choose(p)[0] == "swap_in", "換人 → 新上場的人播 swap_in（%s）" % a.choose(p)[0])
	p.intent.move_x = 1.0
	await frames(1)
	check(a.choose(p)[0] == "run", "swap_in 中移動 → run（%s）" % a.choose(p)[0])
	await free_world(s[0])


func test_heal_shows_bowl() -> void:
	var s := await rig_setup()
	var p = s[1]
	var a = s[2]
	check(a != null, "twin_animator.gd 存在")
	if a == null:
		await free_world(s[0])
		return
	p.health.hp = 1
	p.intent.heal_pressed = true
	check(await wait_until(func(): return p.state == State.HEAL, 10), "進入治療")
	await frames(1)
	var r = a.rigs[p.twin_index]
	check(r.sprite("prop_soup_bowl").is_visible_in_tree(), "治療中湯碗可見")
	check(await wait_until(func(): return p.state != State.HEAL, 120), "治療結束")
	await frames(1)
	check(not r.sprite("prop_soup_bowl").is_visible_in_tree(), "離開治療的下一幀湯碗隱藏")
	await free_world(s[0])


# ---- 接進遊戲（Task 5）----

func test_rig_tint_rules() -> void:
	var tint = load("res://world/tint.gd")
	check(tint != null, "tint.gd 存在")
	var s := await rig_setup()
	var p = s[1]
	var a = s[2]
	if tint == null or a == null:
		await free_world(s[0])
		return
	var cases := [
		["受擊無敵的閃爍幀", func(): p.health.invuln_left = 0.14, func(c: Color): return is_equal_approx(c.a, 0.3)],
		["翻滾無敵", func():
			p.health.invuln_left = 0.0
			p.state = State.ROLL
			p.state_time = (p.tn.roll_iframe_start + p.tn.roll_iframe_end) / 2.0, func(c: Color): return is_equal_approx(c.a, 0.45)],
		["治療", func(): p.state = State.HEAL, func(c: Color): return c.g > c.r and c.g > c.b],
	]
	for c in cases:
		c[1].call()
		a._apply()
		var m: Color = a.rigs[p.twin_index].modulate
		check(m.is_equal_approx(tint.of(p)) and c[2].call(m), "%s：骨架的顏色＝tint.of（%s）" % [c[0], m])
	await free_world(s[0])


func test_signals_above_rig() -> void:
	var s := await rig_setup()
	var a = s[2]
	if a == null:
		check(false, "twin_animator.gd 存在")
		await free_world(s[0])
		return
	for r in a.rigs:
		check(r.show_behind_parent, "%s 畫在玩家後面：招架小盾、光環由玩家 _draw 畫在上面" % r.name)
	await free_world(s[0])


## 最終審查 Important 1：吹射覆寫只在自由狀態；射完立刻攻擊，要看得到攻擊姿勢與武器
func test_dart_overlay_only_in_free() -> void:
	var s := await rig_setup()
	var p = s[1]
	var a = s[2]
	p.intent.dart_pressed = true
	await frames(2)
	p.intent.attack_pressed = true
	check(await wait_until(func(): return p.state == State.ATTACK and p.attack_phase == Phase.ACTIVE, 30), "射完接著攻擊，進入判定段")
	var r = a.rigs[p.twin_index]
	var c: Array = a.choose(p)
	var f: Dictionary = r.frame_at(c[0], c[1])
	var want: float = r.bone("upperarm_r").rest.get_rotation() + deg_to_rad(f.bones.get("upperarm_r", 0.0))
	check(r.sprite("wpn_axe").is_visible_in_tree() and not r.sprite("wpn_blowgun").is_visible_in_tree(), "攻擊中斧頭可見、吹箭收起")
	check(is_equal_approx(r.bone("upperarm_r").rotation, want), "攻擊中手臂照攻擊影格（%s），不被吹射覆寫" % c[0])
	await free_world(s[0])


## 最終審查（Minor 2 升級）：最高射速連射時，兩發之間手臂不閃回主動作
func test_dart_overlay_holds_through_rapid_fire() -> void:
	var s := await rig_setup()
	var p = s[1]
	var a = s[2]
	var shots := [0]
	p.dart_fired.connect(func(): shots[0] += 1)
	var gaps := 0
	for i in int(1.2 * Engine.physics_ticks_per_second):
		p.intent.dart_pressed = true
		await frames(1)
		if shots[0] >= 1 and not a.rigs[p.twin_index].sprite("wpn_blowgun").is_visible_in_tree():
			gaps += 1
	check(shots[0] >= 3, "連射 3 發以上（%d）" % shots[0])
	check(gaps == 0, "連射中吹箭一直在手上（%d 幀閃回）" % gaps)
	await free_world(s[0])


## Brian 試玩 2026-10-11：手動連射節奏不規則（間隔 0.5 秒）時手臂不上下跳
func test_dart_overlay_holds_through_uneven_fire() -> void:
	var s := await rig_setup()
	var p = s[1]
	var a = s[2]
	var shots := [0]
	p.dart_fired.connect(func(): shots[0] += 1)
	var gaps := 0
	var every := int(0.5 * Engine.physics_ticks_per_second)
	for i in every * 4:
		p.intent.dart_pressed = i % every == 0
		await frames(1)
		if shots[0] >= 1 and not a.rigs[p.twin_index].sprite("wpn_blowgun").is_visible_in_tree():
			gaps += 1
	check(shots[0] >= 3, "每 0.5 秒射一發（%d）" % shots[0])
	check(gaps == 0, "間隔 0.5 秒連射時吹管一直舉著（%d 幀放下）" % gaps)
	await free_world(s[0])


## Brian 試玩 2026-10-11：骨架會揮武器，不再畫判定框方塊（原型灰盒照畫）
func test_hitbox_flash_hidden_with_rig() -> void:
	var s := await rig_setup()
	var p = s[1]
	p.state = State.ATTACK
	p.attack_phase = Phase.ACTIVE
	p.portrait_drawn = false
	check(p.draws_hitbox(), "灰盒：判定段畫判定框")
	p.portrait_drawn = true
	check(not p.draws_hitbox(), "有骨架：不畫判定框")
	p.state = State.FREE
	await free_world(s[0])


## MV-TUNE-001：射出點（Intent.muzzle）對得上骨架上的吹管口——兩兄弟、待機／跑／上升／下落、面向左右、一圈角度
func test_blowgun_mouth_matches_muzzle() -> void:
	var s := await rig_setup()
	var a = s[2]
	var worst := 0.0
	var where := ""
	for r in a.rigs:
		var att: Dictionary = r.attachments().wpn_blowgun
		var gun: Sprite2D = r.sprite("wpn_blowgun")
		for anim in ["idle", "run", "jump_up", "fall"]:
			for f in [1, -1]:
				r.scale.x = f
				for deg in range(-180, 180, 15):
					var aim := Vector2.from_angle(deg_to_rad(deg))
					r.pose(anim, 0.0)
					r.overlay_dart(Vector2(aim.x * f, aim.y))
					var mouth: Vector2 = r.transform * gun.transform * (r.v(att.tip) - r.v(att.pivot))
					var err := mouth.distance_to(Intent.muzzle(aim, f))
					if err > worst:
						worst = err
						where = "%s %s 面向 %d %d°" % [r.cid, anim, f, deg]
	check(worst <= 10.0, "射出點與骨架吹管口最多差 %.1f px（%s）" % [worst, where])
	await free_world(s[0])
