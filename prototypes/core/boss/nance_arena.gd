extends Node2D
# 樹下區（MV-PROTO-003 規格書第 4 節、計畫 D8）：樹下篝火 → 約 5 秒的走廊 → nance 樹場地（第 1 段，單一畫面）。
# 樹冠是 Boss 平時停留處（近戰搆不到）；低枝是單跳上得去的單向平台。角色進場後入口關上。

const Terrain := preload("res://boss/terrain.gd")

const GROUND_Y := 900.0
const REST := Vector2(300, GROUND_Y)
const LEFT := 4800.0  # 篝火到入口 4500 px＝跑速 900 約 5 秒
const RIGHT := 6720.0  # 場地寬 1920（單一畫面）
const ENTRY_X := LEFT + 150.0  # 角色越過這裡 → 入口關上
const TREE_X := 5760.0
const CANOPY := Vector2(5760, GROUND_Y - 800)  # Boss 腳底；高於近戰最高點 400＋180＋210＝790
const BRANCH := Rect2(5840, GROUND_Y - 260, 420, 30)
const PERCH := Vector2(6050, GROUND_Y - 260)  # 吃果子時 Boss 的腳底
const GATE := Rect2(LEFT, GROUND_Y - 960, 40, 960)
const VIEW := Rect2(LEFT, GROUND_Y - 960, 1920, 1080)
const REGION := Rect2(-100, GROUND_Y - 960, RIGHT + 100, 1080)
const SOLIDS := [
	Rect2(-100, GROUND_Y, RIGHT + 100, 400),  # 地面
	Rect2(-200, GROUND_Y - 960, 100, 1360),  # 左牆
	Rect2(RIGHT, GROUND_Y - 960, 100, 1360),  # 右牆
]

var gate_closed := false
var _gate: CollisionShape2D


func _ready() -> void:
	for r in SOLIDS:
		Terrain.add_solid(self, r)
	Terrain.add_solid(self, BRANCH, true)
	_gate = Terrain.add_solid(self, GATE)
	open_gate()


func close_gate() -> void:
	gate_closed = true
	_gate.set_deferred("disabled", false)
	queue_redraw()


func open_gate() -> void:
	gate_closed = false
	_gate.set_deferred("disabled", true)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(TREE_X - 40, CANOPY.y + 60, 80, GROUND_Y - CANOPY.y - 60), Color(0.3, 0.22, 0.15))  # 樹幹
	draw_circle(CANOPY + Vector2(0, 40), 260.0, Color(0.2, 0.35, 0.2, 0.85))  # 樹冠
	draw_rect(BRANCH, Color(0.38, 0.28, 0.18))
	for r in SOLIDS:
		draw_rect(r, Terrain.GROUND_COLOR)
	Terrain.draw_bonfire(self, REST)
	if gate_closed:
		draw_rect(GATE, Color(0.3, 0.3, 0.32))
