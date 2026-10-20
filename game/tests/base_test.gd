extends Node
# 測試的共用基底（從 prototypes/core/tests/self_test.gd 拆出；MV-SLICE-001a Task 1）。
# 每個 tests/test_*.gd 繼承這個檔案；runner.gd 依檔名、再依方法名稱排序執行。
# 每項印一行 SELFTEST PASS|FAIL，最後印 SELFTEST SUMMARY。
# 測試一律用 fresh_tuning() 的獨立參數（命中停頓關閉），不動 Tune.data、不寫 .tres。
# 注意：執行期錯誤時 Godot 只印 SCRIPT ERROR 並繼續，該項會被記為 PASS，驗證時要另外 grep。

const Tuning := preload("res://core/tuning/combat_tuning.gd")
const L := preload("res://core/combat/layers.gd")
const Health := preload("res://core/combat/health.gd")
const Hitbox := preload("res://core/combat/hitbox.gd")
const Hurtbox := preload("res://core/combat/hurtbox.gd")
const Player := preload("res://core/player/player.gd")
const PogoCrystal := preload("res://core/level/pogo_crystal.gd")
const Dart := preload("res://core/player/dart.gd")
const Enemy := preload("res://core/enemies/enemy.gd")
const Crawler := preload("res://core/enemies/crawler.gd")
const Flyer := preload("res://core/enemies/flyer.gd")
const Intent := preload("res://core/player/intent.gd")
const Feedback := preload("res://core/fx/feedback.gd")
const Sfx := preload("res://core/fx/sfx.gd")
const Twin := preload("res://core/player/twin.gd")
const Weapons := preload("res://core/player/weapons.gd")
const ParryStats := preload("res://core/combat/parry_stats.gd")
const Barrier := preload("res://core/level/barrier.gd")
const Hud := preload("res://ui/hud.gd")
const BreakGauge := preload("res://core/boss/break_gauge.gd")
const Light := preload("res://core/boss/light_source.gd")
const Nance := preload("res://core/boss/nance_arena.gd")
const Palace := preload("res://core/boss/palace_arena.gd")
const Macaw := preload("res://core/boss/seven_macaw.gd")
const Fruit := preload("res://core/boss/fruit.gd")
const FalseFlash := preload("res://core/boss/moves/false_flash.gd")
const Whiteout := preload("res://ui/whiteout.gd")
const Pillar := preload("res://core/boss/pillar.gd")
const Beam := preload("res://core/boss/moves/beam.gd")
const FightLog := preload("res://core/boss/fight_log.gd")
const TextCard := preload("res://ui/text_card.gd")
const CardText := preload("res://core/boss/card_text.gd")
const BossFight := preload("res://core/boss/boss_fight.gd")
const LaunchArgs := preload("res://launch_args.gd")

const CLIMB := [
	{"frames": 20, "move_x": 1.0},
	{"frames": 22, "move_x": 1.0, "jump": true, "hold": true},
	{"frames": 40, "move_x": 1.0, "jump": true, "hold": true},
	{"frames": 30, "move_x": 1.0},
]
const TEST_LOG_DIR := "user://selftest_boss_logs"

var pass_count := 0
var fail_count := 0
var _name := ""
var _failed := false


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


## 在測試世界放一個由測試操控的角色，等它站穩
func make_player(w: Node2D, at := Vector2.ZERO) -> Node:
	var p := Player.new()
	p.tn = fresh_tuning()
	p.scripted = true
	p.position = at
	w.add_child(p)
	await frames(3)
	return p


func count_darts(w: Node) -> int:
	var n := 0
	for c in w.get_children():
		if c is Dart:
			n += 1
	return n


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


func make_thin_target(w: Node2D, x: float, width: float) -> Array:
	var target := Hurtbox.new()
	target.setup(Vector2(width, 160), Vector2(0, -80), L.ENEMY_HURT)
	target.position = Vector2(x, 0)
	var got := []
	target.hurt.connect(func(amount, _src, _kind): got.append(amount))
	w.add_child(target)
	return got


func make_target(w: Node2D, x: float) -> Array:
	var target := Hurtbox.new()
	target.setup(Vector2(20, 160), Vector2(0, -80), L.ENEMY_HURT)
	target.position = Vector2(x, 0)
	var got := []
	target.hurt.connect(func(amount, _src, kind): got.append([amount, kind]))
	w.add_child(target)
	return got


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


## 木障：x=300 處、從 y=-400 到地面
func make_barrier(w: Node2D) -> Node:
	var b = Barrier.new()
	b.setup(Rect2(300, -400, 60, 400))
	w.add_child(b)
	return b


## 假 Boss：身體受擊框 180×300（x=at_x、站在地上）＋面向角色那一側、水平射的吹管口高度的光源；回傳 [身體, 光源, 紀錄]
func make_fake_boss(w: Node2D, at_x: float) -> Array:
	var got := []
	var body := Hurtbox.new()
	body.setup(Vector2(180, 300), Vector2(0, -150), L.ENEMY_HURT)
	body.position = Vector2(at_x, 0)
	body.hurt.connect(func(_a, _s, kind): got.append(["body", kind]))
	w.add_child(body)
	var light = Light.new()
	light.setup(Vector2(40, 40), Vector2.ZERO, L.LIGHT)
	light.collision_layer = 0
	light.position = Vector2(-60, Intent.muzzle(Vector2.RIGHT, 1).y)
	light.hurt.connect(func(_a, src, _k): got.append(["light", src.get("can_setup")]))
	body.add_child(light)
	return [body, light, got]


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


func remove_test_logs() -> void:
	var path := ProjectSettings.globalize_path(TEST_LOG_DIR)
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(path)


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


## 招架紀錄的總計（不分分鐘）。紀錄依「遊戲啟動後的第 N 分鐘」分段，整套自測跑超過 1 分鐘後，
## 測試裡的招架會落在第 2 分鐘以後；只讀第 1 列的寫法因此會失敗（MV-SLICE-001a Task 1 發現）。
func parry_totals(p) -> Dictionary:
	var t := {"attempts": 0, "successes": 0}
	for r in p.parry_stats.minute_rows():
		t.attempts += r.attempts
		t.successes += r.successes
	return t
