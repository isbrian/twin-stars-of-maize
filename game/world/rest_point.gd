extends Node2D
# 休息點（篝火、祖母家；MV-SLICE-001a 規格 SLICE-a10）：站在附近按互動鍵休息。MV-SLICE-001b1：畫點燃的篝火。
# Boss 段落的兩個篝火也用這個（Task 11）。

const REACH := Vector2(140, 80)  # 角色腳底與休息點的水平、垂直距離上限

var texture: Texture2D = preload("res://art/prop/prop_bonfire_lit.png")


func near(who: Node2D) -> bool:
	var d := who.global_position - global_position
	return absf(d.x) <= REACH.x and absf(d.y) <= REACH.y


func _draw() -> void:
	var sz := texture.get_size()
	draw_texture(texture, Vector2(-sz.x / 2.0, -sz.y))
