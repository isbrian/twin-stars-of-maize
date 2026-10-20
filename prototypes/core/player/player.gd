extends CharacterBody2D
# 灰盒角色（MV-PROTO-001／002）：移動、跳躍、翻滾、三方向攻擊、下劈彈跳、吹箭、治療、受擊；
# 兩兄弟一鍵換人（同一個身體，只切換角色資料）。
# 規格：todo/spec/MV-PROTO-001_戰鬥手感.md 第 3、4 節；todo/spec/MV-PROTO-002_換人與武器.md 第 1、2 節。原點在腳底中央。

const Tuning := preload("res://tuning/combat_tuning.gd")
const Health := preload("res://combat/health.gd")
const Hitbox := preload("res://combat/hitbox.gd")
const Hurtbox := preload("res://combat/hurtbox.gd")
const Intent := preload("res://player/intent.gd")
const L := preload("res://combat/layers.gd")
const Blowgun := preload("res://player/blowgun.gd")
const Twin := preload("res://player/twin.gd")
const Weapons := preload("res://player/weapons.gd")
const ParryStats := preload("res://combat/parry_stats.gd")
const ToolSpirit := preload("res://player/tool_spirit.gd")

signal swung
signal hit_landed(target: Node)
signal dart_fired
signal hurt_taken
signal healed
signal died
signal swapped
signal parried(enemy: Node)
signal double_jumped
signal tool_sent(tool: Node)

enum State { FREE, ATTACK, ROLL, HEAL, HURT, PARRY }
enum AttackDir { SIDE, UP, DOWN }
enum Phase { STARTUP, ACTIVE, RECOVERY }

const SIZE := Vector2(60, 180)
const COLOR := Color(0.85, 0.55, 0.25)  # Hunahpu 暖色（ART-8）；實際顏色取 twin().color
const SWAP_FLASH_TIME := 0.15
const PARRY_RING_TIME := 0.3
const DOUBLE_JUMP_FLASH_TIME := 0.2

var tn: Tuning = Tune.data
var health: Health
var intent := Intent.new()
var scripted := false  # true：不讀實體輸入，由測試或展示模式填 intent

var state := State.FREE
var state_time := 0.0
var facing := 1
var jumping := false  # 上升中、放開跳躍鍵時要削減速度
var coyote_left := 0.0
var jump_buffer_left := 0.0
var roll_buffer_left := 0.0  # 翻滾、攻擊也有輸入緩衝：在不能動作時按下，於第一個合法幀執行
var attack_buffer_left := 0.0
var roll_dir := 1
var roll_cooldown_left := 0.0
var attack_dir := AttackDir.SIDE
var attack_phase := Phase.STARTUP
var attack_weapon := 0  # 出招時的武器（Weapons.Weapon）
var recoil_left := 0.0
var hurtbox: Hurtbox
var hitbox: Hitbox
var blowgun: Blowgun
var twins: Array = []
var twin_index := 0
var swap_buffer_left := 0.0
var swap_cooldown_left := 0.0
var swap_flash_left := 0.0
var parry_stats := ParryStats.new()  # 只在關閉遊戲時清除（respawn 不重建）
var parry_pending := false  # 這次招架的結果還沒記
var parry_ring_left := 0.0
var air_jump_used := false  # 本次滯空的二段跳已用；記在身體上，換人不刷新（PROTO2-10）
var double_jump_flash_left := 0.0
var tool: Node  # Xbalanque 派出、還在外面的工具
var abilities_enabled := true  # 二段跳與讓工具自己動（MV-PROTO-003：Boss 戰中停用，覺醒後開啟）
var last_hurt_source: Node  # 最後打中角色的來源（Boss 戰日誌的死因）


func _ready() -> void:
	twins = [Twin.hunahpu(), Twin.xbalanque()]
	health = Health.new(tn.max_hp, tn.heal_charges)
	collision_layer = L.PLAYER_BODY
	collision_mask = L.WORLD
	var body := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	body.shape = rect
	body.position = Vector2(0, -SIZE.y / 2.0)
	add_child(body)
	hurtbox = Hurtbox.new()
	hurtbox.setup(SIZE * Vector2(0.8, 0.9), Vector2(0, -SIZE.y / 2.0), L.PLAYER_HURT)
	hurtbox.hurt.connect(_on_hurt)
	add_child(hurtbox)
	hitbox = Hitbox.new()
	add_child(hitbox)
	blowgun = Blowgun.new()
	blowgun.player = self
	add_child(blowgun)


func _physics_process(delta: float) -> void:
	if not scripted:
		intent.read_from_input(self)
	health.tick(delta)
	roll_cooldown_left = maxf(roll_cooldown_left - delta, 0.0)
	recoil_left = maxf(recoil_left - delta, 0.0)
	swap_cooldown_left = maxf(swap_cooldown_left - delta, 0.0)
	swap_flash_left = maxf(swap_flash_left - delta, 0.0)
	parry_ring_left = maxf(parry_ring_left - delta, 0.0)
	double_jump_flash_left = maxf(double_jump_flash_left - delta, 0.0)
	_update_input_timers(delta)
	state_time += delta
	_try_swap()
	match state:
		State.FREE:
			_state_free(delta)
		State.ROLL:
			_state_roll(delta)
		State.ATTACK:
			_state_attack(delta)
		State.HEAL:
			_state_heal(delta)
		State.HURT:
			_state_hurt(delta)
		State.PARRY:
			_state_parry(delta)
	move_and_slide()
	_process_hits()
	intent.clear_presses()
	queue_redraw()


func _update_input_timers(delta: float) -> void:
	if is_on_floor():
		coyote_left = tn.coyote_time
		air_jump_used = false
	else:
		coyote_left = maxf(coyote_left - delta, 0.0)
	jump_buffer_left = tn.jump_buffer if intent.jump_pressed else maxf(jump_buffer_left - delta, 0.0)
	roll_buffer_left = tn.action_buffer if intent.roll_pressed else maxf(roll_buffer_left - delta, 0.0)
	attack_buffer_left = tn.action_buffer if intent.attack_pressed else maxf(attack_buffer_left - delta, 0.0)
	swap_buffer_left = tn.action_buffer if intent.swap_pressed else maxf(swap_buffer_left - delta, 0.0)


func _enter(s: State) -> void:
	if state == State.ATTACK and s != State.ATTACK:
		hitbox.stop()
	if state == State.PARRY and s != State.PARRY:
		_record_parry(ParryStats.Result.WHIFF)  # 換人、換武器、重生等方式離開招架，仍要記下這次（成功的已先記）
	state = s
	state_time = 0.0


# ---- 換人（PROTO2-1、PROTO2-2）----

func twin():
	return twins[twin_index]


## 自由狀態（地面、空中）或攻擊收招中才能換；出招、判定、翻滾、治療、受擊硬直中不能換
func can_swap() -> bool:
	if state == State.PARRY:
		return state_time >= tn.parry_window
	return state == State.FREE or (state == State.ATTACK and attack_phase == Phase.RECOVERY)


## 緩衝中的換人：冷卻中按下直接丟棄（冷卻比緩衝長，不排隊）
func _try_swap() -> void:
	if swap_buffer_left <= 0.0:
		return
	if swap_cooldown_left > 0.0:
		swap_buffer_left = 0.0
		return
	if can_swap():
		swap_twin()


## 換上場的人回到自由狀態；位置、速度、面向、血量、無敵計時都保留（共用身體）
func swap_twin() -> void:
	twin_index = 1 - twin_index
	swap_cooldown_left = tn.swap_cooldown
	swap_buffer_left = 0.0
	swap_flash_left = SWAP_FLASH_TIME
	hitbox.stop()
	_enter(State.FREE)
	swapped.emit()


## 破綻滿時自動換人（MV-PROTO-003 計畫 D13）：不受冷卻、也不設冷卻；攻擊或招架中結束該動作，翻滾、受擊、治療照舊
func force_twin(i: int) -> void:
	if twin_index == i:
		return
	if state == State.ATTACK or state == State.PARRY:
		hitbox.stop()
		_enter(State.FREE)
	twin_index = i
	swap_flash_left = SWAP_FLASH_TIME
	swap_buffer_left = 0.0
	swapped.emit()


# ---- 自由狀態 ----

func _state_free(delta: float) -> void:
	_apply_horizontal(delta, intent.move_x)
	_apply_gravity(delta)
	if intent.move_x != 0.0:
		facing = 1 if intent.move_x > 0.0 else -1
	if _try_jump():
		return
	if roll_buffer_left > 0.0 and _try_roll():
		return
	if intent.heal_pressed and _try_heal():
		return
	if attack_buffer_left > 0.0:
		if not twin().weapon_enabled:  # 斷臂：攻擊鍵無效
			attack_buffer_left = 0.0
		else:
			_start_attack()
			return
	if intent.dart_pressed:
		_fire_dart()


func _apply_horizontal(delta: float, dir: float) -> void:
	if recoil_left > 0.0:  # 側攻命中後退
		velocity.x = -facing * tn.side_hit_recoil
		return
	var target := dir * tn.run_speed
	var t := tn.accel_time if target != 0.0 else tn.decel_time
	velocity.x = move_toward(velocity.x, target, tn.run_speed * delta / maxf(t, 0.0001))


func _apply_gravity(delta: float) -> void:
	if jumping and velocity.y < 0.0 and not intent.jump_held:
		velocity.y *= tn.jump_cut_multiplier  # 可變跳躍高度
		jumping = false
	if velocity.y >= 0.0:
		jumping = false
	var g := tn.gravity()
	if velocity.y > 0.0:
		var down_slash := state == State.ATTACK and attack_dir == AttackDir.DOWN
		g *= tn.down_slash_gravity_multiplier if down_slash else tn.fall_gravity_multiplier  # 彈起後仍在收招：上升不加重，彈跳高度不變
	velocity.y = minf(velocity.y + g * delta, tn.max_fall_speed)


## 土狼時間＋跳躍緩衝：兩者同時有效才起跳；否則 Hunahpu 在空中可二段跳一次
func _try_jump() -> bool:
	if jump_buffer_left <= 0.0:
		return false
	if coyote_left <= 0.0:
		return _try_double_jump()
	velocity.y = -tn.jump_velocity()
	jump_buffer_left = 0.0
	coyote_left = 0.0
	jumping = true
	return true


## 二段跳（只有 Hunahpu）：高度 jump_height × double_jump_ratio，所以速度乘 sqrt(比例)（計畫 D1）
func _try_double_jump() -> bool:
	if not twin().can_double_jump or not abilities_enabled or is_on_floor() or air_jump_used:
		return false
	velocity.y = -tn.jump_velocity() * sqrt(tn.double_jump_ratio)
	jump_buffer_left = 0.0
	air_jump_used = true
	jumping = true
	double_jump_flash_left = DOUBLE_JUMP_FLASH_TIME
	double_jumped.emit()
	return true


# ---- 翻滾（PROTO1-2：只能在地面）----

func _try_roll() -> bool:
	if not is_on_floor() or roll_cooldown_left > 0.0:
		return false
	if intent.move_x != 0.0:
		facing = 1 if intent.move_x > 0.0 else -1
	roll_dir = facing
	roll_buffer_left = 0.0
	_enter(State.ROLL)
	return true


func _state_roll(delta: float) -> void:
	velocity.x = roll_dir * tn.roll_speed()
	_apply_gravity(delta)
	if state_time >= tn.roll_time:
		roll_cooldown_left = tn.roll_cooldown
		_enter(State.FREE)


func is_roll_invulnerable() -> bool:
	return state == State.ROLL and state_time >= tn.roll_iframe_start and state_time <= tn.roll_iframe_end


# ---- 近戰攻擊（PROTO1-3：只有收招能被翻滾、跳躍、換人取消；武器資料見 weapons.gd）----

func _start_attack() -> void:
	if intent.down and not is_on_floor():
		attack_dir = AttackDir.DOWN
	elif intent.up:
		attack_dir = AttackDir.UP
	else:
		attack_dir = AttackDir.SIDE
	attack_weapon = twin().weapon
	if attack_dir == AttackDir.DOWN and velocity.y > 0.0:  # 按下劈的瞬間變回原本的下落速度（同樣下落時間、換成下劈倍率）
		velocity.y = minf(velocity.y * tn.down_slash_gravity_multiplier / maxf(tn.fall_gravity_multiplier, 0.01), tn.max_fall_speed)
	if Weapons.is_parry(attack_weapon, attack_dir):
		_start_parry()
		return
	var box := Weapons.box(attack_weapon, attack_dir, tn)
	var offset: Vector2
	match attack_dir:
		AttackDir.SIDE:
			offset = Vector2(facing * (SIZE.x + box.x) / 2.0, -SIZE.y * Weapons.side_height(attack_weapon))
		AttackDir.UP:
			offset = Vector2(0, -SIZE.y - box.y / 2.0)
		AttackDir.DOWN:
			offset = Vector2(0, box.y / 2.0)
	var mask := L.ENEMY_HURT | L.BARRIER | (L.POGO if attack_dir == AttackDir.DOWN else 0)  # 彈跳物只會被下劈打中；近戰打木障只有悶響
	hitbox.configure(box, offset, mask)
	attack_buffer_left = 0.0
	attack_phase = Phase.STARTUP
	_enter(State.ATTACK)
	swung.emit()


func _state_attack(delta: float) -> void:
	_apply_horizontal(delta, intent.move_x)  # 攻擊中仍可左右移動（HK），面向不變
	_apply_gravity(delta)
	var tm := Weapons.timing(attack_weapon, tn)
	var active_at := tm.x
	var recovery_at := active_at + tm.y
	var end_at := recovery_at + tm.z
	if attack_phase == Phase.STARTUP and state_time >= active_at:
		attack_phase = Phase.ACTIVE
		hitbox.start()
	if attack_phase == Phase.ACTIVE and state_time >= recovery_at:
		attack_phase = Phase.RECOVERY
		hitbox.stop()
	if attack_phase != Phase.RECOVERY:
		return
	if roll_buffer_left > 0.0 and _try_roll():
		return
	if _try_jump():
		_enter(State.FREE)
		return
	if state_time >= end_at:
		_enter(State.FREE)


## 傷害 0 的命中（球具下劈）：對敵人不扣血、不發 hit_landed（不停頓、不閃白），仍會彈跳；彈跳物照舊（計畫 D7）
func _process_hits() -> void:
	var dmg := Weapons.damage(attack_weapon, tn)
	for hb in hitbox.collect():
		if hb.collision_layer & L.BARRIER != 0:
			hb.receive(dmg, self, &"melee")  # 木障只發悶響：不觸發命中回饋、不後退、不彈跳
			continue
		var is_pogo: bool = hb.collision_layer & L.POGO != 0
		if dmg > 0 or is_pogo:
			hb.receive(dmg, self, &"melee")
			hit_landed.emit(hb)
		if attack_dir == AttackDir.DOWN:
			velocity.y = -tn.pogo_velocity  # 下劈彈跳（B8）
			jumping = false
			air_jump_used = false  # 彈起恢復二段跳
		elif attack_dir == AttackDir.SIDE and dmg > 0:
			recoil_left = tn.side_hit_recoil_time


## 除錯鍵 1／2／3：改目前場上的人的武器；攻擊中改武器會立即結束攻擊、關閉判定
func set_weapon(w: int) -> void:
	twin().weapon = w
	if state == State.ATTACK or state == State.PARRY:
		hitbox.stop()
		_enter(State.FREE)


# ---- 球具招架（MV-PROTO-002 規格書第 4 節；PROTO2-5、PROTO2-6）----

func _start_parry() -> void:
	attack_buffer_left = 0.0
	parry_pending = true
	_enter(State.PARRY)


func is_parry_window() -> bool:
	return state == State.PARRY and state_time < tn.parry_window


func _record_parry(result: int) -> void:
	if not parry_pending:
		return
	parry_pending = false
	parry_stats.record(Time.get_ticks_msec() / 1000.0, result)


## 招架中可左右移動、面向不變（同攻擊）；窗口結束仍未有結果記白揮；收招可被翻滾、跳躍、換人取消
func _state_parry(delta: float) -> void:
	_apply_horizontal(delta, intent.move_x)
	_apply_gravity(delta)
	if state_time < tn.parry_window:
		return
	_record_parry(ParryStats.Result.WHIFF)
	if roll_buffer_left > 0.0 and _try_roll():
		return
	if _try_jump():
		_enter(State.FREE)
		return
	if state_time >= tn.parry_window + tn.parry_recovery:
		_enter(State.FREE)


## 窗口內被打：正面＋可招架 → 成功（回傳 true，不受傷）；不可招架、背後 → 記結果後照常受傷（計畫 D2）
func _try_parry(source: Node) -> bool:
	if not is_parry_window():
		return false
	var p = source.get("parryable") if source != null else null
	if p == null:
		_record_parry(ParryStats.Result.WHIFF)
		return false
	var side := signf(source.global_position.x - global_position.x)
	if p and (side == 0.0 or int(side) == facing):
		_record_parry(ParryStats.Result.SUCCESS)
		source.parried()
		parry_ring_left = PARRY_RING_TIME
		_enter(State.FREE)
		parried.emit(source)
		return true
	_record_parry(ParryStats.Result.WHIFF if p else ParryStats.Result.UNPARRYABLE)
	return false


# ---- 治療（PROTO1-6：按下就扣次數，硬直結束才回血，被打就中斷）----

func _try_heal() -> bool:
	if not is_on_floor() or not health.begin_heal():
		return false
	_enter(State.HEAL)
	return true


func _state_heal(delta: float) -> void:
	velocity.x = 0.0
	_apply_gravity(delta)
	if state_time >= tn.heal_time:
		health.finish_heal(tn.heal_amount)
		healed.emit()
		_enter(State.FREE)


# ---- 受擊 ----

func _on_hurt(amount: int, source: Node, _kind: StringName) -> void:
	if is_roll_invulnerable():
		return
	if _try_parry(source):
		return
	if not health.take_damage(amount, tn.hurt_invuln_time):
		return
	var dir := -facing
	if source is Node2D:
		dir = 1 if global_position.x >= source.global_position.x else -1
	velocity = Vector2(dir * tn.hurt_knockback.x, tn.hurt_knockback.y)
	jumping = false
	last_hurt_source = source
	_enter(State.HURT)  # 治療中被打 → 離開 HEAL，這次治療作廢
	hurt_taken.emit()
	if health.is_dead():
		died.emit()


func _state_hurt(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, tn.run_speed * delta / maxf(tn.hurt_stun_time, 0.0001))
	if state_time >= tn.hurt_stun_time:
		_enter(State.FREE)


## 掉進坑：扣血（無視受擊無敵，避免無敵中免費重來），回到指定位置
func fall_into_pit(respawn_at: Vector2) -> void:
	health.take_damage(tn.pit_damage, tn.hurt_invuln_time, true)
	hurt_taken.emit()
	if health.is_dead():
		died.emit()
		return
	position = respawn_at
	velocity = Vector2.ZERO
	_enter(State.FREE)


## 重置：血量、治療次數補滿，回到指定位置
func respawn(at: Vector2) -> void:
	health = Health.new(tn.max_hp, tn.heal_charges)
	position = at
	velocity = Vector2.ZERO
	roll_cooldown_left = 0.0
	recoil_left = 0.0
	roll_buffer_left = 0.0
	attack_buffer_left = 0.0
	twin_index = 0  # 重置回到 Hunahpu、兩人回預設武器（計畫 D4）
	for t in twins:
		t.weapon = t.default_weapon
	swap_buffer_left = 0.0
	swap_cooldown_left = 0.0
	swap_flash_left = 0.0
	air_jump_used = false
	if is_instance_valid(tool):  # 收回在外的工具（計畫 D4）
		tool.queue_free()
	tool = null
	_enter(State.FREE)


# ---- 讓工具自己動（Xbalanque；PROTO2-9）----

## 由木障在被 Xbalanque 的飛鏢射中時呼叫；同時只有一把工具在外
func send_tool(barrier: Node) -> bool:
	if is_instance_valid(tool):
		return false
	var t := ToolSpirit.new()
	t.tn = tn
	t.player = self
	t.barrier = barrier
	get_parent().add_child(t)
	t.global_position = global_position + ToolSpirit.OFFSET
	tool = t
	tool_sent.emit(t)
	return true


# ---- 吹箭（只在自由狀態可射；B3）----

func _fire_dart() -> void:
	if blowgun.try_fire(intent.aim) != null:
		dart_fired.emit()


# ---- 灰盒繪圖 ----

func _draw() -> void:
	var alpha := 1.0
	if is_roll_invulnerable():
		alpha = 0.45
	elif health.invuln_left > 0.0 and int(health.invuln_left * 15.0) % 2 == 0:
		alpha = 0.3
	var col: Color = twin().color
	if state == State.HEAL:
		col = Color(0.5, 0.9, 0.6)
	var body := Rect2(-SIZE.x / 2.0, -SIZE.y, SIZE.x, SIZE.y)
	if state == State.ROLL:
		body = Rect2(-SIZE.x / 2.0 - 20.0, -SIZE.y * 0.5, SIZE.x + 40.0, SIZE.y * 0.5)
	draw_rect(body, Color(col, alpha))
	if state == State.PARRY:  # 招架窗口：面前一面半透明小圓盾，收招中變淡
		var a := 0.6 if is_parry_window() else 0.2
		draw_circle(Vector2(facing * 50.0, -SIZE.y * 0.55), 26.0, Color(1, 1, 1, a))
	if parry_ring_left > 0.0:  # 招架成功：白色圓形光環擴散（ART_SPEC 第 5 節）
		var k := 1.0 - parry_ring_left / PARRY_RING_TIME
		draw_arc(Vector2(facing * 50.0, -SIZE.y * 0.55), 30.0 + 90.0 * k, 0.0, TAU, 40, Color(1, 1, 1, 1.0 - k), 6.0)
	if double_jump_flash_left > 0.0:  # 二段跳：腳下一圈小光點
		var k := double_jump_flash_left / DOUBLE_JUMP_FLASH_TIME
		for i in 6:
			draw_circle(Vector2(cos(TAU * i / 6.0), sin(TAU * i / 6.0) * 0.3) * (30.0 + 30.0 * (1.0 - k)), 5.0, Color(1, 0.95, 0.7, k))
	if swap_flash_left > 0.0:
		draw_rect(body, Color(1, 1, 1, swap_flash_left / SWAP_FLASH_TIME), false, 6.0)  # 換人閃一下
	draw_rect(Rect2(facing * 14.0 - 6.0, body.position.y + 16.0, 12.0, 12.0), Color(0, 0, 0, alpha))  # 眼睛＝面向
	if state == State.ATTACK and attack_phase != Phase.STARTUP:
		var a := 0.65 if attack_phase == Phase.ACTIVE else 0.2
		draw_rect(Rect2(hitbox.shape.position - hitbox.rect.size / 2.0, hitbox.rect.size), Color(1, 1, 1, a))
