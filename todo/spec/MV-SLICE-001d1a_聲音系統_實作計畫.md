# MV-SLICE-001d1a 聲音系統 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立全域聲音單例 `Audio`（匯流排、資料表、環境音、距離層、配樂），把已生成的音檔接進遊戲，取代對應的合成佔位。

**Architecture:** autoload `Audio`（`core/audio/audio.gd`）開機時用程式建 4 條匯流排與播放器池，讀純資料表 `core/audio/sound_table.gd`。`feedback.play(id)` 先問 `Audio.has_sound(id)`，有就交給 `Audio`，沒有就照舊播 `sfx.gd` 合成。環境音由房間 theme 對照，`room_flow` 換房時呼叫；距離層每幀依 listener 與 group 裡的來源算音量。前兆在 `enemy._enter` 與 `seven_macaw` 的 `signal_kind` 變化處觸發；配樂在 `boss_fight` 偵測 stage 進出 `FIGHT`。為了 headless 自測，`Audio` 記錄自己的狀態（最近播的檔、目前環境音、配樂、層音量），測試讀這些狀態。

**Tech Stack:** Godot 4.7.2 GDScript；`ffmpeg`（轉 OGG、量響度與接縫）；自測 `godot --headless --path game -- --self-test`（單檔 `bash /tmp/wt/st_only.sh test_d1a`、全套 `bash /tmp/wt/step6.sh`）；影片 Godot Movie Maker（`--write-movie *.avi`，含音軌）＋ffmpeg 轉 mp4。

**Spec:** [MV-SLICE-001d1a_聲音系統.md](MV-SLICE-001d1a_聲音系統.md)（Brian 2026-10-19 核准）

## Global Constraints

- 匯流排：`Master` 底下 `Music`、`Amb`、`Sfx`、`Tell`；初始音量 `Tell` 0 dB、`Sfx` −3 dB、`Music` −8 dB、`Amb` −12 dB；`Music`、`Amb` 各一個 `AudioEffectCompressor`，`sidechain = &"Tell"`（壓低約 6～8 dB、release 0.3 秒）。
- 環境音：`home`、`field` → `amb_02`；`yard` → `amb_03`；`forest` 與 Boss 段落 → `amb_01`；交叉淡化 1.5 秒；同 id 不重啟。
- 距離層（相對 `Amb`，最大 −14 dB）：玻璃 `amb_01_glass` 300 px 內最大、900 px 外為 0；危險 `voc_danger_loop` 150 px 內最大、600 px 外為 0；中間線性（以 dB 換算前的線性振幅內插）。Boss 段落的假光造物不算。
- 前兆：`tell_parry`／`tell_heavy`，`Tell` 匯流排；同一種 0.15 秒內只播一次。
- 配樂：Boss 進 `FIGHT` 淡入 1 秒（從頭播）、離開 `FIGHT` 淡出 1.5 秒；覺醒放 `mus_s01`（不循環）。
- 檔案：環境音、玻璃層、配樂、危險循環轉 OGG Vorbis `-q:a 6`；其餘 WAV 原樣複製；全部放 `game/art/audio/`；來源留在 `assets-test/`。循環在載入時設 `stream.loop = true`（不改 `.import`）。
- 資料表沒有的 id 一律回退到 `sfx.gd` 合成（d1b 前不可靜音）。
- 不做：新音效、聆聽、音量設定、標題畫面聲音。
- 註解、文件繁體中文；commit 英文、結尾 `(MV-SLICE-001d1a)`；全套自測基準 602 項。

## Review Focus

1. **換房間時正在淡化中又換一次**（快速穿門）：最後只剩新房間的環境音在播，舊的兩條都停掉 → Task 2 `test_ambience_double_switch_settles`
2. **回主選單、讀檔、死亡回點**：環境音與配樂不殘留、不疊兩份（`GameWorld` 重建時 `Audio` 是全域的，不會跟著釋放）→ Task 2 `test_ambience_stops_on_title`、Task 4 `test_music_stops_when_fight_node_freed`
3. **房間裡的假光造物在同一幀被打死並釋放**：距離層不讀到已釋放的節點、不報錯，回到 0 → Task 2 `test_glass_layer_survives_freed_source`
4. **遊戲暫停（暫停選單、兌換、文字卡）時**：`Audio` 的淡化與距離層照常收尾，不會卡在半音量（`process_mode = ALWAYS`）→ Task 2 `test_audio_fades_while_paused`
5. **關門戰多隻敵人同一幀前搖**：只播一次前兆 → Task 3 `test_tell_throttled_same_frame`

---

## 檔案結構

| 檔案 | 責任 | Task |
|---|---|---|
| `game/art/audio/*.ogg`、`*.wav`（新） | 正式音檔 | 1 |
| `game/core/audio/sound_table.gd`（新） | `SOUNDS`、`THEME_AMBIENCE`、混音常數 | 1（2～4 補列） |
| `game/core/audio/audio.gd`（新，autoload `Audio`） | 匯流排、播放、變體、環境音、距離層、配樂、前兆節流、狀態紀錄 | 1～4 |
| `game/project.godot` | 加 autoload `Audio` | 1 |
| `game/core/fx/feedback.gd` | `play()` 先交給 `Audio` | 1 |
| `game/world/room_flow.gd`、`game/world/room.gd`、`game/world/game_world.gd` | 換房設環境音、listener、group、互動語彙、回主選單停聲音 | 2、3 |
| `game/core/enemies/enemy.gd`、`game/core/boss/seven_macaw.gd` | 前兆 | 3 |
| `game/core/boss/moves/move.gd`、`moves/*.gd`、`game/core/boss/boss_fight.gd`、`game/world/cutscene/*.gd` | Seven Macaw 音效、配樂 | 4 |
| `game/world/sound_tour.gd`（新）、`game/launch_args.gd`、`game/main.gd` | 聲音展示（開發版 `--sound-tour`） | 5 |
| `game/tests/test_d1a.gd`（新） | 本計畫的測試 | 1～4 |
| 報告、規格、`game/README.md`、`todo/todo.md` | 文件 | 5 |

---

### Task 1：音檔、`Audio` 骨架與回退

**Files:** Create `game/art/audio/`、`game/core/audio/sound_table.gd`、`game/core/audio/audio.gd`、`game/tests/test_d1a.gd`；Modify `game/project.godot`、`game/core/fx/feedback.gd`

**Interfaces:**
- Produces（`sound_table.gd`，`extends RefCounted`，只有常數）：
  - `const BUS_DB := {"Music": -8.0, "Amb": -12.0, "Sfx": -3.0, "Tell": 0.0}`、`const LAYER_MAX_DB := -14.0`、`const TELL_THROTTLE := 0.15`、`const AMB_FADE := 1.5`、`const MUSIC_IN := 1.0`、`const MUSIC_OUT := 1.5`
  - `const SOUNDS := {id(StringName): {"files": [res 路徑...], "bus": String, "db": float, "loop": bool}}`。Task 1 放：`voc_*` 8 種（各 3 檔，`Sfx`；`tell_parry`、`tell_heavy` 用 `Tell`）、`amb_01`／`amb_02`／`amb_03`／`amb_01_glass`／`voc_danger_loop`（`Amb`、loop）、`mus_b01`（`Music`、loop）、`mus_s01`（`Music`、不 loop）、`boss_sm_*` 19 種與 `evt_cover`（`Sfx`）、以及合成 id 的取代 `&"shatter": voc_glass 三檔`。
  - `const THEME_AMBIENCE := {"home": &"amb_02", "field": &"amb_02", "yard": &"amb_03", "forest": &"amb_01", "": &"amb_01"}`
- Produces（`audio.gd`，`extends Node`，autoload 名 `Audio`，`process_mode = ALWAYS`）：
  - `func has_sound(id: StringName) -> bool`
  - `func play(id: StringName) -> String` — 播一次、回傳選到的檔案路徑（沒有這個 id 回 `""`）；變體不連續重複
  - `var last_played: Dictionary` — `id → 最後一次的檔案路徑`（測試讀）
  - `var play_count: Dictionary` — `id → 次數`（測試讀）
  - `func _load(path: String, loop: bool) -> AudioStream` — OGG 設 `loop`；快取
- Produces（`feedback.gd`）：`play(sound)` 開頭 `if Audio.has_sound(sound): Audio.play(sound); return`。

- [ ] **Step 1：轉檔與複製**：寫 `/tmp/wt/d1a_audio.sh`（多步驟寫成腳本，不用子 shell）：
  - `ffmpeg -i <wav> -c:a libvorbis -q:a 6` 轉 `amb_01_forest`→`amb_01.ogg`、`amb_02_home`→`amb_02.ogg`、`amb_03_ballcourt`→`amb_03.ogg`、`amb_01_forest_glass`→`amb_01_glass.ogg`、`mus_b01_sevenmacaw`→`mus_b01.ogg`、`mus_s01_awaken`→`mus_s01.ogg`、`sfx_voc_danger_01`→`voc_danger_loop.ogg`
  - 複製 `batch0/audio/sfx_voc_*.wav`（24）、`batch2/audio/sfx_boss_sm_*.wav`（31）、`sfx_evt_cover_01.wav`
  - 量測寫進 `/tmp/wt/d1a_measure.txt`：每個 OGG 與原 WAV 的 `ebur128` 整合響度差（≤ 1 LU）；循環的最後與第一個樣本差（`ffmpeg ... -f f32le` 讀出比較）
  - 跑完 `godot --headless --path game --import`
- [ ] **Step 2：失敗測試**（`test_d1a.gd`，`extends "res://tests/base_test.gd"`）
  - `test_audio_buses`：`AudioServer.get_bus_index` 對 `Music`、`Amb`、`Sfx`、`Tell` 都 ≥ 0、送往 `Master`；音量等於 `BUS_DB`；`Music`、`Amb` 第 0 個效果是 `AudioEffectCompressor` 且 `sidechain == &"Tell"`
  - `test_sound_table_files_load`：`SOUNDS` 每個檔都 `ResourceLoader.exists` 且 `load` 不為 null；`bus` 在四條之一
  - `test_variants_do_not_repeat`：對 `files.size() >= 2` 的每個 id 連播 20 次，相鄰兩次的 `last_played` 都不同
  - `test_loop_flags`：`_load` 出來的 `amb_01`、`mus_b01`、`voc_danger_loop` 的 `loop` 為 true，`mus_s01` 為 false
  - `test_feedback_falls_back_to_synth`：`Feedback.play(&"swing")` 後 `Audio.play_count` 沒有 `swing`、Feedback 的播放器有一個在播；`Feedback.play(&"shatter")` 後 `Audio.play_count[&"shatter"] == 1`
- [ ] **Step 3：跑** `bash /tmp/wt/st_only.sh test_d1a` → 失敗（`Audio` 不存在）
- [ ] **Step 4：實作** `sound_table.gd`、`audio.gd`（`_ready` 建匯流排：已存在就不重建，方便測試重跑；短音效用 12 個 `AudioStreamPlayer` 輪流）、`project.godot` autoload `Audio="*res://core/audio/audio.gd"`（放在 `Tune` 之後）、`feedback.gd`
- [ ] **Step 5：跑** `bash /tmp/wt/st_only.sh test_d1a` 全過；`bash /tmp/wt/st_only.sh test_combat`、`test_enemies` 全過
- [ ] **Step 6：Commit** `Add the Audio singleton, its buses and the existing sound files (MV-SLICE-001d1a)`

### Task 2：環境音與距離層

**Files:** Modify `game/core/audio/audio.gd`、`game/world/room_flow.gd`、`game/world/room.gd`、`game/core/boss/boss_fight.gd`、`game/world/game_world.gd`、`game/tests/test_d1a.gd`

**Interfaces:**
- Consumes：Task 1 的 `SOUNDS`、`THEME_AMBIENCE`、`_load`
- Produces（`audio.gd`）：
  - `func set_ambience(id: StringName) -> void` — 同 id 不動；不同就 `AMB_FADE` 秒交叉淡化；`&""` 淡出全部
  - `var ambience := &""`（目前的）、`func ambience_players_playing() -> int`（測試讀，淡化完成後應為 1 或 0）
  - `var listener: Node2D`（弱參照語意：每次用前 `is_instance_valid`）
  - group 名：`const GROUP_GLASS := &"audio_glass"`、`const GROUP_DANGER := &"audio_danger"`
  - `func layer_db(layer: StringName) -> float`（`&"glass"`／`&"danger"`；0 振幅時回 `-80.0`）
  - `func stop_all() -> void` — 環境音、層、配樂全部淡出（回主選單用）
- Produces（接入點）：
  - `room_flow._swap` 建好房間後 `Audio.set_ambience(Sound.THEME_AMBIENCE.get(d.get("theme", ""), &"amb_01"))`
  - `room.gd` 建敵人時（`kind` 為假光造物三種）`add_to_group(Audio.GROUP_GLASS)`、建 `Hazard` 時 `add_to_group(Audio.GROUP_DANGER)`；`build` 結束設 `Audio.listener = player`
  - `boss_fight` 建好角色後 `Audio.listener = player`（召喚的假光造物不進 group）
  - `game_world._to_title` 呼叫 `Audio.stop_all()`
- 距離：取 listener 與來源 `global_position` 的水平距離與垂直距離合成的直線距離；`死亡`（`state == DEAD`）的敵人不算。

- [ ] **Step 1：失敗測試**
  - `test_every_room_has_ambience`：`Index.ROOMS` 每間的 `data().get("theme", "")` 都在 `THEME_AMBIENCE` 裡
  - `test_ambience_same_id_keeps_playing`：`set_ambience(&"amb_01")` 兩次，第二次後播放位置不歸零（記下播放器與 `get_playback_position()`，等幾幀後仍 ≥ 原值）
  - `test_ambience_crossfade`：`amb_02` → `amb_01`，等 `AMB_FADE + 0.2` 秒後 `ambience == &"amb_01"`、`ambience_players_playing() == 1`
  - `test_ambience_double_switch_settles`：`amb_02` → `amb_01` → 0.3 秒後 → `amb_03`，淡化結束後只剩 `amb_03` 在播
  - `test_ambience_stops_on_title`：`stop_all()` 後淡化結束 `ambience_players_playing() == 0`、配樂不在播
  - `test_glass_layer_by_distance`：listener 在 (0,0)；group 裡一隻敵人在 x=200 → `layer_db(&"glass") == LAYER_MAX_DB`（±0.1）；移到 x=600 → 介於兩者；移到 x=1000 → `-80`
  - `test_glass_layer_survives_freed_source`：敵人 `queue_free()` 後下一幀 `layer_db(&"glass") == -80`，沒有錯誤
  - `test_danger_layer_by_distance`：同上，用 150／600 的門檻
  - `test_room_registers_sources`：`dev_start("forest_1")` 後 group `audio_glass` 的數量＝房間裡的假光造物數、`audio_danger` 的數量＝荊棘數、`Audio.listener` 是角色；`ambience == &"amb_01"`
  - `test_audio_fades_while_paused`：`get_tree().paused = true` 下做一次交叉淡化，`AMB_FADE + 0.2` 秒後完成；測試結束恢復 `paused = false`
- [ ] **Step 2：跑** `bash /tmp/wt/st_only.sh test_d1a` → 新測試失敗
- [ ] **Step 3：實作**（淡化用 `Tween`，`set_pause_mode`／`process_mode` 為 ALWAYS；層的播放器開機就以 `-80 dB` 循環播放，`_process` 每幀更新音量）
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_d1a`、`test_rooms`、`test_c4a`、`test_walkthrough` 全過
- [ ] **Step 5：Commit** `Play the room ambience and the glass and thorn layers (MV-SLICE-001d1a)`

### Task 3：前兆與其他聲音語彙

**Files:** Modify `game/core/audio/audio.gd`、`game/core/enemies/enemy.gd`、`game/core/boss/seven_macaw.gd`、`game/world/room.gd`、`game/core/boss/boss_fight.gd`、`game/tests/test_d1a.gd`

**Interfaces:**
- Produces（`audio.gd`）：`func play_tell(parryable: bool) -> bool` — 播 `tell_parry`／`tell_heavy`；同一種在 `TELL_THROTTLE` 秒內（用 `Time.get_ticks_msec()`）已播過就回 false 不播
- Produces（接入點）：
  - `enemy._enter(s)`：`s == State.TELEGRAPH` 且原本不是 TELEGRAPH 時 `Audio.play_tell(parryable)`
  - `seven_macaw`：`var _last_sig := 0`；每幀若 `move != null` 且 `move.signal_kind != _last_sig` 且新值不是 `NONE` → `Audio.play_tell(move.signal_kind == Sig.PARRY)`；更新 `_last_sig`（`move == null` 時歸 `NONE`）
  - `room._on_interact`：`t == "rest"` → `Audio.play(&"voc_real")`；`t == "npc"` → `Audio.play(&"voc_alive")`；`boss_fight` 的篝火休息同樣放 `voc_real`
  - 過場：`rat_deal`、`couple` 開始時放 `voc_alive`（老鼠、老夫婦登場）

- [ ] **Step 1：失敗測試**
  - `test_crawler_telegraph_plays_parry_tell`：建爬行型（`parryable` true）呼叫 `start_telegraph()` → `Audio.play_count[&"tell_parry"]` +1
  - `test_heavy_telegraph_plays_heavy_tell`：把 `parryable` 設 false 再前搖 → `tell_heavy` +1
  - `test_tell_throttled_same_frame`：同一幀 3 隻爬行型前搖 → `tell_parry` 只 +1；0.2 秒後再一隻 → 再 +1
  - `test_macaw_signal_plays_tell`：用 `test_boss` 的方式建 Seven Macaw 並開始 `throw_fruit` 招式，跑到 `signal_kind == PARRY` → `tell_parry` +1；招式持續期間不重播
  - `test_rest_and_npc_vocab`：`dev_start("home")`，把角色放到休息點旁按互動 → `voc_real` +1；放到祖母旁 → `voc_alive` +1
- [ ] **Step 2：跑** `bash /tmp/wt/st_only.sh test_d1a` → 新測試失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_d1a`、`test_enemies`、`test_c4c1`、`test_boss`、`test_rest_and_cacao`、`test_c3a` 全過
- [ ] **Step 5：Commit** `Sound the attack tells and the alive and real vocabulary (MV-SLICE-001d1a)`

### Task 4：Seven Macaw 的音效與配樂

**Files:** Modify `game/core/boss/moves/move.gd`、`game/core/boss/moves/*.gd`、`game/core/boss/seven_macaw.gd`、`game/core/boss/boss_fight.gd`、`game/world/cutscene/toothache.gd`、`teeth.gd`、`death.gd`、`couple.gd`、`awaken.gd`、`game/core/audio/audio.gd`、`game/tests/test_d1a.gd`

**Interfaces:**
- Produces（`audio.gd`）：`func play_music(id: StringName) -> void`（`MUSIC_IN` 秒淡入、從頭播）、`func stop_music() -> void`（`MUSIC_OUT` 秒淡出）、`var music := &""`
- Produces（`move.gd`）：`func sfx(id: StringName) -> void: Audio.play(id)`（招式腳本統一用這個）
- Produces（`boss_fight`）：`var _music_stage := -1`；`_physics_process` 開頭比對 `stage`：進 `FIGHT` → `Audio.play_music(&"mus_b01")`；從 `FIGHT` 離開 → `Audio.stop_music()`；`_exit_tree` 若 `Audio.music == &"mus_b01"` 就 `stop_music()`
- 對照（MV-ASSET-007 S7-04～23）：

| id | 時機 | 位置 |
|---|---|---|
| `boss_sm_flap` | 飛行移動中每次振翅（約 0.4 秒一次） | `seven_macaw` 飛行移動 |
| `boss_sm_throw` | 擲出果子 | `throw_fruit._throw` |
| `boss_sm_fruit_break` | 果子被擊碎 | `fruit.gd` |
| `boss_sm_eat` | 吃果子 | 吃果子的招式／演出 |
| `boss_sm_dive` | 俯衝落地 | `dive.gd` |
| `boss_sm_gather` | 展翅聚光（假光閃耀、召喚的前搖開始） | `false_flash.gd`、`summon.gd` |
| `boss_sm_flash` | 閃光瞬間 | `false_flash.gd` |
| `boss_sm_flail` | 亂揮翅膀出招 | `flail.gd` |
| `boss_sm_wail` | 捧下顎哀嚎 | `toothache.gd`／`teeth.gd` |
| `boss_sm_throne_hit` | 撞到寶座 | `throne_charge.gd` |
| `boss_sm_pillar_warn`／`boss_sm_pillar_strike` | 反光柱落點預告／落下 | `pillar.gd` |
| `boss_sm_beam_charge`／`boss_sm_beam_fire` | 光束蓄力開始／發射 | `beam.gd` |
| `boss_sm_pounce` | 失衡撲擊出招 | `stagger_pounce.gd` |
| `boss_sm_crack` | 破綻滿 | `boss_fight._on_gauge_filled` |
| `boss_sm_light_pull` | 設局成功、拔掉光源 | 拔光源的地方（`boss_fight`／`palace_arena`） |
| `boss_sm_kneel` | 跪下 | `death.gd` |
| `boss_sm_light_fade` | 光熄滅 | `death.gd` |
| `evt_cover` | 老夫婦遮擋畫面 | `couple.gd`／`teeth.gd` |
| `mus_s01` | 覺醒 | `awaken.gd` 開始時 `Audio.play_music(&"mus_s01")` |

- [ ] **Step 1：失敗測試**
  - `test_fight_starts_and_stops_music`：建 `BossFight`（`test_boss_segment` 的做法）直接 `_start_fight()` → 幾幀後 `Audio.music == &"mus_b01"`；把 stage 設成 `CARD` → 幾幀後 `stop_music` 已呼叫（`music == &""`）
  - `test_music_stops_when_fight_node_freed`：`FIGHT` 中 `queue_free()` 整個 `BossFight` → `music == &""`
  - `test_awaken_plays_s01`：`--cutscene awaken` 的建法跑覺醒過場 → `play_count` 或 `music` 出現 `mus_s01`
  - `test_moves_play_their_sounds`：對 `throw_fruit`、`beam`、`dive`、`flail`、`false_flash`、`throne_charge`、`stagger_pounce` 各跑到出招 → 對應 id 的 `play_count` ≥ 1
  - `test_death_cutscene_sounds`：跑 `death` 過場 → `boss_sm_kneel`、`boss_sm_light_fade` 各 ≥ 1
  - `test_gauge_full_cracks`：`debug_fill_gauge()` → `boss_sm_crack` +1
- [ ] **Step 2：跑** `bash /tmp/wt/st_only.sh test_d1a` → 新測試失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_d1a`、`test_boss`、`test_boss_segment`、`test_cutscene`、`test_fx` 全過
- [ ] **Step 5：Commit** `Give Seven Macaw its sounds and the fights their music (MV-SLICE-001d1a)`

### Task 5：聲音展示影片、全套驗證與文件

**Files:** Create `game/world/sound_tour.gd`；Modify `game/launch_args.gd`、`game/main.gd`、`game/README.md`、`todo/spec/MV-SLICE-001d1a_聲音系統.md`、`todo/todo.md`；Create `report/MV-SLICE-001d1a_聲音系統_<date 的輸出>_執行報告.md`

**Interfaces:**
- Produces（`launch_args.parse`）：`--sound-tour` → `mode == "sound_tour"`（開發版才生效，同 `--shots`）
- Produces（`sound_tour.gd`，同 `shots.gd` 的做法用 `GameWorld.dev_start` 逐段進入）：依序約 10～15 秒一段：`home`（篝火休息、祖母互動）→ `field` → `yard`（換房淡化）→ `forest_1`（荊棘旁走過、等一隻爬行型前搖、打碎）→ 有反光型的森林房（不可招架前兆、玻璃層隨距離）→ Boss 第 1 段開打（配樂、擲果、俯衝）→ 第 2 段（光束、反光柱）→ 第 3 段與死亡過場 → 覺醒過場；用腳本移動角色、呼叫既有 debug 動作，不靠手動輸入；全部跑完結束程式

- [ ] **Step 1：實作** `sound_tour.gd`，跑 `godot --path game --resolution 1920x1080 --write-movie /tmp/wt/d1a_tour.avi -- --sound-tour > /tmp/wt/d1a_tour.log 2>&1`，Expected：產出 avi、log 沒有 `SCRIPT ERROR`
- [ ] **Step 2：轉檔** `ffmpeg -i /tmp/wt/d1a_tour.avi -c:v libx264 -crf 23 -c:a aac -b:a 192k assets-test/d1a_video/d1a_sound_tour.mp4`；`ffprobe` 確認有音軌；`ffmpeg -af ebur128` 量整支的整合響度與最大 true peak（寫進報告）；AI 抽 5 段音訊頻譜確認前兆出現時配樂／環境音被壓低（sidechain 生效；不明顯就走規格書退路改 tween）
- [ ] **Step 3：全套** `bash /tmp/wt/step6.sh`，Expected：`fail=0`、`errors: 0`、`import_art=0 import_rig=0 unittest=0`
- [ ] **Step 4：文件**：README 加「聲音」一節（`Audio` 的用法、`SOUNDS` 怎麼加、`--sound-tour`）；執行報告（時間戳先跑 `date`）寫 Task 結果、轉檔量測、影片位置、自測數；規格書驗收標準打勾；`todo.md` d1a 列更新
- [ ] **Step 5：Commit** `Record the sound tour and document the d1a sound system (MV-SLICE-001d1a)`
- [ ] **Step 6**：最終全分支審查（依選定的執行方式）→ 修正 → 交 Brian 聽影片
