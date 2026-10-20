extends Node2D
# Boss 戰整場流程（MV-PROTO-003 規格書第 4～7 節、計畫 D3、D7、D8、D18）：
# 樹下篝火 → nance 樹（開場、第 1 段）→ 小路 → 宮殿篝火 → 宮殿（第 2、3 段）→ 覺醒 → 出口。
# world 子樹放場地、角色、Boss、造物與飛鏢；文字卡顯示時只凍結 world（不暫停整棵樹）。

const Tuning := preload("res://tuning/combat_tuning.gd")
const Player := preload("res://player/player.gd")
const Intent := preload("res://player/intent.gd")
const Crawler := preload("res://enemies/crawler.gd")
const Flyer := preload("res://enemies/flyer.gd")
const Dart := preload("res://player/dart.gd")
const Feedback := preload("res://fx/feedback.gd")
const Shatter := preload("res://fx/shatter.gd")
const Hud := preload("res://ui/hud.gd")
const Whiteout := preload("res://ui/whiteout.gd")
const TextCard := preload("res://ui/text_card.gd")
const CardText := preload("res://boss/card_text.gd")
const FightLog := preload("res://boss/fight_log.gd")
const Nance := preload("res://boss/nance_arena.gd")
const Palace := preload("res://boss/palace_arena.gd")
const Macaw := preload("res://boss/seven_macaw.gd")
const Fruit := preload("res://boss/fruit.gd")
const Pillar := preload("res://boss/pillar.gd")
const FalseFlash := preload("res://boss/moves/false_flash.gd")

signal finished

enum Stage { APPROACH, INTRO, FIGHT, CARD, EXIT, DONE }

const BG_LEVELS := [Color(0.34, 0.31, 0.22), Color(0.24, 0.22, 0.17), Color(0.15, 0.14, 0.12), Color(0.08, 0.06, 0.05)]  # 每拔掉一個光源暗一階（2.5 節）
const EXIT_HINT := "胡納普能二段跳了：Tab／Y 換人，空中再按一次跳躍"  # 出口高台要二段跳（Brian 試打 2026-10-05：不知道怎麼上去）
const EXIT_HINT_TIME := 6.0

# 設定（add_child 前設定）
var tn: Tuning = Tune.data
var tester := "anon"
var keep_phase := false
var log_dir := "user://boss_logs"
var player_scripted := false  # true：角色一律由測試或展示模式操控

var world: Node2D
var nance
var palace
var player
var boss
var camera: Camera2D
var feedback
var hud
var whiteout
var card
var log  # fight_log.gd
var stage := Stage.APPROACH
var phase := 1
var lights_removed := 0
var awakened := false
var intro_seen := false
var palace_card_seen := false
var player_locked := false
var couple_following := false
var couple_x := 0.0
var first_move_once := ""  # 只給 start_at 與展示模式用
var _last_hit := "unknown"  # 受擊當下記下的死因（計畫 D12）
var _back_window_left := 0.0  # 按過一次 Esc／Start 後，再按一次回選單的剩餘時間
var _exit_hint_left := 0.0
var _t0 := 0


func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	world = Node2D.new()
	add_child(world)
	nance = Nance.new()
	world.add_child(nance)
	palace = Palace.new()
	world.add_child(palace)
	player = Player.new()
	player.tn = tn
	player.scripted = player_scripted
	player.position = Nance.REST
	world.add_child(player)
	camera = Camera2D.new()
	camera.position = Vector2(0, -150)
	camera.position_smoothing_enabled = true
	player.add_child(camera)
	boss = Macaw.new()
	boss.tn = tn
	boss.target = player
	world.add_child(boss)
	boss.park(1)
	feedback = Feedback.new()
	feedback.tn = tn
	feedback.camera = camera
	add_child(feedback)
	_build_ui()
	_wire()
	log = FightLog.new()
	log.keep_phase = keep_phase
	log.open(FightLog.safe_name(tester), FightLog.stamp_from(Time.get_datetime_dict_from_system()), log_dir)
	print("BOSSLOG %s" % ProjectSettings.globalize_path(log_dir))
	_apply_loadout()
	_set_view(Nance.REGION)
	stage = Stage.APPROACH


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.player = player
	hud.show_hint = false
	whiteout = Whiteout.new()
	whiteout.tn = tn
	card = TextCard.new()
	card.min_time = tn.card_min_time
	for c in [hud, whiteout, card]:
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(c)


func _wire() -> void:
	player.swung.connect(feedback.play.bind(&"swing"))
	player.hit_landed.connect(_on_player_hit)
	player.dart_fired.connect(feedback.play.bind(&"dart"))
	player.hurt_taken.connect(_on_player_hurt)
	player.healed.connect(feedback.play.bind(&"heal"))
	player.swapped.connect(feedback.play.bind(&"swap"))
	player.parried.connect(func(_e): feedback.play(&"parry"))
	player.double_jumped.connect(feedback.play.bind(&"double_jump"))
	player.tool_sent.connect(_on_tool_sent)
	palace.barrier.broken.connect(feedback.play.bind(&"barrier_break"))
	palace.barrier.thudded.connect(feedback.play.bind(&"thud"))
	boss.interrupted.connect(feedback.play.bind(&"interrupt"))
	boss.summon_requested.connect(fill_summons)
	boss.gauge_filled.connect(_on_gauge_filled)
	boss.glow_struck.connect(_on_glow_struck)
	boss.window_missed.connect(func(): log.add(now(), "missed_window", {"phase": phase}))
	boss.flashed.connect(_on_flashed)
	boss.setup_succeeded.connect(_on_setup)
	player.died.connect(_on_player_died, CONNECT_DEFERRED)


func _physics_process(delta: float) -> void:
	if _back_window_left > 0.0:
		_back_window_left -= delta
		if _back_window_left <= 0.0:
			hud.notice = ""
	if _exit_hint_left > 0.0:
		_exit_hint_left -= delta
		if _exit_hint_left <= 0.0 and hud.notice == EXIT_HINT:
			hud.notice = ""
	if stage == Stage.APPROACH:
		if couple_following:
			couple_x = move_toward(couple_x, player.position.x - 160.0, tn.run_speed * 0.9 * delta)
		if player.position.x > _entry_x(phase):
			_enter_arena()
	elif stage == Stage.EXIT and Palace.on_exit(player.position):
		_finish()
	_update_hud()
	queue_redraw()


func now() -> float:
	return (Time.get_ticks_msec() - _t0) / 1000.0


## 該段的場地節點：1 → nance 樹，其他 → 宮殿
func arena(p := phase) -> Node:
	return nance if p == 1 else palace


func _entry_x(p: int) -> float:
	return Nance.ENTRY_X if p == 1 else Palace.ENTRY_X


func _view(p: int) -> Rect2:
	return Nance.VIEW if p == 1 else Palace.VIEW


func background_color() -> Color:
	return BG_LEVELS[clampi(lights_removed, 0, 3)]


func _apply_loadout() -> void:
	player.twins[0].weapon_enabled = phase == 1 or awakened
	player.abilities_enabled = awakened


func _set_view(r: Rect2) -> void:
	camera.limit_left = int(r.position.x)
	camera.limit_right = int(r.end.x)
	camera.limit_top = int(r.position.y)
	camera.limit_bottom = int(r.end.y)
	camera.reset_smoothing()


func _update_hud() -> void:
	hud.boss_name = CardText.BOSS_NAME if stage == Stage.FIGHT else ""
	hud.boss_segments = 3 - lights_removed
	hud.boss_gauge = float(boss.gauge.value) / tn.gauge_max


func _lock_player(on: bool) -> void:
	player_locked = on
	player.scripted = on or player_scripted
	if on:
		player.intent = Intent.new()


# ---- 進場、開場、開打 ----

func _enter_arena() -> void:
	arena().close_gate()
	_set_view(_view(phase))
	if phase >= 2:
		couple_following = false
		palace.couple_static = true
		palace.queue_redraw()
	if phase == 1 and not intro_seen:
		stage = Stage.INTRO
		_lock_player(true)
		boss.play_intro()
		await boss.intro_finished
		intro_seen = true
		_lock_player(false)
	elif phase == 2 and not palace_card_seen:
		palace_card_seen = true
		await show_card("toothache")
	_start_fight()


func _start_fight() -> void:
	stage = Stage.FIGHT
	boss.begin_phase(phase, first_move_once)
	first_move_once = ""
	log.keep_phase = keep_phase
	log.add(now(), "attempt_start", {"phase": phase, "keep": keep_phase})
	_update_hud()


## 全螢幕文字卡：顯示時凍結戰場（計畫 D3）
func show_card(key: String) -> void:
	stage = Stage.CARD
	world.process_mode = Node.PROCESS_MODE_DISABLED
	card.show_card(CardText.CARDS[key])
	await card.closed
	world.process_mode = Node.PROCESS_MODE_INHERIT


## Esc／Start：Boss 戰中要在 2 秒內按兩次才回選單（避免想暫停卻丟掉整場進度與日誌）；回傳 true＝離開
func request_menu() -> bool:
	if _back_window_left > 0.0:
		_back_window_left = 0.0
		hud.notice = ""
		return true
	_back_window_left = 2.0
	hud.notice = "再按一次回選單（這場的進度不會保留）"
	return false


## 除錯與測試：p＝1～3 直接從該段開打（該段以前的開場視為看過）；4＝覺醒後的出口
func start_at(p: int, first_move := "") -> void:
	intro_seen = true
	palace_card_seen = p >= 2
	if p == 4:  # 覺醒後的出口
		phase = 3
		lights_removed = 3
		awakened = true
		_apply_loadout()
		boss.deactivate(true)
		palace.couple_static = true
		palace.queue_redraw()
		player.position = Vector2(Palace.RIGHT - 300.0, Palace.GROUND_Y)
		player.velocity = Vector2.ZERO
		_set_view(Palace.EXIT_VIEW)
		_enter_exit()
		return
	phase = p
	lights_removed = p - 1
	_apply_loadout()
	first_move_once = first_move
	player.position = Vector2(_entry_x(p) + 100.0, Nance.GROUND_Y)
	player.velocity = Vector2.ZERO
	_enter_arena()


# ---- 戰鬥中的連動 ----

## 他召出的造物各補到 cap 隻（第 1 段各 1、第 3 段各 2）
func fill_summons(cap: int) -> void:
	var crawlers := 0
	var flyers := 0
	for s in boss.summons:
		if is_instance_valid(s):
			if s is Crawler:
				crawlers += 1
			elif s is Flyer:
				flyers += 1
	var lo := (Nance.LEFT if phase == 1 else Palace.LEFT) + 100.0
	var hi := (Nance.RIGHT if phase == 1 else Palace.THRONE_X) - 100.0
	for i in range(crawlers, cap):
		_spawn(Crawler.new(), Vector2(clampf(boss.position.x + (-250.0 if i % 2 == 0 else 250.0), lo, hi), Nance.GROUND_Y))
	for i in range(flyers, cap):
		_spawn(Flyer.new(), Vector2(clampf(boss.position.x + (150.0 if i % 2 == 0 else -150.0), lo, hi), Nance.GROUND_Y - 500.0))


func _spawn(e: Node2D, at: Vector2) -> void:
	e.tn = tn
	e.target = player
	e.position = at
	world.add_child(e)
	boss.summons.append(e)
	e.died.connect(_on_summon_died)
	e.interrupted.connect(func(_e): feedback.play(&"interrupt"))


func _on_summon_died(e: Node) -> void:
	boss.summons.erase(e)
	var s := Shatter.new()
	s.position = e.position + Vector2(0, -40)
	world.add_child(s)
	feedback.play(&"shatter")


func _on_gauge_filled() -> void:
	log.add(now(), "gauge_full", {"phase": phase})
	player.force_twin(0)  # 場上是希巴拉克時自動原地換成胡納普（計畫 D13）


func _on_glow_struck(light_name: String) -> void:
	log.add(now(), "glow_hit", {"phase": phase, "light": light_name})
	feedback.play(&"interrupt")


func _on_flashed() -> void:
	if FalseFlash.is_facing(player.global_position.x, player.facing, boss.global_position.x):
		whiteout.start()
		log.add(now(), "whiteout", {"phase": phase})


## 清掉飛鏢、果子、反光柱與召喚的造物；Boss 停止行動
func clear_battlefield() -> void:
	for c in world.get_children():
		if c is Dart or c is Fruit or c is Pillar:
			c.queue_free()
	for s in boss.summons:
		if is_instance_valid(s):
			s.queue_free()
	boss.summons.clear()
	boss.deactivate()
	whiteout.stop()


## F11：破綻直接加滿（只在戰鬥中）
func debug_fill_gauge() -> void:
	if stage == Stage.FIGHT:
		boss.add_gauge(tn.gauge_max)


# ---- 設局換段、死亡重試、結尾（規格書第 5、6 節）----

static func retry_phase(died_in: int, keep: bool) -> int:
	return 2 if died_in == 3 and not keep else died_in


static func rest_point(p: int) -> Vector2:
	return Nance.REST if p == 1 else Palace.REST


func _on_setup(p: int) -> void:
	if player.health.is_dead():  # 同一幀先被打死又射中設局：設局優先，保住 1 血（死亡處理延到幀末，會被略過）
		player.health.hp = 1
	log.add(now(), "setup", {"phase": p})
	clear_battlefield()
	lights_removed = p
	match p:
		1:
			await show_card("arm")
			await show_card("couple")
			phase = 2
			_apply_loadout()
			boss.park(2)
			player.position = Palace.PATH_START
			player.velocity = Vector2.ZERO
			couple_following = true
			couple_x = Palace.PATH_START.x - 160.0
			_set_view(Palace.REGION)
			stage = Stage.APPROACH
		2:
			await show_card("teeth")
			phase = 3
			_start_fight()
		3:
			await show_card("death")
			await show_card("awaken")
			awakened = true
			_apply_loadout()
			boss.deactivate(true)
			_set_view(Palace.EXIT_VIEW)
			_enter_exit()


## 覺醒後的出口：短暫提示二段跳（出口高台單跳上不去）
func _enter_exit() -> void:
	stage = Stage.EXIT
	hud.notice = EXIT_HINT
	_exit_hint_left = EXIT_HINT_TIME


func _on_player_died() -> void:
	if stage != Stage.FIGHT:
		return
	log.add(now(), "death", {"phase": phase, "by": _last_hit})
	_retry(retry_phase(phase, keep_phase))


## 回到該段的篝火：血量與治療次數補滿、造物清空、Boss 回到該段開頭、破綻歸 0
func _retry(p: int) -> void:
	clear_battlefield()
	phase = p
	lights_removed = p - 1
	player.respawn(rest_point(p))
	_apply_loadout()
	arena(p).open_gate()
	boss.park(p)
	_set_view(Nance.REGION if p == 1 else Palace.REGION)
	stage = Stage.APPROACH


## F10：重來目前的場地（不記死亡、不退段；計畫 D18）
func reset_area() -> void:
	if stage == Stage.APPROACH or stage == Stage.FIGHT:
		_retry(phase)


func _finish() -> void:
	log.close(now(), "clear")
	show_card("clear")
	stage = Stage.DONE
	await card.closed
	finished.emit()


func _exit_tree() -> void:
	if log != null:
		log.close(now(), "quit")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and log != null:
		log.close(now(), "quit")


func _on_player_hit(_target: Node) -> void:
	feedback.hitstop()
	feedback.shake()
	feedback.play(&"hit")


func _on_player_hurt() -> void:
	var src = player.last_hurt_source
	if src == null:
		_last_hit = "unknown"
	else:
		var mn = src.get("move_name")
		_last_hit = String(mn) if mn != null else "summon"
	feedback.play(&"hurt")
	feedback.shake()


func _on_tool_sent(t: Node) -> void:
	feedback.play(&"tool_out")
	t.chopped.connect(feedback.play.bind(&"chop"))


func _draw() -> void:
	var bg := background_color()
	draw_rect(Nance.REGION, bg)
	draw_rect(Palace.REGION.merge(Palace.EXIT_VIEW), bg)
	if couple_following:  # 兩位老人跟在後面（灰盒）
		draw_rect(Rect2(couple_x - 70, Nance.GROUND_Y - 150, 50, 150), Color(0.6, 0.6, 0.6))
		draw_rect(Rect2(couple_x, Nance.GROUND_Y - 130, 50, 130), Color(0.55, 0.55, 0.55))
