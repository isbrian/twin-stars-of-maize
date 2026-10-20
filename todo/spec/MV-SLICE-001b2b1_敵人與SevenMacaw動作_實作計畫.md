# MV-SLICE-001b2b1 敵人與 Seven Macaw 的骨架與動作：實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 爬行型、飛行型、Seven Macaw 從靜態立繪換成資料驅動的骨架與動作；Seven Macaw 的判定框、光源對到骨架，飛鏢路線經過光源就算中。

**Architecture:** `world/rig_view.gd` 的骨頭表從常數搬進每個角色的 `game/rig/{角色}_rig.json`（雙胞胎行為不變，用快照測試鎖住）；新寫通用切件工具 `tools/cut_rig.py`（雙胞胎的 p4 工具不動），從現有基準圖切分件；每種角色一個 animator 把遊戲狀態對到（動作, 時間）；Seven Macaw 的光源每幀放到頭骨上標好的點。

**Tech Stack:** Godot 4.7.2（GDScript，自測 `--self-test`）、Python 3＋numpy＋Pillow（`tools/`，`unittest`）

**Spec:** [MV-SLICE-001b2b1_敵人與SevenMacaw動作.md](MV-SLICE-001b2b1_敵人與SevenMacaw動作.md)（SLICE-b2b-1～11）

## Global Constraints

- 約 12 fps、不內插（`frame_at` 取 t ≤ 目前時間的最後一格）；不用 AnimationPlayer、不產生 `.tscn`
- 遊戲尺寸：爬行型高 70、飛行型高 60、Seven Macaw 高 450（同 b1 立繪 `fit_height`）
- 遠側件：複製近側、明度 ×0.72（`FAR_DARKEN`）
- 爬行型、飛行型的判定框與所有數值不動（SLICE-b2b-10、SLICE-b4）；Seven Macaw 只改判定框大小與光源位置，不改招式數值
- `core/` 不 preload `world/`；沒有骨架時（原型模式、`make_fight` 測試）行為照舊（`SIZE`、`LIGHT_OFFSETS`）
- `assets-test/` 不進版控；遊戲只讀 `game/art/`；`import_art.py --check`、`import_rig.py --check` 要能重現同樣位元組
- 基準：自測 306 pass；每個 Task 結束跑 `/tmp/b2a_verify.sh`（`MIN_PASS` 跟著新增的測試調高）
- 註解、文件繁體中文；commit 訊息英文、結尾 `(MV-SLICE-001b2b1)`＋Co-Authored-By

## Review Focus

1. **Seven Macaw 的基準圖面向左**（`portrait.gd` `NATIVE_LEFT`）：面向右、左時光源都落在頭件的下顎／牙／眼睛上 → Task 6 的光源測試兩個面向都跑。
2. **玩家和 Boss 重疊時射擊**（飛鏢第一幀從肩膀出發，起點就在 Boss 受擊框裡）→ 仍沿路線找光源 → Task 7 加 `test_dart_from_inside_body_finds_light`。
3. **Boss 隱藏或未參戰時**（`deactivate(hide)`、`park`、第 1 段跌落中）骨架與光源照常更新、不出錯 → Task 6 的狀態對應測試涵蓋 DOWN、INTRO、BROKEN 跌落。
4. **敵人在動作中途被打死**（`queue_free`）→ animator 是敵人的子節點一起消失、沒有 SCRIPT ERROR → Task 4 加 `test_enemy_rig_freed_with_enemy`。
5. **原型模式不變**：沒有骨架的 Seven Macaw（`make_fight`）照舊用 `SIZE` 與 `LIGHT_OFFSETS` → Task 7 加 `test_macaw_without_rig_keeps_greybox_boxes`。

## 檔案結構

| 檔案 | 責任 |
|---|---|
| `tools/cut_rig.py`（新） | 通用切件：讀 `tools/rig_src/{角色}_joints.json`，輸出分件到 `assets-test/chr_b2b1/parts/`、來源尺寸的 `tools/rig_src/{角色}_rig.json` |
| `tools/test_cut_rig.py`（新） | 切件工具單元測試（合成圖） |
| `tools/rig_src/{crawler,flyer,sevenmacaw}_joints.json`（新） | AI 標的關節、骨頭表、多邊形、光點、受傷頭的對位點 |
| `tools/import_rig.py` | 雙胞胎寫入 `bones`／`origin`／`anims`；新增三個角色（來源 `tools/rig_src/`，依目標高度縮放） |
| `tools/import_art.py` | 新增三個角色的分件條目 |
| `game/rig/{crawler,flyer,sevenmacaw}_rig.json`、`_anims.json`（新） | 骨架資料與動作資料 |
| `world/rig_view.gd` | 讀資料的骨頭表、原點、動作檔；人形專用功能依 `humanoid` 旗標；`point(name)` 取標點位置 |
| `world/enemy_animator.gd`（新） | 爬行型、飛行型：`Enemy.State` → 動作 |
| `world/macaw_animator.gd`（新） | Seven Macaw：狀態與招式階段 → 動作；換頭；光源跟著頭骨 |
| `core/boss/seven_macaw.gd` | `body_rect`（受擊框、攻擊框、招式共用）；移除 `light_reach_front`／`ART_*` 立繪常數 |
| `core/boss/moves/{beam,dive,false_flash,flail}.gd` | 用 `boss.body_rect` 取代 `boss.SIZE` |
| `core/player/dart.gd` | SLICE-b2b-5：碰到 Boss 身體後沿剩下的射程找光源（地形擋住就停） |
| `world/room.gd`、`core/boss/boss_fight.gd` | 敵人與 Seven Macaw 改掛骨架（取代 `Portrait.attach`） |
| `world/portrait.gd` | 移除三個角色的條目（`NATIVE_LEFT`、`ANCHOR_X`、`HEADS`）；只剩 b2b2 的 NPC |
| `world/rig_showcase.gd` | 展示畫面加上三個角色 |

---

### Task 1：骨頭表改成資料驅動（雙胞胎不變）

**Files:**
- Modify: `tools/import_rig.py`、`world/rig_view.gd`、`world/twin_animator.gd`、`world/rig_showcase.gd`
- Create: `game/tests/fixtures/twin_rig_snapshot.json`（改之前產生）
- Test: `game/tests/test_rig.gd`

**Interfaces:**
- Produces（rig json 新欄位）：`"bones": [[名稱, 父骨頭, 起點關節, 終點關節], ...]`（終點空字串＝固定朝下、長度用 `"root_length"`）、`"root_length": float`、`"origin": {"x_joint": String, "sole_parts": [短名, ...]}`、`"anims": "res://rig/twin_anims.json"`、`"humanoid": bool`
- Produces（`rig_view.gd`）：`build(char_id)` 不變；`static func anims_at(path: String) -> Dictionary`；`static func frame_in(path: String, anim: String, t: float) -> Dictionary`；`var anims_path: String`；`pose(anim, t)` 用自己的 `anims_path`；`func point(n: String) -> Vector2`（骨架座標，Task 5 用）。保留 `anims()`、`frame_at()` 當雙胞胎的捷徑（＝`anims_at(ANIMS_PATH)`）

- [ ] **Step 1：產生快照** — 用目前的程式（還沒改）寫暫時腳本或測試，對兩兄弟、`twin_anims.json` 每個動作每一格、面向 ±1：記下每根骨頭 `_rig_xf` 與每個分件 `transform`（6 個數字），存成 `game/tests/fixtures/twin_rig_snapshot.json`；吹射覆寫取 `dart` 0°、90°、180° 三個角度也存
- [ ] **Step 2：寫失敗的測試** `test_twin_rig_matches_snapshot`（逐項比對，誤差 ≤ 0.01）與 `test_rig_json_has_bone_table`（兩兄弟 rig json 有 `bones` 16 根、`humanoid == true`、`anims` 指向 `twin_anims.json`）
- [ ] **Step 3：跑測試** — 快照測試通過（還沒改）、`test_rig_json_has_bone_table` 失敗
- [ ] **Step 4：`import_rig.py` 寫入新欄位**（`BONES` 從 `rig_view.gd` 搬來；`root_length`＝60×scale；`origin`＝`{"x_joint": "hip", "sole_parts": ["foot_r", "foot_l"]}`），重產 `game/rig/*_rig.json`
- [ ] **Step 5：`rig_view.gd` 改讀資料** — 骨頭表、骨盆長度、原點（x＝`x_joint` 的 x；y＝`sole_parts` 靜止姿勢最低不透明像素）、動作檔；肩膀收邊、手勢、`NearArm`、吹射覆寫只在 `humanoid` 時建立
- [ ] **Step 6：跑全套** — 快照測試仍通過、306＋2 項全過；`import_rig.py --check` 無差異
- [ ] **Step 7：Commit** `Read the bone table from rig data (MV-SLICE-001b2b1)`

### Task 2：通用切件工具

**Files:**
- Create: `tools/cut_rig.py`、`tools/test_cut_rig.py`

**Interfaces:**
- Consumes：`prototypes/p4-art-pipeline/tools/cut_parts.py` 的 `key_magenta`、`crop_part`、`darken`、`grow`、`polygon_mask`、`seg_dist`（import，不改那支）
- Produces：`cut(char: str, src_dir: Path, out_dir: Path) -> dict`（回傳來源尺寸的 rig dict，同時寫 PNG 與 `tools/rig_src/{char}_rig.json`）；CLI `python3 tools/cut_rig.py crawler flyer sevenmacaw`
- joints json 格式：`{"src": "batch2/chr/xxx.png", "joints": {名稱: [x, y]}, "bones": [[骨頭, 父, 起點, 終點, 分配半徑, z], ...], "polys": {分件: [[x, y], ...]}, "far": [[分件, 骨頭, 複製自, z, [dx, dy]], ...], "cap": 關節重疊半徑, "points": {名稱: {"bone": 骨頭, "at": [x, y]}}, "origin": {...}, "heads": {...}}`（`heads` 見 Task 5）
- 輸出的 rig json：`{"reference": {"size", "joints", "content_height"}, "bones": [...4 欄], "root_length", "origin", "parts": {短名: {"size", "bone", "pivot", "tip", "z"[, "visible"]}}, "points": {名稱: {"bone", "at"（骨頭座標）}}}`

- [ ] **Step 1：寫失敗的測試**（合成 200×120 洋紅底圖：左方塊「身體」、右細長方塊「腿」）
  - `test_pixels_go_to_nearest_bone`：身體、腿兩件的像素各在自己那邊
  - `test_poly_overrides_distance`：腿的 `polys` 圈進一塊靠近身體的區域，那塊歸腿
  - `test_joint_cap_overlaps`：兩件在共用關節半徑 `cap` 內都有不透明像素
  - `test_far_copy_darkened_and_offset`：`far` 件＝近側件明度 ×0.72，關節偏移 `[dx, dy]`
  - `test_points_in_bone_space`：標點換成骨頭座標後，用骨頭變換換回來＝原座標（±0.5）
  - `test_content_height`：`content_height`＝不透明像素的高
  - `test_deterministic`：跑兩次輸出位元組相同
- [ ] **Step 2：跑** `python3 -m unittest tools/test_cut_rig.py` → 失敗（沒有模組）
- [ ] **Step 3：實作** — 每個不透明像素歸給 `seg_dist − 半徑` 最小的骨段；`polys` 依列出順序優先；關節重疊照 `cut_parts.py` 第 3 步（關節圓內帶進相鄰件的像素）；`far` 複製、降明度、關節加偏移
- [ ] **Step 4：跑測試** → 全過
- [ ] **Step 5：Commit** `Add a generic rig cutter (MV-SLICE-001b2b1)`

### Task 3：爬行型、飛行型的分件與骨架

**Files:**
- Create: `tools/rig_src/{crawler,flyer}_joints.json`、`tools/rig_src/{crawler,flyer}_rig.json`（工具產生）、`game/rig/{crawler,flyer}_rig.json`、`game/art/chr/parts/{crawler,flyer}/*.png`
- Modify: `tools/import_rig.py`（`TARGETS = {"crawler": 70, "flyer": 60, "sevenmacaw": 450}`，k＝目標高 ÷ `content_height`）、`tools/import_art.py`（分件條目）
- Test: `game/tests/test_enemy_rig.gd`（新）

- [ ] **Step 1：標關節** — 在原圖上標關節、骨頭表、需要的 `polys`；用暫時腳本把關節與骨段畫在圖上存到 `assets-test/chr_b2b1/check/`，自己看截圖確認每條腿、每片翼都被骨段涵蓋
- [ ] **Step 2：寫失敗的測試**（`test_enemy_rig.gd`，兩種各跑）
  - `test_enemy_rig_assembles`：每個分件都在；靜止姿勢不透明範圍高度＝目標（±5%）；底部對齊原點（±1 px）
  - `test_enemy_rig_rest_matches_reference`：靜止姿勢與 `game/art/chr/enm_falselight_*_reference.png` 疊合，不透明像素差距 ≤ 2 px（同 `test_rig_rest_matches_reference` 的做法）
- [ ] **Step 3：跑** → 失敗（沒有 rig）
- [ ] **Step 4：切件、匯入** — `python3 tools/cut_rig.py crawler flyer`、`python3 tools/import_rig.py`、`python3 tools/import_art.py`；看組好的截圖有沒有接縫（遠側、重疊處）
- [ ] **Step 5：跑測試** → 通過；`import_art.py --check`、`import_rig.py --check`、`tools/test_import_art.py` 通過
- [ ] **Step 6：Commit** `Cut and import the crawler and flyer rigs (MV-SLICE-001b2b1)`

### Task 4：爬行型、飛行型的動作與接進遊戲

**Files:**
- Create: `game/rig/{crawler,flyer}_anims.json`、`world/enemy_animator.gd`
- Modify: `world/room.gd`（`ENEMY_PORTRAITS` → 骨架）、`core/boss/boss_fight.gd:391`（召喚的造物）、`world/portrait.gd`（移除兩種敵人）
- Test: `game/tests/test_enemy_rig.gd`

**Interfaces:**
- Produces：`enemy_animator.gd`：`static func attach(e: Node2D, char_id: String) -> Node`（建 `RigView` 為敵人子節點、`show_behind_parent`、設 `e.portrait_drawn = true`）；`func choose(e) -> Array`（`[動作, 時間]`）
- 動作名（兩種共用）：`idle`（循環）、`telegraph`、`attack`、`recover`、`stagger`

- [ ] **Step 1：寫失敗的測試**
  - `test_enemy_state_to_anim`：IDLE→`idle`、TELEGRAPH→`telegraph`、ATTACK→`attack`、RECOVER→`recover`、STAGGER→`stagger`；時間＝`state_time`（`idle` 用累計時鐘）
  - `test_enemy_anims_present`：兩種的動作檔都有上面 5 個動作；`idle` 是循環
  - `test_enemy_joints_covered_in_every_frame`：同 `test_joints_covered_in_every_frame` 的做法，關節對到兩側分件
  - `test_enemy_rig_faces_and_tints`：面向翻轉（`scale.x`）；受擊閃白、硬直顏色經 `Tint.of(e)`
  - `test_enemy_rig_freed_with_enemy`（Review Focus 4）：攻擊中 `kill()`，下一幀沒有殘留骨架、沒有錯誤
  - `test_room_enemies_use_rigs`：森林房間的敵人有骨架、沒有 `Portrait`
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：寫動作資料**（AI 編關鍵姿勢：爬行型走路腿交替、前搖縮身、撲伸長、收招回位、硬直歪斜；飛行型翼上下拍、前搖翼收、俯衝翼貼身）與 `enemy_animator.gd`；房間與召喚改用 `EnemyAnimator.attach`
- [ ] **Step 4：跑全套** → 通過（含 `test_walkthrough`）
- [ ] **Step 5：Commit** `Animate the crawler and flyer (MV-SLICE-001b2b1)`

### Task 5：Seven Macaw 的分件、受傷的頭、光點

**Files:**
- Create: `tools/rig_src/sevenmacaw_joints.json`、`game/rig/sevenmacaw_rig.json`、`game/art/chr/parts/sevenmacaw/*.png`
- Modify: `tools/cut_rig.py`（`heads`）、`tools/test_cut_rig.py`、`tools/import_rig.py`、`tools/import_art.py`
- Test: `game/tests/test_macaw_rig.gd`（新）

**Interfaces:**
- `heads` 格式：`{"jawhurt": {"src": "batch2/chr/enm_sevenmacaw_head_jawhurt.png", "marks": [[x, y], [x, y]]}, ...}`＋主圖上的 `"head_marks": [[x, y], [x, y]]`（同樣兩個特徵點，例如上喙尖、上喙與頭的交界）
- 產出的分件短名：`head`、`head_jawhurt`、`head_maize`、`head_blind`（後三件 `visible: false`，同掛 `head` 骨）
- 光點：`points` 的 `jaw`、`teeth`、`eye`（掛 `head` 骨）
- 遠側翅膀：`far` 複製近側翅膀各節

- [ ] **Step 1：寫失敗的 Python 測試** `test_head_variant_aligned_and_masked`：合成「頭」與放大 2 倍、平移的「受傷頭」，對位後兩個特徵點誤差 ≤ 1 px；輸出範圍不超出完整頭的範圍（長 6 px）
- [ ] **Step 2：實作 `heads`** — 兩點算縮放＋平移（不旋轉），貼到主圖座標，用完整頭件的不透明範圍（往外長 6 px）裁切
- [ ] **Step 3：標關節**（骨盆、軀幹、脖子、頭、近側翅膀三節、尾羽、兩腿各三節、光點、受傷頭對位點），畫檢查圖自己看
- [ ] **Step 4：寫失敗的 Godot 測試**
  - `test_macaw_rig_assembles`：分件齊全；高度 450（±5%）；腳爪底部對齊原點
  - `test_macaw_rig_rest_matches_reference`：與 `enm_sevenmacaw_reference.png`（面向左）疊合 ≤ 2 px
  - `test_macaw_points_on_head`：靜止姿勢 `point("jaw")`、`point("teeth")`、`point("eye")` 與 b1 量的立繪位置（`ART_LIGHT_OFFSETS`，面向右換算）差 ≤ 8 px
- [ ] **Step 5：切件、匯入、跑測試** → 通過；看組好的截圖（遠側翅膀、受傷頭接縫）
- [ ] **Step 6：Commit** `Cut and import the Seven Macaw rig (MV-SLICE-001b2b1)`

### Task 6：Seven Macaw 的動作、換頭、光源跟著頭骨

**Files:**
- Create: `game/rig/sevenmacaw_anims.json`、`world/macaw_animator.gd`
- Modify: `core/boss/boss_fight.gd:110`（`Portrait.attach(boss, ...)` → `MacawAnimator.attach(boss)`）、`core/boss/seven_macaw.gd`（`set_appearance` 不再找 `Portrait`；`_place_light` 在 `portrait_drawn`（有美術）時不動光源，由 animator 放）、`world/portrait.gd`（移除 Seven Macaw 條目）
- Test: `game/tests/test_macaw_rig.gd`

**Interfaces:**
- Produces：`macaw_animator.gd`：`static func attach(boss) -> Node`；`func choose(b) -> Array`；每幀在 Boss 之後：擺姿勢、依 `b.appearance` 顯示頭件（0 `head`、1 `head_jawhurt`、2 `head_maize`、3 `head_blind`）、`b.light.position = 骨架座標的 point(["jaw", "teeth", "eye"][b.phase - 1]) 換到 Boss 座標`
- `attach` 設 `boss.portrait_drawn = true`（沿用既有旗標：不畫灰盒身體、第 1 段破綻時跌落）
- 動作名：`idle_perch`、`idle_ground`、`fly`、`eat`、`throw`、`dive`、`flail`、`spread`、`wail`、`beam`、`stagger`、`fall`、`down`

- [ ] **Step 1：寫失敗的測試**
  - `test_macaw_state_to_anim`：表列每個（狀態、招式名、`move.step`）對到規格的動作：GAP／DOWN／INTRO 依高度→`idle_perch`／`idle_ground`；各招移動階段→`fly`；`eat_fruit`→`eat`；`throw_fruit`→`throw`；`dive`、`throne_charge`、`stagger_pounce`→`dive`；`flail`→`flail`；`false_flash`、`summon`→`spread`；`wail`→`wail`；`beam`→`beam`；INTERRUPTED、BROKEN→`stagger`；BROKEN 跌落中→`fall`（Review Focus 3 的 DOWN、INTRO、跌落都在表裡）
  - `test_macaw_anims_present`、`test_macaw_joints_covered_in_every_frame`
  - `test_macaw_light_on_head_every_frame`（Review Focus 1）：每個動作每一格、面向 ±1、三段，光源位置＝頭骨上的標點（±4 px）
  - `test_macaw_head_swaps_with_appearance`：appearance 0～3 各只顯示對應的頭件
  - `test_boss_fight_uses_macaw_rig`：`gs_fight()` 的 Boss 有骨架、沒有 `Portrait`
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：寫動作資料與 `macaw_animator.gd`**；接進 `boss_fight.gd`
- [ ] **Step 4：跑全套** → 通過（`test_portraits` 的光源測試此時可能因判定框未改而失敗，記下、Task 7 處理）
- [ ] **Step 5：Commit** `Animate Seven Macaw and move his lights with the head (MV-SLICE-001b2b1)`

### Task 7：Seven Macaw 判定框與「身體不擋光源」

**Files:**
- Modify: `core/boss/seven_macaw.gd`、`core/boss/moves/{beam,dive,false_flash,flail}.gd`、`core/player/dart.gd`、`world/macaw_animator.gd`（設 `body_rect`）
- Test: `game/tests/test_portraits.gd`、`game/tests/test_boss.gd`、`game/tests/test_macaw_rig.gd`

**Interfaces:**
- Seven Macaw：`var body_rect := Rect2(-SIZE.x / 2.0, -SIZE.y, SIZE.x, SIZE.y)`；`func set_body_rect(r: Rect2) -> void`（同時改受擊框、`configure_body_hitbox()` 的攻擊框）；移除 `ART_HURT`、`ART_LIGHT_OFFSETS`、`ART_LIGHT_REACH`、`light_reach_front`；`portrait_drawn` 的 setter 不再改受擊框與光源
- `MacawAnimator.BODY`：從骨架站姿量「軀幹、骨盆、兩腿」分件（不含頭、脖子、翅膀、尾羽）的不透明外框（面向右、相對原點），寫成常數
- `dart.gd`：移除 `BODY_LOOKAHEAD`、`_lookahead`；碰到受擊框時，光源射線延伸到 `to + direction × (dart_range − traveled)`，但先用 `L.WORLD` 射線找地形、延伸只到地形為止

- [ ] **Step 1：寫失敗的測試**
  - `test_macaw_body_matches_rig`：`MacawAnimator.BODY` 等於從骨架量出來的外框（±2 px）；`boss.body_rect`、受擊框、攻擊框都等於它
  - 改 `test_macaw_light_from_close_front_not_from_behind` → `test_macaw_light_from_front_back_and_close`：三段，正面（近 100、遠 400）、背後（250）、近距離往上都射得中；第 2 段低台下（150）被平台擋（光源 0）
  - `test_macaw_body_hit_when_path_misses_light`：瞄準腳（路線不經過光源）→ 身體 1、光源 0
  - `test_dart_from_inside_body_finds_light`（Review Focus 2）：角色站在 Boss 受擊框裡往頭射 → 光源 1
  - 改 `test_boss.test_dart_from_behind_does_not_hit_front_light` → `test_dart_through_body_hits_light_behind`（假 Boss：路線穿過身體到另一側的光源 → 光源 1、身體 0）
  - `test_macaw_moves_still_hit_and_dodge`：俯衝、撞寶座、失衡撲擊、亂揮翅膀打得到站著的角色；翻滾（無敵）閃得掉；光束跳得過（沿用 `test_boss` 既有的招式測試，Boss 改成有骨架的 `gs_fight()` 再跑一次）
  - `test_macaw_without_rig_keeps_greybox_boxes`（Review Focus 5）：`make_fight()` 的 Boss `body_rect` 是 `SIZE`、光源在 `LIGHT_OFFSETS`
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作** — `seven_macaw.gd` 的 `body_rect`／`set_body_rect`；招式裡 `boss.SIZE` 改 `boss.body_rect`（`beam` 的前端 x、`dive` 的半寬、`false_flash` 的中心、`flail` 的偏移）；`dart.gd` 延伸查光源；`macaw_animator.attach` 呼叫 `set_body_rect(BODY)`
- [ ] **Step 4：跑全套** → 通過；掃描各距離射中範圍（同 MV-TUNE-001 的偵查做法，記進報告）
- [ ] **Step 5：Commit** `Fit Seven Macaw's boxes to his rig and let darts reach lights past his body (MV-SLICE-001b2b1)`

### Task 8：展示畫面、影片、文件

**Files:**
- Modify: `world/rig_showcase.gd`、`game/README.md`、`ART_SPEC.md`（第 6 節實作狀態）、`world/portrait.gd` 註解
- Test: `game/tests/test_rig.gd`（`test_showcase_playlist_covers_all`）

- [ ] **Step 1：寫失敗的測試** — `test_showcase_playlist_covers_all` 改成涵蓋每個角色動作檔的每個動作（雙胞胎、爬行型、飛行型、Seven Macaw，含四種頭）
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作** — 雙胞胎播完接著三個角色；Seven Macaw 依序換四種頭
- [ ] **Step 4：跑全套、`--shots`、錄影** — `godot --path game -- --rig-view --frames <資料夾>` 彩色與灰階、ffmpeg 合成到 `assets-test/b2b1_video/`；AI 抽格看接縫與光點
- [ ] **Step 5：文件** — `game/README.md` 骨架一節加三個角色與 `tools/cut_rig.py` 用法；ART_SPEC 第 6 節實作狀態；規格書驗收打勾
- [ ] **Step 6：Commit** `Show the new rigs in the showcase and document them (MV-SLICE-001b2b1)`
