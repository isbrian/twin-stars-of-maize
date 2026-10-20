extends Control
# 按鍵提示（MV-SLICE-001a 規格 SLICE-a7）：第一次需要時出現在畫面下方，依最後使用的裝置顯示手把或鍵盤的按鍵，
# 做到就消失並記進 GameState.hints_seen（會存檔）。同時只顯示一個，其餘排隊。

## 提示 id → [鍵盤, 手把]
const TEXT := {
	"move": ["A／D 或 ←／→ 移動", "左搖桿 移動"],
	"jump": ["Space 跳躍", "A 跳躍"],
	"dart": ["滑鼠右鍵 吹箭", "RT 吹箭（搖桿瞄準）"],
	"attack": ["滑鼠左鍵 攻擊", "X 攻擊"],
	"swap": ["Tab 換人", "Y 換人"],
	"interact": ["E 互動", "十字鍵下 互動"],
	"equip": ["Esc → 裝備 換武器", "Start → 裝備 換武器"],
	"skill": ["Q 老鼠鑽地突襲", "十字鍵左 老鼠鑽地突襲"],
	"heal": ["R 治療", "十字鍵上 治療"],
	"pogo": ["空中 S＋攻擊 下劈（打中會彈起）", "空中左搖桿下＋攻擊 下劈（打中會彈起）"],  # MV-SLICE-001c4a
}

var gs
var current := ""
var _queue: Array = []


func request(id: String) -> void:
	if gs.hints_seen.get(id, false) or id == current or _queue.has(id):
		return
	if current == "":
		current = id
	else:
		_queue.append(id)
	queue_redraw()


## 房間的提示區（MV-SLICE-001c4a）：插到最前面立刻顯示，原本顯示中的放回佇列最前面
func request_now(id: String) -> void:
	if gs.hints_seen.get(id, false) or id == current:
		return
	_queue.erase(id)
	if current != "":
		_queue.push_front(current)
	current = id
	queue_redraw()


func satisfy(id: String) -> void:
	gs.hints_seen[id] = true
	_queue.erase(id)
	if current == id:
		current = ""
		while not _queue.is_empty() and current == "":
			var next: String = _queue.pop_front()
			if not gs.hints_seen.get(next, false):
				current = next
	queue_redraw()


func text_for(id: String) -> String:
	if not TEXT.has(id):
		return ""
	return TEXT[id][0 if InputSetup.uses_mouse() else 1]


func _process(_delta: float) -> void:
	queue_redraw()  # 裝置切換時跟著換字


func _draw() -> void:
	if current == "":
		return
	var t := text_for(current)
	var w := 640.0
	var at := Vector2((size.x - w) / 2.0, size.y - 120)
	draw_rect(Rect2(at, Vector2(w, 56)), Color(0, 0, 0, 0.6))
	draw_string(ThemeDB.fallback_font, at + Vector2(0, 38), t, HORIZONTAL_ALIGNMENT_CENTER, w, 28, Color.WHITE)
