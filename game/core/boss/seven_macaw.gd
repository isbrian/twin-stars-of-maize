extends Node2D
# Seven Macaw 主體（MV-PROTO-003 規格書第 1～3 節、PROTO3-7、計畫 D1、D4～D6）：
# 段落、破綻條、硬直、光源、依循環出招；每一招是 boss/moves/ 裡的一個腳本。
# 不與地形碰撞，位置由招式直接移動；碰觸身體不傷人（PROTO1-4）；沒有血量，血條三段只能由設局打掉。

const Tuning := preload("res://core/tuning/combat_tuning.gd")
const Hurtbox := preload("res://core/combat/hurtbox.gd")
const Hitbox := preload("res://core/combat/hitbox.gd")
const L := preload("res://core/combat/layers.gd")
const BreakGauge := preload("res://core/boss/break_gauge.gd")
const Light := preload("res://core/boss/light_source.gd")
const Nance := preload("res://core/boss/nance_arena.gd")
const Palace := preload("res://core/boss/palace_arena.gd")
const Move := preload("res://core/boss/moves/move.gd")

signal move_started(name: String)
signal gauge_filled
signal glow_struck(light_name: String)
signal setup_succeeded(phase: int)
signal window_missed
signal interrupted
signal summon_requested(cap: int)
signal flashed
signal intro_finished

enum State { DOWN, INTRO, GAP, MOVE, INTERRUPTED, BROKEN }

const SIZE := Vector2(180, 140)
const LIGHT_NAMES := ["jaw", "teeth", "eye"]
const LIGHT_OFFSETS := [Vector2(60, -60), Vector2(70, -95), Vector2(50, -120)]  # 面向右時相對腳底：下顎、玉牙、眼睛
const BODY_COLORS := [Color(0.95, 0.8, 0.35), Color(0.82, 0.68, 0.32), Color(0.68, 0.56, 0.3)]  # 段數越後越暗
const MOVES := {
	"summon": preload("res://core/boss/moves/summon.gd"),
	"throw_fruit": preload("res://core/boss/moves/throw_fruit.gd"),
	"eat_fruit": preload("res://core/boss/moves/eat_fruit.gd"),
	"dive": preload("res://core/boss/moves/dive.gd"),
	"false_flash": preload("res://core/boss/moves/false_flash.gd"),
	"flail": preload("res://core/boss/moves/flail.gd"),
	"wail": preload("res://core/boss/moves/wail.gd"),
	"throne_charge": preload("res://core/boss/moves/throne_charge.gd"),
	"stagger_pounce": preload("res://core/boss/moves/stagger_pounce.gd"),
	"beam": preload("res://core/boss/moves/beam.gd"),
}

var tn: Tuning = Tune.data
var target: Node2D
var phase := 1
var fx_drawn := false  # MV-SLICE-001c1：遊戲模式由 world/fx/ 畫招式特效（光束），不畫灰盒
var portrait_drawn := false  # MV-SLICE-001b1：有美術時不畫灰盒身體與眼睛（訊號、裂紋照畫）；光源由骨架放（b2b1）
## 身體框：面向右、相對腳底。受擊框＝它（依面向翻）；沒有骨架時是灰盒 SIZE，
## 有骨架時 world/macaw_animator.gd 用 set_body_rect() 換成骨架站姿量的身體＋腳（MV-SLICE-001b2b1 SLICE-b2b-6）
var body_rect := Rect2(-SIZE.x / 2.0, -SIZE.y, SIZE.x, SIZE.y)
var _hit_size := SIZE * 1.1  # 碰撞攻擊框（打到角色）的大小，中心＝身體框中心：灰盒比身體大一成；有骨架時等於身體框
var appearance := 0  # MV-SLICE-001b1：0 完整、1 下顎受傷、2 失去玉牙、3 失去眼睛（跟著 boss_fight 的 lights_removed）
var state := State.DOWN
var state_time := 0.0
var facing := -1:
	set(v):
		facing = v
		_fit_hurtbox()  # 身體框不左右對稱（骨架）：受擊框跟著面向翻
var gauge := BreakGauge.new()
var light
var hurtbox: Hurtbox
var hitbox: Hitbox
var move  # 目前的招式（moves/move.gd）；沒有時 null
var move_name := ""
var _flap_left := 0.0
const FLAP_EVERY := 0.4
var _last_sig := 0  # 上一幀的前搖訊號（moves/move.gd 的 Sig：0 無、1 可招架、2 不可招架）
var cycle_index := 0
var cycle_enabled := true  # false：只由 start_move() 出招（測試用）
var summons: Array = []  # 他召出、還活著的造物（boss_fight 維護）
var interrupt_cooldown_left := 0.0
var parryable := false  # 目前招式的前搖訊號是白色圓形；player._try_parry 讀這個
var flash_left := 0.0
var _intro_step := 0
var _intro_t := 0.0
var _falling := false  # 第 1 段在樹冠上破綻滿：先跌到低枝，硬直時間從落定才開始算


func _ready() -> void:
	add_to_group("enemy")  # MV-SLICE-001a：老鼠的鑽地突襲找目標用
	hurtbox = Hurtbox.new()
	var body := faced_body()
	hurtbox.setup(body.size, body.get_center(), L.ENEMY_HURT)
	hurtbox.hurt.connect(_on_hurt)
	add_child(hurtbox)
	hitbox = Hitbox.new()
	add_child(hitbox)
	configure_body_hitbox()
	light = Light.new()
	light.setup(Vector2(40, 40), Vector2.ZERO, L.LIGHT)
	light.collision_layer = 0
	light.hurt.connect(_on_light_hurt)
	add_child(light)
	_place_light()


func _physics_process(delta: float) -> void:
	state_time += delta
	interrupt_cooldown_left = maxf(interrupt_cooldown_left - delta, 0.0)
	flash_left = maxf(flash_left - delta, 0.0)
	match state:
		State.GAP:
			if cycle_enabled and state_time >= tn.boss_move_gap:
				var next := next_in_cycle(cycle(), cycle_index, _has_summons(), MOVES)
				if next[0] == "":
					state_time = 0.0
				else:
					cycle_index = next[1]
					start_move(next[0])
		State.MOVE:
			if move.tick(delta):
				_cancel_move()
				_enter(State.GAP)
		State.INTERRUPTED:
			if state_time >= tn.boss_interrupt_stagger:
				_enter(State.GAP)
		State.BROKEN:
			if _falling:
				if fly_to(Nance.PERCH, tn.boss_fly_speed * 2.0, delta):
					_falling = false
					state_time = 0.0
			elif state_time >= tn.boss_stagger_time:
				gauge.miss(tn.gauge_miss_reset)
				light.set_state(Light.State.OFF)
				_enter(State.GAP)
				window_missed.emit()
		State.INTRO:
			_intro(delta)
	_sync_parryable()
	_sync_tell()
	for hb in hitbox.collect():
		hb.receive(1, self, &"enemy")
	queue_redraw()


# ---- 段落 ----

## 前搖訊號出現（NONE → PARRY／UNPARRY）時放前兆聲；同一次前搖不重播（MV-SLICE-001d1a）
func _sync_tell() -> void:
	var sig: int = move.signal_kind if move != null else 0
	if sig != _last_sig and sig != 0:
		Audio.play_tell(sig == 1)
	_last_sig = sig


func begin_phase(p: int, first_move := "") -> void:
	_cancel_move()
	phase = p
	gauge.clear()
	interrupt_cooldown_left = 0.0
	position = home(p)
	visible = true
	hurtbox.set_deferred("collision_layer", L.ENEMY_HURT)
	light.set_state(Light.State.OFF)
	face_target()
	cycle_index = maxi(cycle().find(first_move), 0) if first_move != "" else 0
	_enter(State.GAP)


## 接近場地時：停在該段的起始位置、不出招
func park(p: int) -> void:
	begin_phase(p)
	_enter(State.DOWN)


func deactivate(hide := false) -> void:
	_cancel_move()
	hitbox.stop()
	light.set_state(Light.State.OFF)
	_enter(State.DOWN)
	if hide:
		visible = false
		hurtbox.set_deferred("collision_layer", 0)


## 第一次進 nance 樹：降到低枝吃果子（下顎微亮）→ 飛回樹冠（BOSS-9d）
func play_intro() -> void:
	_cancel_move()
	_intro_step = 0
	_intro_t = 0.0
	_enter(State.INTRO)


func _intro(delta: float) -> void:
	match _intro_step:
		0:
			if fly_to(Nance.PERCH, tn.boss_fly_speed, delta):
				light.set_state(Light.State.GLOW)
				_intro_step = 1
		1:
			_intro_t += delta
			if _intro_t >= tn.intro_eat_time:
				light.set_state(Light.State.OFF)
				_intro_step = 2
		2:
			if fly_to(Nance.CANOPY, tn.boss_fly_speed, delta):
				_enter(State.DOWN)
				intro_finished.emit()


static func home(p: int) -> Vector2:
	return Nance.CANOPY if p == 1 else Palace.HOME


func cycle() -> Array[String]:
	match phase:
		1:
			return tn.phase1_cycle
		2:
			return tn.phase2_cycle
	return tn.phase3_cycle


func summon_cap() -> int:
	return tn.summon_cap_p1 if phase == 1 else tn.summon_cap_p3


# ---- 出招 ----

## 循環的下一招：跳過未知名稱與「場上有造物時的召喚」；整圈都出不了招回傳 ["", index]（計畫 D6）
static func next_in_cycle(c: Array[String], index: int, has_summons: bool, known: Dictionary) -> Array:
	var n := c.size()
	for k in n:
		var i := (index + k) % n
		var mv := c[i]
		if not known.has(mv) or (mv == "summon" and has_summons):
			continue
		return [mv, (i + 1) % n]
	return ["", index]


func start_move(mv: String) -> bool:
	if not MOVES.has(mv):
		return false
	_cancel_move()
	move = MOVES[mv].new()
	move.boss = self
	move_name = mv
	face_target()
	_enter(State.MOVE)
	move.begin()
	_sync_parryable()
	move_started.emit(mv)
	return true


func _cancel_move() -> void:
	if move != null:
		move.cancel()
	move = null
	parryable = false


func _sync_parryable() -> void:
	parryable = move != null and move.signal_kind == Move.Sig.PARRY


func _has_summons() -> bool:
	summons = summons.filter(func(s): return is_instance_valid(s))
	return not summons.is_empty()


func _enter(s: State) -> void:
	state = s
	state_time = 0.0


## 以固定速度移向 to；距離小於 4 回傳 true
func fly_to(to: Vector2, speed: float, delta: float) -> bool:
	position = position.move_toward(to, speed * delta)
	if phase == 1:  # 振翅（第 1 段在樹上飛；第 2、3 段的 fly_to 是在地上走）（MV-SLICE-001d1a）
		_flap_left -= delta
		if _flap_left <= 0.0:
			_flap_left = FLAP_EVERY
			Audio.play(&"boss_sm_flap")
	return position.distance_to(to) < 4.0


func face_target() -> void:
	if target != null and target.global_position.x != global_position.x:
		facing = 1 if target.global_position.x > global_position.x else -1
	_place_light()


## 原型（沒有骨架）的光源位置；有骨架時由 world/macaw_animator.gd 每幀放到頭骨上的光點（MV-SLICE-001b2b1 SLICE-b2b-7）
func _place_light() -> void:
	if light != null and not portrait_drawn:
		light.position = LIGHT_OFFSETS[phase - 1] * Vector2(facing, 1)


func configure_body_hitbox() -> void:
	hitbox.configure(_hit_size, faced_body().get_center(), L.PLAYER_HURT)


## 換身體框（面向右、相對腳底）：受擊框與碰撞攻擊框都等於它（MV-SLICE-001b2b1 SLICE-b2b-6；招式數值不變）
func set_body_rect(r: Rect2) -> void:
	body_rect = r
	_hit_size = r.size
	_fit_hurtbox()
	configure_body_hitbox()


## 依目前面向翻好的身體框
func faced_body() -> Rect2:
	var r := body_rect
	return r if facing > 0 else Rect2(-r.end.x, r.position.y, r.size.x, r.size.y)


func _fit_hurtbox() -> void:
	if hurtbox == null:
		return
	var cs: CollisionShape2D = hurtbox.get_child(0)
	var r := faced_body()
	cs.shape.size = r.size
	cs.position = r.get_center()


# ---- 破綻條與受擊（規格書第 1 節）----

func add_gauge(amount: int) -> void:
	if state == State.BROKEN or state == State.DOWN:
		return  # 硬直中的命中不累積
	if gauge.add(amount, tn.gauge_max):
		_break()


func _break() -> void:
	_cancel_move()
	_enter(State.BROKEN)
	# 有立繪時（MV-SLICE-001b1，Brian 試玩 2026-10-11）：樹冠上的下顎在畫面外、射不到 → 跌到吃果子的低枝（下顎在畫面內）；原型照舊留在原地
	_falling = portrait_drawn and phase == 1 and position.y < Nance.PERCH.y - 4.0
	light.set_state(Light.State.BRIGHT)
	gauge_filled.emit()


## 被球具招架（計畫 D4）：該次判定結束、破綻 +15，進入該招之後的空檔
func parried() -> void:
	if move != null and move.attacking and move.signal_kind == Move.Sig.PARRY:
		move.on_parried()
		add_gauge(tn.gauge_parry)


func _on_hurt(amount: int, _source: Node, kind: StringName) -> void:
	flash_left = tn.enemy_flash_time
	if state == State.BROKEN or state == State.DOWN or state == State.INTRO:
		return
	if kind == &"melee" and amount > 0:
		add_gauge(tn.gauge_melee)
		return
	if kind == &"dart" and state == State.MOVE and move.interruptible() and interrupt_cooldown_left <= 0.0:
		_cancel_move()
		_enter(State.INTERRUPTED)
		interrupt_cooldown_left = tn.dart_interrupt_cooldown
		interrupted.emit()
		add_gauge(tn.gauge_dart_interrupt)


func _on_light_hurt(_amount: int, source: Node, _kind: StringName) -> void:
	var can_setup: bool = source != null and source.get("can_setup") == true
	match Light.effect(light.state, can_setup):
		Light.Effect.GLOW_HIT:
			if state != State.MOVE:
				return
			if move.on_glow_hit():
				_cancel_move()
				_enter(State.GAP)
			add_gauge(tn.gauge_glow_hit)
			glow_struck.emit(LIGHT_NAMES[phase - 1])
		Light.Effect.SETUP:
			deactivate()
			setup_succeeded.emit(phase)


# ---- 灰盒繪圖 ----

func _draw() -> void:
	var rect := Rect2(-SIZE.x / 2.0, -SIZE.y, SIZE.x, SIZE.y)
	if not portrait_drawn:
		draw_rect(rect, Color.WHITE if flash_left > 0.0 else BODY_COLORS[phase - 1])
		draw_rect(Rect2(facing * SIZE.x * 0.3 - 7.0, -SIZE.y * 0.85, 14.0, 14.0), Color.BLACK)  # 眼睛＝面向
	if move != null:
		move.draw(self)
		if move.telegraphing:
			draw_rect(rect, Color.WHITE, false, 6.0)  # 輪廓亮起
			if move.signal_kind != Move.Sig.NONE:
				# 畫在面向那一側、身體中段：Boss 停在樹冠（畫面頂端）時頭頂沒有空間
				_draw_signal(Vector2(facing * (SIZE.x / 2.0 + 55.0), -SIZE.y * 0.55), move.signal_kind == Move.Sig.PARRY)
	if state == State.BROKEN:  # 破綻滿：身上浮現裂紋（ART_SPEC 第 5 節）
		for i in 5:
			var x0 := -SIZE.x / 2.0 + 20.0 + i * 34.0
			draw_polyline(PackedVector2Array([Vector2(x0, -SIZE.y + 10), Vector2(x0 + 14, -SIZE.y * 0.6), Vector2(x0 - 6, -SIZE.y * 0.35), Vector2(x0 + 10, -10)]), Color.WHITE, 4.0)
	elif state == State.INTERRUPTED:
		draw_rect(rect, Color(0.5, 0.6, 1.0, 0.5))


# ponytail: yagni: 複製 enemy.gd 的訊號繪圖 | upgrade if: 第三個使用者出現時抽成共用
func _draw_signal(at: Vector2, is_parryable: bool) -> void:
	if is_parryable:
		draw_circle(at, 30.0, Color(1, 1, 1, 0.95))  # 可招架＝白色圓形
		return
	var pts := PackedVector2Array()
	for i in 12:
		var ang := TAU * i / 12.0
		var rad := 40.0 if i % 2 == 0 else 18.0
		pts.append(at + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(pts, Color(0.35, 0.1, 0.45))  # 不可招架＝暗紫鋸齒
	pts.append(pts[0])
	draw_polyline(pts, Color(0.8, 0.65, 0.95), 3.0)  # 淡紫外框：最暗一階的背景上也看得清楚


## MV-SLICE-001b1：外觀狀態（有骨架時 world/macaw_animator.gd 依它換頭件，MV-SLICE-001b2b1 SLICE-b2b-8）
func set_appearance(stage: int) -> void:
	appearance = stage
