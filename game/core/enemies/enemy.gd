extends CharacterBody2D
# 假光造物共用邏輯（規格書第 4、5 節）：前搖訊號、吹箭打斷與冷卻、硬直、受擊閃白、死亡。
# 碰觸身體不傷人，只有攻擊中的判定會傷人（PROTO1-4）。子類別覆寫 _ 開頭的行為函式。

const Tuning := preload("res://core/tuning/combat_tuning.gd")
const Health := preload("res://core/combat/health.gd")
const Hitbox := preload("res://core/combat/hitbox.gd")
const Hurtbox := preload("res://core/combat/hurtbox.gd")
const L := preload("res://core/combat/layers.gd")

signal interrupted(enemy: Node)
signal died(enemy: Node)

enum State { IDLE, TELEGRAPH, ATTACK, RECOVER, STAGGER, DEAD }

const BASE_COLOR := Color(0.95, 0.8, 0.35)  # 假光造物：珠寶金

var tn: Tuning = Tune.data
var target: Node2D  # 玩家；null 時不會出招
var health: Health
var state := State.IDLE
var state_time := 0.0
var interrupt_cooldown_left := 0.0
var stagger_time := 0.0  # 這次硬直的時限：吹箭打斷 dart_stagger_time、招架 parry_stagger
var flash_left := 0.0
var facing := -1
var portrait_drawn := false  # MV-SLICE-001b1：有靜態立繪時不畫灰盒身體與眼睛（訊號照畫）
var size := Vector2(100, 70)  # 子類別在 _init 覆寫
var parryable := true  # 前搖訊號：true＝白色圓形，false＝暗紫鋸齒
var hitbox: Hitbox
var hurtbox: Hurtbox
var _step_left := 0.0  # 下一次移動聲的倒數（MV-SLICE-001d1b）
const STEP_EVERY := 0.35
const MOVING := 20.0


# ---- 子類別覆寫 ----

func _max_hp() -> int:
	return 1


func _telegraph_time() -> float:
	return 0.5


func _recover_time() -> float:
	return 0.5


func _damage() -> int:
	return 1


## 音效（MV-SLICE-001d1b）：種類名決定 enm_<種類>_move／_attack；反光型覆寫攻擊與蓄力聲
func _sound_kind() -> String:
	return ""


func _attack_sound() -> StringName:
	return StringName("enm_%s_attack" % _sound_kind())


func _charge_sound() -> StringName:
	return &""


func _uses_gravity() -> bool:
	return true


func _idle(_delta: float) -> void:
	pass


func _begin_attack() -> void:
	pass


## 攻擊中每幀呼叫；結束時呼叫 _end_attack()
func _attack(_delta: float) -> void:
	_end_attack()


# ---- 共用 ----

func _ready() -> void:
	add_to_group("enemy")  # MV-SLICE-001a：老鼠的鑽地突襲找目標用
	health = Health.new(_max_hp())
	collision_layer = L.ENEMY_BODY
	collision_mask = L.WORLD
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = Vector2(0, -size.y / 2.0)
	add_child(cs)
	hurtbox = Hurtbox.new()
	hurtbox.setup(size, Vector2(0, -size.y / 2.0), L.ENEMY_HURT)
	hurtbox.hurt.connect(_on_hurt)
	add_child(hurtbox)
	hitbox = Hitbox.new()
	hitbox.configure(size * 1.1, Vector2(0, -size.y / 2.0), L.PLAYER_HURT)
	add_child(hitbox)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	state_time += delta
	interrupt_cooldown_left = maxf(interrupt_cooldown_left - delta, 0.0)
	flash_left = maxf(flash_left - delta, 0.0)
	match state:
		State.IDLE:
			_idle(delta)
			_step_left -= delta
			if velocity.length() > MOVING and _step_left <= 0.0 and _sound_kind() != "":
				_step_left = STEP_EVERY
				Audio.play_at(StringName("enm_%s_move" % _sound_kind()), global_position)
		State.TELEGRAPH:
			velocity = Vector2(0.0, velocity.y if _uses_gravity() else 0.0)
			if state_time >= _telegraph_time():
				_enter(State.ATTACK)
				hitbox.start()
				_begin_attack()
		State.ATTACK:
			_attack(delta)
		State.RECOVER, State.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 4000.0 * delta)
			if not _uses_gravity():
				velocity.y = 0.0
			var limit := _recover_time() if state == State.RECOVER else stagger_time
			if state_time >= limit:
				_enter(State.IDLE)
	if _uses_gravity():
		velocity.y = minf(velocity.y + tn.gravity() * delta, tn.max_fall_speed)
	move_and_slide()
	for hb in hitbox.collect():
		hb.receive(_damage(), self, &"enemy")
	queue_redraw()


## 開始前搖：面向目標
func start_telegraph() -> void:
	if target != null:
		facing = 1 if target.global_position.x >= global_position.x else -1
	_enter(State.TELEGRAPH)


func _end_attack() -> void:
	_enter(State.RECOVER)


func _enter(s: State) -> void:
	if state == State.ATTACK and s != State.ATTACK:
		hitbox.stop()
	if s == State.TELEGRAPH and state != State.TELEGRAPH:
		Audio.play_tell(parryable)  # 前兆聲（MV-SLICE-001d1a）
		if _charge_sound() != &"":
			Audio.play_at(_charge_sound(), global_position)
	if s == State.ATTACK and state != State.ATTACK and _sound_kind() != "":
		Audio.play_at(_attack_sound(), global_position)  # 出招（依距離衰減，MV-SLICE-001d1b）
	state = s
	state_time = 0.0


func _on_hurt(amount: int, _source: Node, kind: StringName) -> void:
	if state == State.DEAD:
		return
	health.take_damage(amount)
	flash_left = tn.enemy_flash_time
	if health.is_dead():
		_die()
		return
	# PROTO1-5：前搖中被吹箭射中就打斷，同一隻有冷卻；近戰不打斷（B3：打斷是吹箭專屬）
	if kind == &"dart" and state == State.TELEGRAPH and interrupt_cooldown_left <= 0.0:
		interrupt_cooldown_left = tn.dart_interrupt_cooldown
		stagger_time = tn.dart_stagger_time
		_enter(State.STAGGER)
		interrupted.emit(self)


## 被球具招架（MV-PROTO-002 規格書第 4 節）：只在攻擊中有效；硬直比吹箭打斷長，且不受打斷冷卻限制
func parried() -> void:
	if state != State.ATTACK:
		return
	stagger_time = tn.parry_stagger
	flash_left = tn.enemy_flash_time
	_enter(State.STAGGER)


## MV-SLICE-001a：老鼠的鑽地突襲造成的短硬直
func stun(seconds: float) -> void:
	if state == State.DEAD:
		return
	stagger_time = seconds
	flash_left = tn.enemy_flash_time
	_enter(State.STAGGER)


## 場地致死（掉坑）
func kill() -> void:
	if state != State.DEAD:
		_die()


func _die() -> void:
	_enter(State.DEAD)
	collision_layer = 0
	hurtbox.set_deferred("monitorable", false)
	died.emit(self)
	queue_free()


# ---- 灰盒繪圖 ----

func _draw() -> void:
	var rect := Rect2(-size.x / 2.0, -size.y, size.x, size.y)
	if not portrait_drawn:
		draw_rect(rect, Color.WHITE if flash_left > 0.0 else BASE_COLOR)
		draw_rect(Rect2(facing * size.x * 0.3 - 5.0, -size.y * 0.75, 10.0, 10.0), Color.BLACK)
	if state == State.TELEGRAPH:
		draw_rect(rect, Color.WHITE, false, 5.0)  # 輪廓亮起
		_draw_signal(Vector2(0, -size.y - 50.0))
	elif state == State.STAGGER:
		draw_rect(rect, Color(0.5, 0.6, 1.0, 0.5))
	if interrupt_cooldown_left > 0.0:
		draw_circle(Vector2(size.x / 2.0 - 10.0, -size.y - 14.0), 9.0, Color(0.15, 0.15, 0.25, 0.9))  # 打斷冷卻中


func _draw_signal(at: Vector2) -> void:
	if parryable:
		draw_circle(at, 24.0, Color(1, 1, 1, 0.95))  # 可招架＝白色圓形
		return
	var pts := PackedVector2Array()
	for i in 12:
		var ang := TAU * i / 12.0
		var rad := 32.0 if i % 2 == 0 else 14.0
		pts.append(at + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(pts, Color(0.35, 0.1, 0.45))  # 不可招架＝暗紫鋸齒
