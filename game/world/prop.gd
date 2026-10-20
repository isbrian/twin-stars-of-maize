extends Node2D
# 事件用的道具（MV-SLICE-001a Task 10）：灌木（只吃斧頭）、土塊（只吃掘棒）、老鼠、網子、球具（落下中）。
# MV-SLICE-001b1：畫各自的素材（腳底中央在原點）。老鼠在 MV-SLICE-001b2b2 換成骨架（有移動播 run、沒移動播 idle）。

const L := preload("res://core/combat/layers.gd")
const Hurtbox := preload("res://core/combat/hurtbox.gd")
const Weapons := preload("res://core/player/weapons.gd")
const NpcAnimator := preload("res://world/npc_animator.gd")

signal cleared(prop: Node)

var kind := ""
var decor := false  # 只供演出或背景的灌木、土塊：不建受擊框（MV-SLICE-001c3a）
var hurtbox: Hurtbox
var texture: Texture2D
var _last_x := 0.0
var _anim  # 老鼠的 npc_animator.gd
var _still := 0.0  # 老鼠連續沒移動的秒數
const STILL_IDLE := 0.15  # 被追時事件每約 11 幀會停 1 幀；停這麼久才算待著，run 才不會一直從頭播


func _ready() -> void:
	texture = _texture_for(kind)
	_last_x = position.x
	if kind == "rat":
		_anim = NpcAnimator.attach(self, "rat")
	if (kind == "bush" or kind == "clod") and not decor:
		hurtbox = Hurtbox.new()
		hurtbox.setup(Vector2(120, 140), Vector2(0, -70), L.ENEMY_HURT)
		hurtbox.hurt.connect(_on_hurt)
		add_child(hurtbox)


## 近戰、而且是對的工具才清得掉（開墾田地：斧頭砍灌木、掘棒挖土塊）
func _on_hurt(_amount: int, source: Node, k: StringName) -> void:
	if k != &"melee" or source == null:
		return
	var need := Weapons.Weapon.AXE if kind == "bush" else Weapons.Weapon.STICK
	if source.get("attack_weapon") == need:
		cleared.emit(self)
		queue_free()


## 依種類的貼圖（MV-SLICE-001b1 Task 4）；老鼠是骨架、沒有貼圖
func _texture_for(k: String) -> Texture2D:
	match k:
		"bush":
			return load("res://art/prop/prop_field_bush.png")
		"clod":
			return load("res://art/prop/prop_field_clod.png")
		"net":
			return load("res://art/prop/prop_net.png")
		"gear":
			return load("res://art/prop/wpn_ballgear_yoke.png")
	return null


## 老鼠被網子罩住：立刻待著（文字卡可能接著暫停遊戲，不能等 STILL_IDLE）
func rest() -> void:
	if _anim != null:
		_still = STILL_IDLE
		_last_x = position.x  # 同一幀事件先移動牠再罩網：這一格的位移不算
		_anim.play("idle")


## 老鼠：事件在物理幀移動牠；有移動就 run、面向移動方向，連續 STILL_IDLE 秒沒移動才 idle
func _physics_process(delta: float) -> void:
	if _anim == null:
		return
	var dx := position.x - _last_x
	_last_x = position.x
	if absf(dx) > 0.5:
		_still = 0.0
		_anim.facing = 1 if dx > 0.0 else -1
		_anim.play("run")
	else:
		_still += delta
		if _still >= STILL_IDLE:
			_anim.play("idle")


## 腳底中央在原點
func _draw() -> void:
	if texture == null:
		return
	var sz := texture.get_size()
	draw_texture(texture, Vector2(-sz.x / 2.0, -sz.y))
