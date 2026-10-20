extends Node2D
# 飛鏢：直線飛行；碰到敵人受擊判定 → 扣血（打斷與否由敵人判斷）；碰到木障 → 由木障判斷能否標記；
# 碰到地形或飛滿射程就消失。
# MV-PROTO-003：另查一次 Boss 光源；同一段路徑上光源優先，除非地形比光源更近（計畫 D2）；
# 射線碰到 Boss 身體的邊時，再往身體裡查同一個 Boss 的光源。
# 每幀用射線掃過這一幀要走的整段路徑，射速調再高也不會穿過薄的地形或細的目標。

const Hurtbox := preload("res://combat/hurtbox.gd")
const L := preload("res://combat/layers.gd")
const HALF_LENGTH := 14.0  # 鏢身半長：射線多掃這一段，鏢頭碰到就算
const BODY_LOOKAHEAD := 60.0  # 碰到身體的邊時，往身體裡再查這麼遠的光源：夠到正面的光源（離身體邊 ≤ 60），從背後射不會穿過身體

var tn
var direction := Vector2.RIGHT
var traveled := 0.0
var shooter: Node  # 射手（player.gd）
var marks_barrier := false  # 發射時決定：Xbalanque 的飛鏢能標記木障（計畫 D6）
var can_setup := false  # 發射時決定：Hunahpu 的飛鏢能觸發設局（MV-PROTO-003）


func _ready() -> void:
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	var step: Vector2 = direction * tn.dart_speed * delta  # tn 未標型別，不能用 := 推斷
	var to := global_position + step + direction * HALF_LENGTH
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, to, L.ENEMY_HURT | L.BARRIER | L.WORLD)
	query.collide_with_areas = true
	query.hit_from_inside = true
	var hit := space.intersect_ray(query)
	var lq := PhysicsRayQueryParameters2D.create(global_position, to, L.LIGHT)
	lq.collide_with_areas = true
	lq.collide_with_bodies = false
	lq.hit_from_inside = true
	var light_hit := space.intersect_ray(lq)
	if light_hit.is_empty() and not hit.is_empty() and hit.collider is Hurtbox:
		lq.to = to + direction * BODY_LOOKAHEAD
		light_hit = space.intersect_ray(lq)
		if not light_hit.is_empty() and not _same_owner(light_hit.collider, hit.collider):
			light_hit = {}
	if not light_hit.is_empty():
		var wall_first: bool = not hit.is_empty() and not (hit.collider is Hurtbox) \
			and global_position.distance_to(hit.position) < global_position.distance_to(light_hit.position)
		if not wall_first:
			light_hit.collider.receive(tn.dart_damage, self, &"dart")
			queue_free()
			return
	if not hit.is_empty():
		if hit.collider is Hurtbox:
			hit.collider.receive(tn.dart_damage, self, &"dart")
		queue_free()
		return
	position += step
	traveled += step.length()
	if traveled >= tn.dart_range:
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-HALF_LENGTH, -2, HALF_LENGTH * 2.0, 4), Color(0.95, 0.9, 0.7))


## 光源與受擊框屬於同一個 Boss（光源是受擊框的子節點，或兩者同一個父節點）
func _same_owner(light: Node, body: Node) -> bool:
	return light.get_parent() == body or light.get_parent() == body.get_parent()
