extends RefCounted
# 場景主題表（MV-SLICE-001b1 規格「主題與房間」、SLICE-b5）：每種主題的四層圖與視差倍率。
# 房間資料只寫 theme（與 variant）；scenery_view.gd 依這張表組出圖層。

const PARALLAX := {"far": 0.2, "mid": 0.6, "ground": 1.0, "fore": 1.15}
const ORDER := ["far", "mid", "ground", "fore"]
const BG := "res://art/bg/%s.png"
const GROUND_TOP_ROW := 109  # bg_forest_ground_tile.png 第一列超過一半不透明的列＝地面上緣（量自 import_art 的輸出）
const GROUND_BOTTOM_ROW := 247  # 地表條最後一列不透明的列（底部 22 列是透明的）
const EARTH := Color8(55, 28, 27)  # 地表條下方的補色（地表條底部的土色）
const FOREST_MIDS := ["bg_forest_mid_01", "bg_forest_mid_02", "bg_forest_mid_03"]

# Boss 段落（規格「主題與房間」的 boss 三列）：nance 樹與宮殿後牆的視差是 1.0（上面有要對齊碰撞的東西）
const BOSS := {
	"far": "bg_forest_far_01",
	"nance": "bg_nance_mid_01",
	"path_mid": "bg_forest_mid_02",
	"palace": "bg_palace_back_01",
	"fore": "bg_forest_fore_01",
}
const NANCE_TRUNK_X := 835.0  # bg_nance_mid_01.png 樹幹中心（第 650～700 列的樹幹顏色範圍，量自 import_art 的輸出）
const PALACE_FLOOR_ROW := 961  # bg_palace_back_01.png 地板輪廓線（下半部第一列整列亮度 < 0.15）
const DARKNESS := [1.0, 0.75, 0.5, 0.3]  # Boss 段落每拔掉一個光源的灰階倍率
# MV-ASSET-015（量自 import_art 的輸出）
const NANCE_BRANCH_BODY := Vector2(70, 48)  # prop_nance_branch.png：可站的枝幹從第 70 欄開始（左邊是接樹幹的粗端），上緣在第 40～55 列，取 48

const THEMES := {
	"home": {"far": "bg_forest_far_01", "mid": "bg_home_mid_01", "ground": "bg_forest_ground_tile", "fore": ""},
	"field": {"far": "bg_forest_far_01", "mid": "bg_field_mid_01", "ground": "bg_forest_ground_tile", "fore": ""},
	"yard": {"far": "bg_ballcourt_far_01", "mid": "bg_yard_mid_01", "ground": "bg_forest_ground_tile", "fore": ""},
	"forest": {"far": "bg_forest_far_01", "mid": "", "ground": "bg_forest_ground_tile", "fore": "bg_forest_fore_01"},
}


## 圖層名 → res:// 路徑（沒有這層時 ""）；森林的中景依 variant 輪流用三張
static func layers(theme: String, variant := 0) -> Dictionary:
	var out := {}
	var t: Dictionary = THEMES.get(theme, {})
	for k in ORDER:
		var n: String = t.get(k, "")
		if k == "mid" and theme == "forest":
			n = FOREST_MIDS[variant % FOREST_MIDS.size()]
		out[k] = "" if n == "" else BG % n
	return out


static func themes() -> Array:
	return THEMES.keys()
