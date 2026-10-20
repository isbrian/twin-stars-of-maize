extends Node2D
# 彈跳物（假光結晶）：懸空、站不上去、碰到不傷人；只會被攻擊判定打中，供下劈彈跳（B8）。

const Hurtbox := preload("res://core/combat/hurtbox.gd")
const L := preload("res://core/combat/layers.gd")
const SIZE := Vector2(70, 70)

var texture: Texture2D = preload("res://art/prop/prop_pogo_crystal.png")  # MV-ASSET-017 C-01

var flash_left := 0.0


func _ready() -> void:
	var hb := Hurtbox.new()
	hb.setup(SIZE, Vector2.ZERO, L.POGO)
	hb.hurt.connect(_on_hit)
	add_child(hb)


func _on_hit(_amount: int, _source: Node, _kind: StringName) -> void:
	flash_left = 0.1


func _process(delta: float) -> void:
	flash_left = maxf(flash_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	draw_texture(texture, -texture.get_size() / 2.0, Color(1.8, 1.8, 1.8) if flash_left > 0.0 else Color.WHITE)  # 打中時亮一下
