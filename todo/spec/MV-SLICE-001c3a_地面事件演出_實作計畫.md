# MV-SLICE-001c3a 地面事件演出 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 地面房間也能播 c2 的過場；開墾田地、入夜抓老鼠、球具掉下的文字卡換成 5 段有替身動作的短過場（佔位外觀）。

**Architecture:** `cutscene.gd` 透過 `fight` 讀的六樣東西改成通用的 `host`（Boss 戰傳自己；地面傳 `GroundStage`，由房間、HUD、事件排程組成）。事件排程 `event_runner.gd` 提供 `play(段落們)`，在房間底下建一個過場節點（`PROCESS_MODE_ALWAYS`，房間凍結時照常跑、換房時跟著釋放）。演出腳本照 c2 的 duck typing：`play(cs)`＋`end_state(host)`，看完與跳過都由 `end_state` 收成同一個狀態；事件節點在 `run` 回來後做後續（開始追逐、放出可撿的球具）。

**Tech Stack:** Godot 4.7.2、GDScript；自測 `tests/test_*.gd`。

**Spec:** [MV-SLICE-001c3a_地面事件演出.md](MV-SLICE-001c3a_地面事件演出.md)

## Global Constraints

- 規格寫「把 `fight` 改名為 `stage`」；**計畫改名為 `host`**：`BossFight` 已經有自己的 `stage` 欄位（`f.stage = f.Stage.CARD`），叫 `stage` 會變成 `cs.stage.stage`。行為照規格（Ruling，執行時記入 ledger）。
- `host` 的欄位（duck typing）：`player`、`boss`（可 null）、`world`（凍結的節點）、`scenery`（可 null）、`camera`、`hud`（可 null）。Boss 段落的腳本內容與行為不變。
- 旗標：沿用 `field_cleared`、`rat_caught`、`gear_obtained`；新增 `night_seen`、`gear_dropped`；全部寫進 `game_world.gd` 的 `STORY_FLAGS`。舊存檔缺新旗標＝沒看過。
- 夜晚：田地 `field_cleared` 且沒有 `gear_obtained`；祖母家 `rat_caught` 且沒有 `gear_obtained`。有場景時 `scenery.night`，灰盒房間 `room.modulate = Color(0.45, 0.5, 0.75)`（現有 `_tint` 的值）。
- 台詞：旁白 `cs.narrate`；只有老鼠用 `cs.say("老鼠", …)`；雙胞胎不開口。文字見各 Task 的常數。
- 長度：收工、動物復原、交換各約 15～25 秒，咬繩約 15 秒，天亮約 6 秒（`Engine.time_scale` 1 下用 `cs._t` 量，自測容許 12～28 秒、天亮 4～10 秒）。
- 追逐規則不改（300 px、跑速 ×1.1、牆邊 110）。開場旁白卡（`intro_seen`）不改。
- 註解、文件繁體中文；commit 英文、結尾 `(MV-SLICE-001c3a)`；全套自測基準 570 項。
- 驗證腳本（`/tmp/wt/` 已被清掉，執行前重建）：
  - `/tmp/wt/st_only.sh <檔名片段>`：`SELFTEST_ONLY=$1 godot --headless --path game -- --self-test 2>&1 | tee /tmp/wt/st_$1.log | grep -E "SELFTEST (FAIL|SUMMARY)|SCRIPT ERROR|Parse Error"`
  - `/tmp/wt/step6.sh`：`python3 tools/import_art.py --check`、`python3 tools/import_rig.py --check`、`python3 -m unittest discover -s tools -p "test_*.py"`、全套自測（輸出存 `/tmp/wt/s6_*.log`，最後印各段結束碼與 SUMMARY）。約 18 分鐘，背景執行，期間不改 `game/`。

## Review Focus

1. 球具掉下後玩家沒撿就離開祖母家、再回來：球具只有一個、不重播咬繩（`gear_dropped`）——Task 3 `test_gear_left_on_floor_survives_reentry`。
2. 祖母睡著時按互動：不開兌換；天亮後恢復——Task 3 `test_asleep_grandmother_no_shop`。
3. 地面過場中按住暫停鍵跳過，放開時不打開暫停選單；過場中按鍵提示不顯示——Task 1 `test_ground_cutscene_blocks_pause_and_hints`。
4. 拿到球具之後（`gear_obtained`）的田地與祖母家都是白天、祖母醒著——Task 3 `test_day_after_gear`。
5. 地面過場結束後 HUD 透明度回到 1、鏡頭回到房間的鏡頭、真正的玩家可見且能操作——Task 1 `test_ground_handover_restores_room`。

---

### Task 1: 過場的 host 與地面舞台

**Files:**
- Modify: `game/world/cutscene/cutscene.gd`（`fight` → `host`、null 防護、新增 `place()`）
- Modify: `game/world/cutscene/*.gd`、`game/core/boss/boss_fight.gd`、`game/tests/test_cutscene.gd`、`game/world/cutscene_view.gd`（`.fight` → `.host`，機械替換）
- Create: `game/world/cutscene/ground_stage.gd`
- Modify: `game/events/event_runner.gd`（`hud`、`play()`、`cutscene_running()`）、`game/world/game_world.gd`（傳 `hud`、過場中藏提示）
- Test: `game/tests/test_c3a.gd`（新）

**Interfaces:**
- Produces（`cutscene.gd`）：`var host`（取代 `fight`）；`func place(node: Node2D) -> Node2D` 把非骨架的道具（剪影、食物、尾巴、落下中的球具）加進替身容器，交還時一起釋放；`boss`／`scenery`／`hud` 為 null 時 `_begin`、`_handover`、`silhouette`、`_process` 不碰它們。
- Produces（`ground_stage.gd`，`extends RefCounted`）：欄位 `player`、`boss`（null）、`world`（＝房間）、`scenery`、`camera`、`hud`、`room`、`gs`、`runner`；`static func of(room, runner) -> GroundStage`（`hud` 取 `runner.hud`）。
- Produces（`event_runner.gd`）：`var hud`（game_world 設，測試可 null）；`func play(scenes: Array) -> void`（取得或建立房間底下名為 `Cutscene` 的過場節點，`process_mode = PROCESS_MODE_ALWAYS`，`host = GroundStage.of(flow.current, self)`，`await run(scenes)`）；`func cutscene_running() -> bool`；`var cutscene`（目前房間的過場節點，沒有時 null）。

- [ ] **Step 1：重建 `/tmp/wt/st_only.sh`、`step6.sh`（見 Global Constraints），寫失敗測試 `test_c3a.gd`**
  - 測試房間的設置沿用 `test_events.gd` 的 `setup()` 寫法（`RoomFlow`＋`EventRunner`，`card_min_time` 0），另加 `runner.hud = Control.new()`。
  - `test_ground_cutscene_hides_player_and_freezes_room`：在 `field`（有 `tools_obtained`、`field_cleared`、`night_seen`、`rat_caught`，沒有事件）呼叫 `runner.play([Probe])`（測試內的小段落：`play(cs)` 裡 `await cs.wait(0.3)`，記錄當下 `room.player.visible`、`room.process_mode`、`cs.camera.is_current()`）→ 演出中玩家不可見、房間 `PROCESS_MODE_DISABLED`、過場鏡頭是目前鏡頭；`Probe.end_state(host)` 收到的 `host.room == flow.current`。
  - `test_ground_handover_restores_room`：同上，結束後 `player.visible`、`room.process_mode == PROCESS_MODE_INHERIT`、`room.camera.is_current()`、`runner.hud.modulate.a == 1.0`、`cutscene_running()` 為 false，再給 `intent.move_x = 1` 數幀後玩家 x 增加。
  - `test_ground_cutscene_skip`：演出中 `runner.cutscene.skipped = true` → `run` 回來、`end_state` 有被呼叫。
  - `test_ground_cutscene_blocks_pause_and_hints`：用 `GameWorld`（同 `test_walkthrough.gd` 的建法）進 `field`，`runner.play([Probe 長 2 秒])` 中 `hints.visible` 為 false、`get_tree().get_first_node_in_group(&"cutscene") != null`（暫停選單據此不開）。
  - `test_boss_host_unchanged`：`BossFight` 的 `cutscene.host == fight`（boss_fight 改用 `host`）。
- [ ] **Step 2：跑** `bash /tmp/wt/st_only.sh test_c3a`。Expected：FAIL／載入錯誤（`play`、`host`、`GroundStage` 不存在）。
- [ ] **Step 3：實作**
  - `cutscene.gd`：`fight` 改名 `host`（含註解）；`_begin` 的 `_shown` 只收非 null 的 `player`、`boss`；`scenery` 非 null 才設處理模式；`silhouette` 在 `scenery` 為 null 時只調 `world.modulate`；斷臂判斷改成 `host.player.get("twins") != null` 時才做。新增 `place()`。
  - 其他檔 `.fight` → `.host`（`grep -rn "\.fight\b" game` 清到 0）；`test_cutscene.gd` 裡 `cs.fight = …` 一併改。
  - `ground_stage.gd`、`event_runner.gd` 照 Interfaces；`game_world.gd`：`runner.hud = hud`；`_process` 的 `hints.visible` 再加 `and not runner.cutscene_running()`。
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_c3a`、`bash /tmp/wt/st_only.sh test_cutscene`、`bash /tmp/wt/st_only.sh test_boss`。Expected：全 PASS、0 `SCRIPT ERROR`。
- [ ] **Step 5：Commit** `git commit -m "Let cutscenes run in ground rooms through a generic host (MV-SLICE-001c3a)"`

### Task 2: 田地——收工、動物復原、夜晚

**Files:**
- Create: `game/world/cutscene/field_dusk.gd`、`field_animals.gd`、`game/world/cutscene/silhouette.gd`（佔位剪影）
- Modify: `game/world/prop.gd`（`decor`）、`game/world/rooms/field.gd`（`decor_bushes`）、`game/events/field_clearing.gd`、`game/events/night_rat.gd`、`game/events/event_runner.gd`（`apply_night`、`start_night`）、`game/world/game_world.gd`（`STORY_FLAGS`）
- Modify: `game/tests/test_events.gd`、`game/tests/test_walkthrough.gd`（入夜的文字卡改成過場）
- Test: `game/tests/test_c3a.gd`

**Interfaces:**
- Consumes：Task 1 的 `runner.play()`、`cs.place()`、`host.room`／`host.gs`／`host.runner`。
- Produces（`prop.gd`）：`var decor := false`；為 true 時灌木、土塊不建受擊框（只供演出）。
- Produces（`field.gd`）：`"decor_bushes": [Vector2(350, GROUND_Y), Vector2(500, GROUND_Y), Vector2(650, GROUND_Y), Vector2(800, GROUND_Y)]`。
- Produces（`silhouette.gd`，`extends Node2D`）：`var kind := ""`（`"deer"`、`"rabbit"`、`"critter"`、`"tail_deer"`、`"tail_rabbit"`、`"corn"`、`"beans"`、`"cacao"`）；`_draw` 畫深色多邊形或小圓（腳底中央在原點；食物 `cacao` 可用 `res://art/prop/prop_cacao_bean.png`）。c3b 換正式素材。
- Produces（`event_runner.gd`）：`func apply_night(room) -> void`（依 Global Constraints 的夜晚規則設 `scenery.night` 或 `room.modulate`；每次 `_on_room` 呼叫）；`func start_night(prelude: Array = []) -> void`（掛 `NightRat`，把 `prelude` 交給它）。
- Produces（`field_dusk.gd`）：`_init(decor: Array)`（田左半的演出灌木）；`play`：兩個替身（`TwinAnimator.CHARS[player.twin_index]` 在玩家位置、另一個在旁 90 px）走到田邊播 `interact`（插工具；`place()` 放斧頭與掘棒的圖，找不到圖就畫矩形）、`decor` 一叢一叢 `cs.tint(..., 透明, 0.4)`、兄弟倆播 `dart` 起手後往畫面外走、`cs.tint(scenery, SceneryView.NIGHT, 1.5)`（灰盒調 `world`）。`end_state(host)`：`field_cleared`、`decor` 全部釋放、`host.runner.apply_night(host.room)`。
  - 常數 `N1 := "兄弟倆把斧頭插在樹上，掘棒插進土裡。"`、`N2 := "斧頭自己砍樹，掘棒自己翻土。兄弟倆拿起吹管，打獵去了。"`
- Produces（`field_animals.gd`）：`_init(regrow: Array, rat: Node2D)`（`regrow`＝`NightRat` 建好、透明度 0 的灌木與土塊；`rat`＝真正的老鼠道具）；`play`：`conceal(rat)`、`place()` 幾個剪影（鹿、兔子、小動物）從右往左跑過，`regrow` 依序淡入，兄弟倆替身 `lunge` 撲向鹿與兔子，手上留下尾巴剪影、動物跑出畫面，老鼠替身留在田中央。`end_state(host)`：`night_seen`、`regrow` 透明度 1、老鼠道具透明度 1 並放在田中央。
  - 常數 `N1 := "夜裡，森林的動物來了，田地又長回原樣。"`、`N2 := "兄弟倆撲上去，只抓到鹿和兔子的尾巴。"`、`N3 := "所以鹿和兔子的尾巴，到今天都很短。"`、`N4 := "最後只剩一隻老鼠，還在田裡竄。"`
- 事件：`field_clearing.gd` 全清後 `runner.start_night([FieldDusk.new(decor)])`（不再 `set_flag`、不等 3 秒；`decor` 在 `_ready` 依 `decor_bushes` 建）。`night_rat.gd` 移除 `TEXT_NIGHT` 卡與 `_tint`：`_ready` 建灌木、土塊、老鼠（沒有 `night_seen` 時灌木與土塊透明度 0）→ 沒有 `night_seen` 時 `await runner.play(prelude + [FieldAnimals.new(regrow, rat)])` → `_active = true`。

- [ ] **Step 1：失敗測試（`test_c3a.gd`）**
  - `test_field_clear_plays_dusk_and_animals`：`field`＋`tools_obtained`，清掉 6 個 → `wait_until(runner.cutscene_running())`；`Engine.time_scale = 8` 看完（結束後還原 1）→ `field_cleared`、`night_seen`、`scenery.night`、田裡有 3 叢灌木 3 個土塊（透明度 1）、老鼠在 x ≈ 房寬/2、沒有 `decor` 灌木留下、玩家可操作。
  - `test_field_clear_skip_same_state`：同上但演出一開始就 `skipped = true`，狀態相同。
  - `test_field_reentry_skips_animals`：有 `field_cleared`、`night_seen` 進田地 → 數幀內 `cutscene_running()` 為 false、夜晚、老鼠在、靠近時老鼠會跑。
  - `test_field_reentry_without_night_seen_plays_animals`：有 `field_cleared`、沒有 `night_seen` → 播動物復原（只有這一段：`runner.cutscene` 的段落數為 1）。
  - `test_field_cutscene_lengths`：`time_scale` 1、不跳過，量收工、動物復原各自 12～28 秒（在 `play` 前後讀 `cs._t`；可用 `cs.host` 的 Probe 包一層，或直接 `await FieldDusk.new(decor).play(cs)`）。
  - `test_decor_bush_has_no_hurtbox`：`decor` 灌木的 `hurtbox == null`。
- [ ] **Step 2：跑** `bash /tmp/wt/st_only.sh test_c3a`。Expected：Task 2 的測試 FAIL，Task 1 的仍 PASS。
- [ ] **Step 3：實作** 照 Interfaces；`STORY_FLAGS` 加 `night_seen`、`gear_dropped`。
- [ ] **Step 4：改舊測試**：`test_events.gd` 的 `test_night_starts_three_seconds_after_clear` 改成「清完立刻開始過場、跳過後是夜晚」並改名 `test_night_cutscene_starts_after_clear`；`test_rat_flees_and_net_at_wall_sets_flag`、`test_death_mid_event_restarts_it` 的「入夜卡」改成有 `night_seen` 直接開始，或跳過動物復原過場（`runner.cutscene.skipped = true`）；`test_walkthrough.gd` 的「入夜」改成等過場、跳過。網子之後的卡留到 Task 3 改。
- [ ] **Step 5：跑** `bash /tmp/wt/st_only.sh test_c3a`、`test_events`、`test_walkthrough`、`test_scenery`。Expected：全 PASS（`test_events` 裡網子後的交換卡與球具卡此時仍是文字卡，照舊 PASS）。
- [ ] **Step 6：Commit** `git commit -m "Stage the field dusk and the animals' night as cutscenes (MV-SLICE-001c3a)"`

### Task 3: 交換、咬繩、天亮

**Files:**
- Create: `game/world/cutscene/rat_deal.gd`、`gear_rope.gd`、`morning.gd`
- Modify: `game/events/night_rat.gd`（`_catch`）、`game/events/gear_drop.gd`、`game/events/event_runner.gd`（祖母睡著）、`game/world/room.gd`（`npc_asleep`）
- Modify: `game/tests/test_events.gd`、`game/tests/test_walkthrough.gd`（交換、球具、第二天的文字卡改成過場）
- Test: `game/tests/test_c3a.gd`

**Interfaces:**
- Consumes：Task 1 的 `play()`、`place()`；Task 2 的 `apply_night()`、`Silhouette`（`corn`、`beans`、`cacao`）。
- Produces（`room.gd`）：`var npc_asleep := false`（setter：在祖母頭上顯示／移除一個「Zzz」`Label`；為 true 時 `interact_target()` 不回傳 `"npc"`）。
- Produces（`event_runner.gd`）：進 `home` 時 `room.npc_asleep = gs.has_flag("rat_caught") and not gs.has_flag("gear_obtained")`。
- Produces（`rat_deal.gd`）：`_init(rat: Node2D, net: Node2D)`；`play`：`conceal` 真的老鼠與網子、在同位置放老鼠替身與網子（`place()`），兄弟倆替身走到旁邊；`say` → `place()` 三樣食物、`narrate` → `say`；網子移除、老鼠替身 `walk(..., anim "run")` 跑出房間右側。`end_state(host)`：`rat_caught`、真的老鼠與網子 `queue_free`、`apply_night`（田地維持夜晚）。
  - 常數 `S1 := "別吃我！給我一頓飯，我就告訴你們一件事。"`、`N1 := "兄弟倆給了牠玉米、豆子與可可。"`（食物見原典 p.138）、`S2 := "你們父親的球具，就掛在家裡的屋頂下。"`
- Produces（`gear_rope.gd`）：`play`：祖母家夜晚、祖母睡著（`npc_asleep` 已由 runner 設好）；老鼠替身從左門跑到繩子下（`home.gd` 的 `rope` 道具位置 x 930、y 420），`fly(..., "run")` 爬到繩子位置、原地小幅抖動（咬）約 1.5 秒；`place()` 一個 `Prop`（`kind "gear"`）從繩子位置 0.5 秒掉到地上（`cs.animate`）。`end_state(host)`：`gear_dropped`。
  - 常數 `N1 := "祖母睡著了。"`、`N2 := "老鼠爬上屋梁，咬斷了吊著球具的繩子。"`
- Produces（`morning.gd`）：`play`：`fade_to_black(0.8)` → `narrate(TEXT)` → 祖母家變回白天、`npc_asleep = false` → `fade_in(0.8)`。`end_state(host)`：`gear_obtained`、`apply_night`、`npc_asleep = false`。
  - 常數 `TEXT := "第二天早上，兄弟倆出發了。"`
- 事件：`night_rat.gd` 的 `_catch` 改成 `await runner.play([RatDeal.new(rat, net)])`（不再跳卡、不再 `_tint(false)`）。`gear_drop.gd`：移除兩張卡與舊的落下動畫；沒有 `gear_dropped` 時 `await runner.play([GearRope.new()])`；之後 `room.add_pickup("gear", "gear", Vector2(930, ground_y))`；`await runner.gear_picked` → `await runner.play([Morning.new()])`。

- [ ] **Step 1：失敗測試（`test_c3a.gd`）**
  - `test_rat_deal_cutscene`：有 `field_cleared`、`night_seen` 進田地，把老鼠趕到牆角（同 `test_events` 的追法）→ 過場開始；看完（`time_scale` 8）與另一次跳過：`rat_caught`、田裡沒有老鼠與網子、仍是夜晚。
  - `test_gear_rope_then_pickup`：有 `rat_caught` 進 `home` → 夜晚、`npc_asleep`、過場；結束後 `gear_dropped`、`pickups.size() == 1`、玩家可撿；撿起 → 天亮過場 → `gear_obtained`、白天、`npc_asleep` false、有球具與老鼠技能。跳過版同結果。
  - `test_gear_left_on_floor_survives_reentry`：咬繩結束後不撿、`flow.goto("field", "to_home")` 再回 `home` → 不播過場、`pickups.size() == 1`。
  - `test_asleep_grandmother_no_shop`：`npc_asleep` 時站在祖母旁 `interact_target() != "npc"`；天亮後 `== "npc"`。
  - `test_day_after_gear`：有 `gear_obtained` 進 `field` 與 `home` → 都不是夜晚、`npc_asleep` false、沒有過場。
  - `test_deal_and_rope_lengths`：交換 12～28 秒、咬繩 12～28 秒、天亮 4～10 秒（`time_scale` 1）。
- [ ] **Step 2：跑** `bash /tmp/wt/st_only.sh test_c3a`。Expected：Task 3 的測試 FAIL，其餘 PASS。
- [ ] **Step 3：實作** 照 Interfaces。
- [ ] **Step 4：改舊測試**：`test_events.gd` 的 `test_rat_flees_and_net_at_wall_sets_flag`（等過場、檢查 `rat_caught`）、`test_gear_event_only_after_rat`（等咬繩過場、撿起、等天亮過場）；`test_walkthrough.gd` 的「把老鼠逼到牆角」「球具的祕密」「第二天早上」改成等對應過場並跳過。
- [ ] **Step 5：跑** `bash /tmp/wt/st_only.sh test_c3a`、`test_events`、`test_walkthrough`、`test_rest_and_cacao`、`test_npc_rig`。Expected：全 PASS。
- [ ] **Step 6：Commit** `git commit -m "Stage the rat deal, the rope and the morning as cutscenes (MV-SLICE-001c3a)"`

### Task 4: 錄影、截圖、文件

**Files:**
- Modify: `game/world/cutscene_view.gd`（地面段落）、`game/main.gd`（若名稱檢查在那裡）
- Modify: `game/README.md`、`todo/todo.md`、`todo/spec/MV-SLICE-001c3a_地面事件演出.md`；Create: `report/MV-SLICE-001c3a_地面事件演出_<date>_執行報告.md`（時間戳先跑 `date`）
- Test: `game/tests/test_c3a.gd`

**Interfaces:**
- Produces（`cutscene_view.gd`）：`NAMES` 加 `"field"`（`dev_start("field")` 後給斧頭、掘棒與 `tools_obtained`，清掉 6 個 → 收工＋動物復原）、`"deal"`（有 `field_cleared`、`night_seen` 進田地，把老鼠放到牆邊觸發網子）、`"rope"`（有 `rat_caught` 進 `home`）、`"morning"`（有 `rat_caught`、`gear_dropped` 進 `home`，呼叫 `runner._on_interact("pickup:gear")`）；等 `runner.cutscene_running()` 變 false 再結束（Boss 段落的等待條件不變）。

- [ ] **Step 1：失敗測試** `test_cutscene_view_accepts_ground_names`：`CutsceneView.NAMES` 含 `field`、`deal`、`rope`、`morning`。
- [ ] **Step 2：跑** `bash /tmp/wt/st_only.sh test_c3a`。Expected：FAIL。
- [ ] **Step 3：實作** `cutscene_view.gd`；README 的 `--cutscene` 一列加地面段落、「事件」段落改寫成過場（含新旗標、夜晚規則、祖母睡著）。
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_c3a`。Expected：PASS。
- [ ] **Step 5：錄影**：四個名稱各跑 `godot --path game --fixed-fps 30 -- --cutscene <名稱> --frames /tmp/wt/c3a_frames/<名稱>`，ffmpeg 合成 `assets-test/c3a_video/<名稱>.mp4`（30 fps）與一支串接的 `c3a_all.mp4`；抽格總覽 `c3a_frames.jpg`。AI 抽格檢查替身位置、字幕在下方黑邊裡、夜晚、天亮、沒有真角色與替身同時出現。
- [ ] **Step 6：截圖**：`godot --path game -- --shots /tmp/wt/c3a_shots`，確認 `field_night` 等畫面與每個畫面平均幀時間 ≤ 16.7 ms，挑 `home`、`field`、`field_night` 拼成 `assets-test/c3a_shots/c3a_check.jpg`。
- [ ] **Step 7：跑** `bash /tmp/wt/step6.sh`（背景）。Expected：兩個 `--check` 結束碼 0、unittest OK、自測 `fail=0`（570＋新增）、0 `SCRIPT ERROR`／`Parse Error`／`flushing queries`。
- [ ] **Step 8：文件與 Commit**：規格書狀態與驗收清單、執行報告（Rulings、驗證、影片路徑）、todo 狀態；`git commit -m "Record the ground cutscenes and document them (MV-SLICE-001c3a)"`
