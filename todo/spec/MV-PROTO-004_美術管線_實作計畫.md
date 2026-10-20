# MV-PROTO-004 美術管線 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `prototypes/p4-art-pipeline/` 用第 0 批 Hunahpu 分件組出可在編輯器微調的 Skeleton2D 角色（三個動作），量出分件一致性，輸出 180 px 仿戰鬥截圖與灰階版，交給 Brian 檢查。

**Architecture:** 關節對照表（JSON，基準圖像素座標）是唯一的組裝資料：Python 工具量分件主軸並把點畫回圖上供目視確認；GDScript 的 `rig.gd` 算骨頭靜止姿勢與縮放比例，`build_rig.gd` 產生 `hunahpu.tscn`（Skeleton2D＋Bone2D＋Sprite2D＋AnimationPlayer），`anims.gd` 以全域角度描述動作並換算成區域旋轉；`showcase.gd` 是仿戰鬥展示與一致性對照畫面。

**Tech Stack:** Godot 4.7.2、GDScript；Python 3＋Pillow（只用於量測與標點工具）。

**Spec:** [todo/spec/MV-PROTO-004_美術管線.md](MV-PROTO-004_美術管線.md)

## Global Constraints

- Godot 4.7.2；**不使用 `class_name`**，跨檔引用一律 `preload` 常數。
- 專案在 `prototypes/p4-art-pipeline/`，獨立、可丟棄，不引用 `prototypes/core/` 的任何檔案。
- 素材來源 `assets-test/batch0/art/`，由 `sync_art.sh` 複製到專案的 `art/`；**`art/`、`tools/out/`、`shots/` 不進版控**（AI 素材與其衍生圖只留在本機）。
- 畫面基準 1920×1080、`window/stretch/mode="canvas_items"`；角色縮到約 **180 px** 高；背景 `Color(0.1, 0.12, 0.14)`、地面 `Color(0.22, 0.27, 0.25)`（MV-PROTO-001 戰鬥房配色）。
- 左右約定照工單：`_r`＝近側原色，`_l`＝遠側暗一階。
- 對照表座標一律是 `chr_hunahpu_reference.png` 的像素（y 向下）；Godot 角度 0＝朝右、正值順時針（y 向下時「朝下」＝90°）。
- 一致性：縮放比例偏離中位數超過 **15%** 的分件列入補生成清單（不算測試失敗）。
- 關節不穿幫：以「關節周圍半徑 14 px（基準圖尺度）16 個取樣點，每點至少被相連兩件之一覆蓋（alpha ≥ 0.3）」驗證每個動作的每個關鍵影格（見 Task 5 的裁定說明）。
- Bone2D 一律 `set_autocalculate_length_and_angle(false)`、`bone_angle = 0`、`rest = transform`（不設 rest 會出現 `det == 0` 錯誤，2026-10-02 spike 已驗證）；產生器建好的節點樹存檔後 `free()`。
- **驗證命令**（每個 Task 的「執行測試」都用這組）：

  ```bash
  cd '<repo>/prototypes/p4-art-pipeline'
  godot --headless --fixed-fps 60 --quit-after 3600 --path . -- --self-test > /tmp/p4_selftest.txt 2>&1; rc=$?
  grep -E '^SELFTEST (FAIL|SUMMARY)|SELFTEST   x|CONSISTENCY|SCRIPT ERROR|Parse Error' /tmp/p4_selftest.txt; echo "rc=$rc"
  ```

  通過＝`rc=0`、`SELFTEST SUMMARY pass=N fail=0`、沒有 `SCRIPT ERROR`／`Parse Error`。
- 註解繁體中文；捷徑加 `ponytail:` 註解。分支 `feature/MV-PROTO-004_美術管線`，每個 Task 一個 commit。

## Review Focus

1. **Brian 在編輯器微調 `hunahpu.tscn` 後又執行 `--build-rig`**：不可默默覆蓋手動微調；要 `--force` 才覆蓋 → Task 4 `test_build_does_not_overwrite_hand_edits`
2. **還沒執行 `sync_art.sh`（或少了某個分件檔）就產生場景**：不可產出缺件的場景，要給出清楚訊息 → Task 4 `test_build_refuses_missing_art`
3. **某個分件補生成後尺寸改變、對照表沒重量**：組裝會整個錯位，必須被抓到 → Task 2 `test_rig_part_sizes_match_files`
4. **角色從約 1300 px 縮到 180 px**：沒有 mipmap 會閃爍、鋸齒，誤導可讀性判斷 → Task 1 `test_textures_import_with_mipmaps`
5. **平滑內插時角度跨越 ±180°**：線性內插會繞遠路轉一圈 → Task 5 `test_rotation_keys_are_unwrapped`

---

## 檔案結構

| 檔案 | 責任 | 建立於 |
|---|---|---|
| `project.godot`、`.gitignore`、`main.tscn`、`main.gd` | 專案設定；進入點（`--self-test`、`--build-rig`、`--screenshot`、預設展示） | Task 1（Task 4、6 擴充 main.gd） |
| `sync_art.sh` | 複製素材並匯入 | Task 1 |
| `tests/self_test.gd` | 測試執行器＋全部測試 | Task 1（之後追加） |
| `tools/measure_parts.py`、`tools/mark_points.py` | 量分件主軸；把對照表的點畫回圖上 | Task 2 |
| `rig/hunahpu_rig.json` | 關節對照表（量測資料） | Task 2 |
| `rig/rig.gd` | 讀對照表；骨頭靜止姿勢、縮放比例、一致性 | Task 2（Task 3 擴充） |
| `rig/build_rig.gd` | 產生 `hunahpu.tscn`、覆蓋保護 | Task 4（Task 5 加動作） |
| `rig/anims.gd` | 三個動作、內插切換 | Task 5 |
| `hunahpu.tscn`、`rig/hunahpu.build.md5` | 產生器輸出（進版控；貼圖引用 `res://art/`） | Task 4 |
| `showcase.gd` | 仿戰鬥展示、灰階、一致性對照、截圖 | Task 6 |
| `README.md` | 執行、操作、微調流程、工時、驗收結果 | Task 7 |

---

### Task 1: 專案骨架、素材同步、測試執行器

**Files:**
- Create: `prototypes/p4-art-pipeline/project.godot`、`.gitignore`、`main.tscn`、`main.gd`、`sync_art.sh`
- Test: `prototypes/p4-art-pipeline/tests/self_test.gd`

**Interfaces:**
- Produces：`self_test.gd` 的 `check(cond, msg)`、`frames(n)`、`pass_count`、`fail_count`；常數 `PARTS`（17 個分件名，不含 `.png`）、`WEAPON := "wpn_axe"`、`REFERENCE := "chr_hunahpu_reference"`；`main.gd` 的 `--self-test`

- [ ] **Step 0: 開分支**

```bash
cd '<repo>'
git checkout develop
git checkout -b 'feature/MV-PROTO-004_美術管線'
```

- [ ] **Step 1: 寫專案設定、進入點與測試**

`prototypes/p4-art-pipeline/project.godot`：

```ini
config_version=5

[application]

config/name="MV-PROTO-004 美術管線"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.7")

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]

environment/defaults/default_clear_color=Color(0.1, 0.12, 0.14, 1)
```

`prototypes/p4-art-pipeline/.gitignore`：

```text
.godot/
art/
tools/out/
shots/
```

`prototypes/p4-art-pipeline/main.tscn`：

```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
```

`prototypes/p4-art-pipeline/main.gd`：

```gdscript
extends Node2D
# MV-PROTO-004 美術管線（獨立、可丟棄）。規格：todo/spec/MV-PROTO-004_美術管線.md
# 使用者參數（放在 -- 之後）：
#   --self-test   執行自動測試後結束（結束碼 0＝全部通過）

const SelfTest := preload("res://tests/self_test.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--self-test" in args:
		var t := SelfTest.new()
		add_child(t)
		await t.run()
		get_tree().quit(0 if t.fail_count == 0 else 1)
		return
```

`prototypes/p4-art-pipeline/tests/self_test.gd`：

```gdscript
extends Node
# --self-test：每個 test_ 開頭的方法是一項測試，依名稱排序執行。
# 執行期錯誤時 Godot 只印 SCRIPT ERROR 並繼續，驗證時要另外 grep。

const PARTS := [
	"chr_hunahpu_head", "chr_hunahpu_torso", "chr_hunahpu_loincloth_flap",
	"chr_hunahpu_upperarm_r", "chr_hunahpu_forearm_r", "chr_hunahpu_hand_open_r", "chr_hunahpu_hand_grip_r",
	"chr_hunahpu_upperarm_l", "chr_hunahpu_forearm_l", "chr_hunahpu_hand_open_l", "chr_hunahpu_hand_grip_l",
	"chr_hunahpu_thigh_r", "chr_hunahpu_shin_r", "chr_hunahpu_foot_r",
	"chr_hunahpu_thigh_l", "chr_hunahpu_shin_l", "chr_hunahpu_foot_l",
]
const WEAPON := "wpn_axe"
const REFERENCE := "chr_hunahpu_reference"

var pass_count := 0
var fail_count := 0
var _name := ""
var _failed := false


func run() -> void:
	var names: Array = []
	for m in get_method_list():
		if String(m.name).begins_with("test_"):
			names.append(m.name)
	names.sort()
	for n in names:
		_name = n
		_failed = false
		await call(n)
		if _failed:
			fail_count += 1
		else:
			pass_count += 1
		print("SELFTEST %s %s" % ["FAIL" if _failed else "PASS", n])
	print("SELFTEST SUMMARY pass=%d fail=%d" % [pass_count, fail_count])


func check(cond: bool, msg: String) -> void:
	if not cond:
		_failed = true
		print("SELFTEST   x %s：%s" % [_name, msg])


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# ---- Task 1：素材 ----

func test_art_synced_and_imported() -> void:
	for n in PARTS + [WEAPON, REFERENCE]:
		var p := "res://art/%s.png" % n
		check(FileAccess.file_exists(p), "缺少 %s（先執行 ./sync_art.sh）" % p)
		check(ResourceLoader.exists(p), "%s 沒有匯入" % p)


func test_textures_import_with_mipmaps() -> void:
	var cfg := ConfigFile.new()
	check(cfg.load("res://art/chr_hunahpu_torso.png.import") == OK, "缺少匯入設定 res://art/chr_hunahpu_torso.png.import")
	check(cfg.get_value("params", "mipmaps/generate", false) == true, "分件要產生 mipmap（縮到 180 px 時才不會閃爍）")
```

- [ ] **Step 2: 執行測試，確認失敗**

執行驗證命令。Expected：`SELFTEST FAIL test_art_synced_and_imported`（缺 `res://art/…`）、`SELFTEST FAIL test_textures_import_with_mipmaps`、`SUMMARY pass=0 fail=2`。

- [ ] **Step 3: 素材同步與 mipmap 匯入設定**

在 `project.godot` 的 `[rendering]` 之前加入：

```ini
[importer_defaults]

texture={
"mipmaps/generate": true
}

```

並在 `[rendering]` 區加一行（畫布預設用線性＋mipmap 取樣）：

```ini
textures/canvas_textures/default_texture_filter=3
```

`prototypes/p4-art-pipeline/sync_art.sh`：

```zsh
#!/bin/zsh
# 把第 0 批美術素材複製進專案的 art/ 並匯入（art/ 不進版控，素材只存在本機的 assets-test/）
set -euo pipefail
HERE=${0:a:h}
SRC="$HERE/../../assets-test/batch0/art"
if [[ ! -d "$SRC" ]]; then
  echo "找不到素材資料夾：$SRC" >&2
  exit 1
fi
mkdir -p "$HERE/art"
cp "$SRC"/*.png "$HERE/art/"
godot --headless --path "$HERE" --import
echo "SYNC ok: $(ls "$HERE/art"/*.png | wc -l | tr -d ' ') 個 PNG"
```

```bash
cd '<repo>/prototypes/p4-art-pipeline'
chmod +x sync_art.sh && ./sync_art.sh > /tmp/p4_sync.txt 2>&1; rc=$?; tail -1 /tmp/p4_sync.txt; echo "rc=$rc"
```

Expected：`SYNC ok: 21 個 PNG`、`rc=0`。

- [ ] **Step 4: 執行測試，確認通過**

Expected：2 項 PASS，`SUMMARY pass=2 fail=0`，`rc=0`。若 mipmap 測試仍失敗，刪掉 `art/*.import` 與 `.godot/imported` 後重跑 `./sync_art.sh`（舊的匯入設定不會被預設值覆蓋）。

- [ ] **Step 5: Commit**

```bash
cd '<repo>'
git add prototypes/p4-art-pipeline
git commit -m "Scaffold art pipeline prototype with asset sync (MV-PROTO-004)"
```

---

### Task 2: 量測工具與關節對照表

**Files:**
- Create: `prototypes/p4-art-pipeline/tools/measure_parts.py`、`tools/mark_points.py`、`rig/hunahpu_rig.json`、`rig/rig.gd`
- Test: `tests/self_test.gd`（追加）

**Interfaces:**
- Consumes：`art/*.png`
- Produces：
  - `rig.gd`（RefCounted）：常數 `PATH`、`JOINTS`（21 個關節名）、`BONES`（`[骨頭, 父骨頭, 起點關節, 終點關節]`）；欄位 `joints: Dictionary`（名稱 → Vector2）、`parts: Dictionary`、`ref_size: Vector2`；`load_file(path := PATH) -> Error`；`static v(a: Array) -> Vector2`；`static sprite_name(part: String) -> String`
  - `hunahpu_rig.json` 結構：

    ```json
    {
      "reference": {"size": [1024, 1536], "joints": {"hip": [x, y], "...": [x, y]}},
      "parts": {
        "chr_hunahpu_thigh_r": {"size": [w, h], "bone": "thigh_r", "pivot": [x, y], "tip": [x, y], "z": 2},
        "chr_hunahpu_hand_open_r": {"size": [w, h], "bone": "hand_r", "pivot": [x, y], "tip": [x, y], "z": 2, "visible": false, "scale_from": "chr_hunahpu_forearm_r"},
        "wpn_axe": {"size": [w, h], "bone": "hand_r", "pivot": [x, y], "tip": [x, y], "z": 3, "attach_t": 0.5, "angle_deg": 0}
      }
    }
    ```

- [ ] **Step 1: 寫測試**

在 `tests/self_test.gd` 的 `const REFERENCE := …` 下一行加入：

```gdscript
const Rig := preload("res://rig/rig.gd")
```

在檔案末尾加入：

```gdscript
# ---- Task 2：關節對照表 ----

func load_rig():
	var r := Rig.new()
	check(r.load_file() == OK, "讀不到 %s" % Rig.PATH)
	return r


func load_art(part: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path("res://art/%s.png" % part))


func opaque_near(img: Image, pt: Vector2, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var p := Vector2i(pt) + Vector2i(dx, dy)
			if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() and img.get_pixelv(p).a >= 0.5:
				return true
	return false


func test_rig_has_all_parts_and_joints() -> void:
	var r = load_rig()
	for n in PARTS + [WEAPON]:
		check(r.parts.has(n), "對照表缺少分件 %s" % n)
	for j in Rig.JOINTS:
		check(r.joints.has(j), "對照表缺少基準圖關節 %s" % j)
	for n in r.parts:
		check(Rig.BONES.any(func(b): return b[0] == r.parts[n].bone), "%s 掛的骨頭 %s 不存在" % [n, r.parts[n].bone])


func test_rig_part_sizes_match_files() -> void:
	var r = load_rig()
	check(Vector2(load_art(REFERENCE).get_size()) == r.ref_size, "基準圖尺寸與對照表不符")
	for n in r.parts:
		var size := Vector2i(int(r.parts[n].size[0]), int(r.parts[n].size[1]))
		check(load_art(n).get_size() == size, "%s 的尺寸 %s 與對照表 %s 不符（補生成後要重量兩點）" % [n, load_art(n).get_size(), size])


func test_rig_points_on_opaque_pixels() -> void:
	var r = load_rig()
	for n in r.parts:
		var img := load_art(n)
		for key in ["pivot", "tip"]:
			var pt := Rig.v(r.parts[n][key])
			check(Rect2(Vector2.ZERO, Vector2(img.get_size())).has_point(pt), "%s 的 %s %s 在圖外" % [n, key, pt])
			check(opaque_near(img, pt, 12), "%s 的 %s %s 附近 12 px 內沒有不透明像素" % [n, key, pt])
	for j in r.joints:
		check(Rect2(Vector2.ZERO, r.ref_size).has_point(r.joints[j]), "基準圖關節 %s 在圖外" % j)
```

- [ ] **Step 2: 執行測試，確認失敗**

Expected：`Parse Error`（`res://rig/rig.gd` 不存在）。

- [ ] **Step 3: 寫讀取器與量測工具**

`prototypes/p4-art-pipeline/rig/rig.gd`：

```gdscript
extends RefCounted
# 關節對照表（PROTO4-1）：讀 rig/hunahpu_rig.json。
# 座標一律是基準圖 chr_hunahpu_reference.png 的像素（y 向下）；角度用弧度，0＝朝右、正值順時針。

const PATH := "res://rig/hunahpu_rig.json"
const JOINTS := [
	"hip", "neck", "crown", "waist", "loin_tip",
	"shoulder_r", "elbow_r", "wrist_r", "hand_tip_r",
	"shoulder_l", "elbow_l", "wrist_l", "hand_tip_l",
	"hip_r", "knee_r", "ankle_r", "toe_r",
	"hip_l", "knee_l", "ankle_l", "toe_l",
]
## [骨頭, 父骨頭, 起點關節, 終點關節]；父骨頭排在前面；終點空字串＝固定朝下（骨盆）
const BONES := [
	["pelvis", "", "hip", ""],
	["spine", "pelvis", "hip", "neck"],
	["head", "spine", "neck", "crown"],
	["upperarm_l", "spine", "shoulder_l", "elbow_l"],
	["forearm_l", "upperarm_l", "elbow_l", "wrist_l"],
	["hand_l", "forearm_l", "wrist_l", "hand_tip_l"],
	["thigh_l", "pelvis", "hip_l", "knee_l"],
	["shin_l", "thigh_l", "knee_l", "ankle_l"],
	["foot_l", "shin_l", "ankle_l", "toe_l"],
	["loincloth", "pelvis", "waist", "loin_tip"],
	["thigh_r", "pelvis", "hip_r", "knee_r"],
	["shin_r", "thigh_r", "knee_r", "ankle_r"],
	["foot_r", "shin_r", "ankle_r", "toe_r"],
	["upperarm_r", "spine", "shoulder_r", "elbow_r"],
	["forearm_r", "upperarm_r", "elbow_r", "wrist_r"],
	["hand_r", "forearm_r", "wrist_r", "hand_tip_r"],
]

var joints := {}
var parts := {}
var ref_size := Vector2.ZERO


func load_file(path := PATH) -> Error:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return ERR_FILE_NOT_FOUND
	var d = JSON.parse_string(text)
	if typeof(d) != TYPE_DICTIONARY:
		return ERR_PARSE_ERROR
	ref_size = v(d.reference.size)
	joints.clear()
	for j in d.reference.joints:
		joints[j] = v(d.reference.joints[j])
	parts = d.parts
	return OK


static func v(a: Array) -> Vector2:
	return Vector2(a[0], a[1])


## 場景裡的分件節點名（避免和骨頭同名，例如骨頭 head、分件 head_art）
static func sprite_name(part: String) -> String:
	return part.replace("chr_hunahpu_", "").replace("wpn_", "") + "_art"
```

`prototypes/p4-art-pipeline/tools/measure_parts.py`：

```python
"""量每個分件的主軸與兩端點，輸出草稿與對照圖（A＝紅、B＝藍），供決定哪一端是軸心。
用法（在 prototypes/p4-art-pipeline/ 執行）：python3 tools/measure_parts.py
輸出：tools/out/parts_axes.png、tools/out/parts_draft.json"""
import json
import math
import os

from PIL import Image, ImageDraw

ART = 'art'
OUT = 'tools/out'
PARTS = [
    'chr_hunahpu_head', 'chr_hunahpu_torso', 'chr_hunahpu_loincloth_flap',
    'chr_hunahpu_upperarm_r', 'chr_hunahpu_forearm_r', 'chr_hunahpu_hand_open_r', 'chr_hunahpu_hand_grip_r',
    'chr_hunahpu_upperarm_l', 'chr_hunahpu_forearm_l', 'chr_hunahpu_hand_open_l', 'chr_hunahpu_hand_grip_l',
    'chr_hunahpu_thigh_r', 'chr_hunahpu_shin_r', 'chr_hunahpu_foot_r',
    'chr_hunahpu_thigh_l', 'chr_hunahpu_shin_l', 'chr_hunahpu_foot_l',
    'wpn_axe',
]
TILE = 360  # 對照圖每格最長邊


def axis_ends(im):
    """主成分分析求主軸；兩端點取主軸方向最外側 3% 像素的平均，再往內收 4%（落在關節圓弧附近）。"""
    w, h = im.size
    a = im.getchannel('A').load()
    pts = [(x, y) for y in range(h) for x in range(w) if a[x, y] >= 128]
    n = len(pts)
    mx = sum(p[0] for p in pts) / n
    my = sum(p[1] for p in pts) / n
    sxx = sum((p[0] - mx) ** 2 for p in pts) / n
    syy = sum((p[1] - my) ** 2 for p in pts) / n
    sxy = sum((p[0] - mx) * (p[1] - my) for p in pts) / n
    ang = 0.5 * math.atan2(2 * sxy, sxx - syy)
    ux, uy = math.cos(ang), math.sin(ang)
    proj = [((p[0] - mx) * ux + (p[1] - my) * uy, p) for p in pts]
    lo = min(t for t, _ in proj)
    hi = max(t for t, _ in proj)
    span = hi - lo

    def end(at_lo):
        edge = [p for t, p in proj if ((t - lo) if at_lo else (hi - t)) <= span * 0.03]
        ex = sum(p[0] for p in edge) / len(edge)
        ey = sum(p[1] for p in edge) / len(edge)
        k = span * 0.04 * (1 if at_lo else -1)
        return [round(ex + ux * k, 1), round(ey + uy * k, 1)]

    return {'size': [w, h], 'A': end(True), 'B': end(False)}


def main():
    os.makedirs(OUT, exist_ok=True)
    draft = {}
    tiles = []
    for name in PARTS:
        im = Image.open(os.path.join(ART, name + '.png')).convert('RGBA')
        r = axis_ends(im)
        draft[name] = r
        f = min(1.0, TILE / max(im.size))
        tile = Image.new('RGBA', (TILE, TILE), (70, 70, 70, 255))
        small = im.resize((max(1, int(im.width * f)), max(1, int(im.height * f))))
        tile.alpha_composite(small)
        d = ImageDraw.Draw(tile)
        for key, col in (('A', (255, 50, 50, 255)), ('B', (60, 140, 255, 255))):
            x, y = r[key][0] * f, r[key][1] * f
            d.ellipse([x - 7, y - 7, x + 7, y + 7], outline=col, width=3)
            d.text((x + 9, y - 6), key, fill=col)
        d.text((4, TILE - 14), name.replace('chr_hunahpu_', ''), fill=(255, 255, 255, 255))
        tiles.append(tile)
    cols = 6
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * TILE, rows * TILE), (30, 30, 30, 255))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % cols) * TILE, (i // cols) * TILE))
    sheet.save(os.path.join(OUT, 'parts_axes.png'))
    with open(os.path.join(OUT, 'parts_draft.json'), 'w') as fp:
        json.dump(draft, fp, indent=1)
    print('MEASURE ok', len(draft), '件')


main()
```

`prototypes/p4-art-pipeline/tools/mark_points.py`：

```python
"""把 rig/hunahpu_rig.json 的點畫回圖上，輸出到 tools/out/ 供目視確認。
python3 tools/mark_points.py                      → reference_joints.png、parts_points.png
python3 tools/mark_points.py --grid               → reference_grid.png（每 50 px 一條格線，每 100 px 標原始座標）
python3 tools/mark_points.py --zoom X0 Y0 X1 Y1   → reference_zoom.png（裁切後放大 2 倍，含格線與已標的關節）"""
import json
import os
import sys

from PIL import Image, ImageDraw

ART = 'art'
OUT = 'tools/out'
RIG = 'rig/hunahpu_rig.json'
TILE = 360


def reference():
    return Image.open(os.path.join(ART, 'chr_hunahpu_reference.png')).convert('RGBA')


def draw_grid(im):
    d = ImageDraw.Draw(im)
    for x in range(0, im.width, 50):
        d.line([(x, 0), (x, im.height)], fill=(0, 255, 255, 170 if x % 100 == 0 else 70), width=1)
        if x % 100 == 0:
            d.text((x + 2, 2), str(x), fill=(0, 255, 255, 255))
    for y in range(0, im.height, 50):
        d.line([(0, y), (im.width, y)], fill=(0, 255, 255, 170 if y % 100 == 0 else 70), width=1)
        if y % 100 == 0:
            d.text((2, y + 2), str(y), fill=(0, 255, 255, 255))


def draw_joints(im, rig):
    d = ImageDraw.Draw(im)
    for name, (x, y) in rig['reference']['joints'].items():
        d.ellipse([x - 6, y - 6, x + 6, y + 6], outline=(0, 255, 0, 255), width=3)
        d.text((x + 8, y - 8), name, fill=(0, 255, 0, 255))


def main():
    os.makedirs(OUT, exist_ok=True)
    args = sys.argv[1:]
    if args[:1] == ['--grid']:
        im = reference()
        draw_grid(im)
        im.save(os.path.join(OUT, 'reference_grid.png'))
        print('MARK grid')
        return
    rig = json.load(open(RIG)) if os.path.exists(RIG) else None
    if args[:1] == ['--zoom']:
        x0, y0, x1, y1 = map(int, args[1:5])
        im = reference()
        draw_grid(im)
        if rig:
            draw_joints(im, rig)
        im = im.crop((x0, y0, x1, y1)).resize(((x1 - x0) * 2, (y1 - y0) * 2))
        im.save(os.path.join(OUT, 'reference_zoom.png'))
        print('MARK zoom')
        return
    im = reference()
    draw_joints(im, rig)
    im.save(os.path.join(OUT, 'reference_joints.png'))
    tiles = []
    for name, p in rig['parts'].items():
        part = Image.open(os.path.join(ART, name + '.png')).convert('RGBA')
        f = min(1.0, TILE / max(part.size))
        tile = Image.new('RGBA', (TILE, TILE), (70, 70, 70, 255))
        tile.alpha_composite(part.resize((max(1, int(part.width * f)), max(1, int(part.height * f)))))
        d = ImageDraw.Draw(tile)
        for key, col in (('pivot', (0, 255, 0, 255)), ('tip', (255, 230, 0, 255))):
            x, y = p[key][0] * f, p[key][1] * f
            d.ellipse([x - 6, y - 6, x + 6, y + 6], outline=col, width=3)
        d.text((4, TILE - 14), name.replace('chr_hunahpu_', '') + ' → ' + p['bone'], fill=(255, 255, 255, 255))
        tiles.append(tile)
    cols = 6
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * TILE, rows * TILE), (30, 30, 30, 255))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % cols) * TILE, (i // cols) * TILE))
    sheet.save(os.path.join(OUT, 'parts_points.png'))
    print('MARK ok')


main()
```

- [ ] **Step 4: 量測並填寫對照表**

在 `prototypes/p4-art-pipeline/` 執行，每一步都用 Read 工具開圖目視：

1. `python3 tools/measure_parts.py` → 看 `tools/out/parts_axes.png`。每件決定 A、B 哪一端是**軸心**（靠身體的關節：大腿＝髖端、小腿＝膝端、腳＝腳踝端、上臂＝肩端、前臂＝肘端、手＝手腕端、頭＝脖子底、軀幹＝腰帶下緣中央的髖、腰布＝綁在腰上的頂端、斧頭＝手柄末端），另一端是**末端**。斧頭的軸心改為握點：`手柄末端 + 0.2 ×（斧刃端 − 手柄末端）`，末端＝斧刃端。
2. `python3 tools/mark_points.py --grid` → 看 `tools/out/reference_grid.png`，必要時用 `--zoom` 放大局部，讀出 21 個關節的座標：髖中心 `hip`、脖子底 `neck`、頭頂 `crown`、腰布綁點 `waist`、腰布下緣 `loin_tip`；手臂與腿的肩／肘／腕／指尖（或拳頭前緣）、髖／膝／踝／腳趾。近側（`_r`）＝畫在前面、遮住另一隻的那隻手或腳；被遮住的遠側關節依可見輪廓推估。
3. 寫 `rig/hunahpu_rig.json`：`reference.size` 填 `[1024, 1536]`（以實際尺寸為準），`joints` 填第 2 步的座標；`parts` 每件填 `size`（`parts_draft.json` 的值）、`bone`（見下表）、`pivot`、`tip`、`z`，並依下表補 `visible`、`scale_from`、`attach_t`、`angle_deg`。

   | 分件 | bone | z | 其他 |
   |---|---|---|---|
   | `upperarm_l`、`forearm_l`、`thigh_l`、`shin_l`、`foot_l` | 同名骨頭 | -2 | — |
   | `hand_open_l` | `hand_l` | -2 | 基準圖的遠側手是張開的：量它 |
   | `hand_grip_l` | `hand_l` | -2 | `"visible": false`、`"scale_from": "chr_hunahpu_forearm_l"` |
   | `torso` | `spine` | 0 | — |
   | `loincloth_flap` | `loincloth` | 1 | — |
   | `head` | `head` | 1 | — |
   | `thigh_r`、`shin_r`、`foot_r`、`upperarm_r`、`forearm_r` | 同名骨頭 | 2 | — |
   | `hand_grip_r` | `hand_r` | 2 | 基準圖的近側手握著吹箭：量它 |
   | `hand_open_r` | `hand_r` | 2 | `"visible": false`、`"scale_from": "chr_hunahpu_forearm_r"` |
   | `wpn_axe` | `hand_r` | 3 | `"attach_t": 0.5`；`"angle_deg"` 先填 `0`，Task 4 依畫面調整 |

   若基準圖的實際手勢與上表相反（近側手張開），把上表兩手的 `visible`／`scale_from` 對調，並在 ledger 記一筆裁定。
4. `python3 tools/mark_points.py` → 看 `reference_joints.png` 與 `parts_points.png`，每個點都要落在關節圓弧的中心附近；不準的回到第 2 或第 3 步修正，直到全部合格。

- [ ] **Step 5: 執行測試，確認通過**

Expected：3 項新測試 PASS，`SUMMARY pass=5 fail=0`，`rc=0`。

- [ ] **Step 6: Commit**

```bash
cd '<repo>'
git add prototypes/p4-art-pipeline
git commit -m "Measure Hunahpu joints and part pivots into a rig table (MV-PROTO-004)"
```

---

### Task 3: 骨頭靜止姿勢與分件一致性

**Files:**
- Modify: `prototypes/p4-art-pipeline/rig/rig.gd`（末尾加函式與常數）
- Test: `tests/self_test.gd`（追加）

**Interfaces:**
- Consumes：Task 2 的 `rig.gd`
- Produces：`rig.gd` 常數 `PELVIS_LENGTH := 60.0`、`WEAPON_LENGTH_RATIO := 0.4`、`OUTLIER := 0.15`；方法 `bone_spec(name) -> Array`、`bone_global(name) -> Dictionary {pos: Vector2, angle: float, length: float}`、`ground() -> Vector2`、`body_height() -> float`、`part_length(part) -> float`、`target_length(part) -> float`、`part_scale(part) -> float`、`consistency() -> Dictionary {scales, median, min, max, spread, stdev_ratio, outliers, unmeasured}`

- [ ] **Step 1: 寫測試**

在檔案末尾加入：

```gdscript
# ---- Task 3：靜止姿勢與一致性 ----

func test_bones_parents_before_children() -> void:
	var seen := {}
	for b in Rig.BONES:
		check(b[1] == "" or seen.has(b[1]), "骨頭 %s 的父骨頭 %s 必須排在前面" % [b[0], b[1]])
		seen[b[0]] = true


func test_bone_global_matches_joints() -> void:
	var r = load_rig()
	for b in Rig.BONES:
		var g: Dictionary = r.bone_global(b[0])
		check(g.pos.is_equal_approx(r.joints[b[2]]), "%s 的起點應在關節 %s" % [b[0], b[2]])
		if b[3] != "":
			check(is_equal_approx(g.length, r.joints[b[2]].distance_to(r.joints[b[3]])), "%s 的長度應等於兩關節距離" % b[0])


func test_body_height_and_ground() -> void:
	var r = load_rig()
	check(r.body_height() > 0.6 * r.ref_size.y, "身高應佔基準圖大部分，實際 %.0f px" % r.body_height())
	check(r.ground().y >= r.joints.toe_r.y and r.ground().y >= r.joints.toe_l.y, "原點應在最低的腳趾高度")


func test_part_consistency_report() -> void:
	var r = load_rig()
	var c: Dictionary = r.consistency()
	check(c.scales.size() == 15, "17 件中應量 15 件（兩隻沒出現在基準圖的手勢不量），實際 %d" % c.scales.size())
	for n in c.scales:
		check(c.scales[n] > 0.0, "%s 的縮放比例應為正數" % n)
	check(c.min <= c.median and c.median <= c.max, "統計值順序錯誤")
	print("CONSISTENCY median=%.3f min=%.3f max=%.3f spread=%.1f%% stdev=%.1f%% outliers=%s unmeasured=%s" % [c.median, c.min, c.max, c.spread * 100.0, c.stdev_ratio * 100.0, c.outliers, c.unmeasured])
	for n in c.scales:
		print("CONSISTENCY   %s %.3f" % [n, c.scales[n]])
```

- [ ] **Step 2: 執行測試，確認失敗**

Expected：`SCRIPT ERROR`（`bone_global`、`consistency` 等不存在）與 4 項 FAIL。

- [ ] **Step 3: 實作**

在 `rig.gd` 的 `var joints := {}` 之前加入：

```gdscript
const PELVIS_LENGTH := 60.0
const WEAPON_LENGTH_RATIO := 0.4  # 握點到斧刃端＝身高 × 0.4（手柄全長約身高一半，握點距末端 1/5）
const OUTLIER := 0.15  # 縮放比例偏離中位數超過這個比例 → 列入補生成清單
```

在 `rig.gd` 末尾加入：

```gdscript
func bone_spec(name: String) -> Array:
	for b in BONES:
		if b[0] == name:
			return b
	return []


## 骨頭在基準圖上的靜止姿勢：起點、角度（弧度）、長度
func bone_global(name: String) -> Dictionary:
	var b := bone_spec(name)
	var a: Vector2 = joints[b[2]]
	if b[3] == "":
		return {"pos": a, "angle": PI / 2.0, "length": PELVIS_LENGTH}
	var c: Vector2 = joints[b[3]]
	return {"pos": a, "angle": (c - a).angle(), "length": a.distance_to(c)}


## 角色原點：髖中心正下方、最低的腳趾或腳踝高度
func ground() -> Vector2:
	var y := 0.0
	for j in ["ankle_r", "toe_r", "ankle_l", "toe_l"]:
		y = maxf(y, joints[j].y)
	return Vector2(joints.hip.x, y)


func body_height() -> float:
	return ground().y - joints.crown.y


func part_length(part: String) -> float:
	return v(parts[part].pivot).distance_to(v(parts[part].tip))


## 分件在基準圖上應有的長度：骨頭長度；斧頭依身高比例
func target_length(part: String) -> float:
	if part.begins_with("wpn_"):
		return body_height() * WEAPON_LENGTH_RATIO
	return bone_global(parts[part].bone).length


func part_scale(part: String) -> float:
	var p: Dictionary = parts[part]
	if p.has("scale_from"):
		return part_scale(p.scale_from)
	return target_length(part) / part_length(part)


## 分件一致性（問題 1）：每件的縮放比例與統計；scale_from 的分件沒出現在基準圖，不量
func consistency() -> Dictionary:
	var scales := {}
	var unmeasured := []
	for n in parts:
		if not n.begins_with("chr_"):
			continue
		if parts[n].has("scale_from"):
			unmeasured.append(n)
		else:
			scales[n] = part_scale(n)
	var vals: Array = scales.values()
	vals.sort()
	var m := vals.size()
	var median: float = vals[m / 2] if m % 2 == 1 else (vals[m / 2 - 1] + vals[m / 2]) / 2.0
	var mean := 0.0
	for s in vals:
		mean += s
	mean /= m
	var sq := 0.0
	for s in vals:
		sq += (s - mean) * (s - mean)
	var outliers := []
	for n in scales:
		if absf(scales[n] / median - 1.0) > OUTLIER:
			outliers.append(n)
	return {
		"scales": scales, "median": median, "min": vals[0], "max": vals[m - 1],
		"spread": vals[m - 1] / vals[0] - 1.0, "stdev_ratio": sqrt(sq / m) / mean,
		"outliers": outliers, "unmeasured": unmeasured,
	}
```

- [ ] **Step 4: 執行測試，確認通過**

Expected：4 項新測試 PASS，`SUMMARY pass=9 fail=0`，輸出含 `CONSISTENCY median=… outliers=[…]` 與每件一行。把這段輸出存進 ledger（Task 7 寫進報告）。

- [ ] **Step 5: Commit**

```bash
git add prototypes/p4-art-pipeline
git commit -m "Compute rest pose and part scale consistency (MV-PROTO-004)"
```

---

### Task 4: 產生可編輯的骨架場景

**Files:**
- Create: `prototypes/p4-art-pipeline/rig/build_rig.gd`、`hunahpu.tscn`、`rig/hunahpu.build.md5`（後兩者由產生器輸出）
- Modify: `prototypes/p4-art-pipeline/main.gd`（整個替換）
- Test: `tests/self_test.gd`（追加）

**Interfaces:**
- Consumes：Task 3 的 `rig.gd`
- Produces：`build_rig.gd`：常數 `OUT := "res://hunahpu.tscn"`、`HASH_PATH := "res://rig/hunahpu.build.md5"`；`static build(rig) -> Node2D`（缺檔回傳 null；回傳的樹含 `Skeleton`（Skeleton2D）、各 Bone2D 依骨頭命名、各分件 Sprite2D 依 `Rig.sprite_name()` 命名）；`static save_scene(root, out := OUT, hash_path := HASH_PATH, force := false) -> Error`（手動改過且未 force → `ERR_ALREADY_EXISTS`）；`main.gd` 的 `--build-rig [--force]`

- [ ] **Step 1: 寫測試**

在 preload 區加入：

```gdscript
const Build := preload("res://rig/build_rig.gd")
```

在檔案末尾加入：

```gdscript
# ---- Task 4：產生場景 ----

func test_build_structure() -> void:
	var r = load_rig()
	var root: Node2D = Build.build(r)
	check(root != null, "產生失敗")
	if root == null:
		return
	check(root.get_node_or_null("Skeleton") is Skeleton2D, "缺少 Skeleton2D")
	var sprites := root.find_children("*", "Sprite2D", true, false)
	check(sprites.size() == PARTS.size() + 1, "應有 %d 個分件 Sprite2D，實際 %d" % [PARTS.size() + 1, sprites.size()])
	for s in sprites:
		check(s.get_parent() is Bone2D, "%s 沒有掛在骨頭上" % s.name)
	var axe := root.find_child(Rig.sprite_name(WEAPON), true, false)
	check(axe != null and axe.get_parent().name == "hand_r", "斧頭應掛在近側手 hand_r")
	root.free()


func test_rest_pose_matches_reference() -> void:
	var r = load_rig()
	var root: Node2D = Build.build(r)
	add_child(root)
	var g: Vector2 = r.ground()
	for b in Rig.BONES:
		var bone: Bone2D = root.find_child(b[0], true, false)
		check(bone.global_position.distance_to(r.joints[b[2]] - g) < 0.5, "骨頭 %s 應在關節 %s" % [b[0], b[2]])
	for part in r.parts:
		var p: Dictionary = r.parts[part]
		if p.has("scale_from") or part.begins_with("wpn_"):
			continue
		var spec: Array = r.bone_spec(p.bone)
		if spec[3] == "":
			continue
		var s: Sprite2D = root.find_child(Rig.sprite_name(part), true, false)
		var tip_global := s.global_transform * (Rig.v(p.tip) + s.offset)
		check(tip_global.distance_to(r.joints[spec[3]] - g) < 1.0, "%s 的末端應落在關節 %s" % [part, spec[3]])
	root.queue_free()
	await frames(1)


func test_build_refuses_missing_art() -> void:
	var r = load_rig()
	r.parts["chr_hunahpu_missing"] = r.parts["chr_hunahpu_head"].duplicate()
	var root = Build.build(r)
	check(root == null, "缺少分件檔時不應產生殘缺的場景")
	if root != null:
		root.free()


func test_build_does_not_overwrite_hand_edits() -> void:
	var out := "user://selftest_hunahpu.tscn"
	var md5 := "user://selftest_hunahpu.md5"
	for f in [out, md5]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	var r = load_rig()
	var root: Node2D = Build.build(r)
	check(Build.save_scene(root, out, md5) == OK, "第一次存檔應成功")
	var f := FileAccess.open(out, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_string("\n")  # 模擬在編輯器手動改過
	f.close()
	check(Build.save_scene(root, out, md5) == ERR_ALREADY_EXISTS, "手動改過後不加 force 不應覆蓋")
	check(Build.save_scene(root, out, md5, true) == OK, "加 force 應可覆蓋")
	root.free()
	for p in [out, md5]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func test_saved_scene_loads() -> void:
	check(ResourceLoader.exists(Build.OUT), "缺少 %s（先執行 --build-rig）" % Build.OUT)
	if not ResourceLoader.exists(Build.OUT):
		return
	var inst: Node = load(Build.OUT).instantiate()
	check(inst.find_children("*", "Sprite2D", true, false).size() == PARTS.size() + 1, "存檔的場景分件數不對")
	inst.free()
```

- [ ] **Step 2: 執行測試，確認失敗**

Expected：`Parse Error`（`res://rig/build_rig.gd` 不存在）。

- [ ] **Step 3: 實作產生器與進入點**

`prototypes/p4-art-pipeline/rig/build_rig.gd`：

```gdscript
extends RefCounted
# 產生器（PROTO4-1）：依關節對照表建立 Skeleton2D 角色，存成可在編輯器微調的 hunahpu.tscn。
# 存檔時記下 MD5；之後檔案被手動改過，重新產生時不覆蓋，除非 force（先把微調回填到對照表）。

const Rig := preload("res://rig/rig.gd")
const OUT := "res://hunahpu.tscn"
const HASH_PATH := "res://rig/hunahpu.build.md5"


## 建立節點樹（不存檔）；分件檔缺少時回傳 null。呼叫端負責 free()
static func build(rig) -> Node2D:
	for part in rig.parts:
		var path := "res://art/%s.png" % part
		if not ResourceLoader.exists(path):
			printerr("BUILD 缺少分件 %s（先執行 ./sync_art.sh）" % path)
			return null
	var root := Node2D.new()
	root.name = "Hunahpu"
	var sk := Skeleton2D.new()
	sk.name = "Skeleton"
	root.add_child(sk)
	sk.owner = root
	var g: Vector2 = rig.ground()
	var bones := {}
	for b in Rig.BONES:
		var bone := Bone2D.new()
		bone.name = b[0]
		var gl: Dictionary = rig.bone_global(b[0])
		var parent: Node = sk
		var parent_xf := Transform2D.IDENTITY
		if b[1] != "":
			parent = bones[b[1]]
			var pg: Dictionary = rig.bone_global(b[1])
			parent_xf = Transform2D(pg.angle, pg.pos - g)
		bone.transform = parent_xf.affine_inverse() * Transform2D(gl.angle, gl.pos - g)
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(gl.length)
		bone.set_bone_angle(0.0)
		bone.rest = bone.transform
		parent.add_child(bone)
		bone.owner = root
		bones[b[0]] = bone
	for part in rig.parts:
		var p: Dictionary = rig.parts[part]
		var s := Sprite2D.new()
		s.name = Rig.sprite_name(part)
		s.texture = load("res://art/%s.png" % part)
		s.centered = false
		var pivot := Rig.v(p.pivot)
		var tip := Rig.v(p.tip)
		var k: float = rig.part_scale(part)
		s.offset = -pivot  # 軸心對齊骨頭原點
		s.rotation = -(tip - pivot).angle() + deg_to_rad(p.get("angle_deg", 0.0))  # 分件主軸轉到骨頭方向
		s.scale = Vector2(k, k)
		if p.has("attach_t"):
			s.position = Vector2(bones[p.bone].get_length() * p.attach_t, 0)
		s.z_index = int(p.get("z", 0))
		s.visible = p.get("visible", true)
		bones[p.bone].add_child(s)
		s.owner = root
	return root


## 存成場景；out 在上次產生後被手動改過且未 force → ERR_ALREADY_EXISTS
static func save_scene(root: Node2D, out := OUT, hash_path := HASH_PATH, force := false) -> Error:
	if FileAccess.file_exists(out) and not force:
		var last := FileAccess.get_file_as_string(hash_path).strip_edges() if FileAccess.file_exists(hash_path) else ""
		if FileAccess.get_md5(out) != last:
			printerr("BUILD %s 在上次產生後被手動修改過，不覆蓋；確定要覆蓋請加 --force（先把微調回填到 rig/hunahpu_rig.json）" % out)
			return ERR_ALREADY_EXISTS
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		return err
	err = ResourceSaver.save(ps, out)
	if err != OK:
		return err
	var f := FileAccess.open(hash_path, FileAccess.WRITE)
	f.store_string(FileAccess.get_md5(out))
	f.close()
	return OK
```

`prototypes/p4-art-pipeline/main.gd`：整個替換為：

```gdscript
extends Node2D
# MV-PROTO-004 美術管線（獨立、可丟棄）。規格：todo/spec/MV-PROTO-004_美術管線.md
# 使用者參數（放在 -- 之後）：
#   --self-test            執行自動測試後結束（結束碼 0＝全部通過）
#   --build-rig [--force]  依 rig/hunahpu_rig.json 產生 hunahpu.tscn；檔案被手動改過時不覆蓋，除非加 --force

const SelfTest := preload("res://tests/self_test.gd")
const Rig := preload("res://rig/rig.gd")
const Build := preload("res://rig/build_rig.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--self-test" in args:
		var t := SelfTest.new()
		add_child(t)
		await t.run()
		get_tree().quit(0 if t.fail_count == 0 else 1)
		return
	if "--build-rig" in args:
		get_tree().quit(_build_rig("--force" in args))
		return


func _build_rig(force: bool) -> int:
	var rig := Rig.new()
	if rig.load_file() != OK:
		printerr("BUILD 讀不到 %s" % Rig.PATH)
		return 1
	var root := Build.build(rig)
	if root == null:
		return 1
	var err := Build.save_scene(root, Build.OUT, Build.HASH_PATH, force)
	root.free()
	print("BUILD %s err=%d" % [Build.OUT, err])
	return 0 if err == OK else 1
```

產生場景：

```bash
cd '<repo>/prototypes/p4-art-pipeline'
godot --headless --path . -- --build-rig > /tmp/p4_build.txt 2>&1; rc=$?; grep -E 'BUILD|ERROR' /tmp/p4_build.txt; echo "rc=$rc"
```

Expected：`BUILD res://hunahpu.tscn err=0`、`rc=0`、沒有 `ERROR`。

- [ ] **Step 4: 執行測試，確認通過**

Expected：5 項新測試 PASS，`SUMMARY pass=14 fail=0`。

- [ ] **Step 5: Commit**

```bash
cd '<repo>'
git add prototypes/p4-art-pipeline
git commit -m "Generate editable Skeleton2D scene from the rig table (MV-PROTO-004)"
```

---

### Task 5: 三個動作與內插切換

**Files:**
- Create: `prototypes/p4-art-pipeline/rig/anims.gd`
- Modify: `prototypes/p4-art-pipeline/rig/build_rig.gd`（`build()` 末尾加 AnimationPlayer）
- Test: `tests/self_test.gd`（追加）

**Interfaces:**
- Consumes：Task 3 的 `rig.gd`、Task 4 的 `build_rig.gd`
- Produces：`anims.gd`：常數 `FPS := 12.0`、`JOINT_RING := 14.0`、`JOINT_PAIRS`（關節 → `[靠身體那件, 外側那件]`）；`static make_library(rig, bones: Dictionary, root: Node) -> AnimationLibrary`（動作名 `idle`、`run`、`axe_side`）；`static set_smooth(ap: AnimationPlayer, smooth: bool)`；場景裡的 AnimationPlayer 名為 `Anim`

**裁定說明**：規格書第 5 節寫「相連兩件的軸心距離不超過 6 px」，但剛性分件掛在骨頭上，軸心距離依構造恆為 0，這個檢查驗不到任何東西。改用「關節周圍取樣點是否被相連兩件覆蓋」，才能真的抓到旋轉後露出的縫（穿幫）。執行時在 ledger 記一筆裁定。

- [ ] **Step 1: 寫測試**

在 preload 區加入：

```gdscript
const Anims := preload("res://rig/anims.gd")
```

在檔案末尾加入：

```gdscript
# ---- Task 5：動作 ----

func test_animations_exist_and_default_stepped() -> void:
	var r = load_rig()
	var root: Node2D = Build.build(r)
	var ap: AnimationPlayer = root.get_node("Anim")
	for spec in [["idle", 1.0, true], ["run", 0.5, true], ["axe_side", 0.32, false]]:
		check(ap.has_animation(spec[0]), "缺少動作 %s" % spec[0])
		if not ap.has_animation(spec[0]):
			continue
		var a := ap.get_animation(spec[0])
		check(is_equal_approx(a.length, spec[1]), "%s 長度應為 %.2f 秒" % [spec[0], spec[1]])
		check((a.loop_mode == Animation.LOOP_LINEAR) == spec[2], "%s 的循環設定錯誤" % spec[0])
		for t in a.get_track_count():
			check(a.track_get_interpolation_type(t) == Animation.INTERPOLATION_NEAREST, "%s 預設應不內插" % spec[0])
	root.free()


func test_interpolation_toggle() -> void:
	var root: Node2D = Build.build(load_rig())
	var ap: AnimationPlayer = root.get_node("Anim")
	Anims.set_smooth(ap, true)
	for name in ap.get_animation_list():
		var a := ap.get_animation(name)
		for t in a.get_track_count():
			check(a.track_get_interpolation_type(t) == Animation.INTERPOLATION_LINEAR, "%s 切換後應為線性內插" % name)
	Anims.set_smooth(ap, false)
	for name in ap.get_animation_list():
		var a := ap.get_animation(name)
		for t in a.get_track_count():
			check(a.track_get_interpolation_type(t) == Animation.INTERPOLATION_NEAREST, "%s 切回後應不內插" % name)
	root.free()


func test_rotation_keys_are_unwrapped() -> void:
	var root: Node2D = Build.build(load_rig())
	var ap: AnimationPlayer = root.get_node("Anim")
	for name in ap.get_animation_list():
		var a := ap.get_animation(name)
		for t in a.get_track_count():
			if not String(a.track_get_path(t)).ends_with(":rotation"):
				continue
			for k in range(1, a.track_get_key_count(t)):
				var d := absf(a.track_get_key_value(t, k) - a.track_get_key_value(t, k - 1))
				check(d <= PI, "%s 的 %s 相鄰關鍵影格差 %.0f°，平滑內插會繞遠路" % [name, a.track_get_path(t), rad_to_deg(d)])
	root.free()


func joint_coverage(root: Node, r, joint: String, images: Dictionary) -> float:
	var pair: Array = Anims.JOINT_PAIRS[joint]
	var child_bone: Bone2D = root.find_child(r.parts[pair[1]].bone, true, false)
	var c := child_bone.global_position
	var covered := 0
	for i in 16:
		var p := c + Vector2.from_angle(TAU * i / 16.0) * Anims.JOINT_RING
		for part in pair:
			var s: Sprite2D = root.find_child(Rig.sprite_name(part), true, false)
			var px := s.global_transform.affine_inverse() * p - s.offset
			var img: Image = images[part]
			if px.x >= 0 and px.y >= 0 and px.x < img.get_width() and px.y < img.get_height() and img.get_pixelv(Vector2i(px)).a >= 0.3:
				covered += 1
				break
	return covered / 16.0


func test_joints_covered_in_every_key() -> void:
	var r = load_rig()
	var root: Node2D = Build.build(r)
	add_child(root)
	var images := {}
	for pair in Anims.JOINT_PAIRS.values():
		for part in pair:
			images[part] = load_art(part)
	var ap: AnimationPlayer = root.get_node("Anim")
	var gaps := []
	for name in ["idle", "run", "axe_side"]:
		var a := ap.get_animation(name)
		ap.play(name)
		for k in a.track_get_key_count(0):
			var t := a.track_get_key_time(0, k)
			ap.seek(t, true)
			for joint in Anims.JOINT_PAIRS:
				var cov := joint_coverage(root, r, joint, images)
				if cov < 1.0:
					gaps.append("%s@%.2fs %s %.0f%%" % [name, t, joint, cov * 100.0])
	check(gaps.is_empty(), "關節穿幫：%s" % ", ".join(gaps))
	root.queue_free()
	await frames(1)
```

- [ ] **Step 2: 執行測試，確認失敗**

Expected：`Parse Error`（`res://rig/anims.gd` 不存在）。

- [ ] **Step 3: 實作動作**

`prototypes/p4-art-pipeline/rig/anims.gd`：

```gdscript
extends RefCounted
# 三個動作（PROTO4-2）。角度一律是「全域角度」（度；0＝朝右、90＝朝下、-90＝朝上）；
# rel＝相對父骨頭的全域角度（例如小腿＝大腿角度＋膝彎）；mean 為 null＝用靜止姿勢的角度。
# 沒列出的骨頭維持靜止姿勢的全域角度（例如待機時腿不動）。
# 循環動作以正弦描述、12 fps 取樣；斧頭側攻四個姿勢對應 MV-PROTO-001 的出招 0.06、判定 0.08、收招 0.18 秒。
# 預設不內插（抄本平面感）；set_smooth() 切成線性內插對照。

const Rig := preload("res://rig/rig.gd")
const FPS := 12.0
const AXE_LENGTH := 0.32
const JOINT_RING := 14.0  # 穿幫檢查的取樣半徑（基準圖像素）
const JOINT_PAIRS := {
	"neck": ["chr_hunahpu_torso", "chr_hunahpu_head"],
	"shoulder_r": ["chr_hunahpu_torso", "chr_hunahpu_upperarm_r"],
	"elbow_r": ["chr_hunahpu_upperarm_r", "chr_hunahpu_forearm_r"],
	"wrist_r": ["chr_hunahpu_forearm_r", "chr_hunahpu_hand_grip_r"],
	"shoulder_l": ["chr_hunahpu_torso", "chr_hunahpu_upperarm_l"],
	"elbow_l": ["chr_hunahpu_upperarm_l", "chr_hunahpu_forearm_l"],
	"wrist_l": ["chr_hunahpu_forearm_l", "chr_hunahpu_hand_open_l"],
	"hip_r": ["chr_hunahpu_torso", "chr_hunahpu_thigh_r"],
	"knee_r": ["chr_hunahpu_thigh_r", "chr_hunahpu_shin_r"],
	"ankle_r": ["chr_hunahpu_shin_r", "chr_hunahpu_foot_r"],
	"hip_l": ["chr_hunahpu_torso", "chr_hunahpu_thigh_l"],
	"knee_l": ["chr_hunahpu_thigh_l", "chr_hunahpu_shin_l"],
	"ankle_l": ["chr_hunahpu_shin_l", "chr_hunahpu_foot_l"],
}

const CYCLES := {
	"idle": {"length": 1.0, "bob": 3.0, "bob_freq": 1.0, "bones": {
		"spine": {"amp": 2.0, "phase": 0.0, "mean": null, "rel": false},
		"head": {"amp": 1.5, "phase": 0.1, "mean": null, "rel": true},
		"upperarm_r": {"amp": 3.0, "phase": 0.05, "mean": null, "rel": true},
		"forearm_r": {"amp": 0.0, "phase": 0.0, "mean": null, "rel": true},
		"hand_r": {"amp": 0.0, "phase": 0.0, "mean": null, "rel": true},
		"upperarm_l": {"amp": 3.0, "phase": 0.05, "mean": null, "rel": true},
		"forearm_l": {"amp": 0.0, "phase": 0.0, "mean": null, "rel": true},
		"hand_l": {"amp": 0.0, "phase": 0.0, "mean": null, "rel": true},
		"loincloth": {"amp": 1.0, "phase": 0.2, "mean": null, "rel": true},
	}},
	"run": {"length": 0.5, "bob": 8.0, "bob_freq": 2.0, "bones": {
		"spine": {"amp": 2.0, "phase": 0.25, "mean": -78.0, "rel": false},
		"head": {"amp": 0.0, "phase": 0.0, "mean": null, "rel": true},
		"thigh_r": {"amp": 35.0, "phase": 0.0, "mean": 95.0, "rel": false},
		"shin_r": {"amp": 30.0, "phase": 0.75, "mean": 40.0, "rel": true},
		"foot_r": {"amp": 10.0, "phase": 0.0, "mean": null, "rel": true},
		"thigh_l": {"amp": 35.0, "phase": 0.5, "mean": 95.0, "rel": false},
		"shin_l": {"amp": 30.0, "phase": 0.25, "mean": 40.0, "rel": true},
		"foot_l": {"amp": 10.0, "phase": 0.5, "mean": null, "rel": true},
		"upperarm_r": {"amp": 30.0, "phase": 0.5, "mean": 95.0, "rel": false},
		"forearm_r": {"amp": 10.0, "phase": 0.5, "mean": -70.0, "rel": true},
		"hand_r": {"amp": 0.0, "phase": 0.0, "mean": null, "rel": true},
		"upperarm_l": {"amp": 30.0, "phase": 0.0, "mean": 95.0, "rel": false},
		"forearm_l": {"amp": 10.0, "phase": 0.0, "mean": -70.0, "rel": true},
		"hand_l": {"amp": 0.0, "phase": 0.0, "mean": null, "rel": true},
		"loincloth": {"amp": 6.0, "phase": 0.0, "mean": null, "rel": true},
	}},
}
## 斧頭側攻：[時間, 姿勢]；姿勢裡的值同上（amp 省略＝0）；空姿勢＝回到靜止
const AXE_POSES := [
	[0.0, {  # 出招：舉斧過肩、身體後仰
		"spine": {"mean": -95.0, "rel": false}, "head": {"mean": null, "rel": true},
		"upperarm_r": {"mean": -150.0, "rel": false}, "forearm_r": {"mean": -30.0, "rel": true}, "hand_r": {"mean": null, "rel": true},
		"upperarm_l": {"mean": 120.0, "rel": false}, "forearm_l": {"mean": -40.0, "rel": true}, "hand_l": {"mean": null, "rel": true},
	}],
	[0.06, {  # 判定：手臂揮到正前方、身體前傾
		"spine": {"mean": -75.0, "rel": false}, "head": {"mean": null, "rel": true},
		"upperarm_r": {"mean": 0.0, "rel": false}, "forearm_r": {"mean": 0.0, "rel": true}, "hand_r": {"mean": null, "rel": true},
		"upperarm_l": {"mean": 110.0, "rel": false}, "forearm_l": {"mean": -30.0, "rel": true}, "hand_l": {"mean": null, "rel": true},
	}],
	[0.14, {  # 收招：揮過頭往下
		"spine": {"mean": -72.0, "rel": false}, "head": {"mean": null, "rel": true},
		"upperarm_r": {"mean": 60.0, "rel": false}, "forearm_r": {"mean": 15.0, "rel": true}, "hand_r": {"mean": null, "rel": true},
		"upperarm_l": {"mean": 100.0, "rel": false}, "forearm_l": {"mean": -20.0, "rel": true}, "hand_l": {"mean": null, "rel": true},
	}],
	[AXE_LENGTH, {}],
]


## 一個影格各骨頭的區域旋轉（弧度）；u＝循環進度 0～1
static func frame_locals(rig, values: Dictionary, u: float) -> Dictionary:
	var glob := {}
	var locals := {}
	for b in Rig.BONES:
		var name: String = b[0]
		var parent_g: float = glob[b[1]] if b[1] != "" else 0.0
		var rest_g: float = rig.bone_global(name).angle
		var rest_parent_g: float = rig.bone_global(b[1]).angle if b[1] != "" else 0.0
		var g := rest_g
		if values.has(name):
			var spec: Dictionary = values[name]
			var wave := deg_to_rad(spec.get("amp", 0.0) * sin(TAU * (u + spec.get("phase", 0.0))))
			if spec.rel:
				var base_rel: float = (rest_g - rest_parent_g) if spec.mean == null else deg_to_rad(spec.mean)
				g = parent_g + base_rel + wave
			else:
				var base_abs: float = rest_g if spec.mean == null else deg_to_rad(spec.mean)
				g = base_abs + wave
		glob[name] = g
		locals[name] = g - parent_g
	return locals


static func make_library(rig, bones: Dictionary, root: Node) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for name in CYCLES:
		var c: Dictionary = CYCLES[name]
		var a := _new_anim(c.length, true, bones, root)
		var n := int(round(c.length * FPS))
		for i in n + 1:
			var u := float(i) / n
			_key(a, bones, i * c.length / n, frame_locals(rig, c.bones, u), c.bob * sin(TAU * u * c.bob_freq))
		lib.add_animation(name, a)
	var axe := _new_anim(AXE_LENGTH, false, bones, root)
	for pose in AXE_POSES:
		_key(axe, bones, pose[0], frame_locals(rig, pose[1], 0.0), 0.0)
	lib.add_animation("axe_side", axe)
	return lib


static func set_smooth(ap: AnimationPlayer, smooth: bool) -> void:
	for name in ap.get_animation_list():
		var a := ap.get_animation(name)
		for t in a.get_track_count():
			a.track_set_interpolation_type(t, Animation.INTERPOLATION_LINEAR if smooth else Animation.INTERPOLATION_NEAREST)


## 軌道順序：每根骨頭一條旋轉軌（依 BONES 順序），最後一條是骨盆位置（上下起伏）
static func _new_anim(length: float, loop: bool, bones: Dictionary, root: Node) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for b in Rig.BONES:
		var t := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(t, NodePath(_path(root, bones[b[0]]) + ":rotation"))
		a.track_set_interpolation_type(t, Animation.INTERPOLATION_NEAREST)
	var p := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(p, NodePath(_path(root, bones["pelvis"]) + ":position"))
	a.track_set_interpolation_type(p, Animation.INTERPOLATION_NEAREST)
	return a


static func _key(a: Animation, bones: Dictionary, time: float, locals: Dictionary, bob: float) -> void:
	for i in Rig.BONES.size():
		var value: float = locals[Rig.BONES[i][0]]
		var count := a.track_get_key_count(i)
		if count > 0:  # 展開角度：和前一個關鍵影格相差不超過半圈，平滑內插才不會繞遠路
			var prev: float = a.track_get_key_value(i, count - 1)
			value = prev + wrapf(value - prev, -PI, PI)
		a.track_insert_key(i, time, value)
	var rest: Vector2 = bones["pelvis"].rest.origin
	a.track_insert_key(Rig.BONES.size(), time, rest + Vector2(0, -absf(bob)))


static func _path(root: Node, node: Node) -> String:
	var names := PackedStringArray()
	var n := node
	while n != root:
		names.insert(0, n.name)
		n = n.get_parent()
	return "/".join(names)
```

`build_rig.gd`：在 `const Rig := …` 下一行加入：

```gdscript
const Anims := preload("res://rig/anims.gd")
```

並把 `build()` 結尾的 `return root` 換成：

```gdscript
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	root.add_child(ap)
	ap.owner = root
	ap.add_animation_library("", Anims.make_library(rig, bones, root))
	return root
```

- [ ] **Step 4: 執行測試**

Expected：4 項新測試 PASS，`SUMMARY pass=18 fail=0`。

若 `test_joints_covered_in_every_key` 失敗：
1. 先看是哪個關節、哪個影格。若靜止姿勢（idle 的第 0 格）就失敗，是對照表的點不準，回 Task 2 Step 4 修正。
2. 若只在大角度的影格失敗，先把該影格的角度往靜止姿勢收 10～20°，再跑一次。
3. 收到角度已經失去動作意義仍失敗時，判定為分件本身的關節圓弧不夠（問題 1 的結論之一）：把該關節列入補生成清單，並以裁定把該關節在該影格的門檻放寬到 75%（寫進 ledger 與報告），不要直接刪掉測試。

- [ ] **Step 5: 重新產生場景**

```bash
cd '<repo>/prototypes/p4-art-pipeline'
godot --headless --path . -- --build-rig > /tmp/p4_build.txt 2>&1; rc=$?; grep -E 'BUILD|ERROR' /tmp/p4_build.txt; echo "rc=$rc"
```

Expected：`BUILD … err=0`。（Task 4 之後沒有人手動改過場景，不需要 `--force`；若被拒絕，代表場景被改過，先查明再決定。）再跑一次驗證命令，`SUMMARY pass=18 fail=0`。

- [ ] **Step 6: Commit**

```bash
cd '<repo>'
git add prototypes/p4-art-pipeline
git commit -m "Add idle, run and axe side attack with stepped/smooth toggle (MV-PROTO-004)"
```

---

### Task 6: 仿戰鬥展示畫面、灰階、一致性對照、截圖

**Files:**
- Create: `prototypes/p4-art-pipeline/showcase.gd`
- Modify: `prototypes/p4-art-pipeline/main.gd`（整個替換）
- Test: `tests/self_test.gd`（追加）

**Interfaces:**
- Consumes：`hunahpu.tscn`、`rig.gd`、`anims.gd`
- Produces：`showcase.gd`（Node2D）：欄位 `rig`、`heroes: Array`（3 個，依序播 idle／run／axe_side）、`preview`、`showcase_view`、`consistency_view`、`gray: ColorRect`、`smooth: bool`；方法 `toggle_gray()`、`toggle_smooth()`、`set_view(name: String)`（`"showcase"`／`"consistency"`）、`preview_play(name)`、`freeze_for_capture()`、`capture_image(path) -> void`（async）；`main.gd` 的 `--screenshot <資料夾>` 與預設啟動

- [ ] **Step 1: 寫測試**

在 preload 區加入：

```gdscript
const Showcase := preload("res://showcase.gd")
```

在檔案末尾加入：

```gdscript
# ---- Task 6：展示畫面 ----

func test_showcase_heroes_are_180px() -> void:
	var sc := Showcase.new()
	add_child(sc)
	await frames(2)
	check(sc.heroes.size() == 3, "應有三個 180 px 的角色")
	for h in sc.heroes:
		check(absf(h.scale.y * sc.rig.body_height() - Showcase.TARGET_HEIGHT) < 1.0, "角色高度應約 180 px")
	var names := sc.heroes.map(func(h): return h.get_node("Anim").current_animation)
	check(names == ["idle", "run", "axe_side"], "三個角色應依序播待機、跑、斧頭側攻，實際 %s" % [names])
	sc.queue_free()
	await frames(1)


func test_showcase_toggles() -> void:
	var sc := Showcase.new()
	add_child(sc)
	await frames(2)
	sc.toggle_gray()
	check(sc.gray.visible, "按 G 應開啟灰階")
	sc.toggle_gray()
	check(not sc.gray.visible, "再按 G 應關閉灰階")
	sc.toggle_smooth()
	var a: Animation = sc.heroes[1].get_node("Anim").get_animation("run")
	check(a.track_get_interpolation_type(0) == Animation.INTERPOLATION_LINEAR, "按 T 應切成平滑內插")
	sc.toggle_smooth()
	check(a.track_get_interpolation_type(0) == Animation.INTERPOLATION_NEAREST, "再按 T 應切回不內插")
	sc.set_view("consistency")
	check(sc.consistency_view.visible and not sc.showcase_view.visible, "應切到一致性對照")
	sc.set_view("showcase")
	check(sc.showcase_view.visible and not sc.consistency_view.visible, "應切回展示畫面")
	sc.queue_free()
	await frames(1)
```

- [ ] **Step 2: 執行測試，確認失敗**

Expected：`Parse Error`（`res://showcase.gd` 不存在）。

- [ ] **Step 3: 實作展示畫面與進入點**

`prototypes/p4-art-pipeline/showcase.gd`：

```gdscript
extends Node2D
# 展示畫面（PROTO4-3）：MV-PROTO-001 戰鬥房配色、三個 180 px 的 Hunahpu（待機／跑／斧頭側攻）、
# 假光造物灰盒與前搖訊號、右側 450 px 的放大預覽；一致性對照畫面：基準圖、組好的站姿、兩者疊合。
# 操作：1／2／3 預覽切換動作、T 平滑內插、G 灰階、Tab 切換畫面、F12 截圖到 user://shots

const Rig := preload("res://rig/rig.gd")
const Anims := preload("res://rig/anims.gd")
const SCENE_PATH := "res://hunahpu.tscn"
const TARGET_HEIGHT := 180.0
const PREVIEW_HEIGHT := 450.0
const COMPARE_HEIGHT := 700.0
const GROUND_Y := 900.0
const GROUND := Color(0.22, 0.27, 0.25)
const GOLD := Color(0.95, 0.8, 0.35)
const SAW := Color(0.35, 0.1, 0.45)
const AXE_REPLAY := 1.0  # 斧頭側攻不循環，每秒重播一次
const GRAY_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec3 c = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	COLOR = vec4(vec3(dot(c, vec3(0.299, 0.587, 0.114))), 1.0);
}
"""

var rig
var heroes: Array = []
var preview: Node2D
var showcase_view := Node2D.new()
var consistency_view := Node2D.new()
var gray: ColorRect
var smooth := false
var _axe_time := 0.0


func _ready() -> void:
	rig = Rig.new()
	rig.load_file()
	var scene: PackedScene = load(SCENE_PATH)
	add_child(showcase_view)
	add_child(consistency_view)
	consistency_view.visible = false
	_build_showcase(scene)
	_build_consistency(scene)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	gray = ColorRect.new()
	gray.set_anchors_preset(Control.PRESET_FULL_RECT)
	gray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GRAY_SHADER
	mat.shader = sh
	gray.material = mat
	gray.visible = false
	layer.add_child(gray)


func _build_showcase(scene: PackedScene) -> void:
	var ground := ColorRect.new()
	ground.color = GROUND
	ground.position = Vector2(0, GROUND_Y)
	ground.size = Vector2(1920, 1080 - GROUND_Y)
	showcase_view.add_child(ground)
	var k := TARGET_HEIGHT / rig.body_height()
	var names := ["idle", "run", "axe_side"]
	for i in 3:
		var h: Node2D = scene.instantiate()
		h.scale = Vector2(k, k)
		h.position = Vector2(250 + i * 230, GROUND_Y)
		showcase_view.add_child(h)
		h.get_node("Anim").play(names[i])
		heroes.append(h)
	# 假光造物灰盒：爬行型（白色圓形＝可招架）、飛行型（暗紫鋸齒＝不可招架）
	_box(Vector2(1000, GROUND_Y - 70), Vector2(110, 70))
	_circle(Vector2(1055, GROUND_Y - 120), 24.0)
	_box(Vector2(1210, GROUND_Y - 330), Vector2(90, 60))
	_saw(Vector2(1255, GROUND_Y - 380))
	preview = scene.instantiate()
	var kp := PREVIEW_HEIGHT / rig.body_height()
	preview.scale = Vector2(kp, kp)
	preview.position = Vector2(1650, GROUND_Y)
	showcase_view.add_child(preview)
	preview.get_node("Anim").play("idle")


func _build_consistency(scene: PackedScene) -> void:
	var k := COMPARE_HEIGHT / rig.body_height()
	var g: Vector2 = rig.ground()
	var base_y := 960.0
	var ref_tex: Texture2D = load("res://art/chr_hunahpu_reference.png")
	for i in 3:
		var x := 360.0 + i * 600.0
		if i != 1:  # 左：基準圖；右：基準圖半透明＋組好的角色疊合
			var ref := Sprite2D.new()
			ref.texture = ref_tex
			ref.centered = false
			ref.scale = Vector2(k, k)
			ref.position = Vector2(x, base_y) - g * k
			ref.modulate.a = 1.0 if i == 0 else 0.45
			consistency_view.add_child(ref)
		if i != 0:  # 中：組好的站姿（不播動作）
			var h: Node2D = scene.instantiate()
			h.scale = Vector2(k, k)
			h.position = Vector2(x, base_y)
			consistency_view.add_child(h)


func _box(at: Vector2, size: Vector2) -> void:
	var r := ColorRect.new()
	r.color = GOLD
	r.position = at
	r.size = size
	showcase_view.add_child(r)


func _circle(at: Vector2, radius: float) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		pts.append(at + Vector2.from_angle(TAU * i / 24.0) * radius)
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = Color(1, 1, 1, 0.95)
	showcase_view.add_child(p)


func _saw(at: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		pts.append(at + Vector2.from_angle(TAU * i / 12.0) * (32.0 if i % 2 == 0 else 14.0))
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = SAW
	showcase_view.add_child(p)


func _process(delta: float) -> void:
	_axe_time += delta
	if _axe_time >= AXE_REPLAY:
		_axe_time = 0.0
		for h in heroes + [preview]:
			var ap: AnimationPlayer = h.get_node("Anim")
			if ap.current_animation == "axe_side" or (ap.assigned_animation == "axe_side" and not ap.is_playing()):
				ap.stop()
				ap.play("axe_side")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_1:
			preview_play("idle")
		KEY_2:
			preview_play("run")
		KEY_3:
			preview_play("axe_side")
		KEY_T:
			toggle_smooth()
		KEY_G:
			toggle_gray()
		KEY_TAB:
			set_view("consistency" if showcase_view.visible else "showcase")
		KEY_F12:
			var stamp := Time.get_datetime_string_from_system().replace(":", "")
			await capture_image("user://shots/%s.png" % stamp)


func preview_play(name: String) -> void:
	var ap: AnimationPlayer = preview.get_node("Anim")
	ap.stop()
	ap.play(name)


func toggle_gray() -> void:
	gray.visible = not gray.visible


func toggle_smooth() -> void:
	smooth = not smooth
	Anims.set_smooth(heroes[0].get_node("Anim"), smooth)  # 各實例共用同一份動作資源


func set_view(name: String) -> void:
	showcase_view.visible = name == "showcase"
	consistency_view.visible = name == "consistency"


## 截圖用：把動作停在有代表性的影格（跑步跨步、斧頭揮到判定）
func freeze_for_capture() -> void:
	set_process(false)
	var times := {"idle": 0.25, "run": 1.0 / 12.0, "axe_side": 0.07}
	for h in heroes + [preview]:
		var ap: AnimationPlayer = h.get_node("Anim")
		var name := ap.assigned_animation
		ap.seek(times[name], true)
		ap.pause()


func capture_image(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("SHOT %s err=%d" % [path, err])
```

`prototypes/p4-art-pipeline/main.gd`：整個替換為：

```gdscript
extends Node2D
# MV-PROTO-004 美術管線（獨立、可丟棄）。規格：todo/spec/MV-PROTO-004_美術管線.md
# 使用者參數（放在 -- 之後）：
#   --self-test             執行自動測試後結束（結束碼 0＝全部通過）
#   --build-rig [--force]   依 rig/hunahpu_rig.json 產生 hunahpu.tscn；檔案被手動改過時不覆蓋，除非加 --force
#   --screenshot <資料夾>   輸出 showcase.png、showcase_gray.png、consistency.png 後結束（需有視窗）
# 沒有參數時開啟展示畫面。

const SelfTest := preload("res://tests/self_test.gd")
const Rig := preload("res://rig/rig.gd")
const Build := preload("res://rig/build_rig.gd")
const Showcase := preload("res://showcase.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--self-test" in args:
		var t := SelfTest.new()
		add_child(t)
		await t.run()
		get_tree().quit(0 if t.fail_count == 0 else 1)
		return
	if "--build-rig" in args:
		get_tree().quit(_build_rig("--force" in args))
		return
	var sc := Showcase.new()
	add_child(sc)
	var shot := args.find("--screenshot")
	if shot != -1 and shot + 1 < args.size():
		await _screenshots(sc, args[shot + 1])
		get_tree().quit()


func _build_rig(force: bool) -> int:
	var rig := Rig.new()
	if rig.load_file() != OK:
		printerr("BUILD 讀不到 %s" % Rig.PATH)
		return 1
	var root := Build.build(rig)
	if root == null:
		return 1
	var err := Build.save_scene(root, Build.OUT, Build.HASH_PATH, force)
	root.free()
	print("BUILD %s err=%d" % [Build.OUT, err])
	return 0 if err == OK else 1


func _screenshots(sc, dir: String) -> void:
	for i in 10:
		await get_tree().process_frame
	sc.freeze_for_capture()
	await sc.capture_image(dir.path_join("showcase.png"))
	sc.toggle_gray()
	await sc.capture_image(dir.path_join("showcase_gray.png"))
	sc.toggle_gray()
	sc.set_view("consistency")
	await sc.capture_image(dir.path_join("consistency.png"))
```

- [ ] **Step 4: 執行測試，確認通過**

Expected：2 項新測試 PASS，`SUMMARY pass=20 fail=0`。

- [ ] **Step 5: 截圖並目視檢查**

```bash
cd '<repo>/prototypes/p4-art-pipeline'
mkdir -p shots && godot --path . -- --screenshot "$PWD/shots" > /tmp/p4_shot.txt 2>&1; rc=$?; grep -E 'SHOT|SCRIPT ERROR|Parse Error' /tmp/p4_shot.txt; echo "rc=$rc"
```

Expected：三行 `SHOT … err=0`、`rc=0`。用 Read 逐張看 `shots/showcase.png`、`shots/showcase_gray.png`、`shots/consistency.png`：三個小角色站在地面上、斧頭在手上、跑步是跨步姿勢、斧頭揮到前方；敵人灰盒與訊號在；灰階版白色圓形與暗紫鋸齒仍分得出來；一致性對照的疊合圖，組好的角色與基準圖輪廓大致重合。斧頭方向不對時，調 `rig/hunahpu_rig.json` 裡 `wpn_axe` 的 `angle_deg`，執行 `--build-rig --force`（此時場景未經 Brian 微調，可以覆蓋）後重新截圖，直到手柄穿過拳頭、斧刃朝外。其他問題回到對應的 Task 修正（點位→Task 2、動作→Task 5、版面→本 Task）。

- [ ] **Step 6: Commit**

```bash
cd '<repo>'
git add prototypes/p4-art-pipeline
git commit -m "Add combat-like 180 px showcase, grayscale and consistency views (MV-PROTO-004)"
```

---

### Task 7: README、報告、交給 Brian

**Files:**
- Create: `prototypes/p4-art-pipeline/README.md`、`report/MV-PROTO-004_美術管線_<YYYY-MM-DD_HHmm>_執行報告.md`（取代暫停時的分析報告的角色；分析報告保留）
- Modify: `todo/spec/MV-PROTO-004_美術管線.md`（只填「Git Commit」）、`todo/todo.md`（MV-PROTO-004 狀態）、根目錄 `README.md`（原型表加一列）

- [ ] **Step 1: 寫 README**

`prototypes/p4-art-pipeline/README.md`：

````markdown
# MV-PROTO-004 美術管線（獨立、可丟棄）

> 規格：[todo/spec/MV-PROTO-004_美術管線.md](../../todo/spec/MV-PROTO-004_美術管線.md)
> 素材：`assets-test/batch0/art/`（第 0 批；不進版控）

## 要回答的問題

1. ChatGPT 生成的分件，比例、輪廓線、關節能不能一致到可以組裝？
2. 在 Godot 組一個骨架角色要多少工時？
3. 縮到 180 px 戰鬥中看不看得清楚？

## 第一次執行

```bash
cd prototypes/p4-art-pipeline
./sync_art.sh                       # 把素材複製進 art/ 並匯入
godot --path .                      # 展示畫面
```

## 操作

| 按鍵 | 作用 |
|---|---|
| 1／2／3 | 右側放大預覽切換待機／跑／斧頭側攻 |
| T | 切換「不內插（約 12 fps，預設）」與「平滑內插」 |
| G | 灰階（檢查戰鬥訊號） |
| Tab | 切換展示畫面與一致性對照（基準圖／組好的站姿／疊合） |
| F12 | 截圖到 `user://shots/` |

## 微調流程（PROTO4-1）

1. 用 Godot 編輯器開 `prototypes/p4-art-pipeline`，打開 `hunahpu.tscn`。
2. 在場景樹選骨頭（Bone2D）拖曳或改旋轉；分件（`*_art`）可改偏移、旋轉。改完存檔。
3. **重新執行 `--build-rig` 會覆蓋手動微調**：產生器發現場景被改過會拒絕覆蓋。要重新產生時，先把微調的數值回填到 `rig/hunahpu_rig.json`，再執行 `godot --headless --path . -- --build-rig --force`。
4. 記下微調花的時間，填進下面的工時表。

## 工時紀錄（驗收 2）

| 項目 | 時間 | 依據 |
|---|---|---|
| AI 組裝（量測到動作完成） | 依 commit 時間填寫 | Task 2 開始到 Task 5 commit |
| Brian 微調 | （Brian 填） | 自行記錄 |

## 自動驗證

```bash
godot --headless --fixed-fps 60 --quit-after 3600 --path . -- --self-test
```

輸出 `SELFTEST PASS|FAIL`、`CONSISTENCY`（每件縮放比例與統計）、最後 `SELFTEST SUMMARY`；出現 `SCRIPT ERROR` 也算失敗。

## 截圖（需有視窗）

```bash
godot --path . -- --screenshot "$PWD/shots"
```

輸出 `showcase.png`、`showcase_gray.png`、`consistency.png`。
````

AI 組裝工時用 `git log --format='%h %ad %s' --date=format:'%H:%M'` 讀 Task 2 第一個 commit 前後與 Task 5 commit 的時間填入（以 Task 2 開始執行的時間為起點，寫進 ledger）。

- [ ] **Step 2: 完整驗證**

執行驗證命令，Expected `SUMMARY pass=20 fail=0`、`rc=0`、無 `SCRIPT ERROR`；並重跑 Task 6 Step 5 的截圖，三張 `err=0`。

- [ ] **Step 3: 執行報告與派工單**

- 新增 `report/MV-PROTO-004_美術管線_<YYYY-MM-DD_HHmm>_執行報告.md`（frontmatter：`type: task-report`、`id: MV-PROTO-004`、`name: 美術管線（獨立）`、`status: ⏸️ 暫停`、`retry_count: 0`、`pause_reason: 等待人工決策（Brian 檢查截圖與微調）`、`started_at`、`generated_at`）。內容：產出檔案表、自動驗證結果（SUMMARY 行）、**一致性結論**（`CONSISTENCY` 輸出的統計與每件比例、補生成清單）、穿幫檢查結果（含任何放寬門檻的裁定）、三張截圖的目視結論（逐項對照 ART_SPEC 第 11 節，「兩兄弟一眼可分」標為本次不適用）、AI 組裝工時、與規格書的差異（關節不穿幫的檢查方式改為覆蓋率）、交接備註（請 Brian 看截圖、開編輯器微調並回報工時；確認後再決定是否修改 ART_SPEC 第 4 節的製作流程）。
- `todo/spec/MV-PROTO-004_美術管線.md`：「（實作完成後填寫）」換成 `git log --oneline develop..HEAD` 的清單。
- 根目錄 `README.md` 原型表加一列：`| [prototypes/p4-art-pipeline/](prototypes/p4-art-pipeline/) | MV-PROTO-004 美術管線（獨立）：實作完成，待 Brian 檢查截圖與微調 |`
- `todo/todo.md` 的 MV-PROTO-004：狀態維持 `⏸️ 暫停`，暫停原因改為 `等待人工決策（Brian 檢查截圖與微調）`，說明欄加上執行報告連結。

- [ ] **Step 4: Commit**

```bash
cd '<repo>'
git add prototypes/p4-art-pipeline README.md todo report
git commit -m "Document art pipeline prototype and hand off for review (MV-PROTO-004)"
```
