extends "res://tests/base_test.gd"
# 從 prototypes/core/tests/self_test.gd 搬來（MV-SLICE-001a Task 1）。

# ---- Task 4：按鍵、移動、翻滾 ----

func test_input_scheme_a_registered() -> void:
	var expect := {
		"move_left": 3, "move_right": 3, "look_up": 3, "look_down": 3,
		"jump": 2, "roll": 2, "attack": 2, "dart": 2, "heal": 2,
		"aim_left": 1, "aim_right": 1, "aim_up": 1, "aim_down": 1,
		"debug_save": 1, "debug_reset": 1,
		"swap": 2, "debug_weapon_1": 1, "debug_weapon_2": 1, "debug_weapon_3": 1,
		"debug_gauge": 1, "pause": 2,
		"skill_1": 2, "skill_2": 2, "interact": 2,
	}
	for action in expect:
		check(InputMap.has_action(action), "缺少按鍵動作 %s" % action)
		if InputMap.has_action(action):
			var n := InputMap.action_get_events(action).size()
			check(n == expect[action], "%s 應有 %d 個按鍵，實際 %d" % [action, expect[action], n])


func test_player_full_jump_height() -> void:
	var w := make_world()
	var p = await make_player(w)
	var floor_y: float = p.position.y
	p.intent.jump_pressed = true
	var top := floor_y
	for i in 60:
		p.intent.jump_held = true
		await frames(1)
		top = minf(top, p.position.y)
	var h := floor_y - top
	check(h > 360.0 and h < 440.0, "按住跳的高度應約 400 px，實際 %.1f" % h)
	check(p.is_on_floor(), "1 秒內應落回地面")
	await free_world(w)


func test_player_short_hop_is_lower() -> void:
	var w := make_world()
	var p = await make_player(w)
	var floor_y: float = p.position.y
	p.intent.jump_pressed = true
	p.intent.jump_held = true
	await frames(3)
	p.intent.jump_held = false
	var top := floor_y
	for i in 40:
		await frames(1)
		top = minf(top, p.position.y)
	var h := floor_y - top
	check(h < 250.0, "輕按跳應明顯較低（< 250 px），實際 %.1f" % h)
	await free_world(w)


func test_player_jump_buffer_before_landing() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(0, -300))
	await wait_until(func(): return p.position.y >= -80.0, 120)  # 落地前 2～3 幀
	check(not p.is_on_floor(), "前提：按跳時還在空中")
	p.intent.jump_pressed = true
	var jumped := false
	for i in 8:
		p.intent.jump_held = true
		await frames(1)
		if p.velocity.y < -1000.0:
			jumped = true
	check(jumped, "落地前 0.1 秒內按跳，落地時應自動起跳")
	await free_world(w)


func test_roll_only_on_ground() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(0, -400))
	p.intent.roll_pressed = true
	await frames(1)
	check(p.state != Player.State.ROLL, "空中按翻滾應無效（PROTO1-2）")
	await free_world(w)


func test_roll_distance_and_cooldown() -> void:
	var w := make_world()
	var p = await make_player(w)
	var x0: float = p.position.x
	p.intent.roll_pressed = true
	await frames(1)
	check(p.state == Player.State.ROLL, "地面按翻滾應進入翻滾")
	await frames(25)
	var dist: float = p.position.x - x0
	check(dist > 320.0 and dist < 420.0, "翻滾距離應約 360 px，實際 %.1f" % dist)
	check(p.state == Player.State.FREE, "翻滾 0.3 秒後應回到自由狀態")
	p.intent.roll_pressed = true
	await frames(1)
	check(p.state != Player.State.ROLL, "冷卻中不能再翻滾")
	await free_world(w)


# ---- Task 5：攻擊 ----

func test_attack_cancel_only_in_recovery() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.attack_pressed = true
	await frames(1)
	check(p.state == Player.State.ATTACK and p.attack_phase == Player.Phase.STARTUP, "按攻擊應進入出招")
	p.intent.roll_pressed = true
	await frames(1)
	check(p.state == Player.State.ATTACK, "出招中按翻滾應無效")
	await wait_until(func(): return p.attack_phase == Player.Phase.ACTIVE, 30)
	p.intent.roll_pressed = true
	await frames(1)
	check(p.state == Player.State.ATTACK, "判定中按翻滾應無效")
	await wait_until(func(): return p.attack_phase == Player.Phase.RECOVERY, 30)
	p.intent.roll_pressed = true
	await frames(1)
	check(p.state == Player.State.ROLL, "收招中按翻滾應立刻翻滾（PROTO1-3）")
	await free_world(w)


func test_side_attack_damages_target_by_axe_damage() -> void:
	var w := make_world()
	var p = await make_player(w)
	var target := Hurtbox.new()
	target.setup(Vector2(80, 160), Vector2(0, -80), L.ENEMY_HURT)
	target.position = Vector2(110, 0)
	var got := []
	target.hurt.connect(func(amount, _src, kind): got.append([amount, kind]))
	w.add_child(target)
	p.intent.attack_pressed = true
	await frames(15)
	check(got.size() == 1 and got[0][0] == 4 and got[0][1] == &"melee", "側攻應打中一次、傷害 4，實際 %s" % [got])
	await free_world(w)


func test_down_slash_on_crystal_bounces() -> void:
	var w := make_world()
	var c := PogoCrystal.new()
	c.position = Vector2(0, -600)
	w.add_child(c)
	var p = await make_player(w, Vector2(0, -660))
	p.velocity = Vector2.ZERO
	p.intent.down = true
	p.intent.attack_pressed = true
	var bounced: bool = await wait_until(func(): return p.velocity.y < 0.0, 30)
	check(bounced, "下劈打中彈跳物後應向上彈（B8）")
	check(absf(p.velocity.y + 1700.0) < 1.0, "彈跳速度應為 -1700，實際 %.1f" % p.velocity.y)
	await free_world(w)


## Brian 自評（2026-10-06）：一般下落放慢；按下劈的瞬間變回原本的下落速度（1.5 倍）
func test_fall_slower_but_down_slash_snaps_to_normal() -> void:
	var t := fresh_tuning()
	check(is_equal_approx(t.fall_gravity_multiplier, 0.6), "下落重力倍率應為 0.6，實際 %.2f" % t.fall_gravity_multiplier)
	check(is_equal_approx(t.down_slash_gravity_multiplier, 1.5), "下劈重力倍率應為 1.5，實際 %.2f" % t.down_slash_gravity_multiplier)
	var w := make_world()
	var plain = await make_player(w, Vector2(-1000, -3000))
	var slash = await make_player(w, Vector2(1000, -3000))
	plain.velocity = Vector2.ZERO
	slash.velocity = Vector2.ZERO
	await frames(10)
	var g: float = t.gravity() / 60.0  # 每幀；第 1 幀速度為 0 還不算下落，用原本的重力
	var v10: float = g * (1.0 + 9.0 * 0.6)
	check(absf(plain.velocity.y - v10) < g * 0.5 and absf(slash.velocity.y - v10) < g * 0.5, "一般下落 10 幀速度應約 %.0f，實際 %.0f／%.0f" % [v10, plain.velocity.y, slash.velocity.y])
	slash.intent.down = true
	slash.intent.attack_pressed = true
	await frames(1)
	check(slash.state == Player.State.ATTACK, "按下劈後應在攻擊中")
	var snapped: float = v10 * 1.5 / 0.6 + g * 1.5
	check(absf(slash.velocity.y - snapped) < g * 0.5, "按下劈的那一幀速度應跳到約 %.0f，實際 %.0f" % [snapped, slash.velocity.y])
	var before: float = slash.velocity.y
	await frames(5)
	check(absf(slash.velocity.y - (before + 5.0 * g * 1.5)) < g * 0.5, "下劈中每幀應以 1.5 倍重力加速，實際 %.0f → %.0f" % [before, slash.velocity.y])
	await free_world(w)


# ---- Task 6：受擊、治療、掉坑 ----

func test_player_hurt_invuln() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.hurtbox.receive(1, null, &"enemy")
	p.hurtbox.receive(1, null, &"enemy")
	check(p.health.hp == 4, "受擊後無敵時間內再被打不應扣血，實際血量 %d" % p.health.hp)
	check(p.state == Player.State.HURT, "受擊應進入受擊狀態")
	await frames(70)
	p.hurtbox.receive(1, null, &"enemy")
	check(p.health.hp == 3, "無敵結束後應再扣血，實際血量 %d" % p.health.hp)
	await free_world(w)


func test_roll_iframes_window() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.roll_pressed = true
	await frames(1)
	check(not p.is_roll_invulnerable(), "翻滾第 0 幀還沒到無敵區間")
	await wait_until(func(): return p.state_time >= 0.1, 30)
	check(p.is_roll_invulnerable(), "翻滾 0.1 秒時應無敵")
	p.hurtbox.receive(1, null, &"enemy")
	check(p.health.hp == 5 and p.state == Player.State.ROLL, "無敵區間內受擊不應扣血、不中斷翻滾")
	await free_world(w)


func test_roll_outside_iframes_takes_damage() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.roll_pressed = true
	await frames(1)
	p.hurtbox.receive(1, null, &"enemy")
	check(p.health.hp == 4, "翻滾無敵區間外受擊應扣血")
	await free_world(w)


func test_heal_restores_after_stiffness() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.health.hp = 2
	p.intent.heal_pressed = true
	await frames(1)
	check(p.state == Player.State.HEAL and p.health.heal_charges == 1, "按治療應進入治療並立即扣次數")
	await frames(30)
	check(p.health.hp == 2, "硬直結束前不應回血")
	await frames(35)
	check(p.health.hp == 4 and p.state == Player.State.FREE, "硬直 1 秒後應回 2 點並恢復自由，實際血量 %d" % p.health.hp)
	await free_world(w)


func test_heal_interrupted_is_lost() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.health.hp = 3
	p.intent.heal_pressed = true
	await frames(20)
	p.hurtbox.receive(1, null, &"enemy")
	await frames(70)
	check(p.health.hp == 2, "治療中被打應中斷、不回血，實際血量 %d" % p.health.hp)
	check(p.health.heal_charges == 1, "被中斷的治療次數照扣（PROTO1-6）")
	await free_world(w)


func test_heal_at_full_hp_does_nothing() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.heal_pressed = true
	await frames(1)
	check(p.state == Player.State.FREE and p.health.heal_charges == 2, "滿血按治療不應進入治療、不扣次數")
	await free_world(w)


func test_pit_damages_even_when_invulnerable() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.hurtbox.receive(1, null, &"enemy")
	check(p.health.invuln_left > 0.0, "前提：受擊無敵中")
	p.fall_into_pit(Vector2(500, 0))
	check(p.health.hp == 3, "無敵中掉坑仍應扣 1 血，實際血量 %d" % p.health.hp)
	check(p.position == Vector2(500, 0), "掉坑後應回到坑邊")
	await free_world(w)


# ---- Task 7：吹箭 ----

func test_blowgun_rate_limit() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.dart_pressed = true
	await frames(1)
	p.intent.dart_pressed = true
	await frames(1)
	check(count_darts(w) == 1, "射速限制內連按只應發出一發，實際 %d" % count_darts(w))
	await frames(25)
	p.intent.dart_pressed = true
	await frames(1)
	check(count_darts(w) == 2, "0.35 秒後應可再發，實際 %d" % count_darts(w))
	await free_world(w)


func test_dart_hits_enemy_hurtbox_for_dart_damage() -> void:
	var w := make_world()
	var p = await make_player(w)
	var target := Hurtbox.new()
	target.setup(Vector2(80, 160), Vector2(0, -80), L.ENEMY_HURT)
	target.position = Vector2(600, 0)
	var got := []
	target.hurt.connect(func(amount, _src, kind): got.append([amount, kind]))
	w.add_child(target)
	p.intent.dart_pressed = true
	await frames(20)
	check(got.size() == 1 and got[0][0] == 1 and got[0][1] == &"dart", "飛鏢應打中一次、傷害 1、類型 dart，實際 %s" % [got])
	check(count_darts(w) == 0, "打中後飛鏢應消失")
	await free_world(w)


func test_no_dart_during_attack() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.attack_pressed = true
	await frames(2)
	p.intent.dart_pressed = true
	await frames(1)
	check(count_darts(w) == 0, "攻擊中不能射吹箭")
	await free_world(w)


# ---- 最終審查的修正 ----

## MV-TUNE-001（TUNE1-3）：吹管口在嘴邊高度，水平射從爬行型頭上飛過；往下瞄才打得到
func test_facing_dart_flies_over_crawler_aimed_dart_hits() -> void:
	var w := make_world()
	var p = await make_player(w)
	var e = await make_enemy(w, Crawler, Vector2(300, 0))
	e.set_physics_process(false)  # 只當靶，不移動也不出招
	p.intent.dart_pressed = true
	await frames(20)
	check(e.health.hp == e.tn.crawler_hp, "沒瞄準時朝面向射：從爬行型頭上飛過，實際血量 %d" % e.health.hp)
	p.blowgun.cooldown_left = 0.0
	p.intent.aim = Intent.aim_toward(Vector2(300, -35), p.facing)
	p.intent.dart_pressed = true
	await frames(20)
	check(e.health.hp == e.tn.crawler_hp - 1, "往下瞄準爬行型：打中，實際血量 %d" % e.health.hp)
	await free_world(w)


## MV-TUNE-001（TUNE1-1、2）：飛鏢從吹管口出發，吹管口跟著瞄準方向繞肩膀轉、面向左時鏡像
func test_dart_spawns_at_blowgun_mouth() -> void:
	check(Intent.muzzle(Vector2.RIGHT, 1).distance_to(Vector2(104, -151)) <= 10.0, "水平射的吹管口在嘴邊高度、身體前方（%s）" % Intent.muzzle(Vector2.RIGHT, 1))
	check(Intent.muzzle(Vector2.DOWN, 1).distance_to(Vector2(-3, -1)) <= 10.0, "往下射的吹管口在腳邊（%s）" % Intent.muzzle(Vector2.DOWN, 1))
	var w := make_world()
	var p = await make_player(w)
	for c in [[1, Vector2.ZERO], [-1, Vector2.ZERO], [1, Vector2(0.6, -0.8)], [-1, Vector2(0.6, 0.8)]]:
		p.facing = c[0]
		p.blowgun.cooldown_left = 0.0
		var d = p.blowgun.try_fire(c[1])
		var dir: Vector2 = c[1] if c[1] != Vector2.ZERO else Vector2(c[0], 0)
		var want: Vector2 = p.global_position + Intent.muzzle(dir, c[0])
		check(d.global_position.is_equal_approx(want), "面向 %d 瞄準 %s：飛鏢在吹管口 %s（實際 %s）" % [c[0], c[1], want, d.global_position])
		d.queue_free()
	await free_world(w)


## MV-TUNE-001：滑鼠與測試瞄準一個點時，從吹管口出發的直線正好通過那個點（吹管軸線不經過肩膀）
func test_aim_toward_passes_through_target() -> void:
	for t in [Vector2(300, -400), Vector2(-200, 50), Vector2(63, -372), Vector2(500, 0), Vector2(300, -35), Vector2(-600, -300)]:
		for f in [1, -1]:
			var a := Intent.aim_toward(t, f)
			var m := Intent.muzzle(a, f)
			check(is_equal_approx(a.length(), 1.0) and absf((t - m).cross(a)) < 0.5 and (t - m).dot(a) > 0.0,
				"目標 %s 面向 %d：直線通過目標（偏 %.2f px）" % [t, f, (t - m).cross(a)])


## MV-TUNE-001（TUNE1-4）：吹管口伸到薄牆後面時，飛鏢撞牆、不從牆後出發
func test_point_blank_wall_stops_dart() -> void:
	var w := make_world()
	var p = await make_player(w)
	var wall := StaticBody2D.new()
	wall.collision_layer = L.WORLD
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 400)
	cs.shape = rect
	cs.position = Vector2(65, -200)  # x 50～80：在身體（右緣 30）與吹管口（約 104）之間
	wall.add_child(cs)
	w.add_child(wall)
	var got := make_thin_target(w, 400.0, 80.0)
	await frames(2)
	var muzzle_x: float = p.global_position.x + Intent.muzzle(Vector2.RIGHT, 1).x
	check(muzzle_x > 80.0, "前提：吹管口在牆後（%.0f）" % muzzle_x)
	p.intent.aim = Intent.aim_toward(Vector2(400, -151), 1)
	p.intent.dart_pressed = true
	await frames(20)
	check(got.is_empty(), "貼牆射：飛鏢撞牆，不打中牆後的靶")
	check(count_darts(w) == 0, "貼牆射：飛鏢消失")
	await free_world(w)


func test_roll_pressed_during_active_rolls_at_recovery() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.attack_pressed = true
	await wait_until(func(): return p.attack_phase == Player.Phase.ACTIVE, 30)
	p.intent.roll_pressed = true
	await frames(1)
	check(p.state == Player.State.ATTACK, "判定中按翻滾不應立刻翻滾（PROTO1-3）")
	var rolled: bool = await wait_until(func(): return p.state == Player.State.ROLL, 10)
	check(rolled, "判定中按的翻滾應在收招第一幀執行（輸入緩衝）")
	await free_world(w)


func test_attack_pressed_during_recovery_attacks_again() -> void:
	var w := make_world()
	var p = await make_player(w)
	var swings := []
	p.swung.connect(func(): swings.append(1))
	p.intent.attack_pressed = true
	await wait_until(func(): return p.attack_phase == Player.Phase.RECOVERY, 30)
	await frames(6)
	p.intent.attack_pressed = true
	await frames(15)
	check(swings.size() == 2, "收招中按的攻擊應在收招結束後接著出手，實際揮擊 %d 次" % swings.size())
	await free_world(w)


func test_jump_cancels_recovery() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.attack_pressed = true
	await wait_until(func(): return p.attack_phase == Player.Phase.RECOVERY, 30)
	p.intent.jump_pressed = true
	p.intent.jump_held = true
	await frames(1)
	check(p.state == Player.State.FREE and p.velocity.y < -1000.0, "收招中按跳應立刻起跳（PROTO1-3）")
	await free_world(w)


func test_slight_stick_up_is_not_up() -> void:
	var it := Intent.new()
	var who := Node2D.new()
	add_child(who)
	Input.action_press("look_up", 0.35)
	it.read_from_input(who)
	check(not it.up, "左搖桿稍微偏上（強度 0.35）不應算成上攻")
	Input.action_press("look_up", 0.9)
	it.read_from_input(who)
	check(it.up, "左搖桿明確往上（強度 0.9）應算成上攻")
	Input.action_release("look_up")
	Input.action_press("look_down", 0.35)
	it.read_from_input(who)
	check(not it.down, "左搖桿稍微偏下（強度 0.35）不應算成下劈")
	Input.action_release("look_down")
	who.queue_free()
	await frames(1)


## MV-TUNE-001 試玩回饋（Brian 2026-10-12）：手把左搖桿也能瞄準吹箭——8 方向、只推左右＝朝面向、地上推正下＝斜下
func test_left_stick_aims_eight_ways() -> void:
	var d := sqrt(0.5)
	var cases := [
		# [左搖桿, 面向, 在地上, 期望]
		[Vector2.ZERO, 1, true, Vector2.ZERO, "沒推"],
		[Vector2(0.2, -0.1), 1, true, Vector2.ZERO, "死區內"],
		[Vector2(1, 0), 1, true, Vector2.ZERO, "只推右：朝面向"],
		[Vector2(-0.95, -0.25), -1, true, Vector2.ZERO, "左偏上 15°：仍是水平（朝面向）"],
		[Vector2(0.7, -0.7), 1, true, Vector2(d, -d), "右上"],
		[Vector2(-0.6, -0.8), -1, true, Vector2(-d, -d), "左上"],
		[Vector2(0.2, -0.95), 1, true, Vector2.UP, "接近正上：正上"],
		[Vector2(0.7, 0.7), 1, true, Vector2(d, d), "右下"],
		[Vector2(0, 1), 1, false, Vector2.DOWN, "空中正下"],
		[Vector2(0, 1), 1, true, Vector2(d, d), "地上正下＝面向右的斜下"],
		[Vector2(0, 1), -1, true, Vector2(-d, d), "地上正下＝面向左的斜下"],
	]
	for c in cases:
		var got := Intent.left_stick_aim(c[0], c[1], c[2])
		check(got.is_equal_approx(c[3]), "%s：左搖桿 %s → %s（實際 %s）" % [c[4], c[0], c[3], got])


## 手把：右搖桿優先；沒推右搖桿才用左搖桿；滑鼠不受左搖桿影響
func test_right_stick_overrides_left_stick_aim() -> void:
	var it := Intent.new()
	var who := Node2D.new()
	add_child(who)
	var was_pad: bool = InputSetup._last_pad
	InputSetup._last_pad = true
	Input.action_press("look_up", 1.0)
	it.read_from_input(who)
	check(it.aim.is_equal_approx(Vector2.UP), "手把只推左搖桿上：吹箭朝正上（%s）" % it.aim)
	Input.action_press("aim_right", 1.0)
	it.read_from_input(who)
	check(it.aim.is_equal_approx(Vector2.RIGHT), "同時推右搖桿右：聽右搖桿（%s）" % it.aim)
	Input.action_release("aim_right")
	InputSetup._last_pad = false
	it.read_from_input(who)
	check(not it.aim.is_equal_approx(Vector2.UP), "滑鼠模式：左搖桿不改瞄準（%s）" % it.aim)
	Input.action_release("look_up")
	InputSetup._last_pad = was_pad
	who.queue_free()
	await frames(1)


func test_side_attack_ignores_pogo_crystal() -> void:
	var w := make_world()
	var c := PogoCrystal.new()
	c.position = Vector2(110, -100)
	w.add_child(c)
	var p = await make_player(w)
	var hits := []
	p.hit_landed.connect(func(t): hits.append(t))
	p.intent.attack_pressed = true
	await frames(15)
	check(hits.is_empty(), "側攻不應打中彈跳物（只有下劈能打中），實際 %d 次" % hits.size())
	await free_world(w)


# ---- 延後的小問題 ----

func test_fast_dart_does_not_pass_thin_wall() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.tn.dart_speed = 6000.0
	p.tn.dart_range = 3000.0
	var wall := StaticBody2D.new()
	wall.collision_layer = L.WORLD
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 400)
	cs.shape = rect
	cs.position = Vector2(400, -200)
	wall.add_child(cs)
	w.add_child(wall)
	var got := make_thin_target(w, 800.0, 80.0)
	await frames(2)
	p.intent.dart_pressed = true
	await frames(30)
	check(got.is_empty(), "高速飛鏢不應穿過 30 px 的牆打中後面的靶")
	check(count_darts(w) == 0, "撞牆後飛鏢應消失")
	await free_world(w)


func test_fast_dart_hits_thin_target() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.tn.dart_speed = 6000.0
	p.tn.dart_range = 3000.0
	var got := make_thin_target(w, 545.0, 20.0)
	await frames(2)
	p.intent.dart_pressed = true
	await frames(30)
	check(got.size() == 1, "高速飛鏢應打中 20 px 寬的靶，實際 %d 次" % got.size())
	await free_world(w)


# ---- MV-PROTO-002 Task 1：數值、兩兄弟與武器資料 ----

func test_p2_tuning_defaults() -> void:
	var t := fresh_tuning()
	check(is_equal_approx(t.swap_cooldown, 0.3), "換人冷卻應為 0.3")
	check(is_equal_approx(t.double_jump_ratio, 0.75), "二段跳比例應為 0.75")
	check(t.stick_side_box == Vector2(210, 60), "掘棒側攻判定應為 210×60")
	check(is_equal_approx(t.parry_window, 0.2) and is_equal_approx(t.parry_recovery, 0.35), "招架窗口 0.2、收招 0.35")
	check(is_equal_approx(t.parry_stagger, 1.2), "招架硬直應為 1.2")
	check(t.tool_chops == 3 and is_equal_approx(t.tool_speed, 900.0), "工具 900 px/s、砍 3 下")
	var table := Tune.table(t)
	for g in ["換人", "二段跳", "掘棒", "球具", "工具", "練習對象"]:
		check(table.contains("| %s |" % g), "數值表缺群組 %s" % g)


func test_p2_weapon_data() -> void:
	var t := fresh_tuning()
	check(Weapons.damage(Weapons.Weapon.AXE, t) == 4 and Weapons.damage(Weapons.Weapon.STICK, t) == 4, "斧頭與掘棒傷害都是 4")
	check(Weapons.damage(Weapons.Weapon.BALLGEAR, t) == 0, "球具傷害 0")
	check(Weapons.box(Weapons.Weapon.STICK, Weapons.Dir.SIDE, t) == Vector2(210, 60), "掘棒側攻 210×60")
	check(Weapons.box(Weapons.Weapon.AXE, Weapons.Dir.SIDE, t) == t.axe_side_box, "斧頭側攻沿用 axe_side_box")
	check(Weapons.timing(Weapons.Weapon.STICK, t).is_equal_approx(Vector3(0.10, 0.08, 0.22)), "掘棒時間 0.10／0.08／0.22")
	check(Weapons.is_parry(Weapons.Weapon.BALLGEAR, Weapons.Dir.SIDE) and Weapons.is_parry(Weapons.Weapon.BALLGEAR, Weapons.Dir.UP), "球具側攻、上攻是招架")
	check(not Weapons.is_parry(Weapons.Weapon.BALLGEAR, Weapons.Dir.DOWN), "球具下劈不是招架")


func test_p2_twin_defaults() -> void:
	var h = Twin.hunahpu()
	var x = Twin.xbalanque()
	check(h.weapon == Weapons.Weapon.AXE and h.can_double_jump and not h.can_send_tool, "Hunahpu：斧頭、二段跳")
	check(x.weapon == Weapons.Weapon.BALLGEAR and x.can_send_tool and not x.can_double_jump, "Xbalanque：球具、派工具")
	check(h.color.is_equal_approx(Color(0.85, 0.55, 0.25)) and x.color.is_equal_approx(Color(0.25, 0.65, 0.7)), "兩人主色")


# ---- MV-PROTO-002 Task 2：換人 ----

func test_swap_in_free_keeps_motion() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(0, 0))
	p.health.hp = 3
	p.velocity = Vector2(400, -500)
	p.facing = -1
	var pos: Vector2 = p.position
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 1, "自由狀態按換人應換成 Xbalanque")
	check(p.health.hp == 3, "共用血量：換人後血量不變")
	check(p.facing == -1, "換人後面向不變")
	check(p.position.distance_to(pos) < 40.0, "換人不應瞬移")
	await free_world(w)


func test_swap_in_air() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.jump_pressed = true
	await frames(10)
	check(not p.is_on_floor(), "前提：在空中")
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 1, "空中也能換人")
	await free_world(w)


func test_swap_blocked_in_startup_active_buffered_to_recovery() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.attack_pressed = true
	await frames(1)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 0, "出招中不能換")
	await wait_until(func(): return p.attack_phase == Player.Phase.ACTIVE, 30)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 0, "判定中不能換")
	var swapped: bool = await wait_until(func(): return p.twin_index == 1, 12)
	check(swapped, "判定中按下的換人應在收招第一幀執行（0.1 秒緩衝）")
	check(p.state == Player.State.FREE, "換上場的人回到自由狀態")
	await free_world(w)


func test_swap_blocked_in_roll_heal_hurt() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.roll_pressed = true
	await frames(2)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 0 and p.state == Player.State.ROLL, "翻滾中不能換")
	await wait_until(func(): return p.state == Player.State.FREE, 40)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 1, "翻滾結束後能換")
	await frames(30)
	p.health.hp = 3
	p.intent.heal_pressed = true
	await frames(2)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 1 and p.state == Player.State.HEAL, "治療中不能換")
	await wait_until(func(): return p.state == Player.State.FREE, 90)
	await frames(30)
	p.hurtbox.receive(1, null, &"enemy")
	await frames(1)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.state == Player.State.HURT and p.twin_index == 1, "受擊硬直中不能換")
	await free_world(w)


func test_swap_cooldown() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.swap_pressed = true
	await frames(1)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 1, "冷卻 0.3 秒內再按不換")
	await frames(20)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 0, "冷卻過後可再換")
	await free_world(w)


func test_shared_health_across_swap() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.hurtbox.receive(1, null, &"enemy")
	await frames(30)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 1 and p.health.hp == 4, "Hunahpu 受的傷換人後仍在")
	await free_world(w)


# ---- MV-PROTO-002 Task 3：三種武器 ----

func test_stick_reaches_farther_than_axe() -> void:
	# 角色前緣在 x=30；斧頭判定到 30+140=170，掘棒到 30+210=240；靶（寬 20）放在 x=205
	var w := make_world()
	var p = await make_player(w)
	var got := make_target(w, 205.0)
	p.intent.attack_pressed = true
	await frames(20)
	check(got.is_empty(), "斧頭側攻不應打到 205 px 外的靶，實際 %s" % [got])
	await frames(10)
	p.set_weapon(Weapons.Weapon.STICK)
	p.intent.attack_pressed = true
	await frames(25)
	check(got.size() == 1 and got[0][0] == 4, "掘棒側攻應打到並扣 4，實際 %s" % [got])
	await free_world(w)


func test_stick_and_ballgear_down_bounce() -> void:
	for wpn in [Weapons.Weapon.STICK, Weapons.Weapon.BALLGEAR]:
		var w := make_world()
		var c := PogoCrystal.new()
		c.position = Vector2(0, -600)
		w.add_child(c)
		var p = await make_player(w, Vector2(0, -700))
		p.set_weapon(wpn)
		p.velocity = Vector2.ZERO
		p.intent.down = true
		p.intent.attack_pressed = true
		var bounced: bool = await wait_until(func(): return p.velocity.y < 0.0, 30)
		check(bounced, "%s 的下劈應能彈跳" % Weapons.NAMES[wpn])
		await free_world(w)


func test_ballgear_never_damages() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	var got := make_target(w, 80.0)
	p.intent.attack_pressed = true
	await frames(40)
	p.intent.up = true
	p.intent.attack_pressed = true
	await frames(40)
	check(got.is_empty(), "球具側攻、上攻不應造成傷害，實際 %s" % [got])
	await free_world(w)


func test_set_weapon_mid_attack_stops_hitbox() -> void:
	var w := make_world()
	var p = await make_player(w)
	var got := make_target(w, 80.0)
	p.intent.attack_pressed = true
	await frames(2)
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	await frames(20)
	check(p.state == Player.State.FREE, "攻擊中換武器應立即結束攻擊")
	check(got.is_empty(), "換武器後不應殘留斧頭傷害，實際 %s" % [got])
	await free_world(w)


# ---- MV-PROTO-002 Task 4：球具招架與招架紀錄 ----

func test_parry_stats_minute_buckets() -> void:
	var s = ParryStats.new()
	s.record(5.0, ParryStats.Result.SUCCESS)
	s.record(30.0, ParryStats.Result.WHIFF)
	s.record(70.0, ParryStats.Result.SUCCESS)
	s.record(75.0, ParryStats.Result.SUCCESS)
	s.record(80.0, ParryStats.Result.UNPARRYABLE)
	s.record(190.0, ParryStats.Result.SUCCESS)
	var rows: Array = s.minute_rows()
	check(rows.size() == 4, "應列出第 1～4 分鐘，實際 %d 列" % rows.size())
	check(rows[0].attempts == 2 and rows[0].successes == 1, "第 1 分鐘：2 次、成功 1")
	check(rows[1].attempts == 3 and rows[1].successes == 2, "第 2 分鐘：3 次、成功 2")
	check(rows[2].attempts == 0, "第 3 分鐘：0 次")
	var r: String = s.report()
	check(r.contains("| 1 | 2 | 1 | 50% |") and r.contains("| 2 | 3 | 2 | 67% |") and r.contains("| 3 | 0 | 0 | — |"), "報表格式不符：\n%s" % r)
	check(r.contains("被不可招架打到：1 次"), "報表應列出被不可招架打到的次數")


func test_parry_success_staggers_crawler() -> void:
	var a: Array = await parry_setup(Crawler, 300.0)
	var p = a[1]
	var e = a[2]
	await parry_when_close(p, e)
	var ok: bool = await wait_until(func(): return e.state == Enemy.State.STAGGER, 30)
	check(ok, "窗口內被爬行型撲擊打到應招架成功、敵人硬直")
	check(p.health.hp == 5, "招架成功不受傷")
	check(parry_totals(p).successes == 1, "紀錄應 +1 成功")
	await frames(60)
	check(e.state == Enemy.State.STAGGER, "招架硬直應長於 1 秒（1.2 秒）")
	await free_world(a[0])


func test_parry_unparryable_hurts() -> void:
	var a: Array = await parry_setup(Flyer, 200.0)
	var p = a[1]
	var e = a[2]
	await wait_until(func(): return e.state == Enemy.State.ATTACK, 200)
	await wait_until(func(): return e.global_position.distance_to(p.global_position + Vector2(0, -90)) < 220.0, 60)
	p.intent.attack_pressed = true
	var hurt: bool = await wait_until(func(): return p.health.hp < 5, 30)
	check(hurt, "窗口內被飛行型（不可招架）打到應受傷")
	check(p.parry_stats.report().contains("被不可招架打到：1 次"), "紀錄應 +1 被不可招架打到")
	await free_world(a[0])


func test_parry_late_is_whiff() -> void:
	var a: Array = await parry_setup(Crawler, 250.0)
	var p = a[1]
	var e = a[2]
	await wait_until(func(): return e.state == Enemy.State.TELEGRAPH, 120)
	await wait_until(func(): return e.state_time >= 0.3, 30)
	p.intent.attack_pressed = true  # 窗口在前搖中就結束，撲擊到達時角色正在收招
	var hurt: bool = await wait_until(func(): return p.health.hp < 5, 90)
	check(hurt, "窗口外（收招中）被打應受傷")
	var tot := parry_totals(p)
	check(tot.attempts == 1 and tot.successes == 0, "該次應記為白揮")
	await free_world(a[0])


func test_parry_from_behind_hurts() -> void:
	var a: Array = await parry_setup(Crawler, 300.0)
	var p = a[1]
	var e = a[2]
	p.facing = -1  # 背對敵人
	await parry_when_close(p, e)
	var hurt: bool = await wait_until(func(): return p.health.hp < 5, 30)
	check(hurt, "背後被打應受傷")
	await free_world(a[0])


func test_parry_same_x_counts_as_front() -> void:
	var w := make_world()
	var p = await make_player(w)
	var e = await make_enemy(w, Crawler, Vector2(0, 0), p)
	e.set_physics_process(false)
	e.state = Enemy.State.ATTACK
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	p.intent.attack_pressed = true
	await frames(1)
	p.hurtbox.receive(1, e, &"enemy")
	check(p.health.hp == 5 and e.state == Enemy.State.STAGGER, "x 相同時應視為正面、招架成功")
	await free_world(w)


func test_parry_success_allows_swap_same_frame() -> void:
	var a: Array = await parry_setup(Crawler, 300.0)
	var p = a[1]
	var e = a[2]
	await parry_when_close(p, e)
	await wait_until(func(): return e.state == Enemy.State.STAGGER, 30)
	check(p.can_swap(), "招架成功的當下應能換人")
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 1, "招架成功後立刻換人")
	await free_world(a[0])


# ---- MV-PROTO-002 Task 5：二段跳 ----

func test_hunahpu_double_jump_height() -> void:
	var w := make_world()
	var p = await make_player(w)
	var h: float = await double_jump_height(p)
	check(h > 620.0 and h < 760.0, "二段跳總高應約 700 px，實際 %.1f" % h)
	await free_world(w)


func test_xbalanque_cannot_double_jump() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.swap_twin()
	await frames(25)
	var h: float = await double_jump_height(p)
	check(h < 440.0, "Xbalanque 不能二段跳（只有約 400 px），實際 %.1f" % h)
	await free_world(w)


func test_swap_does_not_refresh_double_jump() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.jump_pressed = true
	p.intent.jump_held = true  # 按住跳，避免跳躍被截短而提早落地
	await frames(15)
	p.intent.jump_pressed = true
	await frames(1)
	check(p.air_jump_used, "前提：已用掉二段跳")
	p.intent.swap_pressed = true
	await frames(20)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 0 and p.air_jump_used, "空中換人來回不應刷新二段跳")
	var vy: float = p.velocity.y
	p.intent.jump_pressed = true
	await frames(1)
	check(p.velocity.y >= vy, "已用掉時再按跳不應再往上")
	await free_world(w)


func test_double_jump_restored_by_landing_and_pogo() -> void:
	var w := make_world()
	var c := PogoCrystal.new()
	c.position = Vector2(0, -600)
	w.add_child(c)
	var p = await make_player(w, Vector2(0, -700))
	p.air_jump_used = true
	p.velocity = Vector2.ZERO
	p.intent.down = true
	p.intent.attack_pressed = true
	await wait_until(func(): return p.velocity.y < 0.0, 30)
	check(not p.air_jump_used, "下劈彈起應恢復二段跳")
	p.air_jump_used = true
	await wait_until(func(): return p.is_on_floor(), 180)
	await frames(1)
	check(not p.air_jump_used, "落地應恢復二段跳")
	await free_world(w)


func test_respawn_restores_double_jump() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.air_jump_used = true
	p.respawn(Vector2.ZERO)
	check(not p.air_jump_used and p.twin_index == 0, "重生後二段跳恢復、回到 Hunahpu")
	await free_world(w)


# ---- MV-PROTO-002 Task 6：木障與讓工具自己動 ----

func test_xbalanque_dart_breaks_barrier() -> void:
	var w := make_world()
	var p = await make_player(w)
	var b = make_barrier(w)
	p.swap_twin()
	await frames(25)
	p.intent.dart_pressed = true
	var broke: bool = await wait_until(func(): return b.is_broken, 120)
	check(broke, "Xbalanque 的飛鏢射中木障後，工具應在 2 秒內把它砍碎")
	await wait_until(func(): return not is_instance_valid(p.tool), 120)
	check(not is_instance_valid(p.tool), "工具砍完應飛回並消失")
	await free_world(w)


## MV-TUNE-001（TUNE1-4）：貼著木障射，吹管口已經伸過木障，仍然標記
func test_xbalanque_dart_marks_barrier_point_blank() -> void:
	var w := make_world()
	var b = make_barrier(w)
	var p = await make_player(w, Vector2(270, 0))
	p.swap_twin()
	await frames(25)
	var muzzle_x: float = p.global_position.x + Intent.muzzle(Vector2.RIGHT, 1).x
	check(muzzle_x > 364.0, "前提：吹管口在木障受擊框後面（%.0f）" % muzzle_x)
	p.intent.dart_pressed = true
	var sent: bool = await wait_until(func(): return is_instance_valid(p.tool), 20)
	check(sent and not b.is_broken, "貼著木障射：標記木障、派出工具")
	await free_world(w)


func test_hunahpu_dart_and_melee_do_not_break_barrier() -> void:
	var w := make_world()
	var b = make_barrier(w)
	var p = await make_player(w, Vector2(200, 0))
	var thuds := []
	b.thudded.connect(func(): thuds.append(1))
	p.intent.dart_pressed = true
	await frames(20)
	for wpn in [Weapons.Weapon.AXE, Weapons.Weapon.STICK]:
		p.set_weapon(wpn)
		p.intent.attack_pressed = true
		await frames(30)
	p.swap_twin()
	await frames(25)
	p.set_weapon(Weapons.Weapon.AXE)
	p.intent.attack_pressed = true
	await frames(60)
	check(not b.is_broken, "Hunahpu 的飛鏢與任何人的近戰都不應打壞木障")
	check(thuds.size() >= 3, "打在木障上應發出悶響（thudded），實際 %d 次" % thuds.size())
	await free_world(w)


func test_only_one_tool_at_a_time() -> void:
	var w := make_world()
	var p = await make_player(w)
	var b = make_barrier(w)
	p.swap_twin()
	check(p.send_tool(b), "第一次派工具應成功")
	check(not p.send_tool(b), "工具在外時再派應失敗")
	await free_world(w)


func test_swap_while_tool_out_still_breaks() -> void:
	var w := make_world()
	var p = await make_player(w)
	var b = make_barrier(w)
	p.swap_twin()
	await frames(25)
	p.send_tool(b)
	await frames(2)
	p.swap_twin()
	var broke: bool = await wait_until(func(): return b.is_broken, 120)
	check(broke, "工具在外時換人，木障照樣被砍碎")
	await free_world(w)


func test_dart_mark_decided_at_fire() -> void:
	var w := make_world()
	var p = await make_player(w)
	var b = make_barrier(w)
	p.swap_twin()
	await frames(25)
	p.intent.dart_pressed = true
	await frames(1)
	p.swap_cooldown_left = 0.0
	p.swap_twin()  # 飛鏢還在飛時換回 Hunahpu
	var broke: bool = await wait_until(func(): return b.is_broken, 120)
	check(broke, "Xbalanque 射出的飛鏢在飛行中換人，仍應標記木障")
	await free_world(w)


func test_barrier_restore() -> void:
	var w := make_world()
	var b = make_barrier(w)
	await frames(2)
	b.break_apart()
	await frames(2)
	b.restore()
	await frames(2)
	check(not b.is_broken, "restore 後木障復原")
	var p = await make_player(w, Vector2(150, 0))
	p.intent.move_x = 1.0
	await frames(40)
	check(p.position.x < 300.0, "復原的木障應擋住角色")
	await free_world(w)


# ---- MV-PROTO-002 最終審查的修正 ----

func test_stick_side_hits_real_crawler_and_grounded_flyer() -> void:
	for scr in [Crawler, Flyer]:
		var w := make_world()
		var p = await make_player(w)
		p.set_weapon(Weapons.Weapon.STICK)
		var e = await make_enemy(w, scr, Vector2(200, 0))
		e.set_physics_process(false)  # 停在地面上（飛行型的落地收招就是這個高度）
		e.position = Vector2(200, 0)
		await frames(2)
		var hp0: int = e.health.hp
		p.intent.attack_pressed = true
		await frames(25)
		check(e.health.hp == hp0 - 4, "掘棒側攻應打中地面上的%s，血量 %d → %d" % ["爬行型" if scr == Crawler else "飛行型", hp0, e.health.hp])
		await free_world(w)


func test_dart_passes_broken_barrier() -> void:
	var w := make_world()
	var p = await make_player(w)
	var b = make_barrier(w)
	await frames(2)
	b.break_apart()
	await frames(2)
	var got := make_target(w, 700.0)
	p.intent.dart_pressed = true
	await frames(30)
	check(got.size() == 1, "木障碎掉後，飛鏢應穿過原位置打到後面的靶，實際 %s" % [got])
	await free_world(w)


func test_parry_whiff_recorded_when_left_by_swap_or_weapon_key() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	p.intent.attack_pressed = true
	await frames(8)
	p.intent.swap_pressed = true  # 窗口最後 0.1 秒內按換人：緩衝到窗口結束的那一幀
	await frames(20)
	check(p.twin_index == 1, "前提：已換人")
	check(not p.parry_pending and parry_totals(p).attempts == 1, "換人離開招架時，這次應記為白揮")
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	p.intent.attack_pressed = true
	await frames(2)
	p.set_weapon(Weapons.Weapon.AXE)
	await frames(2)
	check(parry_totals(p).attempts == 2, "用除錯鍵換武器離開招架時，這次也應記為白揮")
	await free_world(w)


func test_melee_on_barrier_is_thud_only() -> void:
	var w := make_world()
	var b = make_barrier(w)
	var p = await make_player(w, Vector2(200, 0))
	var landed := []
	p.hit_landed.connect(func(t): landed.append(t))
	p.intent.attack_pressed = true
	await frames(10)
	check(landed.is_empty() and p.recoil_left == 0.0, "斧頭打木障不應觸發命中回饋與後退")
	await frames(20)
	p.position = Vector2(330, -520)
	p.velocity = Vector2.ZERO
	await frames(1)
	p.intent.down = true
	p.intent.attack_pressed = true
	var bounced := false
	for i in 20:
		await frames(1)
		if p.velocity.y < 0.0:
			bounced = true
	check(not bounced, "下劈打到木障不應彈跳")
	await free_world(w)

