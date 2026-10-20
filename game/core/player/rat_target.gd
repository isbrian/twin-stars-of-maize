extends RefCounted
# 鑽地突襲的找目標（MV-SLICE-001a 規格 SLICE-a3）：面前、距離內、腳底和角色同高（＝地面敵人）的最近一隻。
# 位置一律是腳底（core 慣例）。飛行型懸停在空中、Seven Macaw 在樹上時，腳底不在地面高度，不會被選中。


static func pick(origin: Vector2, facing: int, candidates: Array, reach: float, max_dy: float) -> Node:
	var best: Node = null
	var best_dx := INF
	for c in candidates:
		if not is_instance_valid(c) or not c.is_inside_tree():
			continue
		var h = c.get("health")
		if h != null and h.is_dead():
			continue
		var d: Vector2 = c.global_position - origin
		if d.x * facing < 0.0 or absf(d.x) > reach or absf(d.y) > max_dy:
			continue
		if absf(d.x) < best_dx:
			best = c
			best_dx = absf(d.x)
	return best
