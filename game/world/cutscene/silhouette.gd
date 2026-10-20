extends Node2D
# 地面過場的道具圖（MV-SLICE-001c3a 佔位剪影 → MV-SLICE-001c3b 換成 MV-ASSET-020 的正式圖）：夜裡的動物、抓下的尾巴、給老鼠的食物。
# 腳底中央在原點；facing 翻面（圖都面向左，facing −1＝原圖）。動物調成夜色但比場景亮，跑的時候 bounce() 上下彈跳。

const ART := {
	"deer": "res://art/prop/prop_animal_deer.png",
	"rabbit": "res://art/prop/prop_animal_rabbit.png",
	"critter": "res://art/prop/prop_animal_coati.png",  # 長鼻浣熊
	"tail_deer": "res://art/prop/prop_tail_deer.png",
	"tail_rabbit": "res://art/prop/prop_tail_rabbit.png",
	"corn": "res://art/prop/prop_food_corn.png",
	"beans": "res://art/prop/prop_food_beans.png",
	"cacao": "res://art/prop/prop_cacao_bean.png",
}
const ANIMALS := ["deer", "rabbit", "critter"]
const ANIMAL_NIGHT := Color(0.67, 0.7, 0.85)  # 場景夜色 (0.45, 0.5, 0.75) 和白色之間（往白色 40%）：夜裡也認得出是什麼動物
const HOP := {"deer": [18.0, 6.0], "rabbit": [24.0, 10.0], "critter": [10.0, 12.0]}  # 彈跳：幅度 px、一趟跑完跳幾下

var kind := "":
	set(v):
		kind = v
		texture = load(ART[v]) if ART.has(v) else null
		modulate = ANIMAL_NIGHT if v in ANIMALS else Color.WHITE
		queue_redraw()
var texture: Texture2D
var hop := 0.0
var facing := -1:
	set(v):
		facing = v
		scale.x = -v  # 原圖面向左


## 依移動進度 k（0～1）上下彈跳
func bounce(k: float) -> void:
	var h: Array = HOP.get(kind, [0.0, 0.0])
	hop = -h[0] * absf(sin(k * PI * h[1]))
	queue_redraw()


func _draw() -> void:
	if texture == null:
		return
	var sz := texture.get_size()
	draw_texture(texture, Vector2(-sz.x / 2.0, -sz.y + hop))
