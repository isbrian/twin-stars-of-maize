extends Node2D
# 撿東西的地點（MV-SLICE-001a Task 10）：斧頭、掘棒、球具；站在旁邊按互動鍵撿。灰盒色塊。

const REACH := Vector2(120, 80)
const TEX := {"axe": "res://art/prop/wpn_axe.png", "stick": "res://art/prop/wpn_digging_stick.png", "gear": "res://art/prop/wpn_ballgear_yoke.png"}

var id := ""
var item := ""  # "axe"｜"stick"｜"gear"
var texture: Texture2D


func _ready() -> void:
	texture = load(TEX[item]) if TEX.has(item) else null


func near(who: Node2D) -> bool:
	var d := who.global_position - global_position
	return absf(d.x) <= REACH.x and absf(d.y) <= REACH.y


## 武器平放在地上（MV-SLICE-001b1），上方一個「!」提示可以撿
func _draw() -> void:
	if texture == null:
		return
	var sz := texture.get_size()
	draw_texture(texture, Vector2(-sz.x / 2.0, -sz.y))
	draw_string(ThemeDB.fallback_font, Vector2(-8, -sz.y - 14), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.9, 0.5))
