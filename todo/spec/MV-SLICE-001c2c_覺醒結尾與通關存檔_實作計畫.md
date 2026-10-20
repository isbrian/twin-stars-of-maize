# MV-SLICE-001c2c 覺醒、結尾與通關存檔 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `awaken`、`clear` 文字卡換成引擎內演出（取回手臂、剪影裝回、閃回、能力名、結尾），出口提示做到才換，覺醒時自動存檔、讀檔回到覺醒後的宮殿，並修掉 c2a、c2b 延後的 Minor 與斷臂替身。

**Architecture:** 沿用 c2a／c2b 的執行器（`world/cutscene/cutscene.gd`）與替身（`actor.gd`）。先補機制（跳過分段、離開場景樹、蓋在畫面上的圖層、白幕、逐幀動畫指令、斷臂替身），再把「覺醒後的狀態」集中成 `boss_fight` 的兩個函式（演出結束、讀檔、`start_at(4)`、F10 共用），最後加三支演出腳本（覺醒、閃回布景、結尾）與結束畫面。

**Tech Stack:** Godot 4.7.2 GDScript；自測 `godot --headless --path game -- --self-test`（`SELFTEST_ONLY=` 只跑部分；多檔 `bash /tmp/wt/st_only.sh test_a test_b`；全套 `bash /tmp/wt/step6.sh`）；動作檔 `game/rig/twin_anims.json`（12 fps，格式化 `/tmp/wt/animfmt.py`）；閃回色調用 Godot 內建 `canvas_item` shader。

**Spec:** [MV-SLICE-001c2c_覺醒結尾與通關存檔.md](MV-SLICE-001c2c_覺醒結尾與通關存檔.md)（Brian 2026-10-15 核准）

## Global Constraints

- 只在遊戲模式（`boss_fight.cutscene != null`）播演出；原型模式照舊文字卡 `awaken`、`clear`，行為逐項不變。
- 旁白原句：取回「胡納普從火上取回手臂，」、裝回「兄弟倆把它裝回原處，手臂完好如初。」、閃回「希巴拉克想起開墾田地的那一天：」「斧頭自己砍倒了樹，掘棒自己翻開了土。」、結尾「七金剛鸚鵡的驕傲被拿走了。」
- 能力名：`title("讓工具自己動", "希巴拉克覺醒")`、`title("二段跳", "胡納普覺醒")`。
- 出口提示：`"希巴拉克的飛鏢射中木障，工具會自己去砍碎它"`（木障碎前）→ 現有 `EXIT_HINT`（碎後到走上高台）；兩者不限時。存檔提示 `"已存檔"` 2 秒。
- 結束畫面文字（逐字）：`"垂直切片到此結束，謝謝試玩。\n\n製作　Brian\n故事依據　《Popol Vuh》Allen J. Christenson 英譯本\n美術與音訊　AI 生成"`。
- 存檔欄位與 `Save.VERSION` 不變；寫檔只在篝火休息與覺醒交還那一刻（`last_rest = "palace_camp"`、`awakened = true`、補滿）。
- 看完與跳過的結束狀態必須相同；演出旁白在字幕框內不超過兩行。
- 不加聲音、新美術、新依賴；新動作（若需要）照既有規則：關節覆蓋、12 fps。
- 註解、文件繁體中文；commit 英文、結尾 `(MV-SLICE-001c2c)`；全套自測基準 428 項。

## Review Focus

1. **覺醒的剪影途中跳過**：剪影還原（`world.modulate` 白、暖色底藏起）、胡納普有手臂、繩上沒有手臂 → Task 3 `test_awaken_skip_mid_silhouette`
2. **閃回途中跳過**：白幕與田地布景都清掉，交還後畫面看得到宮殿 → Task 4 `test_flashback_skip_clears`
3. **設局時剛好是希巴拉克在場**（或之後被換回）：交還時保持希巴拉克，不會被換成胡納普 → Task 2 `test_awakening_keeps_xbalanque`
4. **通關後再按「繼續」**：仍是覺醒後的宮殿，可以再走一次出口、再看一次結尾；結尾不改存檔 → Task 5 `test_finale_leaves_save_awakened`
5. **結尾演出被跳過**：黑畫面一直保持到換房，沒有閃一下宮殿，仍換到結束畫面 → Task 5 `test_finale_keeps_black`（看完、跳過各一次）

---

## 檔案結構

| 檔案 | 責任 | Task |
|---|---|---|
| `game/world/cutscene/cutscene.gd` | `skip_stop`、`cast_of`、斷臂替身、離開場景樹、`show_layer`、`fade_to_white`、`animate`、`title(who…)`、`keep_black` | 1、5 |
| `game/world/cutscene/actor.gd` | `hold` 可用骨頭名 | 3 |
| `game/core/boss/boss_fight.gd` | `finish_awakening`、`_enter_awakened_palace`、讀檔、F10、出口提示、遊戲模式播覺醒與結尾 | 2、3、5 |
| `game/world/cutscene/awaken.gd` | 覺醒演出（取回、裝回、閃回、能力名） | 3、4 |
| `game/world/cutscene/flashback.gd` | 閃回布景（田地一角、工具動作、暖褐 shader、暈邊） | 4 |
| `game/world/cutscene/finale.gd` | 結尾演出 | 5 |
| `game/world/ending.gd` | 結束畫面文字 | 5 |
| `game/world/cutscene_view.gd` | `--cutscene` 加 `awaken`、`finale` | 3、5 |
| `game/rig/twin_anims.json` | 視需要：取下、扶回 | 3 |
| `game/tests/test_cutscene.gd` | 新測試（檔尾區段「c2c」） | 1～5 |
| `game/tests/test_walkthrough.gd`、`test_boss_segment.gd` | 跳過兩段、結尾流程、覺醒後繼續 | 2、3、5 |

---

### Task 1：機制與延後的測試補強

**Files:**
- Modify: `game/world/cutscene/cutscene.gd`、`game/tests/test_cutscene.gd`

**Interfaces:**
- Produces（`cutscene.gd`）：
  - 演出腳本可宣告 `var skip_stop := true`。`run()` 播到它時若 `skipped`：設回 `false`、`_need_release = true`、從這段開頭播。`_process`：`_need_release` 時長按不累計；放開暫停鍵清掉 `_need_release`。沒有宣告的段落行為不變。
  - `func cast_of(cid: String) -> Node2D`：`_cast` 裡第一個未 `queue_free`、`cid` 相同的替身；沒有回傳 `null`。
  - `spawn()`：`fight != null` 且 `cid == TwinAnimator.CHARS[0]` 時 `a.rig.set_arm_visible(not fight.player.twins[0].arm_broken)`。
  - `_exit_tree()` 設 `_gone = true`；`_until` 在 `_gone` 時立刻 return（等幀改用 `Engine.get_main_loop().process_frame`）。
  - `func show_layer(node: CanvasItem) -> void`：加到 `_ui` 的第 0 個（在 `_fade`、黑邊、字幕之下）；交還時釋放還在的。
  - `func fade_to_white(secs := 0.4) -> void`：`_fade` 顏色換白、透明度到 1；`fade_to_black` 先換回黑。`fade_in` 不變。
  - `func animate(secs: float, step: Callable) -> void`：每幀呼叫 `step.call(k)`（k 0→1）；跳過時直接 `step.call(1.0)`。
  - `title(who: String, epithet: String, secs := 1.5)`（參數改名，c2a Minor 7）。

- [ ] **Step 1：失敗測試**（`test_cutscene.gd` 檔尾新區段「c2c」）：
  - `test_skip_stop_resumes_scene`：`run([Dummy, StopDummy])`（`StopDummy.skip_stop = true`）；長按到 `skipped` → `StopDummy.play` 有被呼叫且 `skipped == false`；不放開再按 1.5 秒仍 `false`；放開後長按 1.1 秒 → `true`；兩段的 `end_state` 各一次
  - `test_skip_without_stop_skips_all`：`run([Dummy, Dummy2])` 長按 → `Dummy2.play` 沒有播到完（同 c2a 行為）
  - `test_cast_of`：生成 `hunahpu`、`xbalanque` → `cast_of` 各自取得；不存在的 cid 回傳 `null`
  - `test_twin_stand_in_arm_follows_real`：`twins[0].arm_broken = true` 時 `spawn("hunahpu")` 的近側手臂隱藏；`false` 時可見；`start_teeth(f)` 演出中 `cast_of("hunahpu")` 的近側手臂隱藏（c2b 的錯誤）
  - `test_until_ends_when_removed`：`run([LongDummy])`（`wait(30)` 後設 `done = true`）途中把執行器移出場景樹 → 3 幀內 `done`，沒有錯誤
  - `test_show_layer_under_bars`：`show_layer(n)` 後 `n.get_index() < cs._fade.get_index()`；交還後 `n` 已釋放
  - `test_fade_to_white_then_black`：`fade_to_white(0.2)` 後 `_fade.color` 為白、a 1；`fade_to_black(0.2)` 後為黑、a 1
  - `test_animate_steps_to_one`：記錄 `step` 收到的 k，最後一個是 1.0、遞增；跳過中呼叫只收到 1.0
  - `test_cutscene_lines_fit_two_lines`（c2a Minor 6）：`res://world/cutscene/` 每個腳本的常數裡、名稱是 `N` 加數字或 `PLEA` 的字串，套 `_line` 的格式（`PLEA` 加說話者「七金剛鸚鵡」）放進 `subtitle`，等 1 幀 `get_line_count() <= 2`
  - `test_together_finishes_walk_on_early_advance`（c2b Minor 2）：`together([cs.walk.bind(a, a.position.x + 300), cs.narrate.bind("短句")])`，0.6 秒時按攻擊鍵換句 → return 時 `a.position.x` 已到目的地
  - `test_death_skip_during_fade`（c2b Minor 3）：`start_death` 看到奇瑪瑪特 `modulate.a < 0.9` 且 `r <= 0.05`（淡出中）時 `hold_skip` → `death_state` 與完整看完的 `death_state` 相同
- [ ] **Step 2：跑** `SELFTEST_ONLY=test_cutscene` → 新測試失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_cutscene test_boss test_ui test_walkthrough` 全過
- [ ] **Step 5：Commit** `Let a scene stop a skip and keep the twin stand-ins one-armed (MV-SLICE-001c2c)`

### Task 2：覺醒後的狀態、存檔與出口提示

**Files:**
- Modify: `game/core/boss/boss_fight.gd`、`game/tests/test_cutscene.gd`、`game/tests/test_walkthrough.gd`

**Interfaces:**
- Produces（`boss_fight.gd`）：
  - `func _enter_awakened_palace() -> void`：`phase = 3`、`lights_removed = 3`、`_apply_lights()`、`awakened = true`、`intro_seen = true`、`palace_card_seen = true`、`_apply_loadout()`、`boss.deactivate(true)`、`palace.couple_static = false`、老夫婦不可見、`palace.barrier.restore()`、`arena(2).open_gate()`。
  - `func finish_awakening() -> void`：`_enter_awakened_palace()` → `player.twin_index == 0` 時 `player.swap_twin()` → `gs != null` 時 `gs.awakened = true`、`gs.rest("palace_camp")`、`Save.write(gs.to_dict(), save_path)`、`Loadout.apply(player, gs)`、`_apply_loadout()`、`_saved_left = SAVED_TIME` → `_set_view(Palace.EXIT_VIEW)`、`_enter_exit()`。
  - `const EXIT_HINT_BARRIER := "希巴拉克的飛鏢射中木障，工具會自己去砍碎它"`、`const SAVED_NOTICE := "已存檔"`、`const SAVED_TIME := 2.0`；移除 `EXIT_HINT_TIME`、`_exit_hint_left`。
  - `func exit_notice() -> String`：`stage == EXIT` 時依序 `SAVED_NOTICE`（`_saved_left > 0`）→ `EXIT_HINT_BARRIER`（`not palace.barrier.is_broken`）→ `EXIT_HINT`；其他階段 `""`。`_physics_process` 每幀遞減 `_saved_left`；EXIT 期間 `hud.notice = exit_notice()`，離開 EXIT 時清成 `""`。
  - `begin_at_rest(rest_id)`：先 `awakened = gs != null and gs.awakened`。`_retry(p)` 末尾：`awakened` 時 `_enter_awakened_palace()`（Boss 保持藏起）。
  - 走路階段 `awakened` 且越過 `_entry_x(2)`：`_set_view(Palace.EXIT_VIEW)`、`_enter_exit()`（不呼叫 `_enter_arena`：不關閘門、不播牙痛、不開打）。
  - `start_at(4)`：`_enter_awakened_palace()` ＋現有的玩家位置、`_set_view(EXIT_VIEW)`、`_enter_exit()`。
  - `_on_setup(3)`：演出或卡片之後改呼叫 `finish_awakening()`（取代現有的覺醒後段；遊戲模式在本 Task 仍是 `run([Death])` ＋ `awaken` 卡）。

- [ ] **Step 1：失敗測試**：
  - `test_awakening_saves`：遊戲模式 `start_death` → `hold_skip` → 按掉 `awaken` 卡 → `Save.read(TEST_SAVE)`：`awakened`、`last_rest == "palace_camp"`、`hp == tn.max_hp`、`heal_charges == tn.heal_charges`；`player.twin_index == 1`；`stage == EXIT`；`hud.notice == "已存檔"`，2.1 秒後是 `EXIT_HINT_BARRIER`
  - `test_awakening_keeps_xbalanque`（Review Focus 3）：設局後、按掉卡片前把 `player.twin_index` 換成 1 → 結束後仍是 1
  - `test_exit_hints_follow_progress`：`start_at(4)` → `EXIT_HINT_BARRIER`；7 秒後仍是；`palace.barrier.break_apart()` → 下一幀 `EXIT_HINT`；7 秒後仍是
  - `test_load_awakened_palace`：`gs.awakened = true`、`begin_at_rest("palace_camp")` → Boss 不可見、身體可見、奇瑪瑪特隱藏、`scenery.arm_prop` 不可見或不存在、`lights_removed == 3`、老夫婦不可見、`abilities_enabled`、`not twins[0].arm_broken`、`not barrier.is_broken`、`stage == APPROACH`；角色移到 `Palace.ENTRY_X + 100` → `stage == EXIT`、`not palace.gate_closed`、`not cutscene.running`、`not card.visible`
  - `test_start_at_4_matches_load`：`start_at(4)` 與讀檔後的 `{boss.visible, body, chimalmat, lights_removed, couple visible, couple_static, abilities, arm_broken, barrier}` 相同（c2b Minor 1：老夫婦不可見）
  - `test_reset_area_keeps_awakened`：讀檔後 `reset_area()` → Boss 仍不可見、`awakened`、身體可見
  - `test_proto_awaken_no_save`：原型模式 `_on_setup(3)` 照舊 `death`、`awaken` 兩張卡 → EXIT，沒有寫檔
  - `test_walkthrough.gd` `test_continue_after_awakening`：存一個 `awakened`、`last_rest = "palace_camp"` 的檔 → 標題「繼續」→ 進 Boss 段落、`awakened`、Boss 不可見
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_cutscene test_boss test_ui test_walkthrough` 全過
- [ ] **Step 5：Commit** `Save on awakening and come back to an awakened palace (MV-SLICE-001c2c)`

### Task 3：覺醒演出——取回手臂與裝回

**Files:**
- Create: `game/world/cutscene/awaken.gd`
- Modify: `game/world/cutscene/actor.gd`、`game/core/boss/boss_fight.gd`（遊戲模式 `_on_setup(3)`：`await cutscene.run([Death.new(), Awaken.new()])`，不再顯示 `awaken` 卡；`finish_awakening()` 由 `Awaken.end_state` 呼叫）、`game/world/cutscene_view.gd`（`NAMES` 加 `awaken`：`start_at(3)` 後 `Death.new().end_state(f)` 再 `run([Awaken.new()])`；`death` 照舊，現在會接著播覺醒）、視需要 `game/rig/twin_anims.json`＋`test_rig.gd` 白名單、`game/tests/test_cutscene.gd`、`test_walkthrough.gd`、`test_boss_segment.gd`

**Interfaces:**
- Consumes：Task 1 `skip_stop`、`cast_of`、斷臂替身、`together`、`silhouette`；Task 2 `finish_awakening()`；`scenery.set_arm_hung(on)`、`ArmProp.make()`、`rig.set_arm_visible(on)`
- Produces（`actor.gd`）：`hold(node, point)` 的 `point` 不在 `rig.points` 時當骨頭名，跟著該骨頭（雙胞胎沒有 points）。
- Produces（`awaken.gd`）：`var skip_stop := true`；`const N1 := "胡納普從火上取回手臂，"`、`N2 := "兄弟倆把它裝回原處，手臂完好如初。"`；`const REACH_DX`（胡納普站位相對 `ROPE_KNOT.x`，抽格校準到手碰到繩結 ±10 px）、`const MEND_GAP`（裝回時希巴拉克與哥哥的距離）；`play(cs)`：替身用 `cast_of`，沒有就 `Teeth.spawn_twins(cs)`；`end_state(f)`：`f.finish_awakening()`。
- 分鏡照規格「覺醒演出」1～2：取下用候選 `tool_cast`（遠側手 `upperarm_l` −77°），扶回用候選 `heal`；抽格看不出動作時才寫新動作（`reach_up`、`mend`，單次）。取下那一刻 `f.scenery.set_arm_hung(false)`、`hu.hold(ArmProp.make(), "hand_l")`；裝回那一刻釋放道具、`hu.rig.set_arm_visible(true)`。
- `test_walkthrough.gd` 的 `skip_cutscene(f)`（c2a Minor 8）：按住直到 `f.cutscene.skipped` 或演出結束（上限 3 秒）→ 放開；仍在演出（遇到 `skip_stop`）就重複，最多 4 次。

- [ ] **Step 1：失敗測試**：
  - `test_awaken_replaces_card`：遊戲模式 `start_death` 後看完 → 沒有卡片；`awakened`、`stage == EXIT`、存檔已寫
  - `test_death_skip_stops_at_awaken`：死亡段長按 → 播到 `Awaken.play`（`cast_of("hunahpu")` 存在、`skipped == false`），胡納普近側手臂隱藏
  - `test_awaken_watch_equals_skip`：看完與（死亡＋覺醒各長按一次）的 `{awakened, twin_index, arm_broken, arm_prop 可見, abilities, stage, save 內容, boss.visible}` 相同
  - `test_awaken_skip_mid_silhouette`（Review Focus 1）：`backdrop_visible()` 為 true 時長按 → 交還後 `world.modulate == Color.WHITE`、`backdrop_visible() == false`、胡納普有手臂
  - `test_awaken_arm_taken_and_mended`：看完時記錄：取下後繩上手臂不可見、胡納普替身 `held != null`；剪影期間所有替身 `modulate == Color.BLACK`；結束前替身近側手臂可見、`held == null`
  - `test_awaken_lines_match_card`：N1＋N2 去掉標點後等於 `CardText.CARDS["awaken"]` 第一句去掉標點
  - `test_cutscene_view_has_awaken`
  - 更新：`test_death_replaces_card`（不再有 `awaken` 卡）、`test_walkthrough_new_game_to_exit` 的死亡段（`skip_cutscene` 會跳兩段，不再 `pass_card`）、`test_boss_segment` 的 `test_awakening_sets_gamestate`
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**；`--cutscene awaken` 錄一次，抽格校準 `REACH_DX`、`MEND_GAP`、決定是否需要新動作
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_cutscene test_boss test_ui test_rig test_walkthrough test_boss_segment` 全過
- [ ] **Step 5：Commit** `Let Hunahpu take back his arm and his brother set it in place (MV-SLICE-001c2c)`

### Task 4：閃回與能力名

**Files:**
- Create: `game/world/cutscene/flashback.gd`
- Modify: `game/world/cutscene/awaken.gd`、`game/tests/test_cutscene.gd`

**Interfaces:**
- Consumes：Task 1 `show_layer`、`fade_to_white`、`fade_in`、`animate`、`title`、`together`
- Produces（`flashback.gd`，`extends Control`，全螢幕）：`static func make() -> Control`：子節點田地背景（`bg_field_mid_01`，蓋滿）、2 叢灌木、2 個土塊、斧頭、掘棒（`prop_field_bush`、`prop_field_clod`、`wpn_axe`、`wpn_digging_stick`），子節點 `use_parent_material = true`、根節點 `material` 是暖褐 `ShaderMaterial`（灰階亮度 × `Color(0.82, 0.62, 0.40)`）；最上層暈邊用 `GradientTexture2D`（`FILL_RADIAL`，中心透明、邊緣約 0.7 黑）。`func play(cs) -> void`：`together([_chop, _dig])`——斧頭飛到灌木上擺動 3 下，灌木傾倒、淡出；掘棒往土塊戳 3 下，土塊縮小、淡出；約 3.5 秒；全部用 `cs.animate`。
- Produces（`awaken.gd`）：`const N3 := "希巴拉克想起開墾田地的那一天："`、`N4 := "斧頭自己砍倒了樹，掘棒自己翻開了土。"`；分鏡照規格 3～4：`fade_to_white(0.4)` → `show_layer(Flashback.make())` → `fade_in(0.4)` → `together([fb.play, N3 再 N4])` → `fade_to_white(0.4)` → 釋放布景 → `fade_in(0.4)` → 兩個 `title`。

- [ ] **Step 1：失敗測試**：
  - `test_flashback_set`：`Flashback.make()` 有背景、2 灌木、2 土塊、斧頭、掘棒；根節點 `material is ShaderMaterial`；貼圖子節點 `use_parent_material`
  - `test_awaken_shows_flashback_then_removes`：看完時記錄：演出中出現過 `Flashback` 節點、`_fade.color` 曾是白；交還後沒有 `Flashback` 節點、`_fade.color.a == 0`
  - `test_flashback_skip_clears`（Review Focus 2）：`Flashback` 出現後長按 → 交還後沒有布景、`_fade.color.a == 0`
  - `test_awaken_titles`：看完時記錄 `title_label.text` 依序出現「讓工具自己動」「二段跳」，`epithet_label.text` 出現「希巴拉克覺醒」「胡納普覺醒」
  - `test_awaken_flashback_lines`：N3、N4 照 Global Constraints；`test_cutscene_lines_fit_two_lines` 自動涵蓋
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**；`--cutscene awaken` 錄一次抽格看色調、暈邊、工具動作
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_cutscene test_walkthrough` 全過
- [ ] **Step 5：Commit** `Flash back to the field where the tools worked by themselves (MV-SLICE-001c2c)`

### Task 5：結尾與結束畫面

**Files:**
- Create: `game/world/cutscene/finale.gd`
- Modify: `game/world/cutscene/cutscene.gd`（`keep_black`）、`game/core/boss/boss_fight.gd`（`_finish()`：遊戲模式 `stage = DONE`、`hud.notice = ""`、`await cutscene.run([Finale.new()])`、`log.close`、`finished.emit()`；原型照舊 `clear` 卡）、`game/world/ending.gd`（`TEXT` 換成結束畫面文字）、`game/world/cutscene_view.gd`（`finale`：`start_at(4)` → 角色放到高台 → `_finish()`）、`game/tests/test_cutscene.gd`、`test_walkthrough.gd`、`test_boss_segment.gd`

**Interfaces:**
- Consumes：Task 1 `cast_of`、`fade_to_black`；Task 2 出口階段
- Produces（`cutscene.gd`）：演出腳本可宣告 `var keep_black := true`；`run()` 收尾時任何一段有它就把 `_fade.color` 設成 `Color.BLACK`（不收掉），否則照舊歸 0。
- Produces（`finale.gd`）：`var keep_black := true`；`const N1 := "七金剛鸚鵡的驕傲被拿走了。"`；`const VIEW := Rect2(15100, Palace.GROUND_Y - 960, 1920, 1080)`（高台與宮殿右半、地上的身體）；替身站在玩家位置與其左 90 px（限制在高台 x 16320～17020 內）、面向左；N1 → 轉向右 `together([walk 到 Palace.EXIT_RIGHT + 200, 0.5 秒後 fade_to_black(1.0)])`；`end_state(f)`：無。

- [ ] **Step 1：失敗測試**：
  - `test_finale_plays_on_ledge`：遊戲模式 `start_at(4)`、角色放到高台 → 執行器 `running`、`card.visible` 一直 false；結束後 `finished` 發出
  - `test_finale_keeps_black`（Review Focus 5）：看完、長按跳過各一次：`cutscene.running` 變 false 之後到 `finished` 發出的每一幀 `_fade.color == Color.BLACK`
  - `test_finale_leaves_save_awakened`（Review Focus 4）：覺醒存檔後走完結尾 → `Save.read` 仍 `awakened`、`palace_camp`；讀檔 → 覺醒後的宮殿，再走上高台會再播結尾
  - `test_finale_line`：N1 照 Global Constraints
  - `test_end_screen_text`：`Ending.TEXT` 逐字等於 Global Constraints 的結束畫面文字（含「AI 生成」）
  - `test_proto_clear_card`：原型模式 `_finish()` 仍顯示 `clear` 卡
  - `test_cutscene_view_has_finale`
  - 更新：`test_boss_segment` 結尾流程（跳過結尾演出、結束畫面含「垂直切片到此結束，謝謝試玩。」）、`test_walkthrough_new_game_to_exit`（覺醒後：希巴拉克射木障或直接 `break_apart()`、走上高台 → `skip_cutscene` → 結束畫面 → 回主選單）
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_cutscene test_boss test_ui test_walkthrough test_boss_segment` 全過
- [ ] **Step 5：Commit** `Walk the twins out of the palace and end the slice with credits (MV-SLICE-001c2c)`

### Task 6：影片與文件

**Files:**
- Create: `report/MV-SLICE-001c2c_覺醒結尾與通關存檔_{YYYY-MM-DD_HHmm}_執行報告.md`（時間戳先跑 `date`）
- Modify: `game/README.md`（「Boss 戰的演出」加覺醒、結尾；`--cutscene` 名稱；通關存檔）、`todo/spec/MV-SLICE-001c2c_覺醒結尾與通關存檔.md`（驗收、Git Commit）、`todo/todo.md`

本 Task 沒有新程式、沒有新測試。

- [ ] **Step 1：錄影**：`death`（死亡＋覺醒）、`finale` 各 `godot --path game --fixed-fps 30 -- --cutscene <名稱> --frames /tmp/c2c_<名稱>` → `ffmpeg -framerate 30 -i … -c:v libx264 -pix_fmt yuv420p -crf 20 assets-test/c2c_video/c2c_<名稱>.mp4`，`ffprobe`、完整解碼；另錄一段出口操作（`start_at(4)`：射木障、二段跳上高台、結尾、結束畫面）。AI 抽格：斷臂替身、取下、剪影裝回、閃回色調與工具、能力名、交還前後連續、提示切換、結尾黑畫面不閃、結束畫面；`--shots` 每畫面 ≤ 16.7 ms
- [ ] **Step 2：文件**：照 Files；規格書只勾 AI 有證據的項目；`todo.md` 維持 🔄、改「實作完成，待 Brian 看影片與手把試玩」
- [ ] **Step 3：跑** `bash /tmp/wt/step6.sh`（428＋新增、`--check`、unittest）
- [ ] **Step 4：Commit** `Record the awakening and the finale and document them (MV-SLICE-001c2c)`
