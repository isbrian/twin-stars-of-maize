# MV-SLICE-001c4a 森林加大加深與血量碎片 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把森林從 4 間平地房加到 9 間（主路 6＋支路 3），加入下劈水晶、荊棘地形、關門戰與 4 片血量碎片，讓切片的森林段約 +10 分。

**Architecture:** 沿用「房間資料檔 → `room.gd` 建房間」的做法：新元素都是房間資料的新欄位，由 `room.gd` 建出來；荊棘與關門戰的邏輯放在 `core/level/` 的小節點；血量上限由 `GameState` 依碎片片數算出（不加存檔欄位）。先做元素與檢查工具（Task 1～5），再排房間（Task 6、7），最後工單、截圖與文件（Task 8）。

**Tech Stack:** Godot 4.7.2 GDScript；自測 `godot --headless --path game -- --self-test`（`SELFTEST_ONLY=`；多檔 `bash /tmp/wt/st_only.sh test_a test_b`；全套 `bash /tmp/wt/step6.sh`）；截圖 `godot --path game -- --shots <資料夾>`（需要視窗）。

**Spec:** [MV-SLICE-001c4a_森林與藏點.md](MV-SLICE-001c4a_森林與藏點.md)（Brian 2026-10-15 核准）

## Global Constraints

- 存檔欄位與 `Save.VERSION` 不變；碎片記在 `stashes_taken`（id 以 `frag_` 開頭）；舊存檔照常讀得到。
- 血量上限＝`tn.max_hp`（5）＋碎片片數 ÷ 2（取整數）；切片正好 4 片：`frag_a`（支路 A）、`frag_b`（支路 B）、`frag_c`（支路 C 關門戰）、`frag_d`（森林 5 高處）。
- 提示文字：碎片奇數片「血量碎片 1/2」、偶數片「血量上限 +1」；下劈提示 id `pogo`：鍵盤「空中 S＋攻擊 下劈（打中會彈起）」、手把「空中左搖桿下＋攻擊 下劈（打中會彈起）」。
- 荊棘：碰到扣 1 格（無敵時間內不扣）；淡黑約 0.3 秒、回到最後站穩的地面；扣到 0 照一般死亡。
- 關門戰：3 波，2、3、4 隻（爬行型與飛行型混合）；一波清完過 1 秒出下一波；中途死亡整場重置；碎片拿過不再觸發。
- 每間房一個畫面高（1080）、2～3 個畫面寬；主路每間 2～4 隻敵人、只有爬行型與飛行型；主路不需要下劈、只靠單跳（`jump_height` 400）。
- 保留房間 ID `forest_1`～`forest_4` 與森林 3 的可可豆藏點；新房間 `forest_5`、`forest_6`、`forest_a`、`forest_b`、`forest_c`；篝火：森林 2、森林 5。
- 不加新背景美術、不加敵人種類、不做地圖；水晶與碎片素材到位前用程式畫的佔位。
- 註解、文件繁體中文；commit 英文、結尾 `(MV-SLICE-001c4a)`；全套自測基準 469 項。

## Review Focus

1. **Boss 段落死亡重試後血量上限掉回 5**（`player.respawn` 用 `tn.max_hp` 重建血量）：有碎片時重試仍是加成後的上限 → Task 1 `test_boss_retry_keeps_fragment_max_hp`
2. **荊棘的安全點剛好在另一段荊棘旁、或空中受傷後被打進荊棘**：放回的位置必須站在實心地面上、離荊棘至少一個身寬 → Task 2 `test_safe_ground_never_near_hazard`
3. **關門戰途中按暫停 → 回主選單，再「繼續」**：從篝火回來、關門戰沒完成、碎片還在，進房會重新觸發 → Task 4 `test_arena_resets_after_reload`
4. **已經拿到碎片（片數為奇數）時在篝火休息**：血量補到加成後的上限，半格仍顯示 → Task 1 `test_rest_fills_to_fragment_max`
5. **支路門在高處、主路門在地面同一側**：從支路回來時出生在高處平台上，不會掉回支路門裡反覆換房 → Task 5 `room_check` 既有規則（出生點不在自己的門裡）＋ Task 7 `test_branch_return_spawn_on_ledge`

---

## 檔案結構

| 檔案 | 責任 | Task |
|---|---|---|
| `game/state/game_state.gd` | `fragments()`、`max_hp_now()`；`rest()` 用加成後的上限 | 1 |
| `game/state/loadout.gd` | `apply()` 設 `health.max_hp` | 1 |
| `game/core/boss/boss_fight.gd` | `_retry` 後套回加成後的上限 | 1 |
| `game/world/room.gd` | 碎片、荊棘、水晶、提示區、關門戰的建置與事件 | 1～4 |
| `game/ui/hud.gd` | 半格 | 1 |
| `game/core/level/hazard.gd`（新） | 荊棘地形：碰到時發訊號 | 2 |
| `game/core/level/arena.gd`（新） | 關門戰：觸發、閘門、波次、獎勵 | 4 |
| `game/ui/hints.gd`、`game/events/event_runner.gd`、`game/core/player/player.gd` | `pogo` 提示、`pogo_bounced` 訊號、房間提示區接線 | 3 |
| `game/world/scenery_view.gd` | 荊棘地形外觀、支路路標縮小 | 2、5 |
| `game/world/room_check.gd` | 主路通過性、碎片與支路結構檢查 | 5 |
| `game/world/rooms/*.gd`、`index.gd` | 主路 6 間、支路 3 間 | 6、7 |
| `game/world/shots.gd` | 截圖清單加新房間 | 7 |
| `game/tests/test_c4a.gd`（新） | 本計畫的新測試 | 1～7 |
| `game/tests/test_ground_rooms.gd`、`test_walkthrough.gd` | 森林清單、新主路 | 6、7 |
| `docs/assets/MV-ASSET-017_*.md`（新）、報告、規格、`game/README.md`、`todo/todo.md` | 工單與文件 | 8 |

---

### Task 1：血量碎片與血量上限

**Files:** Modify `state/game_state.gd`、`state/loadout.gd`、`core/boss/boss_fight.gd`、`world/room.gd`、`ui/hud.gd`；Create `tests/test_c4a.gd`

**Interfaces:**
- Produces（`game_state.gd`）：`func fragments() -> int`（`stashes_taken` 裡 key 以 `frag_` 開頭且值為 true 的數量）；`func max_hp_now() -> int`（`tn.max_hp + fragments() / 2`）；`rest()` 與 `reset_new_game()` 的 `hp` 用 `max_hp_now()`。
- Produces（`loadout.gd`）：`apply()` 先設 `player.health.max_hp = gs.max_hp_now()` 再設 `hp`。
- Produces（`room.gd`）：房間資料 `fragment: {id: String, pos: Vector2}`；`func place_fragment(f: Dictionary) -> void`（未取過才放撿取物；Task 4 的關門戰獎勵也用它）；建房時對 `fragment` 呼叫；撿起時 `gs.stashes_taken[id] = true`，奇數片 `_float("血量碎片 1/2")`、偶數片 `player.health.max_hp = gs.max_hp_now()`、`hp` 補滿、`gs.hp` 同步、`_float("血量上限 +1")`。撿取物在素材到位前用程式畫的佔位（`fragment_drawn` 為 false 時畫一個菱形外框）。
- Produces（`hud.gd`）：`var half_heart := false`；為 true 時在最後一格血之後畫一個半格（佔位：半個外框）；由 `game_world` 每幀依 `gs.fragments() % 2 == 1` 設定。
- `boss_fight._retry`：`player.respawn(...)` 之後若 `gs != null`：`player.health.max_hp = gs.max_hp_now()`、`hp` 設為它。

- [ ] **Step 1：失敗測試**（`tests/test_c4a.gd`）：
  - `test_max_hp_from_fragments`：0、1 片 → 5；2、3 片 → 6；4 片 → 7；非 `frag_` 的藏點不算
  - `test_fragment_pickup_rules`：測試房間放 `fragment`，撿第 1 片：上限 5、浮字「血量碎片 1/2」、`stashes_taken.frag_x`；再撿第 2 片（另一個 id）：上限 6、`hp == 6`、浮字「血量上限 +1」；重建房間後拿過的不再出現
  - `test_rest_fills_to_fragment_max`（Review Focus 4）：3 片時 `gs.rest("forest_2")` → `hp == 6`；`hud.half_heart` 為 true
  - `test_old_save_without_fragments_loads`：沒有任何 `frag_` 紀錄的存檔字典 `valid_state` 為 true、讀進來上限 5
  - `test_boss_retry_keeps_fragment_max_hp`（Review Focus 1）：有 2 片的 GameState 進 Boss 段落 → `_retry(1)` 後 `player.health.max_hp == 6`
- [ ] **Step 2：跑** `SELFTEST_ONLY=test_c4a` → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_c4a test_rooms test_ui test_boss test_walkthrough test_state test_loadout test_rest_and_cacao test_hud_art` 全過
- [ ] **Step 5：Commit** `Grow max health from collected fragments (MV-SLICE-001c4a)`

### Task 2：荊棘地形

**Files:** Create `core/level/hazard.gd`；Modify `world/room.gd`、`world/scenery_view.gd`、`tests/test_c4a.gd`

**Interfaces:**
- Produces（`hazard.gd`，`extends Area2D`）：`func setup(r: Rect2) -> void`；偵測玩家身體，`signal touched(body: Node)`。
- Produces（`room.gd`）：房間資料 `hazards: Array[Rect2]`；`var safe_ground: Vector2`（每個物理幀：玩家 `is_on_floor()` 且腳底 x 離每個荊棘矩形至少 `SAFE_PAD := 80.0` 時記下 `player.position`；進房時是出生點）；荊棘 `touched` → `_thorn_respawn()`：`player.health.take_damage(1, tn.hurt_invuln_time)`；若死亡交給原本的死亡流程；否則鎖住操作、畫面淡黑 0.15 秒 → 放到 `safe_ground`、速度歸零 → 淡回 0.15 秒、解鎖。淡黑用房間自己的 `CanvasLayer` 上的 `ColorRect`。
- Produces（`scenery_view.gd`）：`place_terrain` 依 `hazards` 用 `prop_thorns_wall.png` 裁下半截、水平重複鋪滿矩形（`add_piece("hazard", …)`）。

- [ ] **Step 1：失敗測試**：
  - `test_hazard_damages_and_returns`：玩家站在 (500, 900) 一段時間後放進荊棘矩形 → 扣 1 格、0.5 秒內回到 (500, 900) 附近（±2 px）
  - `test_hazard_no_double_damage_in_invuln`：剛受傷（無敵中）碰荊棘 → 不扣血、仍被放回
  - `test_hazard_can_kill`：1 格血碰荊棘 → `player_died` 發出
  - `test_safe_ground_never_near_hazard`（Review Focus 2）：在離荊棘 40 px 的地面站著、再跳進荊棘 → 放回的位置離荊棘 ≥ 80 px、腳下是實心地面
  - `test_hazard_art_placed`：有 `hazards` 的房間，`scenery.piece_rects()` 有 `kind == "hazard"` 蓋住每個矩形
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_c4a test_rooms test_scenery` 全過
- [ ] **Step 5：Commit** `Hurt and bounce the twins back from thorn ground (MV-SLICE-001c4a)`

### Task 3：下劈水晶與下劈提示

**Files:** Modify `world/room.gd`、`core/player/player.gd`、`ui/hints.gd`、`events/event_runner.gd`、`tests/test_c4a.gd`

**Interfaces:**
- Produces（`room.gd`）：房間資料 `crystals: Array[Vector2]` → 每個位置放一個 `PogoCrystal`；`hint_at: {id: String, rect: Rect2}` → 玩家進入時發 `signal hint_requested(id: String)`（每次進房最多一次）。
- Produces（`player.gd`）：`signal pogo_bounced`，在下劈打中 `POGO` 層而彈起時發出。
- Produces（`hints.gd`）：`TEXT["pogo"] = ["空中 S＋攻擊 下劈（打中會彈起）", "空中左搖桿下＋攻擊 下劈（打中會彈起）"]`。
- `event_runner._on_room`：接 `room.hint_requested` → `hints.request(id)`；接 `room.player.pogo_bounced` → `hints.satisfy("pogo")`。

- [ ] **Step 1：失敗測試**：
  - `test_crystals_built`：房間資料 2 顆水晶 → 房間裡 2 個 `PogoCrystal`、位置相同
  - `test_pogo_bounce_signal`：玩家在水晶正上方空中下劈 → `pogo_bounced` 發出、`velocity.y < 0`
  - `test_pogo_hint_flow`：遊戲世界進有 `hint_at` 的房間、走進區域 → `hints.current == "pogo"`；發 `pogo_bounced` → `hints_seen.pogo` 為 true、不再出現
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_c4a test_rooms test_ui test_hints test_combat test_events` 全過
- [ ] **Step 5：Commit** `Place pogo crystals and teach the down strike (MV-SLICE-001c4a)`

### Task 4：關門戰

**Files:** Create `core/level/arena.gd`；Modify `world/room.gd`、`tests/test_c4a.gd`

**Interfaces:**
- Consumes：Task 1 `room.place_fragment(f: Dictionary)`
- Produces（房間資料）：`arena: {rect: Rect2, gates: Array[Rect2], waves: Array[Array[{kind, pos}]], reward: {id, pos}}`。
- Produces（`arena.gd`，`extends Node`）：`signal started`、`signal cleared`；`var wave := -1`（-1＝未開始）；由 `room.gd` 建立並餵玩家位置。規則：`reward.id` 已在 `stashes_taken` → 不建；玩家碰撞框整個在 `rect` 內 → 閘門（荊棘牆外觀，同既有 `gates` 的做法）啟用、`wave = 0` 生成第 1 波；一波的敵人全死 → 1.0 秒後下一波；最後一波清完 → 閘門移除、在 `reward.pos` 放碎片、`cleared`。關門戰的敵人不記進 `defeated`。
- 狀態不存檔：死亡、離開房間、讀檔都會重建房間，所以自然重置。

- [ ] **Step 1：失敗測試**：
  - `test_arena_waves_and_reward`：測試房間放 `arena`，玩家走進 `rect` → 閘門擋住（實心）、場上 2 隻；把敵人全殺 → 1 秒後 3 隻 → 再 4 隻 → 清完：閘門消失、碎片出現
  - `test_arena_not_retriggered_after_reward`：`stashes_taken[reward.id] = true` 時進房 → 不觸發、沒有閘門
  - `test_arena_resets_after_reload`（Review Focus 3）：第 2 波時重建房間（模擬死亡或讀檔）→ 未開始、沒有敵人、碎片不在
  - `test_arena_enemies_not_in_defeated`：清完後 `gs.defeated` 沒有關門戰敵人的紀錄
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_c4a test_rooms` 全過
- [ ] **Step 5：Commit** `Lock the twins in for three waves to earn a fragment (MV-SLICE-001c4a)`

### Task 5：房間檢查工具與支路路標

**Files:** Modify `world/room_check.gd`、`world/scenery_view.gd`、`tests/test_c4a.gd`

**Interfaces:**
- Produces（`room_check.gd`）：
  - `const MAX_RISE := 340.0`、`const MAX_GAP := 400.0`（單跳 400 高、約 560 寬，留餘裕）
  - `static func walk_errors(d: Dictionary, from: Vector2, to: Vector2) -> PackedStringArray`（起點、終點是腳底座標；主路傳兩扇門的出生點）：把實心頂面與平台頂面切成可站的線段（扣掉被 `hazards` 蓋住的部分），兩段之間「上升 ≤ MAX_RISE 且水平間隔 ≤ MAX_GAP」或「往下落、水平間隔 ≤ MAX_GAP」就連通；從 `from` 走不到 `to` 時回報錯誤。只用地形，不考慮水晶、二段跳。
  - `errors()` 加：`fragment.pos`、`crystals` 以外的元素位置檢查沿用（`fragment` 要在地形上）；`hazards` 不能蓋住任何門的出生點。
- Produces（房間資料門欄位）：`branch: true` 的門 → `scenery_view` 的路標縮成 `BRANCH_MARK := 0.7` 倍。

- [ ] **Step 1：失敗測試**：
  - `test_walk_errors_rise_and_gap`：人造房間：平台高 300 → 通；高 380 → 不通；間隔 350 → 通、450 → 不通；被荊棘蓋住的地面不算可站
  - `test_fragment_on_terrain_checked`：碎片懸空 → `errors()` 有錯
  - `test_hazard_over_spawn_checked`：荊棘蓋住門的出生點 → 有錯
  - `test_branch_waymark_smaller`：`branch: true` 的門，路標的 `rect.size` 約為一般的 0.7 倍
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_c4a test_rooms test_ground_rooms test_scenery` 全過
- [ ] **Step 5：Commit** `Check that the main path can be walked with single jumps (MV-SLICE-001c4a)`

### Task 6：主路 6 間

**Files:** Modify `world/rooms/forest_1.gd`～`forest_4.gd`、`world/rooms/index.gd`；Create `world/rooms/forest_5.gd`、`forest_6.gd`；Modify `tests/test_ground_rooms.gd`、`tests/test_walkthrough.gd`、`world/shots.gd`、`tests/test_c4a.gd`

**Interfaces:**
- Consumes：Task 1～5 的資料欄位（`fragment`、`hazards`、`crystals`、`hint_at`、`branch`）與 `RoomCheck.walk_errors`
- Produces：主路 `yard → forest_1 → forest_2 → forest_3 → forest_4 → forest_5 → forest_6 → boss`（森林 6 的右門接 Boss 段落，`boss.gd` 的左門目的地改成 `forest_6`）；支路門 id：森林 3 `to_forest_a`、森林 4 `to_forest_b`、森林 6 `to_forest_c`（`branch: true`，目的地房間 Task 7 才建，本 Task 先不加這三扇門）。
- 版面照規格「森林配置」表；寬：主路 3 個畫面；敵人每間 2～4；森林 2 第一顆水晶在主路上、底下是地面、`hint_at` 的範圍在水晶前約 400 px；森林 5 的 `frag_d` 在主路上方的高台（單跳上得去，但從主路的視線看不到正面，要往上看才發現）；森林 1、4、6 有荊棘。
- `index.gd` 的 `ROOMS` 加 `forest_5`、`forest_6`；`shots.gd` 加 `forest_5`、`forest_6`。

- [ ] **Step 1：失敗測試**：
  - `test_main_path_walkable`：每間主路房間 `walk_errors(d, 左門出生點, 右門出生點)` 為空
  - `test_main_path_order`：從 `yard` 依右門走，依序經過 `forest_1`～`forest_6` 到 `boss`
  - `test_forest_rest_points`：篝火正好在 `forest_2`、`forest_5`；`forest_5` 篝火休息後存檔、`Save.read` 的 `last_rest == "forest_5"`、讀檔回到森林 5
  - `test_ground_rooms.gd`：`FORESTS` 改成 6 間主路，每間 2～4 隻
  - `test_walkthrough_new_game_to_exit`：路線改成新主路
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：排版**：寫資料 → `--shots` 每間截圖檢查（平台、荊棘、水晶、路標不重疊、看得清楚）→ 調座標
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_c4a test_ground_rooms test_rooms test_walkthrough test_scenery` 全過
- [ ] **Step 5：Commit** `Lay out a six-room forest road to the nance tree (MV-SLICE-001c4a)`

### Task 7：支路 3 間

**Files:** Create `world/rooms/forest_a.gd`、`forest_b.gd`、`forest_c.gd`；Modify `forest_3.gd`、`forest_4.gd`、`forest_6.gd`（加支路門）、`index.gd`、`world/shots.gd`、`tests/test_c4a.gd`

**Interfaces:**
- Consumes：Task 1～6
- Produces：支路 A（下劈水晶跨過荊棘坑 → `frag_a`，這間是唯一需要下劈的地方）、支路 B（荊棘之間的窄平台 → `frag_b`）、支路 C（`arena` 3 波 → `frag_c`）；每間 2 個畫面寬、只有一扇門（回主路房間）。

- [ ] **Step 1：失敗測試**：
  - `test_four_fragments_total`：所有房間資料的 `fragment` 加上 `arena.reward` 正好 `frag_a`～`frag_d` 各一
  - `test_branches_are_dead_ends`：`forest_a`～`forest_c` 各只有一扇門，目的地是對應的主路房間，主路那扇門 `branch: true`
  - `test_branch_b_walkable`：支路 B `walk_errors(d, 門的出生點, frag_b 的位置)` 為空
  - `test_branch_return_spawn_on_ledge`（Review Focus 5）：從支路回主路，出生點在高處平台上、不在任何門的矩形裡
  - `test_all_forest_reachable`：從 `yard` 經門走得到 9 間森林
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：排版**：同 Task 6（截圖檢查）
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_c4a test_ground_rooms test_rooms test_walkthrough` 全過
- [ ] **Step 5：Commit** `Hide three fragments down short side paths (MV-SLICE-001c4a)`

### Task 8：素材工單、截圖與文件

**Files:** Create `docs/assets/MV-ASSET-017_下劈水晶與血量碎片.md`、`report/MV-SLICE-001c4a_森林與藏點_{YYYY-MM-DD_HHmm}_執行報告.md`（時間戳先跑 `date`）；Modify `game/README.md`（森林、新元素、碎片）、`todo/spec/MV-SLICE-001c4a_森林與藏點.md`（驗收、Git Commit）、`todo/todo.md`（c4a、MV-ASSET-017）

本 Task 沒有新程式、沒有新測試。

- [ ] **Step 1：工單**：照 MV-ASSET-002／003 的格式寫兩件（下劈水晶、血量碎片＋血條半格／一格），四段式 prompt、尺寸、驗收標準
- [ ] **Step 2：截圖**：`--shots` 全部（含 9 間森林）；每間做縮圖總表，AI 檢查版面；幀時間 ≤ 16.7 ms
- [ ] **Step 3：文件**：照 Files；規格書只勾 AI 有證據的項目；`todo.md` 維持 🔄、改「實作完成，待 Brian 看截圖與手把試玩（計時）」
- [ ] **Step 4：跑** `bash /tmp/wt/step6.sh`（469＋新增、`--check`、unittest）
- [ ] **Step 5：Commit** `Write the crystal and fragment art order and document the forest (MV-SLICE-001c4a)`
