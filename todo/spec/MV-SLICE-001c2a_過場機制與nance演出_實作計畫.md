# MV-SLICE-001c2a 過場機制與 nance 樹的演出 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Seven Macaw 戰 nance 樹的開場、斷臂文字卡、轉場文字卡換成引擎內演出，並建立之後 c2b、c2c 共用的過場機制。

**Architecture:** `world/cutscene/cutscene.gd` 是執行器（黑邊、字幕、名號、跳過、剪影、凍結戰場、自己的鏡頭）；每段演出一支腳本（`play(cs)`＋`end_state(fight)`），操作骨架替身 `actor.gd`。`boss_fight` 只在遊戲模式改呼叫執行器，原型模式照舊。

**Tech Stack:** Godot 4.7.2 GDScript；自測 `godot --headless --path game -- --self-test`（`SELFTEST_ONLY=<檔名片段>` 只跑部分）；動作檔 `game/rig/*_anims.json`（手寫 JSON，12 fps）。

**Spec:** [MV-SLICE-001c2a_過場機制與nance演出.md](MV-SLICE-001c2a_過場機制與nance演出.md)（Brian 2026-10-14 核准）

## Global Constraints

- 只在遊戲模式（`boss_fight.gs != null`）播演出；原型模式行為逐項不變（`play_intro`、`show_card("arm")`、`show_card("couple")`）。
- 不改戰鬥數值、判定、重試規則；不加聲音、不加新美術、不用 shader。
- 黑邊：上下各畫面高 11%（1080 × 0.11 ≈ 119 px），0.4 秒滑入／滑出。
- 字幕停留 `max(1.5, 0.12 × 字數)` 秒；攻擊鍵（`attack`）提前換句，每句至少顯示 0.3 秒；說話者名字金色接在前面「名字：」，旁白不加名字；白字黑描邊、置中、在下方黑邊上緣。
- 跳過：按住 `pause` 1 秒（右下角進度小圈）；不滿 1 秒放開歸零、什麼都不做；演出中暫停選單不開。
- 剪影：暖色漸層底（上 `#faaa5a`、下 `#f0e6aa`），場景圖層 `modulate` 黑色＋透明度（遠景 0.35、中景 0.6、地面與前景 0.85），替身純黑。
- 名號「七金剛鸚鵡」、稱號「自稱是太陽，也是月亮」約 1.5 秒；開場旁白「七金剛鸚鵡每天飛到 nance 樹上吃果子。兄弟倆躲在樹下的葉叢裡，等著他。」；其餘台詞照 `card_text.gd` 的 `arm`、`couple` 原句拆開（見 Task 5）。
- 看完與跳過都呼叫 `end_state`，結果必須相同。
- 開發參數只在 `OS.is_debug_build()` 生效。
- 新程式碼的註解、文件用繁體中文；commit 訊息英文、結尾加 `(MV-SLICE-001c2a)`。

## Review Focus

1. **演出中途玩家狂按攻擊鍵**：一下只換一句（0.3 秒下限），不會跳過整段、不會讓角色出手 → Task 1 `test_attack_advances_one_line_at_a_time`
2. **演出結束那一幀按著攻擊或跳躍**：交還操作後不會立刻出手／跳起來（同一下按鍵不穿透） → Task 1 `test_input_not_leaking_after_cutscene`
3. **斷臂後讀檔或死在第 2 段重試**：宮殿繩子上仍掛著手臂、胡納普仍斷臂 → Task 5 `test_arm_hung_after_retry_and_load`
4. **開場中按住暫停鍵跳過、放開後**：暫停選單不會在演出結束時跳出來 → Task 1 `test_pause_hold_does_not_open_menu_after`
5. **跳過時剪影還開著**：跳過後場景顏色、`world.modulate` 全部還原 → Task 2 `test_skip_restores_silhouette`

---

## 檔案結構

| 檔案 | 責任 | Task |
|---|---|---|
| `game/world/cutscene/cutscene.gd` | 執行器：生命週期、黑邊、字幕、名號、跳過、鏡頭、剪影開關、凍結戰場 | 1、2 |
| `game/world/cutscene/actor.gd` | 骨架替身：播動作、走、飛、塗黑、假光源 | 2 |
| `game/world/cutscene/arm_prop.gd` | 胡納普近側手臂拼成的道具 | 2 |
| `game/world/cutscene/opening.gd`、`arm.gd`、`couple.gd` | 三段演出腳本 | 4、5 |
| `game/world/cutscene_view.gd` | `--cutscene` 開發畫面（SubViewport 1920×1080、`--frames` 逐格輸出） | 6 |
| `game/world/scenery_view.gd` | `set_silhouette(on)`、`set_arm_hung(on)` | 2、5 |
| `game/ui/pause_menu.gd` | 演出中不開 | 1 |
| `game/core/boss/boss_fight.gd` | 遊戲模式改播演出；`_apply_loadout` 同步掛手臂 | 4、5 |
| `game/rig/twin_anims.json`、`sevenmacaw_anims.json`、`game/world/rig_showcase.gd`（`ORDER`） | 新動作 | 3 |
| `game/launch_args.gd`、`game/main.gd` | `--cutscene <名稱>` | 6 |
| `game/tests/test_cutscene.gd` | 全部新測試 | 1～6 |

---

### Task 1：執行器（黑邊、字幕、名號、跳過、凍結戰場）

**Files:**
- Create: `game/world/cutscene/cutscene.gd`、`game/tests/test_cutscene.gd`
- Modify: `game/ui/pause_menu.gd`

**Interfaces:**
- Produces（`res://world/cutscene/cutscene.gd`，`extends Node2D`）：
  - `const BAR_FRAC := 0.11`、`const BAR_TIME := 0.4`、`const SKIP_HOLD := 1.0`、`const MIN_LINE := 0.3`、`const GROUP := &"cutscene"`
  - `static func line_time(text: String) -> float` ＝ `maxf(1.5, 0.12 * text.length())`
  - `var fight`（BossFight，可為 null：純 UI 測試）、`var skipped := false`、`var running := false`、`var subtitle: Label`、`var title_label: Label`
  - `func run(scenes: Array) -> void`：依序 `await s.play(self)`，每段之後 `s.end_state(fight)`（跳過時也呼叫；跳過後剩下的場景 `play` 不跑、`end_state` 照呼叫）；開始時加入群組 `GROUP`、黑邊滑入、HUD 淡出（`fight.hud.modulate.a` → 0）、`fight.world.process_mode = DISABLED`、`fight.scenery.process_mode = ALWAYS`、自己的 `Camera2D.make_current()`；結束時反向還原、`fight.camera.make_current()`、`MenuInput.swallow()`
  - 指令（皆 `await`；`skipped` 時立刻 return）：`narrate(text: String)`、`say(who: String, text: String)`、`wait(secs: float)`、`title(name: String, epithet: String)`、`view(rect: Rect2)`（鏡頭置中到 rect 中心，硬切）、`fade_to_black(secs := 0.5)`、`fade_in(secs := 0.5)`
  - 演出腳本的介面（duck typing）：`func play(cs) -> void`、`func end_state(fight) -> void`
- Produces（`pause_menu.gd`）：群組 `&"cutscene"` 有節點時不開選單

- [ ] **Step 1：失敗測試**（`test_cutscene.gd`，`extends "res://tests/base_test.gd"`；helper `cs_fight() -> Array`＝同 `test_fx.fx_fight`、`ui_cs() -> Node`＝單獨一個 `fight = null` 的執行器）：
  - `test_line_time`：`line_time("好。") == 1.5`；20 字句 `== 2.4`
  - `test_bars_and_hud_during_run`：遊戲模式 `run([Dummy])`（Dummy 的 `play` 等 0.5 秒）期間：上下黑邊高 ≈ 119、`fight.hud.modulate.a == 0`、`fight.world.process_mode == DISABLED`、`fight.player.can_process() == false`、`fight.boss.can_process() == false`、`fight.scenery.can_process() == true`、執行器在群組；結束後全部還原、`running == false`
  - `test_say_formats_speaker`：`say("奇瑪瑪特", "你帶了什麼回來？")` 期間 `subtitle.text` 以「奇瑪瑪特：」開頭（BBCode 或兩段 Label 皆可，測試讀純文字）；`narrate` 沒有冒號前綴
  - `test_attack_advances_one_line_at_a_time`：連續 `narrate` 三句；第一句顯示 0.35 秒時 `Input.action_press("attack")`／`release` 一次 → 換到第二句、不是第三句；0.1 秒內再按一次 → 仍在第二句（`MIN_LINE`）
  - `test_skip_by_holding_pause`：`Input.action_press("pause")` 持續 1.05 秒 → `skipped`、剩下的指令立刻完成、`end_state` 被呼叫一次；只按 0.5 秒放開 → 不跳、照常播完
  - `test_pause_hold_does_not_open_menu_after`：`PauseMenu.new()` 加進樹；演出中按住 `pause` 跳過、演出結束後才放開 → 選單沒開（`get_tree().paused == false`）
  - `test_input_not_leaking_after_cutscene`：演出最後一幀 `Input.action_press("attack")`；結束後下一個物理幀玩家沒有進入攻擊狀態
- [ ] **Step 2：跑** `SELFTEST_ONLY=test_cutscene godot --headless --path game -- --self-test` → 失敗（沒有 `cutscene.gd`）
- [ ] **Step 3：實作** `cutscene.gd`：UI 放在自己的 `CanvasLayer`（layer 5，在 Boss 戰 UI 之上）；計時用自己的 `_process(delta)` 累加（測試可用 `Engine.time_scale` 加速）；跳過圈用 `draw_arc` 畫在右下角；`pause_menu.gd` 開選單前檢查 `get_tree().get_first_node_in_group(&"cutscene") == null`
- [ ] **Step 4：跑** `SELFTEST_ONLY=test_cutscene` 通過；`SELFTEST_ONLY=test_ui`、`test_menus` 通過
- [ ] **Step 5：Commit** `Add the cutscene runner: bars, subtitles, title and hold-to-skip (MV-SLICE-001c2a)`

### Task 2：替身、手臂道具、剪影

**Files:**
- Create: `game/world/cutscene/actor.gd`、`game/world/cutscene/arm_prop.gd`
- Modify: `game/world/cutscene/cutscene.gd`（`silhouette`、`spawn`）、`game/world/scenery_view.gd`（`set_silhouette`）、`game/tests/test_cutscene.gd`

**Interfaces:**
- Consumes：Task 1 的執行器；`RigView.build/pose/set_arm_visible/sprite`、`RigView.anims_at`；`MacawAnimator.HEADS`；c1 的 `LightFx.attach(light)`（`light` 需有 `state`、`fx_drawn`）
- Produces（`actor.gd`，`extends Node2D`）：`static func make(cid: String) -> Node2D`（cid：`hunahpu`、`xbalanque`、`sevenmacaw`、`healer_man`、`healer_woman`）；`var rig`、`var facing := 1`（setter 翻 `rig.scale.x = facing * rig.faces`）、`func play(anim: String, loop_override := -1) -> void`（單次動作停在最後一格）、`func anim_length(anim: String) -> float`、`func set_black(on: bool)`、`func add_light() -> Node2D`（回傳有 `state`／`fx_drawn` 的小節點並掛 `LightFx`，每幀放到 `rig.point(point_name)`，`var light_point := "jaw"`）；Seven Macaw 替身預設只顯示完整頭（`HEADS[0]`）
- Produces（`arm_prop.gd`，`extends Node2D`）：`static func make() -> Node2D`：胡納普的 RigView 擺 `idle`、只顯示 `NearArm` 群組的分件；原點在肩膀（上臂起點），往下垂
- Produces（執行器）：`func spawn(cid: String, at: Vector2) -> Node2D`（替身加在執行器底下、`running` 結束時自動釋放）；`func walk(actor, x: float, speed := 300.0)`、`func fly(actor, to: Vector2, secs: float)`、`func play(actor, anim: String)`（等單次動作播完；循環動作不等）、`func silhouette(on: bool)`（`fight.world.modulate = BLACK`／還原、`fight.scenery.set_silhouette(on)`、執行器的漸層底 `CanvasLayer` layer −1 顯示／隱藏、所有替身 `set_black(on)`）
- Produces（`scenery_view.gd`）：`const SIL_ALPHA := {"far": 0.35, "mid": 0.6, "near": 0.85}`；`build_boss` 建圖層時記下角色（`far`＝遠景；`mid`＝`nance`、`path_mid`、`palace` 這些背景層，不論視差；`near`＝地面、`terrain`、前景）；`func set_silhouette(on: bool) -> void`：各圖層 `modulate = Color(0, 0, 0, SIL_ALPHA[角色])`，關閉還原原本的 `modulate`。（nance 樹那層視差 1.0，若依視差會變成 0.85、和純黑角色分不開）

- [ ] **Step 1：失敗測試**：
  - `test_actor_plays_and_holds`：`Actor.make("hunahpu")`，`play("hurt")`（單次）等其長度＋0.2 秒 → 仍停在最後一格（姿勢與最後一格相同）
  - `test_arm_prop_only_arm`：`ArmProp.make()` 可見的分件全部在 `NearArm` 群組、至少 2 件
  - `test_silhouette_on_off`：遊戲模式 `silhouette(true)`：`fight.world.modulate == Color.BLACK`、遠景圖層 `modulate.a == 0.35`、nance 樹圖層 `0.6`、前景 `0.85`、替身 `modulate == Color.BLACK`、漸層底可見；`silhouette(false)` 全部還原
  - `test_skip_restores_silhouette`：腳本開剪影後被跳過 → 結束時 `world.modulate == Color.WHITE`、圖層還原、漸層底隱藏
  - `test_macaw_actor_light`：Seven Macaw 替身 `add_light()` 後 `state = Light.State.GLOW`，底下有 `LightFx`，位置＝`rig.transform * rig.point("jaw")`（±1）
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**（剪影的視差倍率從 `scenery_view._par` 取；`terrain` 與區段外的節點用 0.85）
- [ ] **Step 4：跑** `SELFTEST_ONLY=test_cutscene`、`test_scenery` 通過
- [ ] **Step 5：Commit** `Stand in rigs, the torn-off arm and the backlit silhouette (MV-SLICE-001c2a)`

### Task 3：新動作

**Files:**
- Modify: `game/rig/twin_anims.json`（`crouch` 循環、`walk` 循環、`lunge` 單次、`knocked_down` 單次）、`game/rig/sevenmacaw_anims.json`（`yank` 單次、`hang` 單次）、`game/world/rig_showcase.gd`（`ORDER` 加四個雙胞胎動作）、`game/tests/test_cutscene.gd`

**Interfaces:**
- Produces：上列 6 個動作名（Task 4、5 用）。格式照既有動作（`fps` 12、`frames[].t`、`bones` 角度、雙胞胎 `pelvis` 位移、Seven Macaw `root` 位移；單次動作不寫 `length`）
- 動作要點：`crouch` 骨盆下沉約 45 px、膝蓋大彎、上身前傾；`walk` 0.8 秒一步循環、擺幅約 `run` 的一半；`lunge` 0.5 秒：後腳蹬、身體前撲、近側手臂前伸；`knocked_down` 0.6 秒：後仰跌坐、停在坐姿（骨盆下沉約 70 px）；`yank` 0.6 秒：頭往前探、咬住後往後上方一甩；`hang` 0.8 秒：脖子往前上方伸、停一下、收回

- [ ] **Step 1：失敗測試** `test_cutscene_anims_present`：雙胞胎動作檔有 `crouch`、`walk`（`loop` true）、`lunge`、`knocked_down`（`loop` false）；Seven Macaw 有 `yank`、`hang`（`loop` false）
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：寫動作資料**；`rig_showcase.ORDER` 加 `crouch`、`walk`、`lunge`、`knocked_down`
- [ ] **Step 4：跑** `SELFTEST_ONLY=test_cutscene`、`test_rig`（含每格關節覆蓋、展示清單）、`test_macaw_rig` 通過；`godot --path game -- --rig-view --frames /tmp/c2a_rig` 抽格看 6 個新動作（只看裁切）
- [ ] **Step 5：Commit** `Write crouch, walk, lunge, knocked-down, yank and hang (MV-SLICE-001c2a)`

### Task 4：開場

**Files:**
- Create: `game/world/cutscene/opening.gd`
- Modify: `game/core/boss/boss_fight.gd`（`_enter_arena`：遊戲模式且 `not intro_seen` → `await cutscene.run([Opening.new()])`；原型照舊 `play_intro`；Boss 戰在遊戲模式建立 `cutscene` 子節點）、`game/tests/test_cutscene.gd`

**Interfaces:**
- Consumes：Task 1～3
- Produces（`opening.gd`，`extends RefCounted`）：`const HIDE_X := Nance.LEFT + 520.0`、`const NARRATION := "七金剛鸚鵡每天飛到 nance 樹上吃果子。兄弟倆躲在樹下的葉叢裡，等著他。"`、`const EPITHET := "自稱是太陽，也是月亮"`；`play(cs)`、`end_state(fight)`
- 分鏡照規格「開場」1～6；`end_state`：`intro_seen = true`、Boss `begin_phase(1)` 前的狀態（在 `Nance.CANOPY`、光源熄滅）、玩家在 `HIDE_X`（地面）、`twin_index` 不變；之後 `_start_fight()` 照舊由 `_enter_arena` 呼叫
- Produces（`boss_fight.gd`）：`var cutscene`（遊戲模式才有）

- [ ] **Step 1：失敗測試**：
  - `test_opening_plays_first_time_only`：遊戲模式第一次越過 `Nance.ENTRY_X` → 執行器 `running`、Boss 的 `play_intro` 沒被呼叫（Boss 狀態不是 `INTRO`）；結束後 `intro_seen`、`stage == FIGHT`；`_retry(1)` 後再進場不播
  - `test_opening_watch_equals_skip`：兩場遊戲模式戰鬥，一場 `Engine.time_scale = 8` 看完、一場開始後立刻按住 `pause` 1.05 秒跳過 → 兩場的 `player.position`（±1）、`player.twin_index`、`boss.position`、`boss.state`、`intro_seen`、`stage` 相同
  - `test_proto_keeps_play_intro`：原型模式第一次進場 → Boss 狀態 `INTRO`、沒有 `cutscene`
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `SELFTEST_ONLY=test_cutscene`、`test_boss`、`test_boss_segment`、`test_walkthrough` 通過
- [ ] **Step 5：Commit** `Ambush Seven Macaw at the nance tree in an opening scene (MV-SLICE-001c2a)`

### Task 5：斷臂與轉場，宮殿掛著手臂

**Files:**
- Create: `game/world/cutscene/arm.gd`、`game/world/cutscene/couple.gd`
- Modify: `game/core/boss/boss_fight.gd`（`_on_setup(1)` 遊戲模式：`await cutscene.run([Arm.new(), Couple.new()])` 取代兩張卡與其後的狀態設定；原型照舊；`_apply_loadout()` 末尾 `scenery.set_arm_hung(phase >= 2 and not awakened)`（遊戲模式））、`game/world/scenery_view.gd`（`set_arm_hung(on)`：在 `ROPE_KNOT` 顯示 `ArmProp`）、`game/tests/test_cutscene.gd`

**Interfaces:**
- Consumes：Task 1～3；`Palace.PATH_START`、`Palace.VIEW`、`Nance.VIEW`
- Produces（`scenery_view.gd`）：`const ROPE_KNOT := Vector2(14712, 720)`（實作時以 `bg_palace_back_01.png` 的繩結量準，±10 px）、`func set_arm_hung(on: bool) -> void`、`var arm_prop`
- Produces（`arm.gd`）：台詞常數照 `card_text.gd` 的 `arm` 拆開：
  - `N1 := "七金剛鸚鵡大叫一聲，從樹頂摔落地面。"`
  - `N2 := "胡納普衝上前去抓他，卻被他扯下了手臂。"`
  - `N3 := "他捧著下顎回到家中，把手臂掛在火上。"`
  - `CHIMALMAT := "你帶了什麼回來？"`（說話者「奇瑪瑪特」）
  - `MACAW := "兩個騙子射了我。這條手臂就掛在這裡，等他們來拿回去。"`（說話者「七金剛鸚鵡」）
- Produces（`couple.gd`）：`N := "兄弟倆去找兩位老人：一位頭髮全白，一位彎著腰。"`、`HUNAHPU := "請陪我們去七金剛鸚鵡那裡，取回我們的手臂。"`（「胡納普」）、`XBALANQUE := "我們跟在後面，就說是你們的孫子。"`（「希巴拉克」）、`ELDERS := "好。"`（「兩位老人」）；`const TWINS_FROM := -600.0`、`const ELDERS_AT := 250.0`（相對 `PATH_START.x`）
- `arm.end_state`：`phase = 2`、`_apply_loadout()`、`boss.park(2)`（`lights_removed` 已由 `_on_setup` 設好）；`couple.end_state`：`player.position = Palace.PATH_START`、`velocity = 0`、`couple_following = true`、`couple_x = PATH_START.x - 160`、`_set_view(Palace.REGION)`、`stage = APPROACH`（＝現在兩張卡之後的程式）

- [ ] **Step 1：失敗測試**：
  - `test_arm_and_couple_replace_cards`：遊戲模式 `_on_setup(1)` → 執行器 `running`、`card.visible` 一直是 false；結束後 `phase == 2`、`player.twins[0].arm_broken`、`couple_following`、`stage == APPROACH`、`player.position == Palace.PATH_START`
  - `test_arm_watch_equals_skip`：看完（`time_scale` 8）與跳過的結束狀態相同（同 Task 4 的欄位＋`phase`、`lights_removed`、`arm_broken`、`couple_following`、`couple_x`、`scenery.arm_prop.visible`）
  - `test_arm_lines_match_card`：`N1 + N2 + N3`、`CHIMALMAT`、`MACAW` 的文字都出現在 `CardText.CARDS["arm"]` 裡；`couple` 同理（`ELDERS` 對應卡上的「好。」）
  - `test_arm_hung_after_retry_and_load`：斷臂後 `scenery.arm_prop.visible`、位置 ≈ `ROPE_KNOT`；`_retry(2)` 後仍掛著；新戰鬥 `begin_at_rest("palace_camp")` 也掛著；`start_at(4)`（覺醒）後不掛
  - `test_proto_still_shows_cards`：原型模式 `_on_setup(1)` 仍依序顯示 `arm`、`couple` 文字卡
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**（分鏡照規格「斷臂」「轉場」；斷臂開頭 `view(Nance.VIEW)`、`silhouette(true)`；宮殿前 `fade_to_black` → `silhouette(false)` → `view(Palace.VIEW)` → `fade_in`）
- [ ] **Step 4：跑** `SELFTEST_ONLY=test_cutscene`、`test_boss`、`test_ui`、`test_walkthrough` 通過
- [ ] **Step 5：Commit** `Tear off Hunahpu's arm in silhouette and recruit the two elders on screen (MV-SLICE-001c2a)`

### Task 6：`--cutscene` 開發畫面、影片與文件

**Files:**
- Create: `game/world/cutscene_view.gd`、`report/MV-SLICE-001c2a_過場機制與nance演出_{YYYY-MM-DD_HHmm}_執行報告.md`（時間戳先跑 `date`）
- Modify: `game/launch_args.gd`（`--cutscene <名稱>` → mode `"cutscene"`、`out.cutscene`；`--frames` 照舊）、`game/main.gd`、`game/README.md`（演出段落與錄影指令）、`todo/spec/MV-SLICE-001c2a_過場機制與nance演出.md`（驗收打勾、Git Commit）、`todo/todo.md`、`game/tests/test_cutscene.gd`

**Interfaces:**
- Consumes：Task 4、5 的腳本；`GameWorld.dev_start("boss", phase)`
- Produces（`cutscene_view.gd`）：`const NAMES := ["opening", "arm", "couple"]`；`var name := ""`、`var frames_dir := ""`；1920×1080 SubViewport 裝一個 `GameWorld`，`dev_start` 後擺好前置狀態（opening：玩家走到 `Nance.ENTRY_X` 右邊；arm：`start_at(1)` 後呼叫 `_on_setup(1)`；couple：同 arm，跳過 `Arm` 只跑 `Couple`），演出結束 0.5 秒後 `quit()`；`frames_dir` 非空時每幀存 JPG（同 `fx_showcase._dump_frames`）

- [ ] **Step 1：失敗測試** `test_cutscene_launch_args`：`LaunchArgs.parse(["--cutscene", "arm", "--frames", "/tmp/x"])` → `mode == "cutscene"`、`cutscene == "arm"`、`frames_dir == "/tmp/x"`；`cutscene_view.gd` 存在、`NAMES` 為上列 3 個
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：錄影與檢查**：三段各 `godot --path game --fixed-fps 30 -- --cutscene <名稱> --frames /tmp/c2a_<名稱>`，`ffmpeg -framerate 30 -i … -c:v libx264 -pix_fmt yuv420p -crf 20 assets-test/c2a_video/c2a_<名稱>.mp4`，`ffprobe` 與完整解碼確認；AI 每 0.5 秒抽格看黑邊、字幕、剪影、名號、斷臂動作、宮殿掛手臂、轉場；`--shots` 每畫面 ≤ 16.7 ms
- [ ] **Step 5：文件**：照 Files；規格書只勾 AI 有證據的項目；`todo.md` 維持 🔄、說明改「實作完成，待 Brian 看影片與手把試玩」
- [ ] **Step 6：跑** 全套自測（`MIN_PASS` ＝ 377＋新增）、`import_art.py --check`、`import_rig.py --check`、`python3 -m unittest tools/test_cut_rig.py tools/test_import_art.py` → 全部通過
- [ ] **Step 7：Commit** `Record the nance tree scenes and document the cutscene system (MV-SLICE-001c2a)`
