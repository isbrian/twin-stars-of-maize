extends Area2D
# 碰到就撿的東西（MV-SLICE-001a）：藏點的可可豆。MV-SLICE-001b1：畫 3 顆可可豆疊成一小堆。

const L := preload("res://core/combat/layers.gd")

signal touched

var texture: Texture2D = preload("res://art/prop/prop_cacao_bean.png")
var fragment := false  # 血量碎片（MV-SLICE-001c4a）：加入場景前設定；用 MV-ASSET-017 C-02 的圖


func _ready() -> void:
	collision_layer = 0
	collision_mask = L.PLAYER_BODY
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(60, 60)
	cs.shape = shape
	cs.position = Vector2(0, -30)
	add_child(cs)
	body_entered.connect(func(_b):
		Audio.play(&"pick_fragment" if fragment else &"pick_cacao")  # MV-SLICE-001d1b
		touched.emit())
	if fragment:
		texture = preload("res://art/prop/prop_health_fragment.png")


func _draw() -> void:
	if fragment:
		draw_texture(texture, Vector2(-texture.get_width() / 2.0, -texture.get_height() - 6.0))
		return
	var sz := texture.get_size()
	for at in [Vector2(-sz.x * 0.95, -sz.y), Vector2(-sz.x * 0.05, -sz.y), Vector2(-sz.x * 0.5, -sz.y * 1.7)]:
		draw_texture(texture, at)
