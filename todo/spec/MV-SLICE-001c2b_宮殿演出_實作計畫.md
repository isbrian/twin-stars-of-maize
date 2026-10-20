# MV-SLICE-001c2b 宮殿的演出 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把宮殿的 `toothache`、`teeth`、`death` 三張文字卡換成引擎內演出，並修正 c2a 延後的過場機制問題。

**Architecture:** 沿用 c2a 的執行器（`world/cutscene/cutscene.gd`）與替身（`actor.gd`），先修機制（並行指令、防重入、HUD、交還順序、藏起任意節點、替身可掛身上光點），再加三支演出腳本；死後的宮殿狀態（地上的身體、奇瑪瑪特）由 `scenery_view.set_dead` 依進度決定。

**Tech Stack:** Godot 4.7.2 GDScript；自測 `godot --headless --path game -- --self-test`（`SELFTEST_ONLY=` 只跑部分；多檔用 `bash /tmp/wt/st_only.sh test_a test_b`）；動作檔 `game/rig/*_anims.json`（手寫 JSON，12 fps；格式化工具 `/tmp/wt/animfmt.py` 可逐位元組重寫）。

**Spec:** [MV-SLICE-001c2b_宮殿演出.md](MV-SLICE-001c2b_宮殿演出.md)（Brian 2026-10-14 核准）

## Global Constraints

- 只在遊戲模式（`boss_fight.gs != null`）播演出；原型模式行為逐項不變。
- 不改戰鬥數值、判定、重試規則；不加聲音、新美術、shader、鏡頭移動。
- 台詞皆為 `card_text.gd` 原句：牙痛 3 句旁白；換牙 七金剛鸚鵡「可憐可憐我，治好我的牙吧。」＋旁白「老人取出他的牙，換上一粒粒發亮的白玉米。」「他的臉立刻垮了下來，看起來不再像王。」；死亡旁白「老人又摘去他眼中的貴金屬。」「他不覺得痛，只是呆呆望著前方。」「他身上的光一點一點熄滅了。」「七金剛鸚鵡死了。他的妻子奇瑪瑪特也隨之死去。」「兩位老人帶走了他的珠寶。」
- 舞台 `STAGE_X := 15100`（他伏低的位置、面向左）；老夫婦替身從 `Palace.COUPLE_X − 45`／`+ 25` 出發；雙胞胎替身站在真角色的位置。
- 換頭：換牙後頭 2（白玉米）、摘眼後頭 3（失明）。身上光點熄滅 `extinguish(2.0)`。
- 死後：地上的身體＝Seven Macaw 骨架擺 `collapse` 最後一格、頭 3、`modulate` ×0.5、`STAGE_X`、面向左、沒有判定；奇瑪瑪特隱藏；`couple_static = false`。
- 看完與跳過的結束狀態必須相同。
- 新動作照既有規則：關節覆蓋、Seven Macaw 非拍翅動作 `wing_arm ≥ −8`、腳底（根骨頭位移）用量測校準。
- 註解、文件繁體中文；commit 英文、結尾 `(MV-SLICE-001c2b)`。

## Review Focus

1. **死亡演出被跳過**：場景直接到最暗、宮殿假光全滅、地上有身體、真正的 Boss 藏著、奇瑪瑪特不在——沒有閃一下又亮回來 → Task 5 `test_death_watch_equals_skip`（含 `scenery.modulate`、`palace_lights.alpha`）
2. **死亡 `end_state` 藏起 Boss，交還操作時不能被恢復成顯示** → Task 1 `test_end_state_visibility_wins`
3. **換牙時老夫婦替身在演、真正的老夫婦不能同時出現在入口端** → Task 4 `test_teeth_hides_real_couple`
4. **攻擊鍵提前換句時，並行的「跳到舞台」「老人走過去」仍會做完才往下**（不會在空中伏低、老人沒到就換頭） → Task 1 `test_together_waits_for_all`
5. **第 3 段設局那一刻場景不先變暗**（遊戲模式），原型模式照舊立刻變暗 → Task 5 `test_death_darkens_in_scene_not_before`

---

## 檔案結構

| 檔案 | 責任 | Task |
|---|---|---|
| `game/world/cutscene/cutscene.gd` | `together`、`hide`、防重入、HUD 只在演出時寫、交還順序 | 1 |
| `game/world/cutscene/actor.gd` | 骨架節點名 `Rig`、`faced_body()`、`add_glints()` | 1 |
| `game/rig/sevenmacaw_anims.json`、`healer_man_anims.json`、`healer_woman_anims.json`、`chimalmat_anims.json` | 7 個新動作 | 2 |
| `game/tests/test_macaw_rig.gd`、`test_npc_rig.gd` | 動作白名單加新動作 | 2 |
| `game/world/cutscene/toothache.gd`、`teeth.gd`、`death.gd` | 三段演出腳本 | 3、4、5 |
| `game/core/boss/boss_fight.gd` | 遊戲模式改播三段；第 3 段不先套 `_apply_lights`；`_apply_loadout` 同步 `set_dead` | 3、4、5 |
| `game/world/scenery_view.gd` | `set_dead(on)`、`body_prop`、奇瑪瑪特顯示 | 5 |
| `game/world/cutscene_view.gd` | `NAMES` 加三段與前置狀態 | 3～5 |
| `game/tests/test_cutscene.gd` | 全部新測試 | 1～6 |

---

### Task 1：機制修正

**Files:**
- Modify: `game/world/cutscene/cutscene.gd`、`game/world/cutscene/actor.gd`、`game/tests/test_cutscene.gd`

**Interfaces:**
- Produces（`cutscene.gd`）：
  - `func together(calls: Array[Callable]) -> void`：同時開始每個 Callable（各自是一個指令協程），全部 return 後才 return；`skipped` 時立刻 return。
  - `func hide(node: CanvasItem) -> void`：記下原本的 `visible` 並藏起，交還時恢復。
  - `run()` 已在 `running` 時：`push_error("cutscene 已在執行")` 並 return。
  - `_process` 只在 `running` 時寫 `fight.hud.modulate.a`。
  - 交還（同一幀）：移除替身 → `fight.camera` 回 current、`reset_smoothing` → 恢復 `_shown`（玩家、Boss、`hide` 過的節點）→ 解凍戰場 → `MenuInput.swallow()` → **依序呼叫各段 `end_state`**（播放時不再逐段呼叫）→ 收黑邊。
- Produces（`actor.gd`）：骨架節點名 `"Rig"`；`func faced_body() -> Rect2`（Seven Macaw：`MacawAnimator.BODY`，`facing < 0` 時左右翻；其他角色回傳 `Rect2()`）；`func add_glints() -> Node2D`（`MacawGlints.attach(self)`，回傳光點節點）。

- [ ] **Step 1：失敗測試**：
  - `test_together_waits_for_all`：`together([cs.wait.bind(0.3), cs.wait.bind(0.8)])` 約 0.8 秒後才 return（≥ 0.75）；跳過中呼叫立刻 return
  - `test_run_reentry_ignored`：`run([Dummy])` 中再 `run([Dummy2])` → Dummy2 的 `end_state` 沒被呼叫、第一段照常結束
  - `test_hud_untouched_when_idle`：演出外把 `fight.hud.modulate.a = 0.5`，等 3 幀仍是 0.5
  - `test_end_state_visibility_wins`：假演出的 `end_state` 設 `fight.boss.visible = false` → 演出結束後仍是 false；玩家恢復 true
  - `test_hide_restores`：`cs.hide(fight.couple[0])`（先設可見）→ 演出中不可見、結束後恢復
  - `test_actor_glints`：`Actor.make("sevenmacaw")` 的 `add_glints()` 得到 `MacawGlints`、`lit_count() == NAMES.size()`；`extinguish(0.3)` 後 0.5 秒 `lit_count() == 0`
  - 既有 Task 2 的 c2a 測試（`test_handover_without_doubles`、三段看完＝跳過）照過
- [ ] **Step 2：跑** `SELFTEST_ONLY=test_cutscene` → 失敗
- [ ] **Step 3：實作**（`together` 用一個計數器：每個 Callable 包成協程，結束時遞減；`_until` 等計數為 0）
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_cutscene test_boss test_walkthrough` 全過
- [ ] **Step 5：Commit** `Run cutscene steps together and let end_state decide visibility (MV-SLICE-001c2b)`

### Task 2：新動作

**Files:**
- Modify: 上列 4 個動作檔、`game/tests/test_macaw_rig.gd`（`ANIM_NAMES` 加 `bow`、`collapse`）、`game/tests/test_npc_rig.gd`（`ANIMS`：`healer_man`、`healer_woman` 加 `reach: false`、`pick: false`；`chimalmat` 加 `collapse: false`）、`game/tests/test_cutscene.gd`

**Interfaces:**
- Produces：`sevenmacaw`：`bow`（0.6 秒伏低：torso 約 −38°、neck 約 −30°、根骨頭下沉讓腳仍著地、頭貼近地面高度約 150～200 px，停住）、`collapse`（0.8 秒側倒：身體往後倒、根骨頭下沉、停住；翅膀收著）；老人各自：`reach`（0.4 秒雙臂往前上方伸、停住）、`pick`（0.8 秒彎腰撿起後直起）；`chimalmat`：`collapse`（0.8 秒倒下停住）。全部單次（`loop: false`）。

- [ ] **Step 1：失敗測試** `test_palace_anims_present`：上列每個動作存在、`loop == false`
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：寫動作資料**（用 `/tmp/wt/animfmt.py` 保持格式；根骨頭位移用 probe 量腳底校準到 ±1 px；`bow`、`collapse` 的 `wing_arm ≥ −8`）；更新兩個測試檔的白名單
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_cutscene test_macaw_rig test_npc_rig` 全過；渲染每個新動作的每格做縮圖檢查（伏低時頭的高度在老人身高範圍內）
- [ ] **Step 5：Commit** `Write bow, collapse, reach and pick for the palace scenes (MV-SLICE-001c2b)`

### Task 3：第 2 段開場（牙痛）

**Files:**
- Create: `game/world/cutscene/toothache.gd`
- Modify: `game/core/boss/boss_fight.gd`（`_enter_arena`：`phase == 2 and not palace_card_seen and cutscene != null` → `stage = Stage.CARD`、`await cutscene.run([Toothache.new()])`；原型照舊卡片）、`game/world/cutscene_view.gd`（`NAMES` 加 `toothache`：`start_at(2)` 前置改為「進宮殿前」：`begin_at_rest("palace_camp")` 後把角色放到 `Palace.ENTRY_X + 60`）、`game/tests/test_cutscene.gd`

**Interfaces:**
- Produces（`toothache.gd`）：`const N1 := "七金剛鸚鵡坐在寶座邊上，牙痛得不停哭喊。"`、`N2 := "奇瑪瑪特在寶座旁。"`、`N3 := "他看見老人身後的兩個孩子，猛然站了起來。"`、`const SIT_X := 15250.0`；`play(cs)`（`view(Palace.VIEW)`；替身頭 1、面向右 `wail` → N1、N2 → 面向左 `spread` 同時 N3）、`end_state(f)`：`palace_card_seen = true`

- [ ] **Step 1：失敗測試**：
  - `test_toothache_first_time_only`：遊戲模式 `begin_at_rest("palace_camp")` 後越過 `Palace.ENTRY_X` → 執行器 `running`、`card.visible` 一直 false；結束後 `palace_card_seen`、`stage == FIGHT`、`phase == 2`；`_retry(2)` 再進場不播
  - `test_toothache_watch_equals_skip`：看完（`time_scale` 8）與跳過的 `{player, boss.position, boss.state, palace_card_seen, stage}` 相同
  - `test_toothache_lines_match_card`：N1～N3 都在 `CardText.CARDS["toothache"]`
  - `test_proto_toothache_card`：原型模式進宮殿仍顯示 `toothache` 卡
  - `test_cutscene_view_has_toothache`：`CutsceneView.NAMES` 含 `toothache`
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_cutscene test_boss test_ui test_walkthrough`（`test_walkthrough` 進宮殿處把 `pass_card` 換成 `skip_cutscene`）
- [ ] **Step 5：Commit** `Open the palace fight with Seven Macaw wailing by his throne (MV-SLICE-001c2b)`

### Task 4：換牙

**Files:**
- Create: `game/world/cutscene/teeth.gd`
- Modify: `game/core/boss/boss_fight.gd`（`_on_setup` 的 `2 when cutscene != null:`：`stage = Stage.CARD`、`await cutscene.run([Teeth.new()])`、`_start_fight()`；原型照舊）、`game/world/cutscene_view.gd`（`teeth`：`start_at(2)` 後 `_on_setup(2)`）、`game/tests/test_cutscene.gd`

**Interfaces:**
- Consumes：Task 1 `together`、`hide`；Task 2 `bow`、`reach`
- Produces（`teeth.gd`）：`const PLEA := "可憐可憐我，治好我的牙吧。"`（說話者「七金剛鸚鵡」）、`N1 := "老人取出他的牙，換上一粒粒發亮的白玉米。"`、`N2 := "他的臉立刻垮了下來，看起來不再像王。"`、`const STAGE_X := 15100.0`、`const HEAD_REACH := -220.0`（伏低時頭相對腳的 x，面向左）、`const ELDER_GAP := 70.0`；老人站位：老伯 `STAGE_X + HEAD_REACH − 35`、老婆婆 `+ 35`、面向右；`play(cs)`、`end_state(f)`：`phase = 3`
- 分鏡照規格「換牙」；`together` 用在「跳到舞台＋老人起步」與「老人退回＋他起身」；換頭在 N1 開始時

- [ ] **Step 1：失敗測試**：
  - `test_teeth_replaces_card`：遊戲模式 `start_at(2)` → `_on_setup(2)`：執行器 `running`、沒有卡片；結束後 `phase == 3`、`stage == FIGHT`、`boss.appearance == 2`
  - `test_teeth_watch_equals_skip`：`{player, boss.position, boss.state, phase, lights_removed, couple visible}` 相同
  - `test_teeth_hides_real_couple`：演出中 `fight.couple` 兩個節點都不可見；結束後恢復可見（`couple_static`）
  - `test_teeth_lines_match_card`
  - `test_proto_teeth_card`：原型模式 `_on_setup(2)` 仍顯示 `teeth` 卡
  - `test_cutscene_view_has_teeth`：`CutsceneView.NAMES` 含 `teeth`
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_cutscene test_boss test_ui test_walkthrough`（`test_walkthrough` 第 2 段設局後換成 `skip_cutscene`）
- [ ] **Step 5：Commit** `Replace Seven Macaw's teeth with white maize on screen (MV-SLICE-001c2b)`

### Task 5：死亡與死後的宮殿

**Files:**
- Create: `game/world/cutscene/death.gd`
- Modify: `game/core/boss/boss_fight.gd`（`_on_setup(3)`：遊戲模式 `lights_removed = 3` 但**不呼叫** `_apply_lights`，`await cutscene.run([Death.new()])`，之後照舊 `awaken` 卡與其後程式；`_apply_loadout()` 末尾 `scenery.set_dead(awakened)`（遊戲模式））、`game/world/scenery_view.gd`（`set_dead(on)`、`var body_prop`、`const BODY_AT := Vector2(15100, 900)`；`on` 時顯示身體、`terrain/Chimalmat` 隱藏，`off` 相反）、`game/world/cutscene_view.gd`（`death`：`start_at(3)` 後 `_on_setup(3)`）、`game/tests/test_cutscene.gd`

**Interfaces:**
- Consumes：Task 1 `together`、`hide`、`actor.add_glints`；Task 2 `bow`、`collapse`、`reach`、`pick`；c1 `PalaceLights`、`scenery.set_darkness(n, animate)`
- Produces（`death.gd`）：`const N1 := "老人又摘去他眼中的貴金屬。"`、`N2 := "他不覺得痛，只是呆呆望著前方。"`、`N3 := "他身上的光一點一點熄滅了。"`、`N4 := "七金剛鸚鵡死了。他的妻子奇瑪瑪特也隨之死去。"`、`N5 := "兩位老人帶走了他的珠寶。"`、`const OUT_X := Palace.LEFT − 200.0`（老人走出畫面）、`const JEWELS := 3`（每位老人手上的小金光數）；`play(cs)`、`end_state(f)`：`f._apply_lights()`（直接到最暗）、`f.boss.deactivate(true)`、`f.scenery.set_dead(true)`、`f.palace.couple_static = false`
- 分鏡照規格「死亡」1～6；N3 開始時 `together([glints 熄滅 2.0 秒, scenery.set_darkness(3, true) 後等 0.8 秒])`；奇瑪瑪特：`cs.hide(terrain/Chimalmat)` 換成替身 `chimalmat`（同位置、面向左）`modulate` 漸黑 → `collapse` → 透明度淡到 0；小金光用 `FxKit.glow_texture` 的小 Sprite（加亮）掛在老人替身的手（骨架 `forearm` 末端）

- [ ] **Step 1：失敗測試**：
  - `test_death_replaces_card`：遊戲模式 `start_at(3)` → `_on_setup(3)`：執行器 `running`、`death` 卡不出現；演出結束後顯示 `awaken` 卡（c2c 再改）
  - `test_death_darkens_in_scene_not_before`：遊戲模式 `_on_setup(3)` 後 2 幀 `scenery.modulate` 仍是第 3 段的暗度（`DARKNESS[2]`）、宮殿第 3 組假光 `alpha[2] == 1`；原型模式不受影響（場景為 null，`lights_removed` 立刻 3）
  - `test_death_watch_equals_skip`：`{boss.visible, lights_removed, scenery.modulate, palace_lights.alpha, body_prop.visible, chimalmat.visible, couple_static, player}` 相同；`scenery.modulate` ＝ `DARKNESS[3]`、`alpha` 全 0、身體可見、奇瑪瑪特隱藏、Boss 不可見
  - `test_death_lines_match_card`
  - `test_cutscene_view_has_death`：`CutsceneView.NAMES` 含 `death`
  - `test_dead_palace_follows_awakened`：`start_at(4)` → 身體可見、奇瑪瑪特隱藏；`start_at(2)`、`start_at(3)` → 身體不可見、奇瑪瑪特可見
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_cutscene test_boss test_ui test_fx test_walkthrough`（`test_walkthrough` 第 3 段設局後：`skip_cutscene` 再 `pass_card`（awaken））
- [ ] **Step 5：Commit** `Put out Seven Macaw's false light and leave him lying in the palace (MV-SLICE-001c2b)`

### Task 6：影片與文件

**Files:**
- Create: `report/MV-SLICE-001c2b_宮殿演出_{YYYY-MM-DD_HHmm}_執行報告.md`（時間戳先跑 `date`）
- Modify: `game/README.md`（「Boss 戰的演出」加三段、`--cutscene` 名稱）、`todo/spec/MV-SLICE-001c2b_宮殿演出.md`（驗收、Git Commit）、`todo/todo.md`

本 Task 沒有新程式、沒有新測試（`--cutscene` 的名稱由 Task 3～5 各自測）。

- [ ] **Step 1：錄影**：三段各 `godot --path game --fixed-fps 30 -- --cutscene <名稱> --frames /tmp/c2b_<名稱>` → `ffmpeg … assets-test/c2b_video/c2b_<名稱>.mp4`，`ffprobe`、完整解碼；AI 每 0.5 秒抽格（伏低遮擋、換頭、光熄滅與假光淡出、倒下、奇瑪瑪特、帶走珠寶、死後身體、交還不重疊）；`--shots` 每畫面 ≤ 16.7 ms
- [ ] **Step 2：文件**：照 Files；規格書只勾 AI 有證據的項目；`todo.md` 維持 🔄、改「實作完成，待 Brian 看影片與手把試玩」
- [ ] **Step 3：跑** 全套（`MIN_PASS` ＝ 400＋新增）、`import_art.py --check`、`import_rig.py --check`、`python3 -m unittest tools/test_cut_rig.py tools/test_import_art.py`
- [ ] **Step 4：Commit** `Record the palace scenes and document them (MV-SLICE-001c2b)`
