extends Node2D
# 飄起來的數字（MV-SLICE-001a）：例如「+2」可可豆，0.8 秒後消失。MV-SLICE-001b1：數字前畫可可豆圖示。

var text := ""
var icon: Texture2D = preload("res://art/ui/ui_icon_cacao.png")
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	position.y -= 60.0 * delta
	modulate.a = 1.0 - _t / 0.8
	queue_redraw()
	if _t >= 0.8:
		queue_free()


func _draw() -> void:
	draw_texture(icon, Vector2(-icon.get_width() - 22, -icon.get_height() + 4))
	draw_string(ThemeDB.fallback_font, Vector2(-20, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.85, 0.4))
