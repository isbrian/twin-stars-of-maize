extends Node
# 吹箭：射速限制、自由瞄準；沒瞄準時朝面向（B3、B3-1）。只負責發射，飛行與命中在 dart.gd。

const Dart := preload("res://player/dart.gd")
const Intent := preload("res://player/intent.gd")

var player  # 擁有者 player.gd（不標型別，避免互相預載）
var cooldown_left := 0.0


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


## 發射一發；射速冷卻中回傳 null。飛鏢加到角色的父節點（不跟著角色移動）
func try_fire(aim: Vector2) -> Node:
	if cooldown_left > 0.0:
		return null
	cooldown_left = player.tn.dart_interval
	var d := Dart.new()
	d.tn = player.tn
	d.shooter = player
	d.marks_barrier = player.twin().can_send_tool and player.abilities_enabled
	d.can_setup = player.twin().can_trigger_setup
	d.direction = aim.normalized() if aim != Vector2.ZERO else Vector2(player.facing, 0)
	player.get_parent().add_child(d)
	d.global_position = player.global_position + Intent.MUZZLE
	return d
