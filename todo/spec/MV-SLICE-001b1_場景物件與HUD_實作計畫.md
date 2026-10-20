# MV-SLICE-001b1 場景、物件與 HUD 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `game/` 的灰盒色塊換成正式美術的場景（四層視差）、地形與物件素材、HUD 素材與角色靜態立繪，玩法與碰撞完全不變。

**Architecture:** `tools/import_art.py` 把 `assets-test/` 的定稿處理成遊戲尺寸寫進 `game/art/`（固定輸出、附 `MANIFEST.md`）。房間資料多一個 `theme`，`world/scenery.gd` 的主題表決定四層圖與視差，`world/scenery_view.gd` 用 `Parallax2D` 組出圖層並依地形資料擺上平台、荊棘、路標等素材；Boss 段落依鏡頭 x 切換三個區段的圖層。角色掛一個 `world/portrait.gd`（`Sprite2D`，畫在父節點後面），原本的灰盒身體色塊不畫，戰鬥訊號照舊畫在上面。

**Tech Stack:** Godot 4.7.2（GDScript、`Parallax2D`、`Sprite2D`）；Python 3、Pillow 9.5、numpy 2.0（匯入工具）；Codex CLI `image_gen`（MV-ASSET-014）。

**Spec:** [todo/spec/MV-SLICE-001b1_場景物件與HUD.md](MV-SLICE-001b1_場景物件與HUD.md)（定案 SLICE-b1～b12）；上層 [MV-SLICE-001 總規格](MV-SLICE-001_垂直切片.md)；美術規則 [ART_SPEC.md](../../ART_SPEC.md)。

## Global Constraints

- 引擎 Godot 4.7.2；`prototypes/` 一律不改；`assets-test/` 只讀，唯一例外是 MV-ASSET-014 的生成結果寫進 `assets-test/b1_props/`。
- 碰撞框、受擊框、所有 `combat_tuning.gd` 數值與 `seven_macaw.gd` 的 `SIZE` 不動（SLICE-b4、SLICE-b12）；素材只負責畫。
- 定稿成品放 `game/art/{bg,prop,ui,chr}/` 並 commit；prompt、原始輸出、各輪版本留在 `assets-test/`（SLICE-b2）。`game/art/` 總大小 ≤ 50 MB；放大不超過 2 倍（ART_SPEC 第 3 節）。
- 視差倍率：遠景 0.2、中景 0.6、地表 1.0、前景 1.15；nance 樹與宮殿後牆例外用 1.0（SLICE-b5 與規格「例外」）。地表條上緣對齊碰撞地面 y＝900。
- 前景圖中央寬、高各 2/3 的範圍 Alpha 全為 0（ART_SPEC 第 5 節、MV-ASSET-002 A1-05）。
- 夜晚、Boss 拔掉光源變暗只用引擎調色（`modulate`），不另外生成（ART_SPEC 第 4 節第 5 步）。
- 吹箭、反光柱、光束、白茫、招架光環、裂紋、前搖輪廓等特效維持程式繪製（屬子專案 c）。
- Seven Macaw 立繪站高約 450 px，判定不動（SLICE-b12）；雙胞胎立繪約 180 px。
- 程式註解與 UI 文字用繁體中文；commit 訊息用英文、句首大寫、結尾 `(MV-SLICE-001b1)`。
- 自測輸出格式照 a；測試不動 `Tune.data`、不寫 `.tres`、只寫 `user://test_*`。
- 驗證指令（每個 Task 結尾都跑）：
  - `godot --headless --path game -- --self-test 2>&1 | grep -E "SELFTEST (FAIL|SUMMARY)|SCRIPT ERROR|Parse Error|flushing queries"`：通過＝`fail=0` 且沒有其他三種字串。
  - `python3 -m unittest tools/test_import_art.py`（Task 2 起）：`OK`。
- MV-ASSET-014 照 Codex 交派慣例：`/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex exec -s workspace-write --ephemeral --color never -C <repo> -o <out> "<指示>" < /dev/null`；指示寫明非互動、不要徵求同意、prompt 一字不改、每則附圖 ≤ 5 張、不縮放裁切、只寫 `assets-test/b1_props/`、不 commit、不推送、不下載外部檔案、不改驗收判定。驗收由 AI 用 Read 親眼看每張圖（Codex 自評不可信）。

## Review Focus

1. **換房、死亡回點、休息重開房間很多次**：每個房間只有一組場景圖層，不累積、不殘留上一個房間的圖層。
2. **立繪蓋住戰鬥訊號**：前搖的輪廓、可／不可招架的訊號、招架光環、Boss 裂紋必須畫在立繪上面（立繪 `show_behind_parent`）。
3. **兩個畫面寬的房間，鏡頭在左右兩端**：遠景、中景、前景都不露出空白（重複的範圍蓋得住）。
4. **Boss 死亡重試或從宮殿篝火「繼續」**：Seven Macaw 的外觀（換頭）與場地暗度和目前段落一致，不會回到完整外觀或全亮。
5. **受擊閃白、無敵半透明、翻滾半透明**：在立繪上仍看得到（同灰盒的閃爍規則）。

---

### Task 1: MV-ASSET-014 素材工單、生成與驗收

**Files:**
- Create: `docs/assets/MV-ASSET-014_素材工單_場景物件補件.md`
- Create（不進版控）：`assets-test/b1_props/`（10 件定稿＋各輪版本＋`LOG.md`）、`assets-test/b1_props/check.py`

**Interfaces:**
- Produces（`assets-test/b1_props/`）：`bg_yard_mid_01.png`（1536×1024、透明、左右接縫）、`prop_platform_log.png`（左右可接續）、`prop_thorns_wall.png`、`prop_arena_gate.png`（上下可接續）、`prop_palace_ledge.png`、`prop_palace_barrier.png`、`prop_waymark.png`、`prop_field_bush.png`、`prop_field_clod.png`、`prop_net.png`；物件都是透明背景。Task 2 的對照表以這些檔名為來源。

- [ ] **Step 1: 寫工單**：10 則照 ART_SPEC 第 10 節四段式；每則寫明用途、遊戲中的尺寸（平台 30 高、荊棘 120 寬、閘門 40 寬、高台 700×950、障壁 60×960、路標約 140 高、灌木約 140 高、土塊約 70 高、網子約 120 寬）、接續方向、附圖（≤ 5 張：同區既有場景＋相關角色基準圖）、禁項（ART_SPEC 第 2 節、CULTURAL_PRINCIPLES：無可辨識符號、無太陽圖樣、無東亞造型；不用紅色、暗紫、大片高亮白）。障壁的造型依 MV-BOSS-001（宮殿出口前、覺醒後由「讓工具自己動」打破）寫成擋路的寶座區屏障；網子同 Xbalanque 獵網材質。
- [ ] **Step 2: 寫 `check.py`**：對每件印出尺寸、是否透明、接續方向的邊緣像素差（左右或上下第一與最後一列，目標 0）、禁色比例（紅、暗紫 HSV 285～320°、近白），格式同 `assets-test/book_check.py`。
- [ ] **Step 3: 交派 Codex 生成**（每件最多 3 次、選最佳一張存成正式檔名，其餘留 `.vN.png`）。
- [ ] **Step 4: 驗收**：跑 `python3 assets-test/b1_props/check.py`，再用 Read 逐張看並和既有場景並排、縮到遊戲尺寸看。接續方向邊緣差不為 0 時用 `tools/seam_fix.py` 修。不通過且需要改設計時**停下來請 Brian 決定**（附推薦）。
- [ ] **Step 5: 工單寫入驗收結果，commit** `Add work order MV-ASSET-014 for the slice's missing scenery and props (MV-SLICE-001b1)`（只 commit `docs/assets/`）。

### Task 2: 匯入工具與 `game/art/`

**Files:**
- Create: `tools/import_art.py`、`tools/test_import_art.py`、`game/art/**`（產出）、`game/art/MANIFEST.md`（產出）
- Test: `tools/test_import_art.py`

**Interfaces:**
- Produces：`tools/import_art.py` 的對照表 `ENTRIES`（list of dict：`src`（相對 repo）、`dst`（相對 `game/art/`）、下列處理之一：`height`＝整張縮到該高度、`fit_height`／`fit_width`＝裁到內容外框後縮到該高度／寬度、`fit_size`＝裁到內容外框後縮到 `[w, h]`（長寬比差 ≤ 15%，超過時改用 `fit_width` 並在 Godot 裡重複）、`scale_like`＝沿用另一筆的縮放比例；選填 `key`（洋紅去背，用 `prototypes/p4-art-pipeline/tools/cut_parts.py` 的 `key_magenta`）、`crop`（來源 px 的 `[x, y, w, h]`，先裁再縮））。`python3 tools/import_art.py` 寫入全部並重寫 `MANIFEST.md`；`--check` 只比對不寫，有差異時退出碼 1。之後的 Task 新增素材都是在 `ENTRIES` 加一筆再重跑。
- 初版 `ENTRIES`（Task 2 就要有的；尺寸是遊戲中的像素）：

| 類 | 來源（`assets-test/`） | 目的 | 處理 |
|---|---|---|---|
| bg | `batch1/art/bg_forest_far_01`、`bg_forest_mid_01`～`03`、`bg_forest_fore_01`、`bg_field_mid_01`、`bg_home_mid_01`、`bg_ballcourt_far_01` | `bg/` 同名 | `height: 1080` |
| bg | `batch1/art/bg_forest_ground_tile` | `bg/` 同名 | `scale_like: bg/bg_forest_far_01.png` |
| bg | `batch2/art/bg_nance_mid_01`、`bg_palace_back_01` | `bg/` 同名 | `height: 1080` |
| prop | `batch1/art/prop_bonfire_lit`、`prop_bonfire_unlit` | `prop/` | `fit_height: 150` |
| prop | `batch1/art/prop_cacao_bean` | `prop/` | `fit_height: 36` |
| prop | `batch1/art/prop_soup_bowl` | `prop/` | `fit_height: 64` |
| prop | `batch2/art/prop_nance_fruit` | `prop/` | `fit_height: 36` |
| prop | `batch0/art/wpn_axe`、`batch1/art/wpn_digging_stick`、`chr_batch2/wpn_ballgear_yoke` | `prop/` | `fit_height: 60`（平放在地上；球具要 `key`） |
| ui | `batch1/art/ui_health_pip_full/empty` | `ui/` | `fit_height: 40` |
| ui | `batch1/art/ui_heal_pip_full/empty` | `ui/` | `fit_height: 32` |
| ui | `batch1/art/ui_resource_frame`、`ui_resource_fill` | `ui/` | `fit_height: 24` |
| ui | `batch1/art/ui_skill_slot_frame` | `ui/` | `fit_height: 72` |
| ui | `batch1/art/ui_icon_axe`、`ui_icon_digging_stick`、`ui_icon_blowgun`、`hud_batch2/ui_icon_ballgear` | `ui/` | `fit_height: 40` |
| ui | `batch1/art/ui_icon_cacao`、`ui_icon_soup` | `ui/` | `fit_height: 32` |
| ui | `hud_batch2/ui_icon_rat` | `ui/` | `fit_height: 56` |
| chr | `chr_batch1/chr_hunahpu_reference`、`chr_xbalanque_reference` | `chr/` | `key`、`fit_height: 180` |
| chr | `chr_batch2/chr_xmucane_reference` | `chr/` | `key`、`fit_height: 165` |
| chr | `chr_batch3/chr_healer_man_reference`、`chr_healer_woman_reference` | `chr/` | `key`、`fit_height: 170`、`165` |
| chr | `chr_batch2/chr_rat_reference` | `chr/` | `key`、`fit_height: 40` |
| chr | `batch2/chr/enm_falselight_crawler_reference`、`enm_falselight_flyer_reference` | `chr/` | `key`、`fit_height: 70`、`60`（= 碰撞框高） |
| chr | `batch2/chr/enm_sevenmacaw_reference` | `chr/` | `key`、`fit_height: 450` |
| chr | `batch2/chr/enm_sevenmacaw_head_jawhurt`、`_maize`、`_blind` | `chr/` | `key`、`scale_like: chr/enm_sevenmacaw_reference.png` |

- [ ] **Step 1: Write the failing tests**（`unittest`，同 `tools/test_seam_fix.py` 的寫法）：
  - `test_import_is_deterministic`：連跑兩次，`game/art/` 每個檔案的 sha256 與 `MANIFEST.md` 都相同
  - `test_check_mode_detects_drift`：改壞一個輸出檔後 `--check` 退出碼 1
  - `test_total_size_under_budget`：`game/art/` 總大小 ≤ 50 MB
  - `test_upscale_at_most_2x`：每筆的縮放比例 ≤ 2.0
  - `test_fit_height_matches`：每筆 `fit_height` 的輸出圖內容外框高度在目標 ±1 px
  - `test_keyed_images_have_no_magenta`：`key` 的輸出沒有 R>200、G<60、B>200 且 Alpha>0 的像素
  - `test_foreground_center_transparent`：`bg/bg_forest_fore_01.png` 中央寬、高各 2/3 的 Alpha 全為 0
- [ ] **Step 2:** 跑 `python3 -m unittest tools/test_import_art.py`，Expected：import 失敗（`import_art.py` 不存在）
- [ ] **Step 3:** 實作 `tools/import_art.py`（Pillow `LANCZOS` 縮放、PNG 存檔用固定參數 `optimize=True`、不寫時間戳；`MANIFEST.md` 一列一個檔：目的、來源、處理、輸出尺寸、工單），執行一次產生 `game/art/`
- [ ] **Step 4:** 跑 unittest 與自測，Expected：`OK`、`fail=0`
- [ ] **Step 5: Commit** `Bring the finished scenery, props, HUD and portraits into the game folder (MV-SLICE-001b1)`

### Task 3: 主題表與四層視差

**Files:**
- Create: `game/world/scenery.gd`、`game/world/scenery_view.gd`
- Modify: `game/world/rooms/kit.gd`（刪 `layers`、`room()` 接受 `theme`）、`game/world/rooms/{home,field,yard,forest_1..4}.gd`（加 `theme`）、`game/world/room.gd`（建 `scenery_view`、不再畫地面色塊）、`game/events/night_rat.gd`（夜晚改調 `room.scenery.modulate`）
- Test: `game/tests/test_scenery.gd`

**Interfaces:**
- Produces（`scenery.gd`，extends RefCounted）：`const PARALLAX := {"far": 0.2, "mid": 0.6, "ground": 1.0, "fore": 1.15}`；`static func layers(theme: String, variant: int) -> Dictionary`（鍵 `far`／`mid`／`ground`／`fore`，值是 `res://art/bg/...` 路徑或 `""`）；`static func themes() -> Array`。主題：`home`、`field`、`yard`、`forest`（`variant` 0～2 對應中景 01～03）、`boss_nance`、`boss_path`、`boss_palace`（Task 6 用）。`yard` 的中景在 Task 4 換成 `bg_yard_mid_01`，Task 3 先用 `bg_forest_mid_03`。
- Produces（`scenery_view.gd`，extends Node2D）：`func build(theme: String, variant: int, room_size: Vector2) -> void`；每層一個 `Parallax2D`（`scroll_scale = Vector2(倍率, 1)`、`repeat_size.x` = 圖寬、`repeat_times` 夠蓋住房間寬加一個畫面）；地表層的 y 使圖片第一列不透明像素落在 900；`var night := false`（`true` 時 `modulate = Color(0.45, 0.5, 0.75)`，同 a 的夜晚）；`func ground_top() -> float`。
- Produces（`room.gd`）：`var scenery`（`scenery_view.gd`），`build()` 依 `d.theme`（缺省 `""` 時不建，測試房間 `_test_a`／`_test_b` 維持灰盒）。
- 房間主題：`home`→`home`、`field`→`field`、`yard`→`yard`、`forest_1..4`→`forest` 變體 0、1、2、0。

- [ ] **Step 1: Write the failing tests**：
  - `test_every_room_has_theme_and_files`：`Index.ROOMS` 裡 `kind` 不是 `boss`／`ending` 的房間都有 `theme`；`layers()` 每個非空路徑 `ResourceLoader.exists()`
  - `test_ground_top_aligns_with_floor`：每個主題建出來的 `ground_top()` 等於 900（±1）
  - `test_layers_cover_room_at_camera_limits`（Review Focus 3）：兩畫面寬的 `forest_1`，鏡頭在 `limit_left` 與 `limit_right - 1920` 時，每層 `Parallax2D` 的重複範圍蓋住 [鏡頭 x, 鏡頭 x + 1920]
  - `test_scenery_rebuilt_once_per_room`（Review Focus 1）：用 `RoomFlow` 在 `home`→`field`→`home` 來回換 5 次、休息 2 次，每次換完 `current` 底下恰好 1 個 `scenery_view`，且舊房間已釋放
  - `test_night_tints_scenery`：入夜事件開始後 `room.scenery.modulate` 等於夜色，抓到老鼠後回到白
- [ ] **Step 2:** 跑自測，Expected：`test_scenery` 失敗（`scenery.gd` 不存在）
- [ ] **Step 3:** 實作 `scenery.gd`、`scenery_view.gd`；`kit.gd`、房間檔加 `theme`；`room.gd` 建圖層、`_draw` 不再畫 `solids`（地面由地表層畫；牆在鏡頭外）
- [ ] **Step 4:** 跑自測，Expected：`fail=0`
- [ ] **Step 5: Commit** `Draw the ground rooms with layered parallax scenery (MV-SLICE-001b1)`

### Task 4: 地面房間的地形與物件素材

**Files:**
- Modify: `tools/import_art.py`（`ENTRIES` 加 MV-ASSET-014 的 10 件：`bg_yard_mid_01` `height: 1080`；平台 `fit_height: 40`、荊棘 `fit_width: 120`、閘門 `fit_width: 40`、高台 `fit_size: [700, 950]`、障壁 `fit_size: [60, 960]`、路標 `fit_height: 140`、灌木 `fit_height: 140`、土塊 `fit_height: 70`、網子 `fit_width: 120`）、`game/world/scenery.gd`（`yard` 中景換新圖）、`game/world/scenery_view.gd`、`game/world/room.gd`、`game/world/prop.gd`、`game/world/tool_pickup.gd`、`game/world/pickup.gd`、`game/world/rest_point.gd`、`game/world/float_text.gd`
- Test: `game/tests/test_scenery.gd`

**Interfaces:**
- Consumes：Task 1 的 10 件、Task 2 的 `ENTRIES`、Task 3 的 `scenery_view`
- Produces（`scenery_view.gd`）：`func place_terrain(d: Dictionary) -> void`，依房間資料擺：平台（`prop_platform_log` 橫向重複，蓋住每個 `platforms` 矩形，上緣對齊矩形上緣）、門（每扇門內側 120 px 處一個 `prop_waymark`，腳底在 900）；`func piece_rects() -> Array`（每個素材的 `{kind, rect}`，測試用）。
- Produces（`room.gd`）：每個閘門節點底下加一個名為 `Art` 的子節點（`prop_thorns_wall` 縱向重複，涵蓋閘門矩形），隨閘門釋放一起消失；`_draw` 不再畫平台、閘門、門的色塊。
- 物件：`prop.gd` 的 `bush`、`clod`、`net`、`gear` 改畫對應貼圖（`gear`＝`prop/wpn_ballgear_yoke`），`rat` 改用 `chr/chr_rat_reference`（依逃跑方向翻轉）；`tool_pickup.gd` 依 `item` 畫 `prop/wpn_axe`／`wpn_digging_stick`／`wpn_ballgear_yoke`，保留「!」提示；`pickup.gd`（藏點）畫 3 顆 `prop_cacao_bean` 疊成一小堆；`rest_point.gd` 畫 `prop_bonfire_lit`（腳底在 900）；`float_text.gd` 在數字前畫 `ui/ui_icon_cacao`。

- [ ] **Step 1: Write the failing tests**：
  - `test_platform_art_covers_collision`：`forest_1`、`forest_3` 每個平台矩形都被 `kind == "platform"` 的素材矩形水平涵蓋，素材上緣與平台上緣差 ≤ 4 px
  - `test_thorns_art_covers_gate`：`yard` 的閘門有 `Art` 子節點，其矩形涵蓋閘門矩形；`gear_obtained` 時沒有閘門也沒有 `Art`
  - `test_every_door_has_waymark`：每個地面房間的每扇門都有一個路標，水平距離門矩形 ≤ 200 px、腳底 y＝900
  - `test_props_use_textures`：`bush`、`clod`、`net`、`gear`、`rat` 與三種拾取物、藏點、篝火都有非 null 的貼圖
- [ ] **Step 2:** 跑自測，Expected：上述 4 項失敗
- [ ] **Step 3:** 加 `ENTRIES`、重跑 `python3 tools/import_art.py`，實作上述擺放與貼圖
- [ ] **Step 4:** 跑自測與 unittest，Expected：`fail=0`、`OK`
- [ ] **Step 5: Commit** `Dress the ground rooms with platforms, thorns, waymarks and props (MV-SLICE-001b1)`

### Task 5: 角色的靜態立繪

**Files:**
- Create: `game/world/portrait.gd`
- Modify: `game/core/player/player.gd`、`game/core/enemies/enemy.gd`、`game/core/boss/seven_macaw.gd`（`var portrait_drawn := false`：為 true 時 `_draw` 不畫身體色塊與「眼睛」，其餘訊號照畫）、`game/state/loadout.gd`（建角色時掛立繪）、`game/world/room.gd`（敵人、祖母）、`game/core/boss/boss_fight.gd`（Seven Macaw、召喚的造物、老夫婦）、`game/core/boss/palace_arena.gd`（入口端靜止的老夫婦）
- Test: `game/tests/test_portraits.gd`

**Interfaces:**
- Produces（`portrait.gd`，extends Sprite2D）：`static func attach(actor: Node2D, key: String) -> Sprite2D`（加一個名為 `Portrait` 的子節點，`show_behind_parent = true`、`centered = false`、`offset` 使內容外框底邊中央對齊 actor 原點（腳底），設 `actor.portrait_drawn = true`（有這個屬性時））。每幀：`flip_h` 依 `actor.facing`（< 0 翻轉；沒有 `facing` 的不翻）；玩家依 `twin_index` 換 `chr_hunahpu_reference`／`chr_xbalanque_reference`；`modulate` 照灰盒規則：受擊閃白（`flash_left > 0`）→ `Color(1.8, 1.8, 1.8)`、翻滾無敵 alpha 0.45、受擊無敵閃爍 alpha 0.3。
- Produces（Seven Macaw）：`func set_appearance(stage: int) -> void`（0 完整、1 下顎受傷、2 失去玉牙、3 失去眼睛；1～3 在頭部疊對應的替換頭，位置在實作時量基準圖的頭部對齊後寫成常數）；`boss_fight` 在 `lights_removed` 改變處（`_on_setup`、`_retry`、`start_at`、`begin_at_rest`）呼叫 `boss.set_appearance(lights_removed)`。
- 對應：玩家→雙胞胎；爬行型、飛行型→各自基準圖；Seven Macaw→`enm_sevenmacaw_reference`；`home` 的 `npc`→`chr_xmucane_reference`（面向右）；老夫婦→`chr_healer_man_reference`、`chr_healer_woman_reference`（取代 `boss_fight._draw` 與 `palace_arena` 的兩個色塊）。

- [ ] **Step 1: Write the failing tests**：
  - `test_twin_portrait_height_and_feet`：玩家立繪內容高 180±10、底邊在 y＝0（±2）；`swap` 後貼圖換成另一個人
  - `test_portrait_flips_with_facing`：`facing = -1` → `flip_h == true`；`1` → `false`
  - `test_portrait_drawn_behind_signals`（Review Focus 2）：玩家、爬行型、Seven Macaw 的 `Portrait.show_behind_parent == true`，且 `portrait_drawn == true`
  - `test_portrait_shows_hit_and_invuln`（Review Focus 5）：`flash_left > 0` 時 `modulate.r > 1`；翻滾無敵中 `modulate.a == 0.45`；受擊無敵的閃爍幀 `modulate.a == 0.3`
  - `test_macaw_appearance_follows_phase`（Review Focus 4）：`begin_at_rest("palace_camp")` 後外觀＝1；`start_at(3)`＝2；`_retry(2)`＝1；`start_at(4)`＝3
  - `test_macaw_portrait_about_450`：Seven Macaw 立繪內容高 450±10
- [ ] **Step 2:** 跑自測，Expected：上述 6 項失敗
- [ ] **Step 3:** 實作
- [ ] **Step 4:** 跑自測，Expected：`fail=0`（a 的 Boss 測試全部照舊通過）
- [ ] **Step 5: Commit** `Show the characters as still portraits until their rigs arrive (MV-SLICE-001b1)`

### Task 6: Boss 段落的場景

**Files:**
- Modify: `tools/import_art.py`（`ENTRIES` 加寶座與兩塊低台：從 `batch2/art/bg_palace_mid_01` 用 `crop` 切 3 件，`scale_like: bg/bg_palace_back_01.png`）、`game/world/scenery.gd`、`game/world/scenery_view.gd`、`game/core/boss/boss_fight.gd`、`game/core/boss/nance_arena.gd`、`game/core/boss/palace_arena.gd`、`game/core/boss/fruit.gd`
- Test: `game/tests/test_scenery.gd`

**Interfaces:**
- Consumes：Task 3、4、5
- Produces（`scenery_view.gd`）：`func build_boss() -> void`：三個區段（`boss_nance`：x < `Palace.PATH_START.x - 200`；`boss_path`：到 `Palace.LEFT`；`boss_palace`：其後）各一組圖層，`func update_region(camera_x: float) -> void` 只顯示鏡頭所在區段；`nance` 中景與宮殿後牆 `scroll_scale = Vector2(1, 1)`；nance 樹的放法讓圖上一根水平粗枝的上緣對齊 `Nance.BRANCH` 上緣（實作時量圖、寫成常數；對不上就在 BRANCH 上疊 `prop_platform_log`）；宮殿後牆的地板上緣對齊 900。
- 地形素材：`Nance.GATE` 與宮殿入口閘門→`prop_arena_gate` 縱向重複（閘門打開時隱藏）；`Palace.PLATFORMS`→兩塊低台；寶座→`THRONE_X` 處；`Palace.EXIT_LEDGE`→`prop_palace_ledge`；`Palace.BARRIER`→`prop_palace_barrier`（障壁破了就隱藏）；兩個營地→`prop_bonfire_lit`；Boss 段落左端→`prop_waymark`；`fruit.gd`→`prop_nance_fruit`。
- 暗度：`func set_darkness(lights_removed: int) -> void`，`modulate` 依 `[1.0, 0.75, 0.5, 0.3]`（灰階倍率）；`boss_fight` 在 `lights_removed` 改變處呼叫（同 Task 5 的四處）。`boss_fight._draw` 不再畫背景色塊；`nance_arena`、`palace_arena` 的 `_draw` 不再畫地形色塊。

- [ ] **Step 1: Write the failing tests**：
  - `test_boss_regions_switch_with_camera`：鏡頭在 `Nance.REST.x`、`Palace.PATH_START.x + 500`、`Palace.HOME.x` 時，分別只有 `boss_nance`、`boss_path`、`boss_palace` 可見
  - `test_boss_pieces_cover_collision`：`Nance.GATE`、`Nance.BRANCH`、`Palace.PLATFORMS`、`EXIT_LEDGE`、`BARRIER` 都被對應素材矩形涵蓋
  - `test_palace_floor_aligns`：宮殿後牆地板上緣 y＝900（±2）
  - `test_boss_darkness_follows_lights`（Review Focus 4）：`begin_at_rest("palace_camp")` 後暗度＝0.75；`start_at(3)`＝0.5；`start_at(4)`＝0.3
- [ ] **Step 2:** 跑自測，Expected：上述 4 項失敗
- [ ] **Step 3:** 實作（`import_art.py` 加 3 筆 `crop`、重跑匯入）
- [ ] **Step 4:** 跑自測與 unittest，Expected：`fail=0`、`OK`
- [ ] **Step 5: Commit** `Stage the Seven Macaw segment on the nance tree, the path and the palace (MV-SLICE-001b1)`

### Task 7: HUD 換成素材

**Files:**
- Modify: `game/ui/hud.gd`
- Test: `game/tests/test_hud_art.gd`

**Interfaces:**
- Produces（`hud.gd`）：`static func weapon_icon(w: int) -> Texture2D`（斧頭、掘棒、球具；沒有武器回傳 null）；`func pip_textures() -> Dictionary`（鍵 `health_full`、`health_empty`、`heal_full`、`heal_empty`、`res_frame`、`res_fill`、`skill_frame`、`rat`、`cacao`、`soup`）。版面同 a：血量圖示一排（x 從 40、間距 46）、治療圖示一排＋熱湯圖示與「n／2」、兩兄弟各一行（名字＋武器圖示，沒有武器顯示「—」）、可可豆圖示＋數字、技能槽框＋老鼠圖示＋3 格資源條（框＋填色；閃爍規則同 a）、目標一行。Boss 名稱與血條、破綻條維持程式繪製，顏色改用 ART_SPEC 色盤（不用紅色）。`status_line()`、`skill_line()`、`objective_line()` 保留（a 的測試用）。

- [ ] **Step 1: Write the failing tests**：
  - `test_hud_textures_load`：`pip_textures()` 每一項非 null
  - `test_weapon_icon_mapping`：三種武器各回傳不同貼圖；`-1` 回傳 null
- [ ] **Step 2:** 跑自測，Expected：2 項失敗
- [ ] **Step 3:** 實作
- [ ] **Step 4:** 跑自測，Expected：`fail=0`
- [ ] **Step 5: Commit** `Draw the HUD with its finished icons (MV-SLICE-001b1)`

### Task 8: 截圖模式 `--shots`

**Files:**
- Modify: `game/launch_args.gd`、`game/main.gd`
- Create: `game/world/shots.gd`
- Test: `game/tests/test_scenery.gd`（參數解析）

**Interfaces:**
- Produces：`LaunchArgs.parse` 新增 `mode == "shots"`、`shots_dir`（`--shots <資料夾>`，只在 `OS.is_debug_build()` 生效）；`shots.gd` 依序開 `home`、`field`、`field`（夜晚）、`yard`、`forest_1`～`forest_4`、Boss 的 nance 樹、小路、宮殿，每個畫面等 30 幀後存 `<名稱>.png` 與 `<名稱>_gray.png`（灰階），再量 120 幀的平均幀時間寫進 `frametimes.txt`，全部拍完結束程式。用 `GameWorld.dev_start` 進房間。

- [ ] **Step 1: Write the failing test**：`test_launch_args_shots`：`parse(["--shots", "/tmp/x"])` → `mode == "shots"`、`shots_dir == "/tmp/x"`；沒給資料夾時 `mode == "title"`
- [ ] **Step 2:** 跑自測，Expected：失敗
- [ ] **Step 3:** 實作
- [ ] **Step 4:** 跑自測，Expected：`fail=0`；再跑 `godot --path game -- --shots /tmp/b1_shots`（需視窗），Expected：產出 11 組截圖與 `frametimes.txt`、沒有 `SCRIPT ERROR`
- [ ] **Step 5: 看截圖**：用 Read 逐張檢查（灰階下戰鬥訊號分得出、角色從背景跳出來、前景沒擋到地面與角色、地表與腳底對齊）；平均幀時間 ≤ 16.7 ms。發現問題回到對應 Task 修正（照 TDD）
- [ ] **Step 6: Commit** `Add a screenshot mode that walks every scene (MV-SLICE-001b1)`

### Task 9: 文件與收尾

**Files:**
- Modify: `game/README.md`（素材管線、`--shots`、`game/art/` 規則）、`ART_SPEC.md`（第 4 節加「進遊戲」：匯入工具與 `game/art/`）、`todo/spec/MV-SLICE-001b1_場景物件與HUD.md`（驗收打勾、Git Commit 段）、`todo/todo.md`
- Create: `report/MV-SLICE-001b1_場景物件與HUD_<date>_執行報告.md`（時間先跑 `date`）

- [ ] **Step 1:** 跑兩條驗證指令與 `python3 tools/import_art.py --check`，記錄結果
- [ ] **Step 2:** 寫文件與報告（附截圖檔位置、幀時間、MV-ASSET-014 結果）；派工單 MV-SLICE-001b1 標「⏸️ 暫停（等待 Brian 驗收）」
- [ ] **Step 3: Commit** `Document the art pipeline and report sub-project b1 (MV-SLICE-001b1)`
