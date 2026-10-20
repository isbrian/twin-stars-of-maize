extends "res://core/enemies/enemy.gd"
# 反光型（MV-SLICE-001c4c1）：站著不走，舉起反光面蓄力 → 朝前方射一道貼地水平光束（不可招架、跳得過）→ 放下反光面收招。
# 反光面擋正面：待機、前搖、光束時正面的攻擊只有悶響；前搖中正面的吹箭＝射中光點 → 打斷。正上方與背後全額扣血。
# 玩家繞到背後時要 reflector_turn_time 才轉過來，轉身時不擋。

signal thudded  # 正面擋下

const FRONT_MIN := 30.0  # 玩家在正上方時，水平距離小於這個不轉身（防止左右抖動）
const SIGHT_HEIGHT := 250.0  # 與玩家的高低差超過這個就不出招
const PLATE := Color(0.6, 0.95, 1.0)  # 佔位反光板：淺青（素材到位前，c4c2 換）

var turn_left := 0.0
var beam_rect := Rect2()  # 光束範圍（本地座標），前搖開始時依朝向鎖定
var spark_left := 0.0
var glow_at := Vector2.ZERO  # 蓄力光點（本地座標）：佔位時＝反光板中心，有骨架時由 enemy_animator 寫入反光面寶石的位置（MV-SLICE-001c4c2）


func _init() -> void:
	size = Vector2(250, 150)  # MV-SLICE-001c4c2：從骨架站姿量（反光面＋身體＋尾羽約 252×149），原本 160×140 差超過 20%
	parryable = false


func _max_hp() -> int:
	return tn.reflector_hp


func _telegraph_time() -> float:
	return tn.reflector_telegraph


func _recover_time() -> float:
	return tn.reflector_recover


func _damage() -> int:
	return tn.reflector_damage


func _physics_process(delta: float) -> void:
	spark_left = maxf(spark_left - delta, 0.0)
	super(delta)


## 在身體上方（下劈的位置）
func _above(from: Vector2) -> bool:
	return from.y < global_position.y - size.y * 0.6


## 正面：在地面時看在哪一側；在上方時離中線超過半個身寬才算正面（正上方＝背後，給下劈一點甜頭）
func is_front(from: Vector2) -> bool:
	var dx := (from.x - global_position.x) * facing
	return dx >= size.x / 2.0 if _above(from) else dx >= 0.0


## 這一下會被反光面擋下嗎？（玩家端用來決定要不要給命中回饋，同木障）
func blocks(from: Vector2) -> bool:
	return state != State.DEAD and blocking() and is_front(from)


func blocking() -> bool:
	return turn_left <= 0.0 and (state == State.IDLE or state == State.TELEGRAPH or state == State.ATTACK)


func _idle(delta: float) -> void:
	velocity.x = 0.0
	if turn_left > 0.0:
		turn_left -= delta
		if turn_left <= 0.0:
			turn_left = 0.0
			facing = (1 if target.global_position.x >= global_position.x else -1) if target != null else -facing  # 轉完面向玩家
			state_time = 0.0
		return
	if target == null:
		return
	var d := target.global_position - global_position
	var behind := d.x * facing <= -size.x / 2.0 if _above(target.global_position) else d.x * facing < -FRONT_MIN
	if behind:
		turn_left = tn.reflector_turn_time
		return
	if is_front(target.global_position) and absf(d.x) <= tn.reflector_range and absf(d.y) <= SIGHT_HEIGHT and state_time >= tn.enemy_rest:
		start_telegraph()


func _sound_kind() -> String:
	return "reflector"


## 反光型的攻擊就是光束：沿用 Seven Macaw 的光束聲、小 6 dB（A21-3）
func _attack_sound() -> StringName:
	return &"enm_reflector_beam_fire"


func _charge_sound() -> StringName:
	return &"enm_reflector_beam_charge"


## 前搖開始：鎖定朝向與光束範圍（從身體中心起算，貼身的玩家也打得到；碰到牆就停）；
## 判定形狀要在出招前兩個物理幀以上設好（hitbox.gd）
func start_telegraph() -> void:
	super()
	var x0 := 0.0
	var mid := -(tn.beam_band.x + tn.beam_band.y) / 2.0
	var length: float = size.x / 2.0 + tn.reflector_range  # 反光面前緣往前 reflector_range
	var from := global_position + Vector2(x0, mid)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(facing * length, 0), L.WORLD)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		length = absf(hit.position.x - from.x)
	var top := -tn.beam_band.y
	var h: float = tn.beam_band.y - tn.beam_band.x
	beam_rect = Rect2(x0 if facing > 0 else x0 - length, top, length, h)
	hitbox.configure(beam_rect.size, beam_rect.get_center(), L.PLAYER_HURT)


func _attack(_delta: float) -> void:
	if state_time >= tn.reflector_beam_time:
		_end_attack()


func _end_attack() -> void:
	super()
	hitbox.configure(size * 1.1, Vector2(0, -size.y / 2.0), L.PLAYER_HURT)


func _on_hurt(amount: int, source: Node, kind: StringName) -> void:
	if is_instance_valid(source) and source is Node2D and blocks(source.global_position):
		if kind == &"dart" and state == State.TELEGRAPH and interrupt_cooldown_left <= 0.0:
			interrupt_cooldown_left = tn.dart_interrupt_cooldown  # 射中光點：打斷（同 enemy.gd，但不扣血）
			stagger_time = tn.dart_stagger_time
			_enter(State.STAGGER)
			interrupted.emit(self)
			return
		spark_left = 0.15
		thudded.emit()
		return
	super(amount, source, kind)


func _draw() -> void:
	super()
	if not portrait_drawn:
		_draw_placeholder()
	if state == State.TELEGRAPH:  # 光點由暗到亮（佔位與骨架都畫）
		var k := clampf(state_time / tn.reflector_telegraph, 0.0, 1.0)
		draw_circle(glow_at, 6.0 + 10.0 * k, Color(1, 1, 1, 0.3 + 0.7 * k))


## 佔位外觀（沒有骨架時，例如沒有場景的測試房間）：身體由 enemy.gd 畫，這裡畫反光板、光束、火花
func _draw_placeholder() -> void:
	var px := facing * (size.x / 2.0 - 12.0)
	var y := -size.y * 0.85  # 胸前
	if state == State.TELEGRAPH or state == State.ATTACK:
		y = -size.y - 30.0  # 舉起
	elif state == State.RECOVER or state == State.STAGGER or turn_left > 0.0:
		y = -size.y * 0.5  # 放下
	var plate := Rect2(px - 12.0, y, 24.0, 90.0)
	draw_rect(plate, PLATE)
	draw_rect(plate, Color(0.1, 0.2, 0.3), false, 3.0)
	glow_at = plate.get_center()
	if state == State.ATTACK:
		draw_rect(beam_rect, Color(1.0, 0.82, 0.35, 0.85))
		draw_rect(beam_rect.grow_individual(0, -beam_rect.size.y * 0.3, 0, -beam_rect.size.y * 0.3), Color(1, 1, 1, 0.95))
	if spark_left > 0.0:
		var c := plate.get_center() + Vector2(facing * 14.0, 0)
		for a in [0.0, PI / 2.0, PI / 4.0, -PI / 4.0]:
			var v := Vector2.from_angle(a) * 14.0
			draw_line(c - v, c + v, Color(1, 1, 0.8), 3.0)
