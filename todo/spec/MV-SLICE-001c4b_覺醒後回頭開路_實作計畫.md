# MV-SLICE-001c4b 覺醒後回頭開路 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 覺醒後能從小路走回森林，打開森林 1、4 的二段跳高台（後面各 1 片碎片）與森林 2 ↔ 5 的捷徑（兩頭木障），並在覺醒後第一次進小路時提示一次。

**Architecture:** 沿用「房間資料 → `room.gd` 建房間」：木障是房間資料的新欄位 `barriers`，直接用 `core/level/barrier.gd`；左側高台與高門加進 `kit.gd`（右側版本的鏡像）；`room_check.walk_errors` 加可調的上升、間隔上限，讓自測能用資料證明「單跳到不了、二段跳到得了」。回程在 `boss_fight.gd` 加一個從森林進來的入口函式與覺醒後的小路出口線，`room_flow.gd` 走門進 Boss 段落時呼叫它。先做元素與工具（Task 1、2），再排房間（Task 3），再接回程（Task 4），最後工單、截圖與文件（Task 5）。

**Tech Stack:** Godot 4.7.2 GDScript；自測 `godot --headless --path game -- --self-test`（多檔 `bash /tmp/wt/st_only.sh test_a test_b`；全套 `bash /tmp/wt/step6.sh`）；截圖 `godot --path game -- --shots <資料夾>`（需要視窗）。`/tmp/wt/` 若被清掉，照 c4a 執行報告重建 `st_only.sh`、`step6.sh`（內容：逐檔 `SELFTEST_ONLY=<名稱>` 跑自測、grep `SELFTEST FAIL|SCRIPT ERROR|Parse Error`）。

**Spec:** [MV-SLICE-001c4b_覺醒後回頭開路.md](MV-SLICE-001c4b_覺醒後回頭開路.md)（Brian 2026-10-15 核准）

## Global Constraints

- 存檔欄位與 `Save.VERSION` 不變；捷徑旗標 `shortcut_25`、提示旗標 `hint_forest_return` 用 `gs.flags`；碎片 `frag_e`（森林 1）、`frag_f`（森林 4）用 `stashes_taken`；全切片正好 6 片（`frag_a`～`frag_f`），血量上限最多 8。
- 鎖高台離地約 600 px（頂面 y≈300）：單跳到不了、二段跳到得了；捷徑兩頭高台離地 300 px（頂面 y 600）：單跳上得去。
- 鎖高台水平 1300 px 內不放飛行型出生點與下劈水晶（防下劈飛行型繞過）。
- 木障只有覺醒後（`abilities_enabled`）的 Xbalanque 飛鏢能標記、工具砍碎；有 `flag` 的破開後設旗標、兩頭都不再建；沒有 `flag` 的每次建房都立起。外觀佔位 `prop_palace_barrier.png`（直向重複）。
- 提示文字「森林裡有以前到不了的地方」，畫面下方（`hud.notice`）約 4 秒，只出現一次。
- 回程：已覺醒時小路最左端 → 森林 6 的 `to_boss` 門；已覺醒從森林 6 右門進 → 出生在 `Palace.PATH_START`、狀態同讀檔回宮殿篝火；未覺醒全部照舊。
- 結尾、通關存檔、主路（只靠單跳、不需要下劈）、walkthrough 都不變。
- 註解、文件繁體中文；commit 英文、結尾 `(MV-SLICE-001c4b)`；全套自測基準 503 項。

## Review Focus

1. **從森林進 Boss 段落出生在 `PATH_START`（x 8000），馬上又被小路出口線送回森林**（來回彈）：出口線必須在出生點左邊、進來後站著不動不會離開 → Task 4 `test_forest_entry_does_not_bounce_back`
2. **已覺醒從森林回到小路，往右走進宮殿**：應該直接是出口階段（木障立著、Boss 不開打），不能重打第 2 段 → Task 4 `test_forest_entry_palace_is_exit`
3. **破開捷徑後在森林 5 篝火休息、結束遊戲再「繼續」**：旗標寫進存檔，兩頭的木障都不再出現 → Task 3 `test_shortcut_flag_saved`
4. **覺醒前站上捷徑高台，用希巴拉克射木障**：只有悶響、不派工具、木障不破 → Task 1 `test_barrier_needs_awakening`
5. **剛覺醒（出口階段）走回小路觸發提示**：4 秒後下方要換回出口提示（先破木障），不能留白或一直卡在森林提示 → Task 4 `test_forest_hint_yields_to_exit_hint`

## 與規格書的差異（計畫裁定）

| 規格書 | 計畫 | 原因 |
|---|---|---|
| 木障「從高台頂面一路到房間頂端外（同左右牆的 y −200）」 | 房間左右牆與木障的頂端都改到 `Kit.TOP` −1000 | 森林 4 的鎖高台頂面 y 300，二段跳最高到約 y −400，會從 −200 的牆頂與木障頂上翻過去 |
| 森林 1「房間中段的高台」 | 起始座標 x 1900～2200，飛行型從 3200 移到 3600 | 1300 px 防繞過規則；既有平台 (3700, 640) 要在單跳搆不到的距離外 |

---

## 檔案結構

| 檔案 | 責任 | Task |
|---|---|---|
| `game/world/room.gd` | `barriers` 欄位：建木障、外觀、旗標、回饋音 | 1 |
| `game/world/rooms/kit.gd` | `TOP`、牆加高、左側高台與高門、`barrier()` | 2 |
| `game/world/room_check.gd` | `walk_errors` 可調上升與間隔；單跳搆不到、二段跳的常數 | 2 |
| `game/world/rooms/forest_1.gd`、`forest_2.gd`、`forest_4.gd`、`forest_5.gd` | 3 個鎖、2 片碎片、捷徑 | 3 |
| `game/world/shots.gd` | 截圖清單加鎖與已覺醒的小路 | 3、4 |
| `game/core/boss/boss_fight.gd` | `begin_from_forest()`、覺醒後的小路出口、森林提示 | 4 |
| `game/world/room_flow.gd` | 走門進 Boss 段落時呼叫 `begin_from_forest()` | 4 |
| `game/tests/test_c4b.gd`（新） | 木障、工具、房間資料、鎖 | 1～3 |
| `game/tests/test_c4a.gd` | 碎片總數改 6、高台外觀清單加森林 2、5 | 3 |
| `game/tests/test_boss_segment.gd` | 回程與提示（沿用它的 `setup_flow`、`go`） | 4 |
| `docs/assets/MV-ASSET-017_素材工單_下劈水晶與血量碎片.md`、報告、規格、`game/README.md`、`todo/todo.md` | C-04 森林木障與文件 | 5 |

---

### Task 1：房間木障

**Files:** Modify `world/room.gd`；Create `tests/test_c4b.gd`

**Interfaces:**
- Produces（房間資料）：`barriers: Array[{rect: Rect2, flag?: String}]`。
- Produces（`room.gd`）：`var barriers: Array = []`（建出來的 `barrier.gd` 節點）；建房時對每筆：有 `flag` 且 `gs.has_flag(flag)` → 跳過；否則 `Barrier.new()`、`setup(rect)`、加進房間與 `barriers`；`broken` → 有 `flag` 時 `gs.set_flag(flag)`、`feedback.play(&"barrier_break")`；`thudded` → `feedback.play(&"thud")`（同 `boss_fight.gd` 的接法；feedback 建好後再接）。`scenery != null` 時外觀照 `palace_arena.use_art()`：`barrier.art = true`、子節點 `Art` 用 `SceneryView.fill_vertical(..., load(BARRIER_TEX), Rect2(-size / 2, size))`。
- `const BARRIER_TEX := "res://art/prop/prop_palace_barrier.png"`，註解 `# ponytail: dep: 宮殿木障的圖佔位 | upgrade if: MV-ASSET-017 C-04 prop_forest_barrier.png 到位`。

- [ ] **Step 1：失敗測試**（`tests/test_c4b.gd`，`build_room`、`make_gs` 照 `test_c4a.gd`；測試房間用 `_test_b` 資料、清掉 `enemies` 與 `gates`，木障 `Rect2(1500, 500, 60, 400)`，玩家在 (1200, 900) 面向右）：
  - `test_room_barriers_built`：1 筆 → `r.barriers.size() == 1`、未破、是 `StaticBody2D`
  - `test_barrier_needs_awakening`（Review Focus 4）：`gs.awakened == false`，換到希巴拉克（`twin_index == 1`）、`intent.dart_pressed = true` → 120 幀內沒有 `player.tool`、木障未破、`thudded` 發過；`gs.awakened = true` 重建 → 120 幀內 `is_broken`
  - `test_flagged_barrier_sets_flag_and_stays_open`：`flag: "shortcut_t"`；`break_apart()` → `gs.has_flag("shortcut_t")`；重建 → `r.barriers.is_empty()`
  - `test_unflagged_barrier_rebuilt`：沒有 `flag`；`break_apart()` 後重建 → 1 個、未破
  - `test_barrier_art_in_themed_room`：資料加 `theme: "forest"` → 木障 `art == true`、有子節點 `Art`
- [ ] **Step 2：跑** `bash /tmp/wt/st_only.sh test_c4b` → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_c4b test_c4a test_rooms test_player` 全過
- [ ] **Step 5：Commit** `Let rooms hold barriers that only the awakened tool can break (MV-SLICE-001c4b)`

### Task 2：左側高台、牆加高、可調的通過性檢查

**Files:** Modify `world/rooms/kit.gd`、`world/room_check.gd`、`tests/test_c4b.gd`

**Interfaces:**
- Produces（`kit.gd`）：
  - `const TOP := -1000.0`；`frame()` 左右牆改成從 `TOP` 到 y 1300（`Rect2(-100, TOP, 100, 1300 - TOP)`、右牆同）
  - `static func ledge_left(y: float, width := 500.0) -> Rect2` → `Rect2(0, y, width, 30)`
  - `static func door_branch_left(id: String, to_room: String, to_door: String, ledge_y: float) -> Dictionary` → `rect Rect2(0, ledge_y - 300, 70, 300)`、`spawn Vector2(220, ledge_y)`、`branch: true`
  - `static func door_left_under(id: String, to_room: String, to_door: String, ledge_y: float) -> Dictionary` → `door_left(...)` 的 `rect` 改成 `Rect2(0, ledge_y + 40, 70, GROUND_Y - ledge_y - 40)`
  - `static func barrier(x: float, ledge_y: float, flag := "") -> Dictionary` → `{"rect": Rect2(x, TOP, 60, ledge_y - TOP)}`，`flag` 非空才加 `"flag"`
- Produces（`room_check.gd`）：
  - `walk_errors(d, from, to, max_rise := MAX_RISE, max_gap := MAX_GAP)`；`_hop` 用傳進來的值
  - `const SINGLE_REACH_RISE := 440.0`、`const SINGLE_REACH_GAP := 700.0`（「單跳一定到不了」的保守判斷：理論單跳 400 高，比 440 高、或遠過 700 就上不去）
  - `const MAX_RISE_DOUBLE := 640.0`（二段跳理論 400＋300＝700，留 60 餘裕）

- [ ] **Step 1：失敗測試**：
  - `test_kit_left_versions`：`ledge_left(600, 600) == Rect2(0, 600, 600, 30)`；`door_branch_left` 的 `rect`、`spawn`、`branch`；`door_left_under(..., 600).rect == Rect2(0, 640, 70, 260)`、出生點不在自己的門裡（`RoomCheck.errors` 用一間人造房間）
  - `test_walls_reach_top`：`Kit.frame(3)` 的兩道牆 `position.y == Kit.TOP`、`end.y == 1300`；`Kit.barrier(250, 300, "f").rect == Rect2(250, -1000, 60, 1300)`、`flag == "f"`；沒給 flag 時沒有 `flag` 鍵
  - `test_walk_errors_reach_params`（沿用 c4a 的 `step_room(x0, h)`）：高 600：預設不通、`SINGLE_REACH_RISE` 不通、`MAX_RISE_DOUBLE` 通；高 700：`MAX_RISE_DOUBLE` 不通；高 420：`SINGLE_REACH_RISE` 通（保守判斷算「可能到得了」）
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_c4b test_c4a test_ground_rooms test_rooms test_scenery test_walkthrough` 全過（牆加高不能讓既有測試或外觀出錯）
- [ ] **Step 5：Commit** `Add left-side ledges and doors and raise the room walls (MV-SLICE-001c4b)`

### Task 3：三個鎖與捷徑

**Files:** Modify `world/rooms/forest_1.gd`、`forest_2.gd`、`forest_4.gd`、`forest_5.gd`、`world/shots.gd`、`tests/test_c4a.gd`、`tests/test_c4b.gd`

**Interfaces:**
- Consumes：Task 1 `barriers`、`r.barriers`；Task 2 `Kit.ledge_left`、`door_branch_left`、`door_left_under`、`barrier`、`RoomCheck` 常數
- 起始座標（排版後可調，以 Step 1 的測試為準）：

| 房間 | 改動 |
|---|---|
| 森林 1 | 平台加 `Rect2(1900, 300, 300, 30)`；`fragment: {id: "frag_e", pos: (2050, 300)}`；飛行型 3200 → 3600 |
| 森林 2 | `solids` 加 `Kit.ledge(3, 600, 600)`；右門改 `door_right_under(3, "to_forest_3", …, 600)`；加 `door_branch(3, "to_forest_5", "forest_5", "to_forest_2", 600)`；`barriers: [Kit.barrier(5400, 600, "shortcut_25")]` |
| 森林 4 | `solids` 加 `Kit.ledge_left(300, 700)`；`fragment: {id: "frag_f", pos: (120, 300)}`；`barriers: [Kit.barrier(250, 300)]`；飛行型 2000 → 2100 |
| 森林 5 | `solids` 加 `Kit.ledge_left(600, 600)`；左門改 `door_left_under("to_forest_4", …, 600)`；加 `door_branch_left("to_forest_2", "forest_2", "to_forest_5", 600)`；`barriers: [Kit.barrier(300, 600, "shortcut_25")]` |

- 捷徑的木障在高台的開口與門的出生點之間（森林 2：木障右緣 ≤ 出生點 x；森林 5：木障左緣 ≥ 出生點 x），從哪一頭都打得到。
- 房間檔頭註解加一句本房的鎖（MV-SLICE-001c4b）。
- `shots.gd` 加 `["forest_1_lock", "forest_1", "x=2050"]`；森林 2 右段、森林 4、森林 5 的既有截圖已涵蓋高台。

- [ ] **Step 1：失敗測試**（`test_c4b.gd`；`test_c4a.gd` 只改兩處）：
  - `test_c4a.gd` `test_four_fragments_total` → 改名 `test_fragments_total`、期望 `frag_a`～`frag_f`，6 片全拿時 `max_hp_now() == 8`；`test_ledges_have_art` 的清單加 `forest_2`、`forest_5`
  - `test_lock_ledges_need_double_jump`：森林 1 的 `frag_e`、森林 4 的 `frag_f`：從左門（主路）出生點 `walk_errors(..., SINGLE_REACH_RISE, SINGLE_REACH_GAP)` 不為空；`walk_errors(..., MAX_RISE_DOUBLE, MAX_GAP)` 為空
  - `test_shortcut_ledges_single_jump`：森林 2 從左門出生點走得到 `to_forest_5` 的出生點、森林 5 從右門出生點走得到 `to_forest_2` 的出生點（預設單跳）
  - `test_locks_clear_of_pogo_lifts`：兩個鎖高台（碎片站著的那塊地形）的 x 範圍到每個飛行型出生點與水晶的水平距離 ≥ 1300
  - `test_shortcut_doors_and_barriers`：兩扇門互指、都是 `branch`；兩頭各 1 道 `flag == "shortcut_25"` 的木障、底邊等於高台頂面、在開口與出生點之間；每道木障頂端 ≤ `Kit.TOP`；兩扇捷徑門的出生點不在房內任何門的矩形裡
  - `test_shortcut_flag_opens_both_sides`：沒有旗標 → 森林 2、5 建出來各 1 道；設旗標 → 都是 0
  - `test_forest_4_barrier_rebuilt`：`break_apart()` 後重建 → 立回；`frag_f` 已拿 → 木障仍立著、`fragment_pickup == null`
  - `test_shortcut_flag_saved`（Review Focus 3）：`GameWorld` 從森林 5 開始（照 `test_forest_rest_points`）、`gs.awakened = true`、`r.barriers[0].break_apart()`、`flow.rest_here()` → `Save.read` 的 `flags` 有 `shortcut_25`；新 `GameWorld` `continue_game()` → 森林 5 的 `barriers` 為空
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：排版**：寫資料 → `--shots` 截森林 1、2、4、5（含 `forest_1_lock`）→ 檢查高台、木障、碎片、路標不重疊、看得清楚 → 調座標
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_c4b test_c4a test_ground_rooms test_rooms test_walkthrough test_scenery` 全過
- [ ] **Step 5：Commit** `Lock two fragments and a shortcut behind the awakened abilities (MV-SLICE-001c4b)`

### Task 4：回程與提示

**Files:** Modify `core/boss/boss_fight.gd`、`world/room_flow.gd`、`world/shots.gd`、`tests/test_boss_segment.gd`

**Interfaces:**
- Produces（`boss_fight.gd`）：
  - `const PATH_EXIT_X := 7900.0`（小路左牆內緣 7800、`PATH_START` 8000 之間）
  - `const FOREST_HINT := "森林裡有以前到不了的地方"`、`const FOREST_HINT_TIME := 4.0`、`const FOREST_HINT_FLAG := "hint_forest_return"`；`var _forest_hint_left := 0.0`
  - `func begin_from_forest() -> void`：`gs != null and gs.awakened` → `begin_at_rest("palace_camp")`、`player.position = Palace.PATH_START`、速度歸零、`camera.reset_smoothing()`；否則什麼都不做（照舊在 nance 篝火）
  - `_physics_process`：`gs != null and awakened and (stage == APPROACH or stage == EXIT) and player.position.x < PATH_EXIT_X and not _left_sent` → 同既有寫法發 `left_exit`（`call_deferred`）。`gs != null and awakened and player.position.x < Palace.LEFT and not gs.has_flag(FOREST_HINT_FLAG)` → `gs.set_flag(...)`、`_forest_hint_left = FOREST_HINT_TIME`。倒數中與倒數歸零的那一幀寫 `hud.notice = exit_notice()`
  - `exit_notice()`：`_forest_hint_left > 0.0` 時先回 `FOREST_HINT`（不論 stage），其餘照舊
  - `signal left_exit` 的註解改成「回森林 6（開打前；覺醒後從小路最左端）」
- Produces（`room_flow.gd`）：`"boss"` 分支：`door_id == ""` → `begin_at_rest(room_id)`；否則 `begin_from_forest()`
- Produces（`shots.gd`）：`["boss_path_awake", "boss", "path_awake"]` → `w.gs.awakened = true`、`r.boss.cycle_enabled = false`、`r.begin_from_forest()`

- [ ] **Step 1：失敗測試**（`test_boss_segment.gd`，用它的 `make_gs`、`setup_flow`、`go`、`teardown`）：
  - `test_awakened_forest_entry_at_path_start`：`gs.awakened = true`；森林 6 → `go(s, "boss", "to_forest_6")` → `player.position` 約等於 `PATH_START`（±2）、`f.awakened`、`stage == APPROACH`、`player.abilities_enabled`
  - `test_unawakened_forest_entry_unchanged`：未覺醒同樣進來 → 在 `Nance.REST`、`not f.awakened`
  - `test_forest_entry_does_not_bounce_back`（Review Focus 1）：已覺醒進來、等 30 幀 → `current_id == "boss"`
  - `test_awakened_path_left_exit`：已覺醒進來、`player.position = (7850, 900)` → 60 幀內 `current_id == "forest_6"`、角色在森林 6 `to_boss` 的出生點；另一次從 `go(s, "palace_camp")`（`last_rest` 為 `palace_camp`、已覺醒）走到 7850 → 一樣回森林 6
  - `test_forest_entry_palace_is_exit`（Review Focus 2）：已覺醒進來、`player.position.x = Palace.ENTRY_X + 50` → 幾幀內 `stage == EXIT`、`palace.barrier.is_broken == false`、`boss` 沒有開打（`stage != FIGHT`）
  - `test_forest_hint_once`：已覺醒進來 → `hud.notice == FOREST_HINT`、`gs.has_flag("hint_forest_return")`；4.2 秒後 `hud.notice != FOREST_HINT`；回森林再進來 → 不再出現；未覺醒進來 → 從不出現
  - `test_forest_hint_yields_to_exit_hint`（Review Focus 5）：`make_gs_fight` 已覺醒、`f.start_at(4)`（出口階段、在宮殿）→ 角色移到 x 13000 → `hud.notice == FOREST_HINT`；4.2 秒後 `hud.notice == EXIT_HINT_BARRIER`
- [ ] **Step 2：跑** `bash /tmp/wt/st_only.sh test_boss_segment` → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_boss_segment test_boss test_cutscene test_walkthrough test_c4b` 全過
- [ ] **Step 5：Commit** `Walk back to the forest after awakening and say so once (MV-SLICE-001c4b)`

### Task 5：素材工單、截圖與文件

**Files:** Modify `docs/assets/MV-ASSET-017_素材工單_下劈水晶與血量碎片.md`（加 C-04）、`game/README.md`（回程、鎖、木障欄位）、`todo/spec/MV-SLICE-001c4b_覺醒後回頭開路.md`（木障頂端改 −1000、驗收、Git Commit）、`todo/todo.md`（c4b、MV-ASSET-017）；Create `report/MV-SLICE-001c4b_覺醒後回頭開路_{YYYY-MM-DD_HHmm}_執行報告.md`（時間戳先跑 `date`）

本 Task 沒有新程式、沒有新測試。

- [ ] **Step 1：工單**：C-04 `prop_forest_barrier.png`（1024×1024 生成、洋紅背景、遊戲內約 60 px 寬、直向重複）照 C-01～C-03 的格式寫設計決定一列、清單一列、四段式 prompt 一節與驗收；造型「綠藤綁著的一排木樁」，可讀性「擋路、可以砍」
- [ ] **Step 2：截圖**：`--shots` 全部（含 `forest_1_lock`、`boss_path_awake`）；改動房間做縮圖（`stitch_rooms.py`），AI 檢查高台、木障、碎片、門與路標；`boss_path_awake` 看得到提示；幀時間 ≤ 16.7 ms；截圖放 `assets-test/c4b_shots/`
- [ ] **Step 3：文件**：照 Files；規格書只勾 AI 有證據的項目；`todo.md` c4b 維持 🔄、改「實作完成，待 Brian 看截圖與手把試玩（計時）」；MV-ASSET-017 改成 4 件
- [ ] **Step 4：跑** `bash /tmp/wt/step6.sh`（503＋新增、`--check`、unittest）
- [ ] **Step 5：Commit** `Write the forest barrier art order and document the way back (MV-SLICE-001c4b)`
