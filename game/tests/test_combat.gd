extends "res://tests/base_test.gd"
# 從 prototypes/core/tests/self_test.gd 搬來（MV-SLICE-001a Task 1）。

# ---- Task 1：參數檔 ----

func test_tuning_loads_from_tres() -> void:
	check(Tune.data != null, "Tune.data 沒有載入")
	check(Tune.data.resource_path == Tune.PATH, "Tune.data 應從 %s 載入，實際 %s" % [Tune.PATH, Tune.data.resource_path])
	check(is_equal_approx(fresh_tuning().run_speed, 700.0), "跑速初始值應為 700（MV-TUNE-002，Brian 試玩 2026-10-11）")


func test_tuning_derived_values() -> void:
	var t := fresh_tuning()
	check(is_equal_approx(t.gravity(), 5000.0), "重力應為 2×400/0.4² = 5000，實際 %s" % t.gravity())
	check(is_equal_approx(t.jump_velocity(), 2000.0), "起跳速度應為 2000，實際 %s" % t.jump_velocity())
	check(is_equal_approx(t.roll_speed(), 1200.0), "翻滾速度應為 360/0.3 = 1200，實際 %s" % t.roll_speed())


func test_tuning_table_lists_groups_and_values() -> void:
	var table := Tune.table(fresh_tuning())
	check(table.begins_with("| 分組 | 參數 | 值 |"), "數值表缺表頭")
	check(table.contains("| 移動 | run_speed | 700.0 |"), "數值表缺「移動／run_speed」")
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

