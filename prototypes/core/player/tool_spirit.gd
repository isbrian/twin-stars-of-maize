extends Node2D
# Xbalanque 的工具（MV-PROTO-002 規格書第 6 節）：飛向被標記的木障 → 砍幾下 → 木障碎掉 → 飛回角色身上消失。
# 工具只對木障有效，不打敵人；工具在外時換人，照樣把工作做完。

signal chopped

enum S { OUT, CHOP, BACK }

const OFFSET := Vector2(0, -90)  # 出發與飛回的位置：角色胸口

var tn
var player: Node
var barrier: Node
var s := S.OUT
var t := 0.0
var chops_done := 0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return
	match s:
		S.OUT:
			if not is_instance_valid(barrier):
				s = S.BACK
			elif _fly_to(barrier.global_position, delta, 12.0):
				s = S.CHOP
		S.CHOP:
			t += delta
			var due := mini(floori(t / (tn.tool_chop_time / tn.tool_chops)), tn.tool_chops)
			while chops_done < due:
				chops_done += 1
				chopped.emit()
			if t >= tn.tool_chop_time:
				if is_instance_valid(barrier):
					barrier.break_apart()
				s = S.BACK
		S.BACK:
			if _fly_to(player.global_position + OFFSET, delta, 24.0):
				queue_free()
	queue_redraw()


## 以固定速度飛向 target；距離小於 arrive 時回傳 true
func _fly_to(target: Vector2, delta: float, arrive: float) -> bool:
	global_position = global_position.move_toward(target, tn.tool_speed * delta)
	return global_position.distance_to(target) < arrive


func _draw() -> void:
	var swing := sin(t * 40.0) * 0.6 if s == S.CHOP else 0.0
	draw_set_transform(Vector2.ZERO, swing)
	draw_rect(Rect2(-4, -22, 8, 44), Color(0.55, 0.4, 0.25))  # 柄
	draw_rect(Rect2(4, -22, 18, 16), Color(0.7, 0.72, 0.75))  # 石刃
