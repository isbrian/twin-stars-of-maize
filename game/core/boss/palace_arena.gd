extends Node2D
# 宮殿區（MV-PROTO-003 規格書第 4 節、計畫 D8、D9）：小路 → 宮殿篝火 → 約 5 秒的走廊 → 宮殿（第 2、3 段，單一畫面）→ 出口。
# 入口在左（老夫婦）、金銀寶座在右；出口的木障就是宮殿右牆，後面是走廊與 550 px 高台，頂端是出口。

const Terrain := preload("res://core/boss/terrain.gd")
const SceneryView := preload("res://world/scenery_view.gd")
const GATE_TEX := "res://art/prop/prop_arena_gate.png"
const Barrier := preload("res://core/level/barrier.gd")

const GROUND_Y := 900.0
const PATH_START := Vector2(8000, GROUND_Y)
const REST := Vector2(9500, GROUND_Y)
const LEFT := 14000.0
const RIGHT := 15920.0
const ENTRY_X := LEFT + 150.0
const HOME := Vector2(15300, GROUND_Y)  # 第 2、3 段 Boss 的起始位置
const PLATFORMS := [Rect2(14300, GROUND_Y - 260, 320, 30), Rect2(15150, GROUND_Y - 260, 320, 30)]
const THRONE_X := RIGHT - 140.0  # 撞寶座的終點
const COUPLE_X := LEFT + 120.0
const BARRIER := Rect2(RIGHT - 60, GROUND_Y - 960, 60, 960)
const EXIT_LEDGE := Rect2(16320, GROUND_Y - 550, 700, 950)  # 接到右牆，不留會掉進去的縫
const EXIT_RIGHT := 17020.0
const GATE := Rect2(LEFT, GROUND_Y - 960, 40, 960)
const VIEW := Rect2(LEFT, GROUND_Y - 960, 1920, 1080)
const EXIT_VIEW := Rect2(LEFT, GROUND_Y - 960, EXIT_RIGHT - LEFT, 1080)
const REGION := Rect2(7800, GROUND_Y - 960, RIGHT - 7800, 1080)
const SOLIDS := [
	Rect2(7800, GROUND_Y, EXIT_RIGHT - 7800, 400),  # 地面
	Rect2(7700, GROUND_Y - 960, 100, 1360),  # 左牆
	Rect2(EXIT_RIGHT, GROUND_Y - 960, 100, 1360),  # 右牆
	EXIT_LEDGE,
]

var gate_closed := false
var art := false  # true：地形、篝火、寶座等由場景素材呈現，_draw 不畫
var gate_art: Node2D  # 閘門素材（use_art 之後才有）
var couple_static := false  # 老夫婦站在入口端（第一次走完小路之後）
var draw_couple := true  # MV-SLICE-001b1：false＝老夫婦由 boss_fight 的立繪顯示
var barrier
var _gate: CollisionShape2D


func _ready() -> void:
	for r in SOLIDS:
		Terrain.add_solid(self, r)
	for r in PLATFORMS:
		Terrain.add_solid(self, r, true)
	_gate = Terrain.add_solid(self, GATE)
	open_gate()
	barrier = Barrier.new()
	barrier.setup(BARRIER)
	add_child(barrier)


func close_gate() -> void:
	gate_closed = true
	_gate.set_deferred("disabled", false)
	if gate_art != null:
		gate_art.visible = true
	queue_redraw()


func open_gate() -> void:
	gate_closed = false
	_gate.set_deferred("disabled", true)
	if gate_art != null:
		gate_art.visible = false
	queue_redraw()


## 反光柱（計畫 D16）：第一道在角色位置，其餘 count−1 道平均分布在場地內
static func pillar_xs(count: int, player_x: float) -> Array:
	var xs := [player_x]
	for i in range(1, count):
		xs.append(LEFT + 1920.0 * i / count)
	return xs


## 站上出口高台頂端
static func on_exit(p: Vector2) -> bool:
	return p.x >= EXIT_LEDGE.position.x and p.y <= EXIT_LEDGE.position.y + 2.0


## 垂直切片模式（MV-SLICE-001b1 Task 6）：地形改由場景素材呈現，這裡只留閘門的素材（關上時顯示）
func use_art() -> void:
	art = true
	gate_art = Node2D.new()
	gate_art.name = "GateArt"
	add_child(gate_art)
	SceneryView.fill_vertical(gate_art, load(GATE_TEX), GATE)
	gate_art.visible = gate_closed
	barrier.art = true  # 障壁素材掛在障壁底下，破了（障壁隱藏）就跟著消失
	var b := Node2D.new()
	b.name = "Art"
	barrier.add_child(b)
	SceneryView.fill_vertical(b, load("res://art/prop/prop_palace_barrier.png"), Rect2(-BARRIER.size / 2.0, BARRIER.size))
	barrier.queue_redraw()
	queue_redraw()


func _draw() -> void:
	if art:
		return
	for r in SOLIDS + PLATFORMS:
		draw_rect(r, Terrain.GROUND_COLOR)
	Terrain.draw_bonfire(self, REST)
	draw_rect(Rect2(THRONE_X - 80, GROUND_Y - 300, 80, 300), Color(0.85, 0.72, 0.3))  # 金銀寶座
	draw_rect(Rect2(THRONE_X, GROUND_Y - 300, 80, 300), Color(0.75, 0.78, 0.82))
	draw_rect(Rect2(THRONE_X - 160, GROUND_Y - 230, 50, 230), Color(0.12, 0.1, 0.12, 0.8))  # Chimalmat（背景剪影）
	if couple_static and draw_couple:
		draw_rect(Rect2(COUPLE_X - 70, GROUND_Y - 150, 50, 150), Color(0.6, 0.6, 0.6))  # 兩位老人（灰盒）
		draw_rect(Rect2(COUPLE_X, GROUND_Y - 130, 50, 130), Color(0.55, 0.55, 0.55))
	draw_rect(Rect2(EXIT_LEDGE.position.x + 260, EXIT_LEDGE.position.y - 160, 80, 160), Color(0.95, 0.85, 0.55, 0.5))  # 出口
	if gate_closed:
		draw_rect(GATE, Color(0.3, 0.3, 0.32))
