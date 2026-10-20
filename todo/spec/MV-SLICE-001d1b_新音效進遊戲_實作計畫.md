# MV-SLICE-001d1b 新音效進遊戲 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 MV-ASSET-021 的 61 種音效接進遊戲（腳步、戰鬥、敵人、拾取、介面、過場），補前兆專用播放器與 d1a 延後的 4 項。

**Architecture:** 沿用 d1a 的 `Audio`＋`SOUNDS`：大多數只在資料表補列或把接入點的 id 改成依武器／兄弟／地面而定。新增三個能力：`Audio.play_at(id, pos)`（`AudioStreamPlayer2D` 池，距離衰減）、`Audio.floor_at(pos)`（由目前的房間或 Boss 戰提供 `floor_source`，同 `listener` 的做法）、前兆專用播放器。腳步由雙胞胎的動作器（遊戲中的 `twin_animator`、過場的 `actor`）在 `steps` 標記的格放。

**Tech Stack:** Godot 4.7.2 GDScript；自測 `bash /tmp/wt/st_only.sh <檔名片段>`、全套 `bash /tmp/wt/step6.sh`；影片 `--sound-tour`＋`--write-movie`＋ffmpeg。

**Spec:** [MV-SLICE-001d1b_新音效進遊戲.md](MV-SLICE-001d1b_新音效進遊戲.md)（Brian 2026-10-20 核准，含 `interrupt`→`dart_weak`、`tool_out`→`swing_stick` -4 dB）

## Global Constraints

- 音檔：從 `assets-test/batch3/audio/` 原樣複製 WAV 到 `game/art/audio/`（檔名不改）；id 去掉 `sfx_` 前綴與 `_0N` 變體號，例：`sfx_wpn_axe_swing_01～03` → `wpn_axe_swing`。過場 16 種 id 為 `cs_*`、介面 6 種 `ui_*`。
- 取代合成的 id（`feedback.play` 原本的名字）用資料表別名：`double_jump`、`dart`、`hurt`、`heal`、`pogo`、`barrier_break`、`parry`（→ `wpn_parry_ok`）、`chop`（→ `abl_tool_chop`）、`interrupt`（→ `wpn_dart_weak` 三檔）、`tool_out`（→ `wpn_stick_swing` 三檔，`db` -4）。`swing`、`hit`、`swap`、`thud` 不再用：接入點改傳 `wpn_axe_swing`／`wpn_stick_swing`、`wpn_axe_hit`／`wpn_stick_hit`、`cmb_swap_hunahpu`／`cmb_swap_xbalanque`、`lvl_barrier_thud`／`enm_reflector_block`。
- 反光型光束：`boss_sm_beam_charge`／`beam_fire` 以 `play_at`、`db` -6（資料表另列 `enm_reflector_beam_charge`／`_fire` 指同檔）。
- 敵人移動與攻擊：`play_at`；`max_distance` 2000 px；同一種移動聲 0.1 秒內只放一次；移動聲約 0.35 秒一步、只在 `IDLE` 且水平速度 > 20 時。
- 腳步：只在地面、非翻滾、非硬直；過場只有雙胞胎（`hunahpu`／`xbalanque` 替身）。
- 前兆：2 個專用 `AudioStreamPlayer`（`Tell`），一般 12 個不再播前兆。
- 合成佔位保留（SLICE-d1b-7）。
- 註解、文件繁體中文；commit 英文、結尾 `(MV-SLICE-001d1b)`；全套自測基準 630 項。

## Review Focus

1. **換武器或換人的同一幀揮擊**：揮擊與命中聲用「出招當下」的武器，不是換完的 → Task 2 `test_swing_uses_weapon_at_swing`
2. **腳步在動作切換的那一格**（跑 → 跳、跑 → 翻滾）：不多放一步 → Task 3 `test_no_step_when_leaving_ground`
3. **過場被跳過**：跳過時不連珠炮把剩下的過場音效全放出來 → Task 5 `test_skipped_cutscene_is_quiet`
4. **敵人在房間釋放的同一幀出招**：`play_at` 不讀已釋放的節點（只傳位置） → Task 4 `test_play_at_takes_position_only`
5. **暫停中（兌換、裝備頁）按選單**：介面聲照放（`process_mode` ALWAYS 的 `Audio`） → Task 4 `test_ui_sounds_while_paused`

---

## 檔案結構

| 檔案 | 責任 | Task |
|---|---|---|
| `game/art/audio/sfx_*.wav`（新 123 個） | 正式音檔 | 1 |
| `game/core/audio/sound_table.gd` | 新列、別名 | 1 |
| `game/core/audio/audio.gd` | 前兆專用播放器、`play_at`、`floor_at`、d1a 延後 3 項 | 1、3 |
| `game/core/player/player.gd` | `jumped`、`landed`、`rolled`、`parry_whiffed` 訊號 | 2 |
| `game/core/player/dart.gd` | 命中物件／光源的聲音 | 2 |
| `game/world/room.gd`、`game/core/boss/boss_fight.gd` | 接入點改 id；`floor_source`；荊棘；`_update_forest_hint` 註解 | 2、3、5 |
| `game/rig/twin_anims.json`、`game/world/twin_animator.gd`、`game/world/cutscene/actor.gd` | `steps` 與腳步 | 3 |
| `game/world/rooms/home.gd` | `floor: "hard"` | 3 |
| `game/core/enemies/enemy.gd`、`reflector.gd` | 移動、攻擊、光束 | 4 |
| `game/core/player/rat.gd`、`tool_spirit.gd`、`game/world/pickup.gd`、`game/events/event_runner.gd`、`game/ui/*.gd` | 能力、拾取、兌換、介面 | 4 |
| `game/world/cutscene/*.gd`、`game/events/field_clearing.gd` | 過場 16 種 | 5 |
| `game/world/sound_tour.gd`、文件 | 展示、影片、報告 | 6 |
| `game/tests/test_d1b.gd`（新） | 本計畫的測試 | 1～5 |

---

### Task 1：音檔、資料表、前兆專用播放器、d1a 延後 3 項

**Files:** Create `game/art/audio/sfx_*.wav`、`game/tests/test_d1b.gd`；Modify `game/core/audio/sound_table.gd`、`audio.gd`

**Interfaces:**
- Produces（`sound_table.gd`）：Global Constraints 的所有新 id 與別名；`SOUNDS` 每列格式同 d1a。
- Produces（`audio.gd`）：
  - `const TELL_PLAYERS := 2`；`play(id)` 在 `bus == "Tell"` 時用前兆專用播放器
  - `func play_at(id: StringName, pos: Vector2) -> String` — `AudioStreamPlayer2D` 池（12 個）、`max_distance` 2000、`global_position = pos`；同一 id 0.1 秒內只放一次（`enm_*_move` 用；其他 id 不節流）
  - `_tween()` 加 `set_ignore_time_scale(true)`
  - 不循環的配樂放完（`finished`）時 `music = &""`、播放器釋放
  - `_exit_tree()`：停所有播放器、清 `_cache`
- 指令：`cp assets-test/batch3/audio/sfx_*.wav game/art/audio/` → `godot --headless --path game --import`

- [ ] **Step 1：失敗測試**（`test_d1b.gd`）
  - `test_new_sounds_load`：Global Constraints 的每個新 id 都在 `SOUNDS`，檔案載得到
  - `test_every_used_id_is_in_table`：掃描 `res://` 下所有 `.gd`（不含 `tests/`），用正規式抓 `feedback.play(&"x")`、`Audio.play(&"x")`、`Audio.play_at(&"x"`、`.bind(&"x")`（接在 `feedback.play` 之後）、`sfx(&"x")` 的 id，每個都在 `SOUNDS`
  - `test_tell_not_cut_by_sfx`：連播 20 個一般音效後 `play_tell(false)`，前兆專用播放器有一個在播、串流是 `tell_heavy` 的檔
  - `test_fade_ignores_hitstop`：`Engine.time_scale = 0` 下交叉淡化，`AMB_FADE + 0.2` 秒（真實時間）後完成；結束恢復 1
  - `test_one_shot_music_clears`：`play_music(&"mus_s01")`，4.5 秒後 `Audio.music == &""`
  - `test_play_at_takes_position_only`：`play_at(&"enm_crawler_move", Vector2(100, 0))` 回傳檔名、某個 2D 播放器在 (100, 0)；0.05 秒內再放同 id 回傳 `""`
- [ ] **Step 2：跑** `bash /tmp/wt/st_only.sh test_d1b` → 失敗
- [ ] **Step 3：複製音檔、實作**
- [ ] **Step 4：跑** `test_d1b`、`test_d1a` 全過（`test_every_used_id_is_in_table` 在 Task 2 改完接入點前可能仍失敗——列出缺的 id，Task 2 結束時必須全過）
- [ ] **Step 5：Commit** `Add the MV-ASSET-021 sounds, a tell-only player pool and positional playback (MV-SLICE-001d1b)`

### Task 2：角色與戰鬥的接入點

**Files:** Modify `game/core/player/player.gd`、`dart.gd`、`game/world/room.gd`、`game/core/boss/boss_fight.gd`、`game/tests/test_d1b.gd`

**Interfaces:**
- Produces（`player.gd`）：`signal jumped`（地面起跳，不含二段跳）、`signal landed`（從空中落地）、`signal rolled`、`signal parry_whiffed`（`_record_parry(WHIFF)` 時）
- Produces（共用函式，放 `sound_table.gd`）：`static func swing_id(weapon: int) -> StringName`、`static func hit_id(weapon: int) -> StringName`（斧頭 → `wpn_axe_*`，掘棒與其他 → `wpn_stick_*`）、`static func swap_id(twin_index: int) -> StringName`（0 胡納普、1 希巴拉克）
- 接入點（`room.gd` 與 `boss_fight.gd` 兩處都改）：`swung` → `swing_id(player.attack_weapon)`（出招當下的武器）；`hit_landed` → 水晶 `pogo`、其他 `hit_id(...)`；`swapped` → `swap_id(player.twin_index)`；`jumped`／`landed`／`rolled`／`parry_whiffed` → `mov_jump`／`mov_land`／`mov_roll`／`wpn_parry_miss`；木障 `thudded` → `lvl_barrier_thud`；反光型 `thudded` → `enm_reflector_block`；`_thorn_respawn` → `lvl_thorn_hurt`
- `dart.gd`：打到光源 → `wpn_dart_weak`；打到地形或非 Hurtbox → `wpn_dart_hit`（打到敵人 Hurtbox 不放，打斷另由 `interrupt` 放）

- [ ] **Step 1：失敗測試**：`test_swing_uses_weapon_at_swing`（斧頭揮擊時 `wpn_axe_swing` +1；同一幀換武器後的揮擊仍記出招當下的武器）、`test_hit_id_by_weapon`、`test_swap_plays_twin_cue`（切到希巴拉克 → `cmb_swap_xbalanque`）、`test_jump_land_roll_sounds`（`make_player` 起跳 → `mov_jump`、落地 → `mov_land`、翻滾 → `mov_roll`；二段跳不放 `mov_jump`）、`test_parry_whiff_sound`、`test_dart_hits_wall_and_light`、`test_thorn_and_barrier_sounds`
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `test_d1b`（含 `test_every_used_id_is_in_table` 必須過）、`test_player`、`test_combat`、`test_boss`、`test_c4a`、`test_c4c1` 全過
- [ ] **Step 5：Commit** `Give the twins' moves, weapons and darts their own sounds (MV-SLICE-001d1b)`

### Task 3：腳步

**Files:** Modify `game/rig/twin_anims.json`、`game/world/twin_animator.gd`、`game/world/cutscene/actor.gd`、`game/core/audio/audio.gd`、`game/world/room.gd`、`game/core/boss/boss_fight.gd`、`game/world/rooms/home.gd`、`game/tests/test_d1b.gd`

**Interfaces:**
- Produces（`twin_anims.json`）：`run` 與 `walk` 各加 `"steps": [格號, 格號]`（腳著地的兩格；看動作抽格決定）
- Produces（`audio.gd`）：`var floor_source: Callable`（沒設時一律 `&"dirt"`）；`func floor_at(pos: Vector2) -> StringName`；`func step_id(char_name: String, floor: StringName) -> StringName`（→ `mov_step_<floor>_<hunahpu|xbalanque>`）
- Produces（`room.gd`）：`func floor_material_at(pos: Vector2) -> StringName` — `data.get("floor") == "hard"`，或 `pos` 站在某個 `platforms` 矩形頂端（x 在範圍內、y 在頂端 ±8 px）→ `&"hard"`；否則 `&"dirt"`；`build` 結束設 `Audio.floor_source = floor_material_at`
- Produces（`boss_fight.gd`）：`floor_material_at(pos)` — 宮殿段（`phase >= 2` 或覺醒後在宮殿裡）→ `&"hard"`，其餘 `&"dirt"`；建好時設 `Audio.floor_source`
- `home.gd`：`"floor": "hard"`
- `twin_animator.gd`：目前動作是 `run` 且播到 `steps` 的格（跨格判定，不重複）、角色在地面、不在翻滾／硬直 → `Audio.play(Audio.step_id(目前兄弟, Audio.floor_at(角色腳底)))`
- `actor.gd`：替身是雙胞胎、動作是 `walk`／`run`、播到 `steps` 的格 → 同上（用替身位置）

- [ ] **Step 1：失敗測試**：`test_run_has_steps`、`test_run_cycle_plays_two_steps`（每個循環 2 次）、`test_step_by_twin_and_floor`（胡納普在森林 → `mov_step_dirt_hunahpu`；希巴拉克在祖母家 → `mov_step_hard_xbalanque`；站在平台上 → `hard`）、`test_no_step_when_leaving_ground`（起跳那一幀起不再放）、`test_cutscene_twin_walk_steps`（過場替身走路有腳步、老人沒有）
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**（`steps` 先抽 `run`、`walk` 的格圖，挑腳底最低的兩格）
- [ ] **Step 4：跑** `test_d1b`、`test_twin_animator`、`test_rig`、`test_cutscene`、`test_rooms` 全過；`python3 tools/import_rig.py --check` 結束碼 0
- [ ] **Step 5：Commit** `Put footsteps on the twins' contact frames, on dirt or hard floors (MV-SLICE-001d1b)`

### Task 4：敵人、能力、拾取、兌換與介面

**Files:** Modify `game/core/enemies/enemy.gd`、`reflector.gd`、`game/core/player/rat.gd`、`tool_spirit.gd`、`game/world/pickup.gd`、`game/events/event_runner.gd`、`game/ui/title_menu.gd`、`pause_menu.gd`、`shop.gd`、`equip_page.gd`、`text_card.gd`、`game/tests/test_d1b.gd`

**Interfaces:**
- Produces（`enemy.gd`）：子類別覆寫 `func _sound_kind() -> String`（`"crawler"`／`"flyer"`／`"reflector"`）；`_physics_process` 在 `IDLE` 且水平速度 > 20 時每 0.35 秒 `Audio.play_at(&"enm_<kind>_move", global_position)`；`_enter(ATTACK)` 時 `Audio.play_at(&"enm_<kind>_attack", …)`
- `reflector.gd`：蓄力開始 `play_at(&"enm_reflector_beam_charge")`、發射 `play_at(&"enm_reflector_beam_fire")`
- `rat.gd`：鑽地 `abl_rat_burrow`、竄出 `abl_rat_emerge`；`tool_spirit.gd`：斧頭 `chopped` 已有（`chop` 別名）、掘棒翻土 `abl_tool_dig`
- 拾取：可可豆 `pick_cacao`、碎片 `pick_fragment`、工具與球具 `pick_item`
- `shop.confirm()` 成功 → `npc_exchange`；介面：游標移動 `ui_move`、確認 `ui_confirm`、返回／取消 `ui_back`、裝備頁換技能 `ui_skill_switch`、裝備頁與文字卡開 `ui_page_open`／關 `ui_page_close`

- [ ] **Step 1：失敗測試**：`test_enemy_move_and_attack_positional`（爬行型巡邏中 0.5 秒內 `enm_crawler_move` ≥ 1、出招 `enm_crawler_attack` +1，且是 2D 播放器）、`test_enemy_move_silent_when_still`、`test_reflector_beam_sounds`、`test_rat_burrow_emerge`、`test_pickup_sounds`、`test_exchange_sound`、`test_menu_sounds`（主選單上下、確認；暫停選單返回）、`test_ui_sounds_while_paused`（`paused = true` 時裝備頁開關放得出來）
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `test_d1b`、`test_enemies`、`test_c4c1`、`test_c4c2`、`test_rat`、`test_ui`、`test_menus`、`test_loadout`、`test_rest_and_cacao`、`test_events` 全過
- [ ] **Step 5：Commit** `Sound the false-light creatures, the rat, pickups, the exchange and the menus (MV-SLICE-001d1b)`

### Task 5：過場音效與 boss_fight 註解

**Files:** Modify `game/world/cutscene/opening.gd`、`arm.gd`、`field_animals.gd`、`field_dusk.gd`、`rat_deal.gd`、`gear_rope.gd`、`teeth.gd`、`death.gd`、`awaken.gd`、`game/core/boss/boss_fight.gd`、`game/tests/test_d1b.gd`

**Interfaces:**
- 對照（MV-ASSET-021 G6「用在」欄）：`cs_grass_crouch`（開場蹲進草叢）、`cs_macaw_fall`／`cs_wing_wrench`／`cs_sit_fall`（斷臂）、`cs_animals_run`／`cs_bush_regrow`／`cs_lunge`（動物復原）、`cs_net_drop`／`cs_food_place`（交換）、`cs_rat_climb`／`cs_rat_gnaw`／`cs_rope_snap`（咬繩）、`cs_teeth_swap`（換牙）、`cs_gem_pluck`／`cs_jewels_gather`（死亡）、`cs_arm_restore`（覺醒）；收工裡工具自己砍／翻土用 `abl_tool_chop`／`abl_tool_dig`
- 過場被跳過（`cs.skipped`）時不放
- `boss_fight.gd`：`_update_forest_hint` 的 `##` 說明搬回它上方

- [ ] **Step 1：失敗測試**：`test_cutscene_sounds_each_play`（依序跑 opening、arm、field、deal、rope、teeth、death＋awaken，每個 `cs_*` ≥ 1）、`test_skipped_cutscene_is_quiet`（開場一開始就跳過，`cs_*` 不增加）
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `test_d1b`、`test_cutscene`、`test_c3a`、`test_c3b` 全過
- [ ] **Step 5：Commit** `Give the ground and boss cutscenes their action sounds (MV-SLICE-001d1b)`

### Task 6：展示影片、全套驗證與文件

**Files:** Modify `game/world/sound_tour.gd`、`game/README.md`、`todo/spec/MV-SLICE-001d1b_新音效進遊戲.md`、`todo/todo.md`、`docs/assets/MV-ASSET-021_素材工單_切片缺的音效.md`；Create `report/MV-SLICE-001d1b_新音效進遊戲_<date 的輸出>_執行報告.md`

- [ ] **Step 1：展示加段**：跑過土與硬地（腳步兩兄弟）、揮擊與命中（兩種武器）、招架成功與落空、吹箭打牆與打光源、換人、受擊與治療、拾取、老鼠技能、主選單與裝備頁、地面三段過場與斷臂、換牙；結束印 `play_count`
- [ ] **Step 2：錄影與量測**：`--write-movie` → mp4；整合響度、true peak ≤ -1 dBTP；抽格與頻譜圖；`play_count` 裡 61 種新 id 沒出現的列出理由
- [ ] **Step 3：全套** `bash /tmp/wt/step6.sh` → `fail=0`、`errors: 0`
- [ ] **Step 4：文件**：README「聲音」補 `play_at`、`floor_at`、腳步、前兆專用播放器；執行報告（時間戳先跑 `date`）；規格勾選；MV-ASSET-021 狀態；todo
- [ ] **Step 5：Commit** `Record the d1b sound tour and document the new sounds (MV-SLICE-001d1b)`
- [ ] **Step 6**：最終全分支審查 → 修正 → 交 Brian 聽影片
