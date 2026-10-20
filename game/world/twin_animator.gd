extends Node
# 玩家狀態 → 雙胞胎骨架的動作（MV-SLICE-001b2a）。掛在玩家底下，每個物理幀（在玩家之後）：只顯示場上那位、
# 換武器圖、斷臂、面向翻轉，再依 choose() 擺姿勢；吹射在主動作之後覆寫頭與雙臂（SLICE-b2a-7）。
# 不改玩家的任何狀態：手感與判定照舊（SLICE-b4）。

const RigView := preload("res://world/rig_view.gd")
const Tint := preload("res://world/tint.gd")
const Player := preload("res://core/player/player.gd")
const Weapons := preload("res://core/player/weapons.gd")
const CHARS := ["hunahpu", "xbalanque"]  # 依 twin_index
const DART_TIME := 0.6  # 最後一發後頭與雙臂指向瞄準方向的時間（Brian 試玩 2026-10-11：0.3 秒時手動連射手臂上下跳）
const MOVING := 10.0  # 水平速度超過這個值算在跑
const GROUND_SHORTS := ["land", "swap_in", "interact", "tool_cast"]  # 地面短動作：移動、離地、攻擊等任何動作都打斷

var player
var rigs: Array = []  # [胡納普, 希巴拉克]
var clock := 0.0  # 循環動作（待機、跑、下落）的時間
var short := ""  # 播放中的短動作（land、swap_in、interact、tool_cast、double_jump）
var short_t := 0.0
var dart_left := 0.0
var dart_aim := Vector2.RIGHT  # 骨架座標：(1, 0)＝前
var _was_floor := true


## 在玩家底下建兩副骨架（畫在玩家後面：程式畫的訊號在上面）與 animator
static func attach(p) -> Node:
	var a = new()
	a.name = "TwinAnimator"
	a.player = p
	for c in CHARS:
		var r := RigView.new()
		r.name = "Rig_" + c
		r.show_behind_parent = true
		p.add_child(r)
		r.build(c)
		a.rigs.append(r)
	p.add_child(a)
	p.swapped.connect(a._on_swapped)
	p.interacted.connect(a._start.bind("interact"))
	p.double_jumped.connect(a._start.bind("double_jump"))
	p.tool_sent.connect(func(_tool): a._start("tool_cast"))
	p.dart_fired.connect(a._on_dart)
	a._apply()
	return a


## 段落時間 0～3：出招 0～1、判定 1～2、收招 2～3，依數值表（F9 改數值後自動同步）。
## 招架沒有出招段：窗口 1～2、收招 2～3
static func attack_time(p) -> float:
	var s: float = p.state_time
	var tn = p.tn
	if p.state == Player.State.PARRY:
		if s < tn.parry_window:
			return 1.0 + s / tn.parry_window
		return 2.0 + minf((s - tn.parry_window) / tn.parry_recovery, 0.999)
	var w: Vector3 = Weapons.timing(p.attack_weapon, tn)
	if s < w.x:
		return s / w.x
	if s < w.x + w.y:
		return 1.0 + (s - w.x) / w.y
	return 2.0 + minf((s - w.x - w.y) / w.z, 0.999)


static func attack_anim(w: int, dir: int) -> String:
	if w == Weapons.Weapon.BALLGEAR:
		return ["parry_side", "parry_up", "ballgear_down"][dir]
	return "attack_%s_%s" % ["axe" if w == Weapons.Weapon.AXE else "stick", ["side", "up", "down"][dir]]


## [動作名, 時間]
func choose(p) -> Array:
	match p.state:
		Player.State.HURT:
			return ["hurt", p.state_time]
		Player.State.ROLL:
			return ["roll", p.state_time]
		Player.State.HEAL:
			return ["heal", p.state_time]
		Player.State.ATTACK:
			return [attack_anim(p.attack_weapon, p.attack_dir), attack_time(p)]
	if p.parry_ring_left > 0.0:
		return ["parry_success", Player.PARRY_RING_TIME - p.parry_ring_left]
	if p.state == Player.State.PARRY:
		return [attack_anim(Weapons.Weapon.BALLGEAR, p.attack_dir), attack_time(p)]
	if short != "" and not _interrupted(p):
		return [short, short_t]
	if p.is_on_floor():
		return ["run" if absf(p.velocity.x) > MOVING else "idle", clock]
	return ["jump_up" if p.velocity.y < 0.0 else "fall", clock]


## 循環動作在時間 prev → now 之間跨過幾個著地格（steps：格號；MV-SLICE-001d1b 腳步）
static func steps_crossed(a: Dictionary, fps: float, prev: float, now: float) -> int:
	var steps: Array = a.get("steps", [])
	if steps.is_empty() or now <= prev:
		return 0
	var length: float = a.get("length", a.frames[-1].t + 1.0 / fps)
	var n := 0
	for i in steps:
		var ts: float = a.frames[i].t
		# 落在 (prev, now] 的 ts + k × length 有幾個
		n += int(floor((now - ts) / length)) - int(floor((prev - ts) / length))
	return n


## 播到著地格就放一步；依兄弟與腳下地面（Audio.floor_at）
static func play_steps(char_name: String, a: Dictionary, fps: float, prev: float, now: float, at: Vector2) -> void:
	if steps_crossed(a, fps, prev, now) > 0:
		Audio.play(Audio.step_id(char_name, Audio.floor_at(at)))


func _start(n: String) -> void:
	short = n
	short_t = 0.0


func _on_swapped() -> void:
	_start("swap_in")
	dart_left = 0.0  # 新上場的人不接著舉吹管


## 至少蓋到下一發可以射的時候（再多 2 幀）：射速調得比 DART_TIME 慢時，連射的手臂也不在兩發之間閃回主動作
func _on_dart() -> void:
	dart_left = maxf(DART_TIME, player.tn.dart_interval + 2.0 / Engine.physics_ticks_per_second)
	var aim: Vector2 = player.intent.aim if player.intent.aim != Vector2.ZERO else Vector2(player.facing, 0)
	dart_aim = Vector2(aim.x * player.facing, aim.y)


## 短動作只在自由狀態播；地面的被移動、離地打斷，二段跳到落地為止
func _interrupted(p) -> bool:
	if p.state != Player.State.FREE:
		return true
	if short in GROUND_SHORTS:
		return not p.is_on_floor() or p.intent.move_x != 0.0 or absf(p.velocity.x) > MOVING
	return p.is_on_floor()


func _physics_process(delta: float) -> void:
	var p = player
	clock += delta
	if choose(p)[0] == "run":  # 腳步：只在地面跑步（翻滾、硬直、空中都不是 run）
		var data := RigView.anims_at(rigs[p.twin_index].anims_path)
		play_steps(CHARS[p.twin_index], data.anims.run, data.fps, clock - delta, clock, p.global_position)
	var on_floor: bool = p.is_on_floor()
	if on_floor and not _was_floor and p.state == Player.State.FREE:
		_start("land")
	_was_floor = on_floor
	if short != "":
		short_t += delta
		var data := RigView.anims_at(rigs[p.twin_index].anims_path)
		var a: Dictionary = data.anims[short]
		if short_t >= a.frames[-1].t + 1.0 / data.fps or _interrupted(p):
			short = ""
	dart_left = maxf(dart_left - delta, 0.0) if p.state == Player.State.FREE else 0.0  # 吹射是自由狀態的疊加（規格動作清單）
	_apply()


func _apply() -> void:
	var p = player
	for i in rigs.size():
		rigs[i].visible = i == p.twin_index
	var r = rigs[p.twin_index]
	var t = p.twins[p.twin_index]
	r.scale.x = p.facing
	r.modulate = Tint.of(p)
	r.set_weapon(t.weapon if t.weapon_enabled else -1)
	r.set_arm_visible(not t.arm_broken)
	var c := choose(p)
	r.pose(c[0], c[1])
	r.show_attachment("prop_soup_bowl", p.state == Player.State.HEAL)
	r.show_attachment("wpn_blowgun", false)
	if dart_left > 0.0 and p.state == Player.State.FREE:
		r.overlay_dart(dart_aim)
