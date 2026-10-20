# MV-SLICE-001b2a 雙胞胎的骨架與動作：實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把雙胞胎的靜態立繪換成執行時從資料組出的骨架，依玩家狀態播約 12 fps、不內插的動作，玩法與數值不變。

**Architecture:** 分件與關節資料由工具從 p4 的整張切件換算成遊戲尺寸（`game/art/chr/parts/`、`game/rig/`）。`world/rig_view.gd` 依資料組 Skeleton2D／Bone2D／Sprite2D，`pose(動作, 時間)` 取「時間 ≤ t 的最後一格」（不內插、不用 AnimationPlayer）；`world/twin_animator.gd` 每幀把玩家狀態換成（動作, 時間）並疊吹射。

**Tech Stack:** Godot 4.7.2（GDScript）、Python 3＋Pillow＋numpy（匯入工具）

**Spec:** [todo/spec/MV-SLICE-001b2a_雙胞胎動作.md](MV-SLICE-001b2a_雙胞胎動作.md)（定案 SLICE-b2a-1～9）

## Global Constraints

- 動作約 12 fps、不內插（SLICE-b2a-3）；角度與位移一律寫在資料檔，程式不寫死姿勢（SLICE-b2a-2、8）
- 判定框與數值不動（SLICE-b4）；換人立刻生效、不鎖操作（SLICE-b2a-6）
- 雙胞胎身高 180 px（±5%），腳底對齊碰撞框底部
- 斷臂：近側手臂與武器隱藏、不見血（SLICE-b2a-4）；斧頭、掘棒一直握在手上，吹箭只在吹射時出現（SLICE-b2a-5）；球具只在裝備時穿上
- 程式畫的訊號（招架小盾、光環、二段跳光點、換人閃光）畫在骨架上面；受擊閃白、無敵與翻滾半透明、治療綠色沿用 b1 立繪規則
- 只改雙胞胎；敵人、Seven Macaw、NPC 的立繪不動（b2b）；`gs == null` 的原型模式維持灰盒
- 新增的開發參數只在 `OS.is_debug_build()` 生效
- 每個 Task 的驗證：`python3 -m unittest tools/test_import_art.py` OK，且 `godot --headless --path game -- --self-test` 為 `fail=0`、沒有 `SCRIPT ERROR`／`Parse Error`／`flushing queries`（同 b1 的 `/tmp/b1_verify.sh`）

## Review Focus

1. **換人打斷攻擊**（含破綻滿時的 `force_twin(0)`）：舊的那位骨架立刻隱藏、新的不會卡在攻擊姿勢——Task 4 `test_force_swap_mid_attack`
2. **換房、休息、死亡回點很多次**：每位玩家恰好兩副骨架，不累積——Task 5 `test_one_rig_pair_per_player`
3. **朝背後瞄準的吹射**：頭轉動限制在 ±45°、雙臂仍朝瞄準方向，面向不因吹射改變——Task 4 `test_dart_overlay_behind`
4. **斷臂中換人再換回、覺醒當下手臂回來**：手臂與武器的顯示跟著 `weapon_enabled` 走，不殘留——Task 4 `test_broken_arm_follows_weapon_enabled`
5. **空中攻擊與空中受擊**：腿不播跑步、攻擊姿勢照段落走、落地才播落地——Task 4 `test_air_attack_no_run_legs`

---

### Task 1: 分件、關節資料與附件匯入

**Files:**
- Create: `tools/import_rig.py`、`game/rig/hunahpu_rig.json`、`game/rig/xbalanque_rig.json`
- Modify: `tools/import_art.py`（`ENTRIES` 加分件與附件；新增 `scale` 處理）、`game/art/MANIFEST.md`（重產）
- Test: `tools/test_import_art.py`

**Interfaces:**
- Produces：`game/rig/{角色}_rig.json`＝p4 `prototypes/p4-art-pipeline/rig/{角色}_rig.json` 的所有像素座標（`reference.joints`、`reference.size`、各分件 `size`／`pivot`／`tip`）乘上 `k = 180 / body_height`，並加 `"scale": k`；`body_height`、`ground` 的定義同 p4 `rig.gd`（`ground`＝髖中心正下方、腳踝與腳趾的最低點；`body_height = ground.y − crown.y`）。分件鍵名維持 p4 的 `chr_{角色}_{短名}`
- Produces：`game/art/chr/parts/{角色}/{短名}.png`（16 件＋`hand_grip_l/_r`，`import_art` 新選項 `"scale": k`，不裁切、不去背：p4 分件已是透明背景）
- Produces：`game/art/chr/parts/wpn_axe.png`（全長約 90 px）、`wpn_digging_stick.png`（約 130）、`wpn_blowgun.png`（約 110）、`wpn_ballgear_yoke.png`（寬約 60）、`wpn_ballgear_armguard.png`（長約 40）；來源見規格「角色與附件」；`fit_width`／`fit_height` 依長邊，洋紅底的用 `key`（深褐大面積用 `"hard"`）
- Produces（Python）：`import_rig.rig_scale(char: str) -> float`，`import_art` 的分件條目用它算 `scale`，兩支工具的 `k` 同源

- [ ] **Step 1: 寫失敗測試**（`tools/test_import_art.py`）
  - `test_rig_json_game_scale`：兩角色 `game/rig/{c}_rig.json` 存在；由其 joints 算出的 `body_height` 在 180±1；`scale` 等於 `180 / p4 body_height`（±1e-6）
  - `test_rig_parts_exist`：rig json 裡每個 `chr_` 分件在 `game/art/chr/parts/{c}/` 有對應 PNG，且像素尺寸等於 json 的 `size`（±1）
  - `test_weapon_side_images`：五件附件都存在、長邊在上列目標 ±2
- [ ] **Step 2:** 跑 `python3 -m unittest tools/test_import_art.py`，Expected：3 項 FAIL
- [ ] **Step 3:** 實作 `tools/import_rig.py`（`--check` 同 `import_art`）與 `import_art` 的 `scale` 選項、條目；跑 `python3 tools/import_rig.py && python3 tools/import_art.py && godot --headless --path game --import`
- [ ] **Step 4:** 跑驗證（Global Constraints 最後一條），Expected：unittest OK、`fail=0`
- [ ] **Step 5: Commit** `Bring the twins' parts, joints and side-view gear into the game (MV-SLICE-001b2a)`

---

### Task 2: 骨架組裝 `rig_view.gd`

**Files:**
- Create: `game/world/rig_view.gd`、`game/rig/attachments.json`
- Test: `game/tests/test_rig.gd`

**Interfaces:**
- Consumes：Task 1 的 rig json 與 PNG
- Produces：`rig_view.gd`（`extends Node2D`）
  - `const BONES`：同 p4 `rig.gd` 的 16 根骨頭表（含父子關係、起訖關節）；`_r`＝近側、`_l`＝遠側
  - `func build(char: String) -> void`：組 Skeleton2D、Bone2D（靜止姿勢＝基準圖）、分件 Sprite2D（`offset = -pivot`、主軸轉到骨頭方向、`z_index` 照 json `z`）；原點＝`ground`（腳底）
  - `func pose(anim: String, t: float) -> void`：套用 `twin_anims.json` 的影格（Task 3 產出；Task 2 先用只有 `rest` 一個動作的最小檔）
  - `func set_hand(kind: String) -> void`（`"open"`／`"grip"`：切換近側手）、`func set_weapon(w: int) -> void`（`Weapons.Weapon` 值，`-1`＝空手；球具＝穿上護腰護手、手張開）、`func show_attachment(name: String, on: bool) -> void`（吹箭、湯碗這類只在某些動作出現的附件）、`func set_arm_visible(on: bool) -> void`（近側上臂、前臂、手與武器）
  - `const JOINT_PAIRS`：同 p4 `anims.gd`（關節 → 兩側分件的短名），Task 3 的覆蓋檢查用
  - `func bone(name: String) -> Bone2D`、`func joint_global(name: String) -> Vector2`（測試用）
- Produces：`game/rig/attachments.json`：`{附件名: {"tex": res 路徑, "bone": 骨頭, "pivot": [x, y], "angle_deg": 數字, "z": 數字}}`；握點量自 Task 1 的附件圖（握柄中段），湯碗掛 `hand_r`

- [ ] **Step 1: 寫失敗測試**（`test_rig.gd`）
  - `test_rig_height_and_feet`：兩角色 `build` 後，所有可見分件的不透明像素外框高 180±9、底邊在 y＝0±2
  - `test_rig_rest_matches_reference`：每個關節的 `joint_global` 與 rig json 的關節（減去 `ground`）相差 ≤ 2 px
  - `test_rig_weapon_and_hand`：`set_weapon(AXE)` → 斧頭可見、近側手為握持；`set_weapon(BALLGEAR)` → 護腰護手可見、斧頭與掘棒隱藏；`set_weapon(-1)` → 手張開、無武器；`set_arm_visible(false)` → 近側上臂、前臂、手、武器都隱藏；`show_attachment("wpn_blowgun", true)`、`show_attachment("prop_soup_bowl", true)` → 對應附件可見，預設兩者隱藏
- [ ] **Step 2:** 跑自測，Expected：`test_rig` 3 項 FAIL（`rig_view.gd` 不存在）
- [ ] **Step 3:** 實作 `rig_view.gd`、`attachments.json`、最小 `twin_anims.json`
- [ ] **Step 4:** 跑驗證，Expected：`fail=0`
- [ ] **Step 5: Commit** `Assemble the twins' skeletons from data at runtime (MV-SLICE-001b2a)`

---

### Task 3: 動作資料 `twin_anims.json`

**Files:**
- Modify: `game/rig/twin_anims.json`、`game/world/rig_view.gd`（取樣與覆蓋檢查）
- Test: `game/tests/test_rig.gd`

**Interfaces:**
- Produces：`twin_anims.json` 格式：`{"fps": 12, "anims": {名: {"loop": bool, "hand": "open"|"grip"|"weapon", "frames": [{"t": 數字, "bones": {骨頭: 相對靜止姿勢的角度（度）}, "pelvis": [dx, dy], "phase": "startup"|"active"|"recovery"（只有攻擊類）}]}}}`；`hand: "weapon"`＝依裝備
- 動作名（Task 4 依這些名稱選用）：`idle`、`run`、`jump_up`、`fall`、`land`、`roll`、`hurt`、`heal`、`interact`、`swap_in`、`double_jump`、`tool_cast`、`attack_{axe|stick}_{side|up|down}`（6 個）、`parry_side`、`parry_up`、`ballgear_down`、`parry_success`、`dart`（只列頭、雙臂）
- 時間：循環與一般動作的 `t` 是秒（相鄰影格約 1/12 秒）；攻擊類的 `t` 是「段落時間」：出招 0～1、判定 1～2、收招 2～3（Task 4 依數值表換算）
- `pose()` 規則：取 `t` ≤ 目前時間的最後一格（循環動作先對長度取餘數），不內插；沒列出的骨頭維持靜止姿勢
- 每個攻擊至少一格判定段的「揮出」姿勢：武器主軸指向攻擊方向（側＝前、上＝上、下＝下）±30°

- [ ] **Step 1: 寫失敗測試**（`test_rig.gd`）
  - `test_all_anims_present`：上列 23 個動作都在 json，且每個至少一格
  - `test_attack_frames_cover_phases`：每個攻擊類動作的影格 `phase` 涵蓋 startup、active、recovery，`t` 落在對應區間
  - `test_attack_swing_points_dir`：每個攻擊在 active 段至少一格，武器主軸方向與攻擊方向差 ≤ 30°
  - `test_joints_covered_in_every_frame`：移植 p4 `test_joints_covered_in_every_key`——每個動作的每一格，`JOINT_PAIRS` 的每個關節周圍半徑 14×k 的取樣點都被分件不透明像素蓋住（截斷取整，見 p4 README 的除錯提醒）
  - `test_pose_steps_without_interp`：`run` 在兩格之間的時間取到前一格的角度（不內插）
- [ ] **Step 2:** 跑自測，Expected：上列 FAIL
- [ ] **Step 3:** 寫 23 個動作的資料（p4 `anims.gd` 的 idle、run、斧頭側攻可當起點換算）；用 `--rig-view`（Task 6 之前先用一次性腳本截圖）逐一檢查姿勢
- [ ] **Step 4:** 跑驗證，Expected：`fail=0`
- [ ] **Step 5: Commit** `Write the twins' animations as data (MV-SLICE-001b2a)`

---

### Task 4: 狀態對應 `twin_animator.gd`

**Files:**
- Create: `game/world/twin_animator.gd`
- Test: `game/tests/test_twin_animator.gd`

**Interfaces:**
- Consumes：`Player` 的 `state`、`state_time`、`attack_dir`、`attack_phase`、`attack_weapon`、`twin_index`、`twins[i].weapon`、`twins[i].weapon_enabled`、`facing`、`velocity`、`is_on_floor()`、`intent.aim`、`parry_ring_left`；訊號 `swapped`、`interacted`、`tool_sent`、`double_jumped`、`dart_fired`；`Weapons.timing(w, tn)`
- Produces：`twin_animator.gd`（`extends Node`，掛在玩家底下）
  - `var rigs: Array`（`[Hunahpu 的 rig_view, Xbalanque 的 rig_view]`）
  - `static func choose(p) -> Array`：回傳 `[動作名, 時間]`，純函式（測試直接呼叫）
  - `static func attack_time(p) -> float`：段落時間 0～3，依 `Weapons.timing(attack_weapon, tn)` 把 `state_time` 換成「出招 0～1、判定 1～2、收招 2～3」
  - 每幀：只顯示 `rigs[twin_index]`；`set_weapon`、`set_arm_visible(weapon_enabled)`、`scale.x = facing`；`pose(choose(...))`；吹射覆寫
- 對應：FREE 地面依 `|velocity.x| > 10` 選 `run`／`idle`；空中依 `velocity.y < 0` 選 `jump_up`／`fall`；著地瞬間播 `land`（0.2 秒內有移動、跳躍、攻擊輸入就打斷）；ROLL→`roll`（時間＝`state_time`）；HURT→`hurt`；HEAL→`heal`＋顯示湯碗（其他狀態隱藏）；ATTACK→`attack_{武器}_{方向}`，球具的側、上→`parry_side`／`parry_up`、下→`ballgear_down`；PARRY→`parry_side`／`parry_up`；`parry_ring_left > 0`→`parry_success`；`swapped`→`swap_in`、`interacted`→`interact`、`tool_sent`→`tool_cast`、`double_jumped`→`double_jump`：這四個是 FREE 狀態下的短動作，播完回到對應的基本動作，移動或攻擊輸入立刻打斷
- 吹射：`dart_fired` 後 0.3 秒，頭與雙臂改用 `dart` 動作的角度，再轉到瞄準角度（`intent.aim`，零向量＝面向前方）；頭的轉動限制 ±45°；吹箭顯示 0.3 秒

- [ ] **Step 1: 寫失敗測試**（`test_twin_animator.gd`，用 `Player.new()`＋`Loadout` 建玩家、`scripted = true`）
  - `test_choose_by_state`：逐一設定狀態（地面靜止／移動、上升、下落、ROLL、HURT、HEAL、三武器×三方向、PARRY 側上），`choose()` 回傳的動作名符合上表
  - `test_attack_time_follows_tuning`：`axe_startup` 加倍後，`state_time = axe_startup × 0.5` 時 `attack_time` 為 0.5；`state_time = startup + active × 0.5` 時為 1.5
  - `test_force_swap_mid_attack`（Review Focus 1）：攻擊判定中 `force_twin(1)`，下一幀只有 `rigs[1]` 可見、`choose` 不是攻擊動作
  - `test_dart_overlay_behind`（Review Focus 3）：面向右、瞄準正左發射，0.3 秒內近側前臂朝向與瞄準方向差 ≤ 10°、頭轉動 ≤ 45°、`facing` 仍為 1；0.4 秒後回到主動作
  - `test_dart_overlay_keeps_legs`：邊跑邊射，腿的骨頭角度與同時間的 `run` 影格相同
  - `test_broken_arm_follows_weapon_enabled`（Review Focus 4）：`weapon_enabled = false` → 近側手臂與武器隱藏；換到 Xbalanque 再換回仍隱藏；設回 true 的下一幀出現
  - `test_air_attack_no_run_legs`（Review Focus 5）：空中側攻時 `choose` 為攻擊動作；落地那幀之後播 `land`
  - `test_short_anims_interruptible`：`swap_in` 播放中給移動輸入，下一幀 `choose` 為 `run`
  - `test_heal_shows_bowl`：HEAL 期間湯碗可見，離開 HEAL 的下一幀隱藏
- [ ] **Step 2:** 跑自測，Expected：上列 FAIL
- [ ] **Step 3:** 實作 `twin_animator.gd`
- [ ] **Step 4:** 跑驗證，Expected：`fail=0`
- [ ] **Step 5: Commit** `Drive the twins' animation from the player's state (MV-SLICE-001b2a)`

---

### Task 5: 接進遊戲（取代雙胞胎立繪）

**Files:**
- Create: `game/world/tint.gd`（從 `portrait.gd` 抽出的顏色規則）
- Modify: `game/state/loadout.gd`（雙胞胎改掛骨架與 animator）、`game/world/portrait.gd`（改用 `tint.gd`；`TWINS` 換人邏輯移除）
- Test: `game/tests/test_twin_animator.gd`、`game/tests/test_portraits.gd`（雙胞胎相關項改測骨架）

**Interfaces:**
- Consumes：Task 2、4
- Produces：`tint.gd`：`static func of(actor) -> Color`（受擊閃白 `Color(1.8,1.8,1.8)`、治療 `Color(0.6,1.0,0.7)`、翻滾無敵 α 0.45、受擊無敵閃爍 α 0.3，規則與數值同 b1 `portrait.gd`）；`rig_view` 與 `portrait` 每幀用它設 `modulate`
- `Loadout.make_player`：建兩副 `rig_view`（`show_behind_parent = true`）＋一個 `twin_animator`，`player.portrait_drawn = true`；不再掛雙胞胎的 Portrait

- [ ] **Step 1: 寫失敗測試**
  - `test_rig_tint_rules`：受擊、翻滾無敵、受擊無敵閃爍、治療四種情況下 `rigs[twin_index].modulate` 符合 `tint.of` 的值
  - `test_signals_above_rig`：骨架 `show_behind_parent` 為 true（招架小盾、光環由玩家 `_draw` 畫在上面）
  - `test_one_rig_pair_per_player`（Review Focus 2）：`home`↔`field` 來回 5 次、休息 2 次，目前玩家底下恰好 2 個 `rig_view`、1 個 `twin_animator`，且沒有雙胞胎的 Portrait
  - 原本 b1 的 `test_twin_portrait_height_and_feet` 改成檢查骨架（高 180±9、腳底 0±2）
- [ ] **Step 2:** 跑自測，Expected：上列 FAIL
- [ ] **Step 3:** 實作
- [ ] **Step 4:** 跑驗證，Expected：`fail=0`；子專案 a、b1 的既有測試（含 `test_walkthrough`）照舊通過
- [ ] **Step 5: Commit** `Show the twins as rigs in the game (MV-SLICE-001b2a)`

---

### Task 6: 動作展示畫面 `--rig-view` 與錄影

**Files:**
- Create: `game/world/rig_showcase.gd`
- Modify: `game/launch_args.gd`（`mode == "rig_view"`）、`game/main.gd`
- Test: `game/tests/test_rig.gd`（參數解析、展示順序）

**Interfaces:**
- Produces：`LaunchArgs.parse(["--rig-view"])` → `mode == "rig_view"`（只在開發版生效，同 `--shots`）
- `rig_showcase.gd`：兩兄弟並排（1920×1080、角色 180 px、背景用 `forest` 主題的遠景＋地表），依 Task 3 的動作清單每個動作播 2 輪（攻擊類以斧頭、掘棒、球具各一輪的數值表時間播）、畫面下方顯示動作名；全部播完後切灰階（`CanvasModulate` 不行就用 `BackBufferCopy`＋灰階 shader）再播一輪，然後結束程式；按鍵：G 灰階、空白鍵暫停、→ 逐格
- `static func playlist() -> Array`：`[[動作名, 秒數], …]`

- [ ] **Step 1: 寫失敗測試**：`test_launch_args_rig_view`（`--rig-view` → `rig_view`）；`test_showcase_playlist_covers_all`（`playlist()` 涵蓋 Task 3 的 23 個動作）
- [ ] **Step 2:** 跑自測，Expected：2 項 FAIL
- [ ] **Step 3:** 實作
- [ ] **Step 4:** 跑驗證，Expected：`fail=0`；再跑 `godot --path game --resolution 1920x1080 --write-movie /tmp/b2a_rigs.avi -- --rig-view`，Expected：產出影片、沒有 `SCRIPT ERROR`；用 `ffprobe` 確認 1920×1080（不是的話在展示畫面裡設定視窗大小）
- [ ] **Step 5: Commit** `Add a rig showcase for recording the twins' animations (MV-SLICE-001b2a)`

---

### Task 7: 驗收素材、文件與收尾

**Files:**
- Modify: `game/README.md`（骨架資料、`--rig-view`、錄影指令）、`ART_SPEC.md` 第 6 節（垂直切片雙胞胎動作的實作狀態）、`todo/spec/MV-SLICE-001b2a_雙胞胎動作.md`（驗收打勾、Git Commit）、`todo/todo.md`
- Create: `report/MV-SLICE-001b2a_雙胞胎動作_<date>_執行報告.md`（時間先跑 `date`）

- [ ] **Step 1:** 錄驗收影片（Task 6 的指令）轉成 mp4 放 `assets-test/b2a_video/`（不進版控）；用 `ffmpeg` 每 0.5 秒抽一格拼成總覽，逐張看：灰階下兩兄弟分得出、訊號在角色上面、關節沒有露縫
- [ ] **Step 2:** 跑 `godot --path game -- --shots /tmp/b2a_shots`，Expected：每個畫面平均幀時間 ≤ 16.7 ms；看 `forest_1`、`boss_palace` 的彩色與灰階截圖
- [ ] **Step 3:** 跑兩條驗證指令與 `python3 tools/import_art.py --check`、`python3 tools/import_rig.py --check`，記錄結果
- [ ] **Step 4:** 寫文件與報告；派工單 MV-SLICE-001b2a 標「⏸️ 暫停（等待 Brian 驗收）」
- [ ] **Step 5: Commit** `Document the twins' rigs and report sub-project b2a (MV-SLICE-001b2a)`
