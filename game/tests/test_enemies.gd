extends "res://tests/base_test.gd"
# 從 prototypes/core/tests/self_test.gd 搬來（MV-SLICE-001a Task 1）。

# ---- Task 8：假光造物 ----

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

