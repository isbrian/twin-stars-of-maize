extends Node
# --self-test：每個 test_ 開頭的方法是一項測試，依名稱排序執行。
# 每項印一行 SELFTEST PASS|FAIL，最後印 SELFTEST SUMMARY。
# 測試一律用 fresh_tuning() 的獨立參數（命中停頓關閉），不動 Tune.data、不寫 .tres。
# 注意：執行期錯誤時 Godot 只印 SCRIPT ERROR 並繼續，該項會被記為 PASS，驗證時要另外 grep。

const Tuning := preload("res://tuning/combat_tuning.gd")
const L := preload("res://combat/layers.gd")
const Health := preload("res://combat/health.gd")
const Hitbox := preload("res://combat/hitbox.gd")
const Hurtbox := preload("res://combat/hurtbox.gd")
const Player := preload("res://player/player.gd")
const PogoCrystal := preload("res://level/pogo_crystal.gd")
const Dart := preload("res://player/dart.gd")
const Enemy := preload("res://enemies/enemy.gd")
const Crawler := preload("res://enemies/crawler.gd")
const Flyer := preload("res://enemies/flyer.gd")
const Room := preload("res://level/test_room.gd")
const Intent := preload("res://player/intent.gd")
const Feedback := preload("res://fx/feedback.gd")
const Sfx := preload("res://fx/sfx.gd")
const Twin := preload("res://player/twin.gd")
const Weapons := preload("res://player/weapons.gd")
const ParryStats := preload("res://combat/parry_stats.gd")
const Barrier := preload("res://level/barrier.gd")
const ParryDummy := preload("res://enemies/parry_dummy.gd")
const Hud := preload("res://ui/hud.gd")
const BreakGauge := preload("res://boss/break_gauge.gd")
const Light := preload("res://boss/light_source.gd")
const Nance := preload("res://boss/nance_arena.gd")
const Palace := preload("res://boss/palace_arena.gd")
const Macaw := preload("res://boss/seven_macaw.gd")
const Fruit := preload("res://boss/fruit.gd")
const FalseFlash := preload("res://boss/moves/false_flash.gd")
const Whiteout := preload("res://ui/whiteout.gd")
const Pillar := preload("res://boss/pillar.gd")
const Beam := preload("res://boss/moves/beam.gd")
const FightLog := preload("res://boss/fight_log.gd")
const TextCard := preload("res://ui/text_card.gd")
const StartMenu := preload("res://ui/start_menu.gd")
const CardText := preload("res://boss/card_text.gd")
const BossFight := preload("res://boss/boss_fight.gd")
const LaunchArgs := preload("res://launch_args.gd")

var pass_count := 0
var fail_count := 0
var _name := ""
var _failed := false


func run() -> void:
	var names: Array = []
	for m in get_method_list():
		if String(m.name).begins_with("test_"):
			names.append(m.name)
	names.sort()
	for n in names:
		_name = n
		_failed = false
		await call(n)
		if _failed:
			fail_count += 1
		else:
			pass_count += 1
		print("SELFTEST %s %s" % ["FAIL" if _failed else "PASS", n])
	print("SELFTEST SUMMARY pass=%d fail=%d" % [pass_count, fail_count])


func check(cond: bool, msg: String) -> void:
	if not cond:
		_failed = true
		print("SELFTEST   x %s：%s" % [_name, msg])


func fresh_tuning() -> Tuning:
	var t := Tuning.new()
	t.hitstop_time = 0.0
	return t


## 有地板的測試世界：地板頂端在 y=0，x 從 -3000 到 3000
func make_world() -> Node2D:
	var w := Node2D.new()
	add_child(w)
	var ground := StaticBody2D.new()
	ground.collision_layer = L.WORLD
	ground.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(6000, 200)
	cs.shape = r
	cs.position = Vector2(0, 100)
	ground.add_child(cs)
	w.add_child(ground)
	return w


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## 每幀檢查 cond，成立就回傳 true；超過 max_frames 回傳 cond 最後的結果
func wait_until(cond: Callable, max_frames := 120) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await frames(1)
	return cond.call()


func free_world(w: Node) -> void:
	w.queue_free()
	await frames(1)


# ---- Task 1：參數檔 ----

func test_tuning_loads_from_tres() -> void:
	check(Tune.data != null, "Tune.data 沒有載入")
	check(Tune.data.resource_path == Tune.PATH, "Tune.data 應從 %s 載入，實際 %s" % [Tune.PATH, Tune.data.resource_path])
	check(is_equal_approx(fresh_tuning().run_speed, 900.0), "跑速初始值應為 900")


func test_tuning_derived_values() -> void:
	var t := fresh_tuning()
	check(is_equal_approx(t.gravity(), 5000.0), "重力應為 2×400/0.4² = 5000，實際 %s" % t.gravity())
	check(is_equal_approx(t.jump_velocity(), 2000.0), "起跳速度應為 2000，實際 %s" % t.jump_velocity())
	check(is_equal_approx(t.roll_speed(), 1200.0), "翻滾速度應為 360/0.3 = 1200，實際 %s" % t.roll_speed())


func test_tuning_table_lists_groups_and_values() -> void:
	var table := Tune.table(fresh_tuning())
	check(table.begins_with("| 分組 | 參數 | 值 |"), "數值表缺表頭")
	check(table.contains("| 移動 | run_speed | 900.0 |"), "數值表缺「移動／run_speed」")
	check(table.contains("| 斧頭 | axe_damage | 4 |"), "數值表缺「斧頭／axe_damage」")
	check(table.contains("| 吹箭 | dart_interrupt_cooldown | 3.0 |"), "數值表缺「吹箭／dart_interrupt_cooldown」")


func test_tuning_save_roundtrip() -> void:
	var t := fresh_tuning()
	t.run_speed = 777.0
	var path := "user://selftest_tuning.tres"
	check(Tune.save(t, path) == OK, "存檔應成功")
	var back = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(back != null and is_equal_approx(back.run_speed, 777.0), "存回後重新載入應保留調整值")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_tuning_save_skips_default_values() -> void:
	# F9 存檔只存和初始值不同的數值；出招循環沒改時不應寫進 .tres
	var path := "user://selftest_tuning_defaults.tres"
	check(Tune.save(Tuning.new(), path) == OK, "存檔應成功")
	var text := FileAccess.get_file_as_string(path)
	check(not text.contains("_cycle"), "沒改過的出招循環不應寫進 .tres：\n%s" % text)
	var values := Array(text.split("\n")).filter(func(l): return l.contains(" = ") and not l.begins_with("script"))
	check(values.is_empty(), "初始值不應寫進 .tres：%s" % str(values))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ---- Task 2：血量 ----

func test_health_damage_and_invuln() -> void:
	var h := Health.new(5, 2)
	check(h.take_damage(1, 1.0), "第一次受擊應扣血")
	check(h.hp == 4, "受擊後血量應為 4，實際 %d" % h.hp)
	check(not h.take_damage(1, 1.0), "無敵中第二次受擊不應扣血")
	h.tick(0.5)
	check(not h.take_damage(1, 1.0), "無敵剩 0.5 秒時仍不應扣血")
	h.tick(0.6)
	check(h.take_damage(1, 1.0) and h.hp == 3, "無敵結束後應再扣血")
	check(h.take_damage(1, 1.0, true) and h.hp == 2, "ignore_invuln 應無視無敵（掉坑用）")


func test_health_heal_rules() -> void:
	var h := Health.new(5, 2)
	check(not h.begin_heal(), "滿血不能開始治療")
	check(h.heal_charges == 2, "滿血按治療不應扣次數")
	h.hp = 2
	check(h.begin_heal() and h.heal_charges == 1, "開始治療應立即扣一次（PROTO1-6）")
	h.finish_heal(2)
	check(h.hp == 4, "回 2 點後應為 4，實際 %d" % h.hp)
	check(h.begin_heal(), "還有 1 次應可治療")
	h.finish_heal(2)
	check(h.hp == 5, "回血不應超過上限，實際 %d" % h.hp)
	h.hp = 1
	check(not h.begin_heal(), "次數用完不能治療")
	h.hp = 0
	h.heal_charges = 1
	check(not h.begin_heal(), "已死不能治療")
	check(not h.take_damage(1), "已死不再扣血")


# ---- Task 3：判定框 ----

func test_hitbox_hits_each_target_once_per_swing() -> void:
	var w := make_world()
	var target := Hurtbox.new()
	target.setup(Vector2(100, 100), Vector2.ZERO, L.ENEMY_HURT)
	target.position = Vector2(0, -300)
	var got := []
	target.hurt.connect(func(amount, _src, kind): got.append([amount, kind]))
	w.add_child(target)
	var hb := Hitbox.new()
	hb.configure(Vector2(100, 100), Vector2.ZERO, L.ENEMY_HURT)
	hb.position = Vector2(30, -300)
	w.add_child(hb)
	await frames(3)
	check(hb.collect().is_empty(), "未啟用時不應打中")
	hb.start()
	for h in hb.collect():
		h.receive(4, hb, &"melee")
	for h in hb.collect():
		h.receive(4, hb, &"melee")
	check(got.size() == 1 and got[0][0] == 4 and got[0][1] == &"melee", "同一次揮擊只應打中一次，實際 %s" % [got])
	hb.stop()
	hb.start()
	for h in hb.collect():
		h.receive(4, hb, &"melee")
	check(got.size() == 2, "重新揮擊應可再打中，實際 %d 次" % got.size())
	await free_world(w)


# ---- Task 4：按鍵、移動、翻滾 ----

## 在測試世界放一個由測試操控的角色，等它站穩
func make_player(w: Node2D, at := Vector2.ZERO) -> Node:
	var p := Player.new()
	p.tn = fresh_tuning()
	p.scripted = true
	p.position = at
	w.add_child(p)
	await frames(3)
	return p


func test_input_scheme_a_registered() -> void:
	var expect := {
		"move_left": 3, "move_right": 3, "look_up": 3, "look_down": 3,
		"jump": 2, "roll": 2, "attack": 2, "dart": 2, "heal": 2,
		"aim_left": 1, "aim_right": 1, "aim_up": 1, "aim_down": 1,
		"debug_save": 1, "debug_reset": 1,
		"swap": 2, "debug_weapon_1": 1, "debug_weapon_2": 1, "debug_weapon_3": 1,
		"debug_gauge": 1, "menu_back": 2,
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

func count_darts(w: Node) -> int:
	var n := 0
	for c in w.get_children():
		if c is Dart:
			n += 1
	return n


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


# ---- Task 8：假光造物 ----

## 放一隻敵人；target 省略時給遠處的假人（敵人只會巡邏）
func make_enemy(w: Node2D, scr, at: Vector2, target: Node2D = null) -> Node:
	var e = scr.new()
	e.tn = fresh_tuning()
	e.position = at
	if target == null:
		target = Node2D.new()
		target.position = Vector2(100000, 0)
		w.add_child(target)
	e.target = target
	w.add_child(e)
	await frames(3)
	return e


func test_dart_interrupts_telegraph_with_cooldown() -> void:
	var w := make_world()
	var e = await make_enemy(w, Crawler, Vector2(0, 0))
	e.start_telegraph()
	e.hurtbox.receive(1, null, &"dart")
	check(e.state == Enemy.State.STAGGER, "前搖中被吹箭射中應進入硬直")
	check(e.health.hp == 11, "吹箭應扣 1 血，實際 %d" % e.health.hp)
	await wait_until(func(): return e.state == Enemy.State.IDLE, 60)
	e.start_telegraph()
	e.hurtbox.receive(1, null, &"dart")
	check(e.state == Enemy.State.TELEGRAPH, "打斷冷卻中再被射中不應硬直（PROTO1-5）")
	check(e.health.hp == 10, "冷卻中射中仍應扣血")
	await free_world(w)


func test_melee_does_not_interrupt() -> void:
	var w := make_world()
	var e = await make_enemy(w, Crawler, Vector2(0, 0))
	e.start_telegraph()
	e.hurtbox.receive(4, null, &"melee")
	check(e.state == Enemy.State.TELEGRAPH, "斧頭打中前搖中的敵人不應打斷（打斷是吹箭專屬）")
	check(e.health.hp == 8, "斧頭應扣 4 血，實際 %d" % e.health.hp)
	await free_world(w)


func test_touching_enemy_body_does_no_damage() -> void:
	var w := make_world()
	var p = await make_player(w)
	await make_enemy(w, Crawler, Vector2(0, 0))
	await frames(60)
	check(p.health.hp == 5, "碰到沒在攻擊的敵人身體不應受傷（PROTO1-4），實際血量 %d" % p.health.hp)
	await free_world(w)


func test_crawler_lunge_hits_player() -> void:
	var w := make_world()
	var p = await make_player(w)
	await make_enemy(w, Crawler, Vector2(300, 0), p)
	var hit: bool = await wait_until(func(): return p.health.hp < 5, 120)
	check(hit, "爬行型發現玩家後應前搖、撲擊並打中")
	check(p.health.hp == 4, "爬行型傷害應為 1，實際血量 %d" % p.health.hp)
	await free_world(w)


func test_flyer_dives_at_telegraph_position() -> void:
	var w := make_world()
	var p = await make_player(w)
	var e = await make_enemy(w, Flyer, Vector2(250, -350), p)
	var started: bool = await wait_until(func(): return e.state == Enemy.State.TELEGRAPH, 120)
	check(started, "飛行型就位後應開始前搖")
	check(e.dive_target == p.global_position, "俯衝目標應是前搖開始時玩家的位置")
	check(not e.parryable, "飛行型的訊號應為不可招架（暗紫鋸齒）")
	var landed: bool = await wait_until(func(): return e.state == Enemy.State.RECOVER, 120)
	check(landed and e.is_on_floor(), "俯衝後應在地面收招")
	await free_world(w)


func test_enemy_dies_at_zero_hp() -> void:
	var w := make_world()
	var e = await make_enemy(w, Crawler, Vector2(0, 0))
	var deaths := []
	e.died.connect(func(who): deaths.append(who))
	for i in 3:
		e.hurtbox.receive(4, null, &"melee")
	check(deaths.size() == 1, "血量歸零應發出一次 died，實際 %d 次" % deaths.size())
	await frames(1)
	check(not is_instance_valid(e), "死亡後應被移除")
	await free_world(w)


# ---- Task 9：測試房間 ----

func make_room() -> Node:
	var r := Room.new()
	r.tn = fresh_tuning()
	add_child(r)
	await frames(3)
	return r


func test_room_layout() -> void:
	var r = await make_room()
	var crawlers := 0
	var flyers := 0
	var crystals := 0
	for c in r.get_children():
		if c is Crawler:
			crawlers += 1
		elif c is Flyer:
			flyers += 1
		elif c is PogoCrystal:
			crystals += 1
	check(crawlers == 3 and flyers == 2, "應有爬行型 ×3、飛行型 ×2（戰鬥房＋小戰鬥房），實際 %d、%d" % [crawlers, flyers])
	check(crystals == 3, "平台段應有 3 個彈跳物，實際 %d" % crystals)
	await free_world(r)


func test_room_pit_respawns_at_edge() -> void:
	var r = await make_room()
	var p = r.player
	p.position = Vector2(Room.PIT_LEFT + 500.0, Room.GROUND_Y - 300.0)
	p.velocity = Vector2.ZERO
	var fell: bool = await wait_until(func(): return p.health.hp == 4, 120)
	check(fell, "掉進坑應扣 1 血")
	await frames(2)
	check(p.position.distance_to(Room.PIT_RESPAWN) < 50.0, "掉坑後應回到坑邊，實際位置 %s" % p.position)
	await free_world(r)


func test_room_reset_restores_everything() -> void:
	var r = await make_room()
	r.player.health.hp = 1
	r.player.health.heal_charges = 0
	r.enemies[0].hurtbox.receive(100, null, &"melee")
	await frames(1)
	r.reset_room()
	await frames(2)
	check(r.player.health.hp == 5 and r.player.health.heal_charges == 2, "重置後血量與治療次數應補滿")
	check(r.enemies.size() == 5, "重置後敵人應全部重生，實際 %d" % r.enemies.size())
	check(r.player.position.distance_to(Room.START) < 50.0, "重置後角色應回起點")
	await free_world(r)


func test_room_death_resets_room() -> void:
	var r = await make_room()
	var p = r.player
	p.health.hp = 1
	p.fall_into_pit(Room.PIT_RESPAWN)
	await frames(2)
	check(p.health.hp == 5, "血量歸零應重置房間（血量補滿），實際 %d" % p.health.hp)
	check(p.position.distance_to(Room.START) < 50.0, "血量歸零應回到起點")
	await free_world(r)


# ---- Task 10：回饋 ----

func test_hitstop_always_recovers() -> void:
	var f := Feedback.new()
	f.tn = fresh_tuning()
	f.tn.hitstop_time = 0.05
	add_child(f)
	f.hitstop()
	f.hitstop()
	check(Engine.time_scale == 0.0, "命中停頓中時間應暫停")
	OS.delay_msec(80)
	f._process(0.0)
	check(Engine.time_scale == 1.0, "停頓時間過後應恢復（連續命中也不會卡住）")
	Engine.time_scale = 1.0
	f.queue_free()
	await frames(1)


func test_sfx_bank_complete() -> void:
	var bank := Sfx.build_all()
	for s in [&"swing", &"hit", &"dart", &"interrupt", &"hurt", &"heal", &"pogo", &"shatter"]:
		check(bank.has(s), "缺少佔位音效 %s" % s)
		if bank.has(s):
			check(bank[s].data.size() > 0, "%s 沒有聲音資料" % s)


# ---- 最終審查的修正 ----

func test_facing_dart_hits_real_crawler() -> void:
	var w := make_world()
	var p = await make_player(w)
	var e = await make_enemy(w, Crawler, Vector2(300, 0))
	e.set_physics_process(false)  # 只當靶，不移動也不出招
	p.intent.dart_pressed = true
	await frames(20)
	check(e.health.hp == 11, "沒瞄準時朝面向射的飛鏢應打中同一地面上的爬行型，實際血量 %d" % e.health.hp)
	await free_world(w)


func test_room_full_jump_near_crawlers() -> void:
	var r = await make_room()
	var p = r.player
	p.scripted = true
	for e in r.enemies:
		e.set_physics_process(false)
	for home in Room.CRAWLERS:
		for dx in [-r.tn.crawler_patrol_range, 0.0, r.tn.crawler_patrol_range]:
			p.position = Vector2(home.x + dx, Room.GROUND_Y)
			p.velocity = Vector2.ZERO
			await frames(3)
			var y0: float = p.position.y
			p.intent.jump_pressed = true
			var top := y0
			for i in 40:
				p.intent.jump_held = true
				await frames(1)
				top = minf(top, p.position.y)
			check(y0 - top > 300.0, "在爬行型地盤 x=%d 完整跳應高於 300 px，實際 %.1f" % [home.x + dx, y0 - top])
	await free_world(r)


func test_room_flyer_leaves_pit_segment_alone() -> void:
	var r = await make_room()
	var p = r.player
	p.scripted = true
	p.position = Room.PIT_RESPAWN
	p.velocity = Vector2.ZERO
	await frames(600)
	check(p.health.hp == 5, "角色在坑邊待 10 秒不應被打（飛行型不該追到平台段），實際血量 %d" % p.health.hp)
	await free_world(r)


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

func test_room_camera_snaps_after_reset_and_pit() -> void:
	var r = await make_room()
	var p = r.player
	p.scripted = true
	for e in r.enemies:
		e.set_physics_process(false)
	p.position = Room.PIT_RESPAWN
	await frames(90)
	r.reset_room()
	await frames(2)
	var early: Vector2 = r.camera.get_screen_center_position()
	await frames(90)
	var settled: Vector2 = r.camera.get_screen_center_position()
	check(early.distance_to(settled) < 30.0, "重置後鏡頭應立即到位，不該掃過房間（差 %.0f px）" % early.distance_to(settled))
	p.position = Vector2(Room.PIT_LEFT + 500.0, Room.GROUND_Y - 300.0)
	p.velocity = Vector2.ZERO
	await wait_until(func(): return p.health.hp == 4, 120)
	await frames(2)
	early = r.camera.get_screen_center_position()
	await frames(90)
	settled = r.camera.get_screen_center_position()
	check(early.distance_to(settled) < 30.0, "掉坑回到坑邊後鏡頭應立即到位（差 %.0f px）" % early.distance_to(settled))
	await free_world(r)


func test_room_enemy_falling_into_pit_dies() -> void:
	var r = await make_room()
	var e = r.enemies[0]
	e.position = Vector2(Room.PIT_LEFT + 300.0, Room.GROUND_Y - 100.0)
	var gone: bool = await wait_until(func(): return r.enemies.size() == 4, 120)
	check(gone, "掉進坑的敵人應死亡並從清單移除（不能一直往下掉）")
	await free_world(r)


## 平台段機器人：從坑邊全速起跳，依序朝 targets（彈跳物 x）移動並在下落時下劈；
## 打完 targets 後往對岸走。回傳 [打中彈跳物的次數, 是否安全落在對岸]
func pogo_bot(r, targets: Array) -> Array:
	var p = r.player
	p.scripted = true
	for e in r.enemies:
		e.set_physics_process(false)
	p.position = Vector2(Room.PIT_LEFT - 20.0, Room.GROUND_Y)
	p.velocity = Vector2.ZERO
	await frames(3)
	var hits := []
	p.hit_landed.connect(func(t): hits.append(t))
	var far_x: float = Room.PIT_LEFT + Room.PIT_WIDTH + 200.0
	var crystal_y: float = Room.CRYSTALS[0].y
	p.intent.jump_pressed = true
	for i in 400:
		var idx := hits.size()
		var tx: float = targets[idx] if idx < targets.size() else far_x
		p.intent.jump_held = true
		p.intent.down = true
		p.intent.move_x = 1.0 if p.position.x < tx - 15.0 else (-1.0 if p.position.x > tx + 15.0 else 0.0)
		var lined_up: bool = idx < targets.size() and absf(p.position.x - tx) < 120.0
		p.intent.attack_pressed = lined_up and p.velocity.y > 0.0 and p.position.y > crystal_y - 260.0 and p.state != Player.State.ATTACK
		await frames(1)
		if p.health.hp < 5:
			break
		if i > 10 and p.is_on_floor():
			break
	var landed: bool = p.health.hp == 5 and p.is_on_floor() and p.position.x > Room.PIT_LEFT + Room.PIT_WIDTH
	return [hits.size(), landed]


func test_pogo_chain_of_three_crosses_pit() -> void:
	var r = await make_room()
	var xs := Room.CRYSTALS.map(func(c): return c.x)
	var result: Array = await pogo_bot(r, xs)
	check(result[0] == 3 and result[1], "依序下劈 3 顆彈跳物應能過坑，實際打中 %d 顆、落在對岸 %s" % [result[0], result[1]])
	await free_world(r)


func test_pogo_cannot_skip_first_crystal() -> void:
	var r = await make_room()
	var result: Array = await pogo_bot(r, [Room.CRYSTALS[1].x, Room.CRYSTALS[2].x])
	check(result[0] == 0 and not result[1], "從坑邊應跳不到第 2 顆（必須先彈第 1 顆），實際打中 %d 顆" % result[0])
	await free_world(r)


func test_pogo_cannot_skip_middle_crystal() -> void:
	var r = await make_room()
	var result: Array = await pogo_bot(r, [Room.CRYSTALS[0].x, Room.CRYSTALS[2].x])
	check(result[0] == 1 and not result[1], "從第 1 顆應彈不到第 3 顆（必須彈第 2 顆），實際打中 %d 顆" % result[0])
	await free_world(r)


func test_pogo_cannot_skip_last_crystal() -> void:
	var r = await make_room()
	var result: Array = await pogo_bot(r, [Room.CRYSTALS[0].x, Room.CRYSTALS[1].x])
	check(result[0] == 2 and not result[1], "從第 2 顆應落不到對岸（必須彈第 3 顆），實際打中 %d 顆、落在對岸 %s" % [result[0], result[1]])
	await free_world(r)


func make_thin_target(w: Node2D, x: float, width: float) -> Array:
	var target := Hurtbox.new()
	target.setup(Vector2(width, 160), Vector2(0, -80), L.ENEMY_HURT)
	target.position = Vector2(x, 0)
	var got := []
	target.hurt.connect(func(amount, _src, _kind): got.append(amount))
	w.add_child(target)
	return got


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


func test_room_reset_clears_darts() -> void:
	var r = await make_room()
	var p = r.player
	p.scripted = true
	p.intent.dart_pressed = true
	await frames(2)
	check(count_darts(r) == 1, "前提：有一支飛鏢在飛")
	r.reset_room()
	await frames(1)
	check(count_darts(r) == 0, "重置房間應清掉飛行中的飛鏢")
	await free_world(r)


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

func make_target(w: Node2D, x: float) -> Array:
	var target := Hurtbox.new()
	target.setup(Vector2(20, 160), Vector2(0, -80), L.ENEMY_HURT)
	target.position = Vector2(x, 0)
	var got := []
	target.hurt.connect(func(amount, _src, kind): got.append([amount, kind]))
	w.add_child(target)
	return got


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


## 角色面向右、在 x=0；爬行型在右邊撲過來
func parry_setup(enemy_scr, enemy_x: float) -> Array:
	var w := make_world()
	var p = await make_player(w)
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	var e = await make_enemy(w, enemy_scr, Vector2(enemy_x, 0), p)
	return [w, p, e]


## 在敵人攻擊判定碰到角色前 frames_before 幀按下招架
func parry_when_close(p, e, frames_before := 3) -> void:
	await wait_until(func(): return e.state == Enemy.State.ATTACK, 120)
	await wait_until(func(): return absf(e.global_position.x - p.global_position.x) < 150.0 + frames_before * 18.0, 30)
	p.intent.attack_pressed = true


func test_parry_success_staggers_crawler() -> void:
	var a: Array = await parry_setup(Crawler, 300.0)
	var p = a[1]
	var e = a[2]
	await parry_when_close(p, e)
	var ok: bool = await wait_until(func(): return e.state == Enemy.State.STAGGER, 30)
	check(ok, "窗口內被爬行型撲擊打到應招架成功、敵人硬直")
	check(p.health.hp == 5, "招架成功不受傷")
	check(p.parry_stats.minute_rows()[0].successes == 1, "紀錄應 +1 成功")
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
	var rows: Array = p.parry_stats.minute_rows()
	check(rows.size() == 1 and rows[0].attempts == 1 and rows[0].successes == 0, "該次應記為白揮")
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

## 從地面按住跳，在上升頂點附近（第 22 幀）再按一次；回傳最高點離地高度
func double_jump_height(p) -> float:
	var y0: float = p.position.y
	p.intent.jump_pressed = true
	var top := y0
	for i in 90:
		p.intent.jump_held = true
		if i == 22:
			p.intent.jump_pressed = true
		await frames(1)
		top = minf(top, p.position.y)
	return y0 - top



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

## 木障：x=300 處、從 y=-400 到地面
func make_barrier(w: Node2D) -> Node:
	var b = Barrier.new()
	b.setup(Rect2(300, -400, 60, 400))
	w.add_child(b)
	return b


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


# ---- MV-PROTO-002 Task 7：招架練習對象 ----

func test_dummy_attacks_periodically_and_never_dies() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(150, 0))
	var d = await make_enemy(w, ParryDummy, Vector2(0, 0), p)
	var telegraphs := 0
	var last = d.state
	for i in 300:
		await frames(1)
		if d.state == Enemy.State.TELEGRAPH and last != Enemy.State.TELEGRAPH:
			telegraphs += 1
		last = d.state
	check(telegraphs >= 2, "5 秒內應至少出招 2 次（每 2 秒），實際 %d" % telegraphs)
	check(d.parryable, "練習對象的攻擊應可招架（白色圓形）")
	check(absf(d.position.x) < 1.0, "練習對象不應移動")
	d.hurtbox.receive(100, null, &"melee")
	await frames(1)
	check(is_instance_valid(d) and d.state != Enemy.State.DEAD, "練習對象不會死")
	check(p.health.hp < 5, "站在面前 150 px 內應會被打到")
	await free_world(w)


func test_dummy_can_be_parried() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(150, 0))
	p.facing = -1
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	var d = await make_enemy(w, ParryDummy, Vector2(0, 0), p)
	await wait_until(func(): return d.state == Enemy.State.TELEGRAPH, 200)
	await wait_until(func(): return d.state_time >= d.tn.crawler_telegraph - 0.1, 60)
	p.intent.attack_pressed = true
	var ok: bool = await wait_until(func(): return d.state == Enemy.State.STAGGER, 30)
	check(ok and p.health.hp == 5, "練習對象的攻擊應能被招架、不受傷")
	await free_world(w)


# ---- MV-PROTO-002 Task 8：探索區與房間整合 ----

## 探索區機器人：在 start 放下角色（指定兄弟），依 steps 逐幀輸入；回傳角色
## steps 每項：{"frames": int, "move_x": float, "jump": bool, "hold": bool, "swap": bool, "dart": bool, "aim": Vector2}
func explore_bot(r, start: Vector2, twin: int, steps: Array) -> Node:
	var p = r.player
	p.scripted = true
	for e in r.enemies:
		e.set_physics_process(false)
	p.position = start
	p.velocity = Vector2.ZERO
	if p.twin_index != twin:
		p.swap_twin()
	p.swap_cooldown_left = 0.0
	p.facing = 1
	await frames(3)
	for s in steps:
		for i in s.get("frames", 1):
			p.intent.move_x = s.get("move_x", 0.0)
			p.intent.jump_held = s.get("hold", false)
			if i == 0:
				p.intent.jump_pressed = s.get("jump", false)
				p.intent.swap_pressed = s.get("swap", false)
				p.intent.dart_pressed = s.get("dart", false)
				p.intent.aim = s.get("aim", Vector2.ZERO)
			await frames(1)
	return p


func test_explore_ledge1_needs_double_jump() -> void:
	var r = await make_room()
	var climb := [
		{"frames": 20, "move_x": 1.0},
		{"frames": 22, "move_x": 1.0, "jump": true, "hold": true},
		{"frames": 40, "move_x": 1.0, "jump": true, "hold": true},
		{"frames": 30, "move_x": 1.0},
	]
	var p = await explore_bot(r, Vector2(5450, Room.GROUND_Y), 0, climb)
	check(p.position.x > 5650 and p.position.y < Room.GROUND_Y - 500, "Hunahpu 應能二段跳上 ① 高台，實際 %s" % p.position)
	p = await explore_bot(r, Vector2(5450, Room.GROUND_Y), 1, climb)
	check(p.position.x < 5600, "Xbalanque 單跳上不了 ① 高台，實際 %s" % p.position)
	await free_world(r)


func test_explore_pit2_needs_xbalanque() -> void:
	var r = await make_room()
	var b2 = r.barriers[0]
	var p = await explore_bot(r, Vector2(6950, Room.GROUND_Y), 0, [{"frames": 40, "dart": true}])
	check(not b2.is_broken, "Hunahpu 的飛鏢不能破 ② 的木障")
	p = await explore_bot(r, Vector2(6950, Room.GROUND_Y), 1, [{"frames": 150, "dart": true}])
	check(b2.is_broken, "Xbalanque 在坑緣朝面向射，應破 ② 的木障")
	p = await explore_bot(r, Vector2(6950, Room.GROUND_Y), 0, [
		{"frames": 4, "move_x": 1.0},
		{"frames": 45, "move_x": 1.0, "jump": true, "hold": true},
		{"frames": 40, "move_x": 1.0},
	])
	check(p.position.x > Room.PIT2_LEFT + Room.PIT2_WIDTH and p.health.hp == 5, "破障後應能跳過 ② 的坑，實際 %s、血量 %d" % [p.position, p.health.hp])
	await free_world(r)


func test_explore_ledge3_needs_both() -> void:
	var r = await make_room()
	var b3 = r.barriers[1]
	# Hunahpu 先二段跳上台階頂端的落腳處，換 Xbalanque 近距離射破木障，再往右走
	var p = await explore_bot(r, Vector2(7850, Room.GROUND_Y), 0, [
		{"frames": 22, "move_x": 1.0, "jump": true, "hold": true},
		{"frames": 40, "move_x": 0.6, "jump": true, "hold": true},
		{"frames": 30},
	])
	check(p.position.y < Room.GROUND_Y - 500 and p.position.x < 8160, "Hunahpu 應落在 ③ 木障前的落腳處，實際 %s" % p.position)
	p = await explore_bot(r, p.position, 1, [{"frames": 150, "dart": true}])
	check(b3.is_broken, "換 Xbalanque 後應能破 ③ 的木障")
	p = await explore_bot(r, p.position, 1, [{"frames": 120, "move_x": 1.0}])
	check(p.position.x > 8800, "破障後應能走到小戰鬥房，實際 %s" % p.position)
	await free_world(r)


func test_room_pit2_respawns_at_edge() -> void:
	var r = await make_room()
	var p = r.player
	p.position = Vector2(Room.PIT2_LEFT + 150.0, Room.GROUND_Y - 300.0)
	p.velocity = Vector2.ZERO
	var fell: bool = await wait_until(func(): return p.health.hp == 4, 120)
	check(fell, "掉進 ② 的坑應扣 1 血")
	await frames(2)
	check(p.position.distance_to(Room.PIT2_RESPAWN) < 50.0, "應回到 ② 的坑緣，實際 %s" % p.position)
	await free_world(r)


func test_room_reset_recalls_tool() -> void:
	var r = await make_room()
	var p = r.player
	p.scripted = true
	var b2 = r.barriers[0]
	p.position = Vector2(6950, Room.GROUND_Y)
	p.swap_twin()
	await frames(3)
	p.send_tool(b2)
	await frames(2)
	r.reset_room()
	await frames(3)
	check(not is_instance_valid(p.tool), "重置房間應收回在外的工具")
	check(not b2.is_broken, "重置後木障完好")
	check(p.twin_index == 0, "重置後回到 Hunahpu")
	p.position = Vector2(6950, Room.GROUND_Y)
	p.swap_twin()
	await frames(3)
	check(p.send_tool(b2), "重置後應能再派工具")
	await free_world(r)


func test_room_has_dummy_and_barriers() -> void:
	var r = await make_room()
	check(r.barriers.size() == 2, "應有 2 道木障")
	check(r.dummy != null and r.dummy.position.distance_to(Room.DUMMY) < 5.0, "練習對象應在起點左側")
	await free_world(r)


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
	check(not p.parry_pending and p.parry_stats.minute_rows().size() == 1 and p.parry_stats.minute_rows()[0].attempts == 1, "換人離開招架時，這次應記為白揮")
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	p.intent.attack_pressed = true
	await frames(2)
	p.set_weapon(Weapons.Weapon.AXE)
	await frames(2)
	check(p.parry_stats.minute_rows()[0].attempts == 2, "用除錯鍵換武器離開招架時，這次也應記為白揮")
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


func test_dummy_restarts_cycle_after_parry_stagger() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(150, 0))
	p.facing = -1
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	var d = await make_enemy(w, ParryDummy, Vector2(0, 0), p)
	await wait_until(func(): return d.state == Enemy.State.TELEGRAPH, 200)
	await wait_until(func(): return d.state_time >= d.tn.crawler_telegraph - 0.1, 60)
	p.intent.attack_pressed = true
	await wait_until(func(): return d.state == Enemy.State.STAGGER, 30)
	await wait_until(func(): return d.state != Enemy.State.STAGGER, 120)
	var gap := 0
	while d.state != Enemy.State.TELEGRAPH and gap < 300:
		await frames(1)
		gap += 1
	check(gap >= 108, "招架硬直結束後應重新計時（約 2 秒才再出招），實際 %.2f 秒" % (gap / 60.0))
	await free_world(w)


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


## 假 Boss：身體受擊框 180×140（x=at_x、站在地上）＋面向角色那一側、吹箭口高度的光源；回傳 [身體, 光源, 紀錄]
func make_fake_boss(w: Node2D, at_x: float) -> Array:
	var got := []
	var body := Hurtbox.new()
	body.setup(Vector2(180, 140), Vector2(0, -70), L.ENEMY_HURT)
	body.position = Vector2(at_x, 0)
	body.hurt.connect(func(_a, _s, kind): got.append(["body", kind]))
	w.add_child(body)
	var light = Light.new()
	light.setup(Vector2(40, 40), Vector2.ZERO, L.LIGHT)
	light.collision_layer = 0
	light.position = Vector2(-60, -45)
	light.hurt.connect(func(_a, src, _k): got.append(["light", src.get("can_setup")]))
	body.add_child(light)
	return [body, light, got]


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

## 在場地放角色（不放 Boss）；回傳 [容器, 場地, 角色]
func arena_setup(scr, at: Vector2) -> Array:
	var w := Node2D.new()
	add_child(w)
	var a = scr.new()
	w.add_child(a)
	var p := Player.new()
	p.tn = fresh_tuning()
	p.scripted = true
	p.position = at
	w.add_child(p)
	await frames(3)
	return [w, a, p]


## 依 steps 逐幀填角色的操作（格式同 explore_bot）
func drive(p, steps: Array) -> void:
	for s in steps:
		for i in s.get("frames", 1):
			p.intent.move_x = s.get("move_x", 0.0)
			p.intent.jump_held = s.get("hold", false)
			if i == 0:
				p.intent.jump_pressed = s.get("jump", false)
				p.intent.swap_pressed = s.get("swap", false)
				p.intent.dart_pressed = s.get("dart", false)
				p.intent.aim = s.get("aim", Vector2.ZERO)
			await frames(1)


## 從高台左緣前 150 px 起跑 → 跳 → 空中再按跳（同 test_explore_ledge1_needs_double_jump）
const CLIMB := [
	{"frames": 20, "move_x": 1.0},
	{"frames": 22, "move_x": 1.0, "jump": true, "hold": true},
	{"frames": 40, "move_x": 1.0, "jump": true, "hold": true},
	{"frames": 30, "move_x": 1.0},
]


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

## Boss 單元測試：第 phase 段的場地＋角色（Boss 起始位置左邊 500 px、面向右、站在地上）＋Boss（不自動出招）
func boss_setup(phase: int) -> Array:
	var w := Node2D.new()
	add_child(w)
	w.add_child(Nance.new() if phase == 1 else Palace.new())
	var home: Vector2 = Nance.CANOPY if phase == 1 else Palace.HOME
	var p := Player.new()
	p.tn = fresh_tuning()
	p.scripted = true
	p.position = Vector2(home.x - 500.0, Nance.GROUND_Y)
	w.add_child(p)
	var b = Macaw.new()
	b.tn = p.tn
	b.target = p
	b.cycle_enabled = false
	w.add_child(b)
	b.begin_phase(phase)
	await frames(3)
	return [w, p, b]


func count_of(w: Node, scr) -> int:
	var n := 0
	for c in w.get_children():
		if is_instance_of(c, scr):
			n += 1
	return n


## 只當飛鏢來源用（不加進場景）
func fake_dart(can_setup: bool) -> Node:
	var d := Dart.new()
	d.can_setup = can_setup
	return d


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
	check(p.parry_stats.minute_rows()[0].successes == 1, "記一筆招架成功")
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

const TEST_LOG_DIR := "user://selftest_boss_logs"


func remove_test_logs() -> void:
	var path := ProjectSettings.globalize_path(TEST_LOG_DIR)
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(path)


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


func test_start_menu_items_and_toggle() -> void:
	var m = StartMenu.new()
	add_child(m)
	var got := []
	m.chosen.connect(func(mode, keep): got.append([mode, keep]))
	check(m.labels() == PackedStringArray(["練習房", "Boss 戰", "Boss 段落保留：關"]), "兩個選項＋段落保留開關")
	m.move(1)
	m.move(1)
	m.confirm()
	check(m.keep_phase and m.labels()[2] == "Boss 段落保留：開", "切換段落保留")
	m.move(-1)
	m.confirm()
	m.move(-1)
	m.move(-1)
	m.confirm()
	check(got == [["boss", true], ["room", true]], "選 Boss 戰與練習房，實際 %s" % [got])
	m.queue_free()
	await frames(1)


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


# ---- MV-PROTO-003 Task 10：Boss 戰流程（一）----

## 完整 Boss 戰（日誌寫到測試資料夾、文字卡不需等 0.5 秒）；start_phase 1～3 直接開打、4＝覺醒後的出口、0＝從樹下篝火開始
func make_fight(start_phase := 0, cycle := false) -> Node:
	var f = BossFight.new()
	f.tn = fresh_tuning()
	f.tester = "selftest"
	f.log_dir = TEST_LOG_DIR
	f.player_scripted = true
	add_child(f)
	await frames(3)
	f.card.min_time = 0.0
	f.boss.cycle_enabled = cycle
	if start_phase > 0:
		f.start_at(start_phase)
		await frames(2)
	return f


func free_fight(f) -> void:
	f.queue_free()
	await frames(2)
	remove_test_logs()


func log_types(f) -> Array:
	var out := []
	for e in f.log.events:
		out.append(e.type)
	return out


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


# ---- MV-PROTO-003 Task 11：Boss 戰流程（二）----

func kill_player(f, by: String) -> void:
	f.boss.move_name = by
	f.player.health.hp = 1
	f.player.hurtbox.receive(1, f.boss, &"enemy")
	await frames(3)


func setup_now(f) -> void:
	f.debug_fill_gauge()
	await frames(1)
	var h := fake_dart(true)
	f.boss.light.receive(1, h, &"dart")
	h.free()
	await wait_until(func(): return f.card.visible, 10)


func next_card(f, key: String) -> bool:
	var ok: bool = f.card.visible and f.card.text == CardText.CARDS[key]
	f.card.confirm()
	await frames(2)
	return ok


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
	check(f.hud.notice.contains("二段跳"), "覺醒後提示胡納普能二段跳，實際「%s」" % f.hud.notice)
	await free_fight(f)


func test_exit_hint_fades() -> void:
	var f = await make_fight(4)
	check(f.hud.notice.contains("二段跳"), "直接進出口也顯示二段跳提示")
	await frames(int(BossFight.EXIT_HINT_TIME * 60) + 10)
	check(f.hud.notice == "", "提示 %s 秒後消失" % BossFight.EXIT_HINT_TIME)
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


# ---- MV-PROTO-003 Task 12：入口與參數 ----

func test_launch_args_parse() -> void:
	check(LaunchArgs.parse(PackedStringArray()).mode == "menu", "沒有參數 → 開頭選單")
	check(LaunchArgs.parse(PackedStringArray(["--self-test"])).mode == "selftest", "--self-test")
	var a := LaunchArgs.parse(PackedStringArray(["--boss"]))
	check(a.mode == "boss" and a.boss_phase == 0 and a.tester == "anon", "--boss 直接進 Boss 戰，代號預設 anon")
	a = LaunchArgs.parse(PackedStringArray(["--boss-phase", "3", "--tester", "A 01"]))
	check(a.mode == "boss" and a.boss_phase == 3 and a.tester == "A_01", "--boss-phase 與 --tester（清理檔名字元）")
	check(LaunchArgs.parse(PackedStringArray(["--boss-phase", "9"])).boss_phase == 0, "段數超出範圍 → 從頭")
	check(LaunchArgs.parse(PackedStringArray(["--tester"])).tester == "anon", "--tester 缺值 → anon")
	a = LaunchArgs.parse(PackedStringArray(["--demo-parry"]))
	check(a.mode == "room" and a.demo == "--demo-parry", "既有展示模式進練習房")
	a = LaunchArgs.parse(PackedStringArray(["--demo-boss-p3"]))
	check(a.mode == "boss" and a.boss_phase == 3 and a.demo == "--demo-boss-p3", "Boss 展示模式")


# ---- MV-PROTO-003 最終審查的修正 ----

func test_menu_back_needs_second_press_in_boss() -> void:
	var f = await make_fight(1)
	check(not f.request_menu(), "Boss 戰中第一次按 Esc／Start 不離開")
	check(f.hud.notice != "", "顯示「再按一次回選單」")
	check(f.request_menu(), "2 秒內再按一次才離開")
	f.hud.notice = ""
	check(not f.request_menu(), "重新開始計算")
	await frames(125)
	check(f.hud.notice == "" and not f.request_menu(), "超過 2 秒要重新按兩次")
	await free_fight(f)


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


func test_dart_from_behind_does_not_hit_front_light() -> void:
	var w := make_world()
	var p = await make_player(w)
	var a := make_fake_boss(w, 600.0)
	a[1].position = Vector2(60, -45)
	a[1].set_state(Light.State.GLOW)
	await frames(2)
	p.intent.dart_pressed = true
	await frames(25)
	check(a[2] == [["body", &"dart"]], "從背後射：打到身體，不會穿過身體打中另一側的光源，實際 %s" % [a[2]])
	await free_world(w)

