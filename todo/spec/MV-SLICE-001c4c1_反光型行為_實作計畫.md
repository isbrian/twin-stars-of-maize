# MV-SLICE-001c4c1 反光型的行為 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增第三種假光造物「反光型」：站著用反光面射貼地光束、正面擋攻擊，破解靠前搖時吹箭打斷與繞背；用程式佔位外觀放進森林 3、5、6 與關門戰，並交出素材工單。

**Architecture:** `core/enemies/reflector.gd` 繼承 `enemy.gd`，沿用 IDLE → TELEGRAPH → ATTACK → RECOVER／STAGGER 的狀態機；擋與否在覆寫的 `_on_hurt` 判斷（攻擊來源相對反光面的方向），轉身是 IDLE 裡的子狀態，光束是 ATTACK 時把共用 `hitbox` 改成光束矩形。房間端只改生成（三種 `kind`）、回饋音接線與資料。

**Tech Stack:** Godot 4.7.2 GDScript；自測 `godot --headless --path game -- --self-test`（多檔 `bash /tmp/wt/st_only.sh test_a test_b`；全套 `bash /tmp/wt/step6.sh`）；截圖 `godot --path game -- --shots <資料夾>`；素材生成 Codex CLI（`/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex exec ... < /dev/null`）。

**Spec:** [MV-SLICE-001c4c1_反光型行為.md](MV-SLICE-001c4c1_反光型行為.md)（Brian 2026-10-16 核准）

## Global Constraints

- 名稱「反光型」，房間資料 `kind: "reflector"`；血 24、傷害 1、前搖 1.0 秒、光束 0.5 秒、射程 960、收招 1.0 秒、轉身 0.8 秒、體型約 160×140；光束離地 `beam_band`（20～100 px）。
- 前搖訊號暗紫鋸齒（`parryable = false`）；不用紅色。
- 正面（攻擊來源在反光面朝向那一側、水平距離 ≥ 30 px）在待機、前搖、光束時：不扣血、發 `thudded`；前搖中的正面吹箭＝打斷（硬直 `dart_stagger_time` 0.6、冷卻 `dart_interrupt_cooldown` 3）。正上方（水平距離 < 30）與背後全額扣血；轉身、收招、硬直時正面也扣血。
- 出招：玩家在正面、水平距離 ≤ 960、高低差 ≤ 250、`state_time ≥ enemy_rest`。
- 放置：森林 3、5、6 主路各 1 隻（主路 19 → 22）；支路 C 關門戰第 3 波一隻爬行型換成反光型（仍 4 隻）。主路通過性與 c4a、c4b 版面規則照舊。
- 沒有骨架前不掛 `EnemyAnimator`，用程式畫佔位（身體＋看得出朝向的反光板）。
- 存檔欄位不變；註解、文件繁體中文；commit 英文、結尾 `(MV-SLICE-001c4c1)`；全套自測基準 538 項。

## Review Focus

1. **玩家站在反光型正上方下劈**：算背後、扣血，而且反光型不會在正上方來回轉身（左右判定在中線附近抖動）→ Task 1 `test_from_above_hurts_without_turn_jitter`
2. **光束射向近處的牆**：在牆前就停，不穿牆打到牆後的東西 → Task 1 `test_beam_stops_at_wall`
3. **打斷冷卻中再射一發正面吹箭**：不打斷、不扣血、只有悶響（不能因為冷卻中就變成扣血）→ Task 1 `test_front_dart_during_cooldown_thuds`
4. **前搖到一半玩家翻滾到背後**：光束仍朝原方向射（朝向在前搖開始時鎖定），打不到背後的玩家 → Task 1 `test_beam_locked_forward`
5. **關門戰第 3 波有反光型**：打倒它也算清掉、波次照常結束、碎片出現 → Task 2 `test_arena_wave3_with_reflector_clears`

---

## 檔案結構

| 檔案 | 責任 | Task |
|---|---|---|
| `game/core/tuning/combat_tuning.gd` | 反光型數值 | 1 |
| `game/core/enemies/reflector.gd`（新） | 行為、擋、轉身、光束、佔位繪圖 | 1 |
| `game/tests/test_c4c1.gd`（新） | 本計畫的測試 | 1、2 |
| `game/world/room.gd` | `spawn_enemy` 三種、反光型不掛骨架、`thudded` 回饋音 | 2 |
| `game/world/room_check.gd` | 反光型也要站在地形上 | 2 |
| `game/world/rooms/forest_3.gd`、`forest_5.gd`、`forest_6.gd`、`forest_c.gd` | 放置 | 2 |
| `game/tests/test_ground_rooms.gd` | 每房敵人數改成「爬行＋飛行 1～4、反光型 ≤ 1」 | 2 |
| `game/world/shots.gd` | 截圖清單（若既有畫面拍不到反光型就加 `x=` 拍法） | 2 |
| `docs/assets/MV-ASSET-019_素材工單_反光型.md`（新）、報告、規格、`game/README.md`、`todo/todo.md` | 素材工單、生成與驗收、文件 | 3 |

---

### Task 1：反光型的行為

**Files:** Modify `core/tuning/combat_tuning.gd`；Create `core/enemies/reflector.gd`、`tests/test_c4c1.gd`

**Interfaces:**
- Produces（`combat_tuning.gd`）：`@export var reflector_hp := 24`、`reflector_damage := 1`、`reflector_telegraph := 1.0`、`reflector_beam_time := 0.5`、`reflector_range := 960.0`、`reflector_recover := 1.0`、`reflector_turn_time := 0.8`。
- Produces（`reflector.gd`，`extends "res://core/enemies/enemy.gd"`）：
  - `_init()`：`size = Vector2(160, 140)`、`parryable = false`；`const FRONT_MIN := 30.0`（水平距離小於它算正上方＝背後）；`const SIGHT_HEIGHT := 250.0`。
  - `signal thudded`（正面擋下）。
  - `func is_front(from: Vector2) -> bool`：`(from.x - global_position.x) * facing >= FRONT_MIN`。
  - `func blocking() -> bool`：`state` 是 IDLE、TELEGRAPH、ATTACK 且 `turn_left <= 0`。
  - `var turn_left := 0.0`：IDLE 中玩家在背後（`(target.x - x) * facing <= -FRONT_MIN`）且沒在轉時設為 `reflector_turn_time`；倒數到 0 時 `facing = -facing`；轉身中不出招。
  - `_idle`：不移動；轉身中只倒數；否則玩家在正面、`absf(dx) <= reflector_range`、`absf(dy) <= SIGHT_HEIGHT`、`state_time >= tn.enemy_rest` → `start_telegraph()`。
  - `_telegraph_time()`／`_recover_time()`／`_max_hp()`／`_damage()` 回對應數值；`_uses_gravity()` true。
  - `var beam_rect := Rect2()`（本地座標）：`_begin_attack()` 依 `facing` 從反光面前緣往前 `reflector_range`，用一次水平射線（`L.WORLD`，高度 = 離地 `beam_band` 中點）找牆、截短；`hitbox.configure(beam_rect.size, beam_rect.get_center(), L.PLAYER_HURT)` 後 `hitbox.start()`（`enemy.gd` 進 ATTACK 時已呼叫 `start`，順序以光束形狀生效為準）。`_attack`：`state_time >= reflector_beam_time` → `_end_attack()`；離開 ATTACK 後把 hitbox 還原成身體大小（不留光束判定）。
  - `_on_hurt(amount, source, kind)` 覆寫：`blocking()` 且 `source` 有效且 `is_front(source.global_position)` → 若 `kind == &"dart"`、`state == TELEGRAPH`、`interrupt_cooldown_left <= 0` → 打斷（同 `enemy.gd` 的打斷分支、不扣血）；否則 `thudded.emit()`、`spark_left = 0.15`；兩者都 return。其餘交給 `super`。
  - `_draw()`：`portrait_drawn` false 時畫佔位——珠寶金身體＋前方一塊高對比（淺青）的反光板：待機、轉身時板子在胸前，前搖、光束時舉高到頭上方前側，收招、硬直時放低；前搖時板子中心的光點由暗到亮（`state_time / reflector_telegraph`）；ATTACK 時畫光束（白芯＋金邊，範圍 `beam_rect`）；`spark_left > 0` 時在板子上畫小火花。前搖訊號、硬直色照 `enemy.gd` 的 `_draw` 共用部分。

- [ ] **Step 1：失敗測試**（`tests/test_c4c1.gd`；用 `make_world()`、`make_player(w, at)`、`make_enemy(w, Reflector, at, target)`，地面頂在 y 0）：
  - `test_reflector_numbers`：血 24；`parryable` false；體型 160×140
  - `test_front_blocks_back_hurts`：反光型在 (0, 0) 面向右（`facing = 1`）；從 (300, 0) 的來源打 5 點 → 血仍 24、`thudded` 發 1 次；從 (-300, 0) 打 5 點 → 血 19
  - `test_from_above_hurts_without_turn_jitter`（Review Focus 1）：玩家在 (10, -150)，60 幀內 `facing` 不改變；從 (10, -150) 打 5 點 → 扣血
  - `test_front_dart_interrupts_in_telegraph`：玩家在 (500, 0) → 前搖；正面 `kind &"dart"` 打中 → `state == STAGGER`、血仍 24、發 `interrupted`
  - `test_front_dart_during_cooldown_thuds`（Review Focus 3）：打斷後硬直結束、再次前搖時（冷卻 3 秒內）正面吹箭 → 仍在 TELEGRAPH、血不變、`thudded` 加 1
  - `test_recover_and_turn_take_front_hits`：收招中正面打 → 扣血；玩家移到 (-500, 0) 後 0.4 秒內（轉身中）正面打 → 扣血；0.9 秒後 `facing == -1`
  - `test_telegraph_conditions`：玩家在正面 900 → 前搖；正面 1000、背後 300、正面 300 但高 300 → 1.5 秒內都不前搖
  - `test_beam_hits_ground_not_jumper`：玩家站在正面 600 → 前搖 1.0 秒後光束出現、玩家扣 1；玩家在光束時間內離地 150（`position.y = -150`）→ 不扣
  - `test_beam_length_and_time`：光束時 `beam_rect.size.x == 960`（前方沒有牆）、持續約 0.5 秒後回 RECOVER、hitbox 恢復身體大小
  - `test_beam_stops_at_wall`（Review Focus 2）：正面 400 處放一道實心牆（`L.WORLD`）→ `beam_rect.size.x` 約等於牆到反光面前緣的距離（±10）
  - `test_beam_locked_forward`（Review Focus 4）：前搖開始後把玩家移到背後 (-300, 0) → 光束仍向右、玩家不扣血
  - `test_reflector_dies_at_24`：累計背後扣 24 → 發 `died`
- [ ] **Step 2：跑** `bash /tmp/wt/st_only.sh test_c4c1` → 失敗（找不到 `reflector.gd`）
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_c4c1 test_enemies test_combat test_player` 全過
- [ ] **Step 5：Commit** `Add the reflector creature: a frontal mirror and a ground beam (MV-SLICE-001c4c1)`

### Task 2：放進房間

**Files:** Modify `world/room.gd`、`world/room_check.gd`、`world/rooms/forest_3.gd`、`forest_5.gd`、`forest_6.gd`、`forest_c.gd`、`tests/test_ground_rooms.gd`、`world/shots.gd`、`tests/test_c4c1.gd`

**Interfaces:**
- Consumes：Task 1 `reflector.gd`（`thudded`、`kind` 字串 `"reflector"`）
- Produces（`room.gd`）：`spawn_enemy` 依 `e.kind`：`crawler` → Crawler、`flyer` → Flyer、`reflector` → Reflector；`EnemyAnimator.attach` 只對 `crawler`、`flyer`；反光型 `thudded` → `feedback.play(&"thud")`。
- Produces（`room_check.gd`）：站在地形上的檢查從 `crawler` 擴成 `crawler`、`reflector`。
- 放置起始座標（排版時以截圖與測試校準）：森林 3 x 2000、森林 5 x 3300、森林 6 x 2700（都在地面 `Kit.GROUND_Y`；離門出生點 ≥ 600、不在荊棘上、前方 960 內不要剛好是鎖高台的落腳點）；支路 C 第 3 波 `Vector2(3000, GROUND_Y)` 的爬行型改成反光型。

- [ ] **Step 1：失敗測試**：
  - `test_rooms_spawn_reflector`：建一間只有一隻 `reflector` 的測試房間（`_test_b` 資料、清掉敵人）→ `r.enemies[0]` 是 Reflector、有場景時沒有骨架子節點；`thudded` 時 feedback 收到 `thud`（檢查訊號有連到 `r.feedback`）
  - `test_reflector_placement`：森林 3、5、6 各正好 1 隻 `reflector`、其他森林與支路 A、B 沒有；主路 6 間合計 22 隻；關門戰第 3 波 4 隻、其中 1 隻 `reflector`
  - `test_reflector_on_terrain_checked`：懸空的 `reflector` → `RoomCheck.errors` 有錯
  - `test_arena_wave3_with_reflector_clears`（Review Focus 5）：照 c4a `test_arena_waves_and_reward` 的做法打完 3 波（用 `kill()`）→ 閘門消失、碎片出現
  - `test_ground_rooms.gd` `test_enemy_counts_per_room`：改成「爬行型＋飛行型 1～4、反光型 ≤ 1」
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作與排版**：寫資料 → `--shots` 截森林 3、5、6 與支路 C（拍不到反光型的位置就在 `shots.gd` 加 `x=` 拍法）→ 檢查佔位朝向清楚、和其他敵人不重疊 → 調座標
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_c4c1 test_c4a test_c4b test_ground_rooms test_rooms test_walkthrough test_tune004` 全過
- [ ] **Step 5：Commit** `Place reflectors in forests 3, 5, 6 and the arena (MV-SLICE-001c4c1)`

### Task 3：素材工單、生成與文件

**Files:** Create `docs/assets/MV-ASSET-019_素材工單_反光型.md`、`report/MV-SLICE-001c4c1_反光型行為_{YYYY-MM-DD_HHmm}_執行報告.md`（時間戳先跑 `date`）；Modify `game/README.md`（敵人三種）、`todo/spec/MV-SLICE-001c4c1_反光型行為.md`（驗收、Git Commit）、`todo/todo.md`（c4c1、MV-ASSET-019、MV-ASSET-003 的待決項）

本 Task 沒有新程式、沒有新測試。

- [ ] **Step 1：工單**：照 MV-ASSET-003 B 部分（假光造物爬行型、飛行型）的格式與 ART_SPEC 第 8 節寫一件——反光型基準圖（1536×1024 或 1024×1024、洋紅背景）：珠寶色假光造物、中型、雙腳站立或矮壯的身體＋一塊獨立的反光面（圓或橢圓的打磨面、中央一個光點位置）、反光面不和身體重疊（方便 c4c2 切分件）；不畫真光、光暈、紅色、暗紫；四段式 prompt、附爬行型與飛行型基準圖當風格參考
- [ ] **Step 2：生成**：交 Codex（指示寫明非互動、不 commit、不推送、不下載、只寫 `assets-test/c4c_art/`、最多 3 次、不可用程式繪圖取代生成；`< /dev/null`）；AI 親眼驗收（縮到遊戲內大小、放在森林底上；反光面是否獨立、可讀性、文化限制），結果寫進工單
- [ ] **Step 3：截圖**：`--shots` 全部；森林 3、5、6 與支路 C 縮圖，AI 檢查；幀時間 ≤ 16.7 ms；存 `assets-test/c4c1_shots/`
- [ ] **Step 4：文件**：照 Files；規格書只勾 AI 有證據的項目；`todo.md` c4c1 維持 🔄、改「實作完成，待 Brian 手把試玩」；新增 MV-ASSET-019 列；MV-ASSET-003 的待決項改成「反光型行為已定（c4c1），素材見 MV-ASSET-019」
- [ ] **Step 5：跑** `bash /tmp/wt/step6.sh`（538＋新增、`--check`、unittest）
- [ ] **Step 6：Commit** `Write the reflector art order and document the new creature (MV-SLICE-001c4c1)`
