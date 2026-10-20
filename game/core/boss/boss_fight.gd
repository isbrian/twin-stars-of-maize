extends Node2D
# Boss 戰整場流程（MV-PROTO-003 規格書第 4～7 節、計畫 D3、D7、D8、D18）：
# 樹下篝火 → nance 樹（開場、第 1 段）→ 小路 → 宮殿篝火 → 宮殿（第 2、3 段）→ 覺醒 → 出口。
# world 子樹放場地、角色、Boss、造物與飛鏢；文字卡顯示時只凍結 world（不暫停整棵樹）。
# MV-SLICE-001a Task 11：有 gs（GameState）時是垂直切片的 Boss 段落——裝備、兩個篝火、開打前的左出口、覺醒；
# 沒有 gs 時行為同原型（MV-PROTO-003 搬來的測試用）。

const Sound := preload("res://core/audio/sound_table.gd")
const Tuning := preload("res://core/tuning/combat_tuning.gd")
const Player := preload("res://core/player/player.gd")
const Intent := preload("res://core/player/intent.gd")
const Crawler := preload("res://core/enemies/crawler.gd")
const Flyer := preload("res://core/enemies/flyer.gd")
const Dart := preload("res://core/player/dart.gd")
const Feedback := preload("res://core/fx/feedback.gd")
const Shatter := preload("res://core/fx/shatter.gd")
const Hud := preload("res://ui/hud.gd")
const Whiteout := preload("res://ui/whiteout.gd")
const TextCard := preload("res://ui/text_card.gd")
const CardText := preload("res://core/boss/card_text.gd")
const FightLog := preload("res://core/boss/fight_log.gd")
const Nance := preload("res://core/boss/nance_arena.gd")
const Palace := preload("res://core/boss/palace_arena.gd")
const Macaw := preload("res://core/boss/seven_macaw.gd")
const Fruit := preload("res://core/boss/fruit.gd")
const Pillar := preload("res://core/boss/pillar.gd")
const FalseFlash := preload("res://core/boss/moves/false_flash.gd")
const Loadout := preload("res://state/loadout.gd")
const Save := preload("res://state/save.gd")
const RestPoint := preload("res://world/rest_point.gd")
const NpcAnimator := preload("res://world/npc_animator.gd")
const EnemyAnimator := preload("res://world/enemy_animator.gd")  # 召喚的造物（MV-SLICE-001b2b1，取代立繪）
const MacawAnimator := preload("res://world/macaw_animator.gd")  # Seven Macaw 的骨架（MV-SLICE-001b2b1，core→world preload）
const LightFx := preload("res://world/fx/light_fx.gd")  # 光源的柔光暈（MV-SLICE-001c1）
const PillarFx := preload("res://world/fx/pillar_fx.gd")  # 柔光光柱（MV-SLICE-001c1）
const BeamFx := preload("res://world/fx/beam_fx.gd")  # 瞄準虛線＋柔光光束（MV-SLICE-001c1）
const FlashFx := preload("res://world/fx/flash_fx.gd")  # 假光閃耀的光點匯聚（MV-SLICE-001c1）
const WhiteoutFx := preload("res://world/fx/whiteout_fx.gd")  # 從 Boss 身上擴散的白茫（MV-SLICE-001c1）
const MacawGlints := preload("res://world/fx/macaw_glints.gd")  # 身上金飾的假光（MV-SLICE-001c1）
const SceneryView := preload("res://world/scenery_view.gd")
const Cutscene := preload("res://world/cutscene/cutscene.gd")  # 過場執行器（MV-SLICE-001c2a）
const Opening := preload("res://world/cutscene/opening.gd")
const Arm := preload("res://world/cutscene/arm.gd")
const Couple := preload("res://world/cutscene/couple.gd")
const Toothache := preload("res://world/cutscene/toothache.gd")
const Awaken := preload("res://world/cutscene/awaken.gd")
const Finale := preload("res://world/cutscene/finale.gd")
const Teeth := preload("res://world/cutscene/teeth.gd")
const Death := preload("res://world/cutscene/death.gd")

signal finished
signal left_exit  # 回森林 6：第 1 段開打前走回最左邊；覺醒後走到小路最左端（MV-SLICE-001c4b）

enum Stage { APPROACH, INTRO, FIGHT, CARD, EXIT, DONE }

const BG_LEVELS := [Color(0.34, 0.31, 0.22), Color(0.24, 0.22, 0.17), Color(0.15, 0.14, 0.12), Color(0.08, 0.06, 0.05)]  # 每拔掉一個光源暗一階（2.5 節）
const EXIT_HINT := "胡納普能二段跳了：Tab／Y 換人，空中再按一次跳躍"  # 出口高台要二段跳（Brian 試打 2026-10-05：不知道怎麼上去）
const EXIT_HINT_BARRIER := "希巴拉克的飛鏢射中木障，工具會自己去砍碎它"  # 出口第一步（MV-SLICE-001c2c）
const SAVED_NOTICE := "已存檔"
const SAVED_TIME := 2.0
const LEFT_EXIT_X := 0.0  # 樹下篝火在 300；左牆內緣 -100
const PATH_EXIT_X := 7900.0  # 覺醒後走回森林的線：小路左牆內緣 7800、PATH_START 8000 之間（MV-SLICE-001c4b）
const FOREST_HINT := "森林裡有以前到不了的地方"
const FOREST_HINT_TIME := 4.0
const FOREST_HINT_FLAG := "hint_forest_return"
const CAMPS := {"nance_camp": 1, "palace_camp": 2}  # 篝火 id → 該段

# 設定（add_child 前設定）
var tn: Tuning = Tune.data
var tester := "slice"
var keep_phase := false
var log_dir := "user://boss_logs"
var player_scripted := false  # true：角色一律由測試或展示模式操控
var gs  # state/game_state.gd；null＝原型模式
var save_path := Save.PATH

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
var _music_on := false  # 上一幀是否在放 Boss 配樂（MV-SLICE-001d1a）
var lights_removed := 0
var awakened := false
var intro_seen := false
var palace_card_seen := false
var player_locked := false
var couple_following := false
var couple_x := 0.0
var _couple_last_x := 0.0
const COUPLE_STEP_MAX := 60.0  # 一次更新超過這個位移＝瞬移（開始跟隨、換段落），不算走路
var first_move_once := ""  # 只給 start_at 與展示模式用
var _last_hit := "unknown"  # 受擊當下記下的死因（計畫 D12）
var rests := {}  # 篝火 id → rest_point.gd（只在有 gs 時）
var _left_sent := false
var cutscene  # MV-SLICE-001c2a：過場執行器（遊戲模式才有）
var scenery  # MV-SLICE-001b1：scenery_view.gd（gs 模式；原型模式為 null，畫背景色塊）
var couple: Array = []  # 兩位老人的節點（gs 模式，底下是 MV-SLICE-001b2b2 的骨架）；[老爺爺, 老奶奶]
var _saved_left := 0.0  # 覺醒存檔後顯示「已存檔」的剩餘秒數
var _forest_hint_left := 0.0  # 森林提示的剩餘秒數（MV-SLICE-001c4b）
var _t0 := 0


func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	world = Node2D.new()
	add_child(world)
	if gs != null:
		scenery = SceneryView.new()
		world.add_child(scenery)
		scenery.build_boss()
	nance = Nance.new()
	world.add_child(nance)
	palace = Palace.new()
	world.add_child(palace)
	player = Loadout.make_player(gs, tn) if gs != null else Player.new()
	player.tn = tn
	player.scripted = player_scripted
	player.position = Nance.REST
	world.add_child(player)
	Audio.listener = player  # 召喚的假光造物不進 glass 群組（MV-SLICE-001d1a）
	Audio.floor_source = floor_material_at
	camera = Camera2D.new()
	camera.position = Vector2(0, -150)
	camera.position_smoothing_enabled = true
	player.add_child(camera)
	boss = Macaw.new()
	boss.tn = tn
	boss.target = player
	world.add_child(boss)
	boss.park(1)
	if gs != null:  # 骨架：Seven Macaw（MV-SLICE-001b2b1）、老夫婦（MV-SLICE-001b2b2）
		MacawAnimator.attach(boss)
		MacawGlints.attach(boss)
		LightFx.attach(boss.light)
		BeamFx.attach(boss)
		FlashFx.attach(boss)
		boss.fx_drawn = true
		world.child_entered_tree.connect(_on_world_child)
		for k in ["healer_man", "healer_woman"]:
			var n := Node2D.new()
			n.visible = false
			world.add_child(n)
			NpcAnimator.attach(n, k)
			couple.append(n)
		palace.draw_couple = false
		nance.use_art()
		palace.use_art()
		for id in CAMPS:
			var rp := RestPoint.new()
			rp.position = rest_point(CAMPS[id])
			world.add_child(rp)
			world.move_child(rp, player.get_index())  # 排在角色前面：同層依樹順序，角色畫在篝火上（MV-SLICE-001b2a 最終審查）
			rests[id] = rp
		player.interacted.connect(_on_interact)
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
	hud.gs = gs
	hud.show_objective = false
	whiteout = Whiteout.new()
	whiteout.tn = tn
	card = TextCard.new()
	card.min_time = tn.card_min_time
	for c in [hud, whiteout, card]:
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(c)
	if gs != null:  # 遊戲模式：白茫從 Boss 身上擴散（MV-SLICE-001c1）；過場執行器（MV-SLICE-001c2a）
		WhiteoutFx.attach(whiteout, boss)
		cutscene = Cutscene.new()
		cutscene.host = self
		add_child(cutscene)


func _wire() -> void:
	feedback.wire_moves(player)
	player.hit_landed.connect(_on_player_hit)
	player.dart_fired.connect(feedback.play.bind(&"dart"))
	player.hurt_taken.connect(_on_player_hurt)
	player.healed.connect(feedback.play.bind(&"heal"))
	player.parried.connect(func(_e): feedback.play(&"parry"))
	player.double_jumped.connect(feedback.play.bind(&"double_jump"))
	player.tool_sent.connect(_on_tool_sent)
	palace.barrier.broken.connect(feedback.play.bind(&"barrier_break"))
	palace.barrier.thudded.connect(feedback.play.bind(&"lvl_barrier_thud"))
	boss.interrupted.connect(feedback.play.bind(&"interrupt"))
	boss.summon_requested.connect(fill_summons)
	boss.gauge_filled.connect(_on_gauge_filled)
	boss.glow_struck.connect(_on_glow_struck)
	boss.window_missed.connect(func(): log.add(now(), "missed_window", {"phase": phase}))
	boss.flashed.connect(_on_flashed)
	boss.setup_succeeded.connect(_on_setup)
	player.died.connect(_on_player_died, CONNECT_DEFERRED)


func _physics_process(delta: float) -> void:
	_sync_music()
	_saved_left = maxf(_saved_left - delta, 0.0)
	_update_forest_hint(delta)
	if stage == Stage.EXIT:
		hud.notice = exit_notice()
		# 覺醒後閘門開著：走回小路時鏡頭範圍換成小路，回到宮殿再換回（c2c 最終審查）
		_set_view(Palace.EXIT_VIEW if player.position.x >= Palace.LEFT else Palace.REGION)
	if stage == Stage.APPROACH:
		if couple_following:
			couple_x = move_toward(couple_x, player.position.x - 160.0, tn.run_speed * 0.9 * delta)
		if awakened and player.position.x > _entry_x(2):  # 覺醒後讀檔：進宮殿直接是出口（MV-SLICE-001c2c）
			_set_view(Palace.EXIT_VIEW)
			_enter_exit()
		elif player.position.x > _entry_x(phase):
			_enter_arena()
		elif gs != null and phase == 1 and player.position.x < LEFT_EXIT_X and not _left_sent:
			_left_sent = true
			left_exit.emit.call_deferred()  # 換房會釋放這個節點，不在 physics 回呼裡做
	elif stage == Stage.EXIT and Palace.on_exit(player.position):
		_finish()
	if gs != null and awakened and (stage == Stage.APPROACH or stage == Stage.EXIT) and player.position.x < PATH_EXIT_X:
		left_exit.emit.call_deferred()  # 覺醒後走到小路最左端 → 回森林 6（MV-SLICE-001c4b）；每幀都送：換房中的 goto 會被忽略，換完要能再送
	_update_hud()
	_update_couple()
	queue_redraw()


## 腳下地面（MV-SLICE-001d1b）：宮殿是石地（硬地），nance 樹下與小路是土
func floor_material_at(pos: Vector2) -> StringName:
	return &"hard" if pos.x >= Palace.LEFT and pos.x <= Palace.RIGHT else &"dirt"


## 配樂（SLICE-d-11）：進 FIGHT 淡入 MUS-B01（每段從頭）、離開 FIGHT 淡出；過場、文字卡中不放
func _sync_music() -> void:
	var fighting := stage == Stage.FIGHT
	if fighting == _music_on:
		return
	_music_on = fighting
	if fighting:
		Audio.play_music(&"mus_b01")
	elif Audio.music == &"mus_b01":
		Audio.stop_music()


## 覺醒後第一次走進小路（宮殿左緣以西）：畫面下方提示一次、記旗標；倒數中與歸零那一幀更新下方文字（MV-SLICE-001c4b）
func _update_forest_hint(delta: float) -> void:
	if gs != null and awakened and player.position.x < Palace.LEFT and not gs.has_flag(FOREST_HINT_FLAG):
		gs.set_flag(FOREST_HINT_FLAG)
		_forest_hint_left = FOREST_HINT_TIME
	elif _forest_hint_left > 0.0:
		_forest_hint_left = maxf(_forest_hint_left - delta, 0.0)
	else:
		return
	hud.notice = exit_notice()


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


## 先套 GameState 的裝備，再疊原型規則（第 2 段起胡納普斷臂、覺醒才有二段跳與工具）
func _apply_loadout() -> void:
	var has_weapon := true
	if gs != null:
		Loadout.apply_weapons(player, gs)
		has_weapon = gs.equip[0] != -1
	player.twins[0].weapon_enabled = has_weapon and (phase == 1 or awakened)
	player.twins[0].arm_broken = not (phase == 1 or awakened)
	player.abilities_enabled = awakened
	if scenery != null:  # 宮殿繩結上的手臂：第 2 段起、覺醒前（MV-SLICE-001c2a）
		scenery.set_arm_hung(phase >= 2 and not awakened)
		scenery.set_dead(awakened)  # 死後的宮殿（MV-SLICE-001c2b）


## lights_removed 改變的地方都呼叫（MV-SLICE-001b1 Pre-flight）：Seven Macaw 的外觀、場景的暗度
## 閘門與木障是要操作的東西，保持原色（Brian 試玩 2026-10-11：出口時木障暗到看不見）
## animate：段落進行中拔掉光源（宮殿假光淡出）；開打、重試、讀檔直接對應（MV-SLICE-001c1）
func _apply_lights(animate := false) -> void:
	if gs != null:
		boss.set_appearance(lights_removed)
		scenery.set_darkness(lights_removed, animate)


## 老夫婦：跟在後面時在角色身後（走路），第一次走完小路後站在宮殿入口端（待機）
func _update_couple() -> void:
	if couple.is_empty():
		return
	var show: bool = couple_following or palace.couple_static
	var x := couple_x if couple_following else Palace.COUPLE_X
	var dx := x - _couple_last_x  # MV-SLICE-001b2b2：跟隨中而且這次有移動才走路
	_couple_last_x = x
	for i in 2:
		couple[i].visible = show
		couple[i].position = Vector2(x - 45.0 + i * 70.0, Nance.GROUND_Y)
		var a = couple[i].get_node("NpcAnimator")
		if couple_following and dx != 0.0 and absf(dx) <= COUPLE_STEP_MAX:
			a.play("walk")
			a.facing = 1 if dx > 0.0 else -1
		else:
			a.play("idle")
			if absf(dx) > COUPLE_STEP_MAX:
				a.facing = 1  # 瞬移後照立繪面向右


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
	if phase == 1 and not intro_seen and cutscene != null:  # 遊戲模式：開場演出（MV-SLICE-001c2a）
		stage = Stage.INTRO
		await cutscene.run([Opening.new()])
	elif phase == 1 and not intro_seen:
		stage = Stage.INTRO
		_lock_player(true)
		boss.play_intro()
		await boss.intro_finished
		intro_seen = true
		_lock_player(false)
	elif phase == 2 and not palace_card_seen and cutscene != null:  # 遊戲模式：牙痛開場演出（MV-SLICE-001c2b）
		stage = Stage.CARD
		await cutscene.run([Toothache.new()])
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


## 「繼續」或死亡回點：從該篝火接續（nance_camp → 第 1 段、palace_camp → 第 2 段；其他 id 當成 nance）
func begin_at_rest(rest_id: String) -> void:
	var p: int = CAMPS.get(rest_id, 1)
	awakened = gs != null and gs.awakened  # 覺醒後存的檔（MV-SLICE-001c2c）
	if p >= 2:
		intro_seen = true
		palace.couple_static = true
		palace.queue_redraw()
	_retry(p)


## 從森林 6 的右門進來（MV-SLICE-001c4b）：已覺醒＝讀檔回宮殿篝火的狀態、只是出生在小路起點；未覺醒照舊在 nance 篝火
func begin_from_forest() -> void:
	if gs == null or not gs.awakened:
		return
	begin_at_rest("palace_camp")
	player.position = Palace.PATH_START
	player.velocity = Vector2.ZERO
	camera.reset_smoothing()


## 遊戲模式：寶座反光柱（throne_charge 加到 world）掛上柔光外觀；延後一幀，避開進樹途中加子節點
func _on_world_child(n: Node) -> void:
	if n is Pillar:
		(func(): if is_instance_valid(n): PillarFx.attach(n)).call_deferred()


## 篝火休息（SLICE-a10）：回滿、存檔；只在走路階段
func _on_interact() -> void:
	if stage != Stage.APPROACH or player_locked:
		return
	for id in rests:
		if rests[id].near(player):
			gs.rest(id)
			Save.write(gs.to_dict(), save_path)
			Loadout.apply(player, gs)
			_apply_loadout()
			feedback.play(&"heal")
			Audio.play(&"voc_real")  # 篝火休息＝真實（MV-SLICE-001d1a）
			return


## 除錯與測試：p＝1～3 直接從該段開打（該段以前的開場視為看過）；4＝覺醒後的出口
func start_at(p: int, first_move := "") -> void:
	intro_seen = true
	palace_card_seen = p >= 2
	if p == 4:  # 覺醒後的出口
		_enter_awakened_palace()
		player.position = Vector2(Palace.RIGHT - 300.0, Palace.GROUND_Y)
		player.velocity = Vector2.ZERO
		_set_view(Palace.EXIT_VIEW)
		_enter_exit()
		return
	phase = p
	lights_removed = p - 1
	_apply_lights()
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
	if gs != null:
		EnemyAnimator.attach(e, "crawler" if e is Crawler else "flyer")
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
	Audio.play(&"boss_sm_crack")  # 破綻滿（MV-SLICE-001d1a）
	player.force_twin(0)  # 場上是希巴拉克時自動原地換成胡納普（計畫 D13）


func _on_glow_struck(light_name: String) -> void:
	log.add(now(), "glow_hit", {"phase": phase, "light": light_name})  # 聲音由 dart.gd 放（wpn_dart_weak），這裡不再放，免得疊兩層（MV-SLICE-001d1b 最終審查）


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
	Audio.play(&"boss_sm_light_pull")  # 設局成功、拔掉光源（MV-SLICE-001d1a）
	clear_battlefield()
	lights_removed = p
	if not (p == 3 and cutscene != null):  # 遊戲模式第 3 段：假光與暗度改由死亡演出淡出（MV-SLICE-001c2b）
		_apply_lights(true)
	match p:
		1 when cutscene != null:  # 遊戲模式：斷臂與轉場演出（MV-SLICE-001c2a）
			stage = Stage.CARD
			await cutscene.run([Arm.new(), Couple.new()])
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
		2 when cutscene != null:  # 遊戲模式：換牙演出（MV-SLICE-001c2b）
			stage = Stage.CARD
			await cutscene.run([Teeth.new()])
			_start_fight()
		2:
			await show_card("teeth")
			phase = 3
			_start_fight()
		3:
			if cutscene != null:  # 遊戲模式：死亡接覺醒演出（MV-SLICE-001c2b、c2c）；覺醒的 end_state 呼叫 finish_awakening
				stage = Stage.CARD
				await cutscene.run([Death.new(), Awaken.new()])
			else:
				await show_card("death")
				await show_card("awaken")
				finish_awakening()


## 覺醒後的宮殿（死亡演出之後、讀檔、start_at(4)、F10 共用；MV-SLICE-001c2c）：最暗、Boss 藏起、地上有身體、
## 奇瑪瑪特與老夫婦不在、手臂裝回、能力開啟、木障立著、閘門開著
func _enter_awakened_palace() -> void:
	phase = 3
	lights_removed = 3
	_apply_lights()
	awakened = true
	intro_seen = true
	palace_card_seen = true
	_apply_loadout()
	boss.deactivate(true)
	couple_following = false
	palace.couple_static = false
	palace.queue_redraw()
	for n in couple:
		n.visible = false
	palace.barrier.restore()
	arena(2).open_gate()


## 覺醒（死亡演出或卡片之後）：換成希巴拉克（下一步是他射木障）、同篝火休息後存檔，進出口階段
func finish_awakening() -> void:
	_enter_awakened_palace()
	if player.twin_index == 0:
		player.swap_twin()
	if gs != null:
		gs.awakened = true
		gs.rest("palace_camp")
		Save.write(gs.to_dict(), save_path)
		Loadout.apply(player, gs)
		_apply_loadout()
		_saved_left = SAVED_TIME
	_set_view(Palace.EXIT_VIEW)
	_enter_exit()


## 覺醒後的出口：提示做到才換——先破木障，再二段跳上高台（出口高台單跳上不去）
func _enter_exit() -> void:
	stage = Stage.EXIT
	hud.notice = exit_notice()


func exit_notice() -> String:
	if _forest_hint_left > 0.0:  # 森林提示優先（MV-SLICE-001c4b）
		return FOREST_HINT
	if stage != Stage.EXIT:
		return ""
	if _saved_left > 0.0:
		return SAVED_NOTICE
	return EXIT_HINT_BARRIER if not palace.barrier.is_broken else EXIT_HINT


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
	_apply_lights()
	player.respawn(rest_point(p))
	if gs != null:  # respawn 用預設上限重建血量：套回碎片加成（MV-SLICE-001c4a）
		player.health.max_hp = gs.max_hp_now()
		player.health.hp = player.health.max_hp
	_apply_loadout()
	arena(p).open_gate()
	boss.park(p)
	_set_view(Nance.REGION if p == 1 else Palace.REGION)
	stage = Stage.APPROACH
	if awakened:
		_enter_awakened_palace()


## F10：重來目前的場地（不記死亡、不退段；計畫 D18）
func reset_area() -> void:
	if stage == Stage.APPROACH or stage == Stage.FIGHT:
		_retry(phase)


func _finish() -> void:
	hud.notice = ""
	if cutscene != null:  # 遊戲模式：結尾演出，黑畫面接到出口房間的結束畫面（MV-SLICE-001c2c）
		stage = Stage.DONE
		await cutscene.run([Finale.new()])
		log.close(now(), "clear")
		finished.emit()
		return
	log.close(now(), "clear")
	show_card("clear")
	stage = Stage.DONE
	await card.closed
	finished.emit()


func _exit_tree() -> void:
	if Audio.music == &"mus_b01":  # MV-SLICE-001d1a
		Audio.stop_music()
	if log != null:
		log.close(now(), "quit")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and log != null:
		log.close(now(), "quit")


func _on_player_hit(_target: Node) -> void:
	feedback.hitstop()
	feedback.shake()
	feedback.play(Sound.hit_id(player.attack_weapon))


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
	if scenery == null:
		var bg := background_color()
		draw_rect(Nance.REGION, bg)
		draw_rect(Palace.REGION.merge(Palace.EXIT_VIEW), bg)
	if couple_following and couple.is_empty():  # 兩位老人跟在後面（灰盒；gs 模式改用骨架）
		draw_rect(Rect2(couple_x - 70, Nance.GROUND_Y - 150, 50, 150), Color(0.6, 0.6, 0.6))
		draw_rect(Rect2(couple_x, Nance.GROUND_Y - 130, 50, 130), Color(0.55, 0.55, 0.55))
