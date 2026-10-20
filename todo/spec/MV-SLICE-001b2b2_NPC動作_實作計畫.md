# MV-SLICE-001b2b2 NPC 的骨架與動作：實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 祖母、老鼠（事件＋技能）、治療者老夫婦、Chimalmat 從靜態立繪／灰盒換成資料驅動的骨架與動作。

**Architecture:** 5 個角色各一份 `tools/rig_src/{角色}_joints.json`，用 `tools/cut_rig.py` 從高解析原始立繪切件、`import_rig.py`／`import_art.py` 匯入；新增共用的 `world/npc_animator.gd`（呼叫端決定動作與面向），五個呼叫端換掉 `Portrait`／梯形；移除 `world/portrait.gd`。

**Tech Stack:** Python 3（numpy、Pillow）、Godot 4.7.2 GDScript、ffmpeg。

**Spec:** [todo/spec/MV-SLICE-001b2b2_NPC動作.md](MV-SLICE-001b2b2_NPC動作.md)

## Global Constraints

- 角色 id 與遊戲高度：`xmucane` 165、`healer_man` 170、`healer_woman` 165、`rat` 40、`chimalmat` 340（同現在立繪的 `fit_height`）
- 原始立繪（相對 `assets-test/`）：`chr_batch2/chr_xmucane_reference.png`、`chr_batch3/chr_healer_man_reference.png`、`chr_batch3/chr_healer_woman_reference.png`、`chr_batch2/chr_rat_reference.png`、`batch2/chr/chr_chimalmat_reference.png`
- 面向：`xmucane`、`healer_man`、`healer_woman`、`rat` 的基準圖面向右（`faces` 1）；`chimalmat` 面向左（`faces` −1）
- 靜止姿勢對齊現有立繪 `res://art/chr/chr_{角色}_reference.png`：`MATCH_PX` 2、`MIN_IOU` 0.9；內容中心 x＝原點 ±1、腳底 y＝0（同立繪 `Portrait` 的「寬一半、腳底」對齊）
- 遠側手腳：`far` 複製近側、明度 ×0.72，和近側反向擺動
- 動作（`loop`）：`xmucane` `idle`(是)、`give`(否，約 0.75 秒)；`rat` `idle`(是)、`run`(是)；`healer_man`／`healer_woman` `idle`(是)、`walk`(是)；`chimalmat` `idle`(是)；12 fps、不內插
- 既有角色（`hunahpu`、`xbalanque`、`crawler`、`flyer`、`sevenmacaw`）的 rig json 與分件逐位元組不變
- 不改：互動距離、逃跑距離（300）與速度（跑速 ×1.1）、技能射程／速度／傷害／暈眩與咬到即消失、老夫婦跟隨速度（跑速 ×0.9）、文字卡流程、夜晚只調場景圖層
- 不開新美術工單；切出來露縫先用 `overlap`／`caps` 補，補不了停下來回報 BLOCKED（附檢查圖）
- `assets-test/` 不進版控（檢查圖放 `assets-test/b2b2/check/`）；`import_art.py --check`、`import_rig.py --check` 要重現同樣位元組
- 註解、文件繁體中文；commit 訊息英文、結尾 `(MV-SLICE-001b2b2)`，最後一行 `Co-Authored-By: Claude <noreply@anthropic.com>`
- 全套驗證：`MIN_PASS=<目前通過數> bash /tmp/wt/b2a_verify.sh`（起點 336；每個 Task 結束時用該 Task 跑出的通過數當下一個 Task 的下限）

## Review Focus

1. **祖母兌換時連按互動鍵**：`give` 播放中再按不應從頭重播（不抽動），回到 `idle` 後再按才重播 → Task 5 `test_npc_give_not_restarted`
2. **老鼠技能咬到當幀被釋放**：animator 和骨架掛在老鼠底下一起釋放，不該有存取已釋放節點的錯誤 → Task 6 `test_rat_skill_rig_freed_on_bite`
3. **老夫婦跟隨中但角色停著**：x 沒變就播 `idle`，不是原地走路 → Task 5 `test_couple_walks_only_when_moving`
4. **夜晚抓老鼠時骨架被調暗**：夜晚只調場景圖層，老鼠骨架顏色照舊 → Task 6 `test_night_rat_keeps_colour`
5. **重新進房、讀檔後 NPC 骨架重複**：每個 NPC 節點底下剛好一副骨架 → Task 5 `test_npc_single_rig`

---

## 檔案結構

| 檔案 | 責任 | Task |
|---|---|---|
| `tools/import_rig.py` | `TARGETS`、`CUT_CHARS` 加 5 個 NPC；`FACES_RIGHT` 讓面向右的角色 `faces` 1 | 1 |
| `tools/test_import_art.py` | NPC 的 rig json 面向、高度、分件存在 | 1 |
| `tools/rig_src/{角色}_joints.json`、`{角色}_rig.json` | 人工標的關節與切件輸出 | 1～4 |
| `game/rig/{角色}_rig.json`、`{角色}_anims.json`、`game/art/chr/parts/{角色}/*`、`game/art/MANIFEST.md` | 匯入與動作 | 1～4 |
| `game/tests/test_npc_rig.gd` | 組裝、靜止對齊、原點、動作清單、關節覆蓋；整合 | 1～6 |
| `game/world/npc_animator.gd` | 建骨架、播動作、面向 | 5 |
| `game/world/room.gd`、`world/scenery_view.gd`、`core/boss/boss_fight.gd` | 祖母、Chimalmat、老夫婦換骨架 | 5 |
| `game/world/portrait.gd` | 移除 | 5 |
| `game/world/prop.gd`、`core/player/rat.gd` | 老鼠事件與技能換骨架 | 6 |
| `game/world/rig_showcase.gd`、`game/README.md`、`ART_SPEC.md`、規格書、`todo/todo.md`、報告 | 展示與文件 | 7 |

---

### Task 1：匯入工具支援 NPC，切祖母

**Files:**
- Modify: `tools/import_rig.py`（`TARGETS`、`CUT_CHARS`、新增 `FACES_RIGHT`、`cut_game_rig` 的 `faces`）、`tools/test_import_art.py`
- Create: `tools/rig_src/xmucane_joints.json`、`game/rig/xmucane_anims.json`、`game/tests/test_npc_rig.gd`
- Regenerate: `tools/rig_src/xmucane_rig.json`、`game/rig/xmucane_rig.json`、`game/art/chr/parts/xmucane/*`、`game/art/MANIFEST.md`

**Interfaces:**
- Produces: `import_rig.FACES_RIGHT: tuple[str, ...] = ("xmucane", "healer_man", "healer_woman", "rat")`；`cut_game_rig(c)["faces"]` 為 `1 if c in FACES_RIGHT else -1`；`TARGETS` 加 `{"xmucane": 165, "healer_man": 170, "healer_woman": 165, "rat": 40, "chimalmat": 340}`，`CUT_CHARS` 依 Task 進度加入（本 Task 只加 `xmucane`；Task 2～4 各自加）
- Produces（測試，供 Task 2～6）：`test_npc_rig.gd` 的 `const NPCS := {角色: [立繪 key, 高度]}`、`const ANIMS := {角色: {動作: loop}}`；helper 一律借 `res://tests/test_enemy_rig.gd`（`make_rig(c)`、`rig_json(c)`、`rig_mask`、`image_mask`、`near_share`、`iou`、`visible_bounds`、`anims_of(c)`、`bone_coverage`）

- [ ] **Step 1：Python 失敗測試**：`test_import_art.py` 新增 `NpcRigImportTest.test_npc_rig_faces_and_height`：對 `CUT_CHARS` 中屬於 NPC 的角色，`game/rig/{c}_rig.json` 的 `faces` ＝ `1 if c in FACES_RIGHT else -1`，`scale × content_height` ≈ `TARGETS[c]`（±1）；`crawler`、`flyer`、`sevenmacaw` 的 `faces` 仍是 −1
- [ ] **Step 2：Godot 失敗測試**：`test_npc_rig.gd`（`NPCS` 先只有 `"xmucane": ["chr_xmucane_reference", 165.0]`、`ANIMS` 先只有 `"xmucane": {"idle": true, "give": false}`）：
  - `test_npc_rig_assembles`：rig json 存在、`humanoid` false、`faces` 同 Global Constraints、`anims` ＝ `res://rig/{c}_anims.json`、每個分件的 sprite 有貼圖
  - `test_npc_rig_rest_matches_reference`：同 `test_enemy_rig_rest_matches_reference`（外框差 ≤ 2、`near_share` 雙向 1.0、IoU ≥ 0.9）
  - `test_npc_rest_centred_on_feet`：`visible_bounds` 中心 x 在 0±1、下緣 y 在 0±1
  - `test_npc_anims_present`：12 fps；動作集合恰為 `ANIMS[c]` 的鍵、`loop` 相符；骨頭都在 rig 裡
  - `test_npc_joints_covered_in_every_frame`：同 `test_macaw_joints_covered_in_every_frame`（靜止蓋得住的取樣點每一格都還蓋得住）
- [ ] **Step 3：跑** `python3 -m unittest tools/test_import_art.py -k npc` 與 `SELFTEST_ONLY=test_npc_rig godot --headless --path game -- --self-test` → 失敗（沒有 rig）
- [ ] **Step 4：`import_rig.py`**：加 `FACES_RIGHT`、`TARGETS` 的 5 個高度、`CUT_CHARS` 加 `"xmucane"`；`cut_game_rig` 的 `faces` 改依 `FACES_RIGHT`（註解改成「基準圖面向：FACES_RIGHT 面向右，其餘面向左」）
- [ ] **Step 5：`xmucane_joints.json`**：`src` 原始立繪；原點 `{"x_joint": "center", "sole_parts": [腳的分件]}`（`center` 關節放在內容外框中心 x，同 crawler）；骨頭表：`pelvis`（根，含裙子）、`torso`、`neck`／`head`（含髮辮）、近側 `upper_arm`、`forearm`、`hand`，`far` 複製三節手臂（z 在軀幹後面）；腿不切、腳掛在 `pelvis`。每次改關節後用檢查圖確認（靜止重組 vs 立繪、分件上色、遊戲尺寸 ×2；放 `assets-test/b2b2/check/`）
- [ ] **Step 6：`xmucane_anims.json`**：`idle` 循環約 1.0 秒（軀幹、頭微幅呼吸，手臂跟著）、`give` 單次約 0.75 秒（近側上臂、前臂往前伸到最遠再收回，最後一格回到靜止姿勢）；只用 rig 的骨頭名
- [ ] **Step 7：切與匯入**：`python3 tools/cut_rig.py xmucane`、`python3 tools/import_rig.py`、`python3 tools/import_art.py`、`godot --headless --path game --import`
- [ ] **Step 8：跑** Step 3 的兩個指令 → 通過；`python3 tools/import_rig.py --check`、`python3 tools/import_art.py --check` 結束碼 0；`git diff --stat` 確認既有 5 個角色的 rig json 與分件沒有變更；全套 `MIN_PASS=336 bash /tmp/wt/b2a_verify.sh` 通過
- [ ] **Step 9：Commit** `Cut Xmucane into a rig and let the importer face NPCs right (MV-SLICE-001b2b2)`

---

### Task 2：老夫婦

**Files:**
- Create: `tools/rig_src/healer_man_joints.json`、`healer_woman_joints.json`、`game/rig/healer_man_anims.json`、`healer_woman_anims.json`
- Modify: `tools/import_rig.py`（`CUT_CHARS`）、`game/tests/test_npc_rig.gd`（`NPCS`、`ANIMS`）
- Regenerate: 兩個角色的 rig json、分件、`MANIFEST.md`

**Interfaces:**
- Consumes: Task 1 的 `NPCS`／`ANIMS`、`FACES_RIGHT`
- Produces: `healer_man`、`healer_woman` 的 `idle`、`walk`

- [ ] **Step 1：測試**：`NPCS` 加 `"healer_man": ["chr_healer_man_reference", 170.0]`、`"healer_woman": ["chr_healer_woman_reference", 165.0]`；`ANIMS` 兩者 `{"idle": true, "walk": true}`
- [ ] **Step 2：跑** `SELFTEST_ONLY=test_npc_rig ...` → 新角色失敗（沒有 rig）
- [ ] **Step 3：joints json**：
  - 老伯：`pelvis`（根，含腰布）、`torso`（含披肩）、`neck`／`head`、近側 `thigh`、`shin`、`foot`、`upper_arm`、`forearm`、`hand`；`far` 複製腿與手臂
  - 老婆婆：`pelvis`（根，含長裙）、`torso`（含背上的陶罐）、`neck`／`head`（含長髮）、近側 `foot`（掛在 `pelvis`，裙下只露腳）、手臂三節；`far` 複製腳與手臂
  - 原點同 Task 1（`center`、腳）；兩者都是跨步立繪，靜止姿勢就是跨步
- [ ] **Step 4：動作**：`walk` 循環約 0.83 秒（10 格）：近側與遠側腿（腳）反向擺動、手臂反向擺、軀幹上下 1～2 px（`root` 位移）；`idle` 循環約 1.0 秒（呼吸）
- [ ] **Step 5：切與匯入**（同 Task 1 Step 7，角色換成 `healer_man healer_woman`）；`CUT_CHARS` 加兩者
- [ ] **Step 6：跑** `SELFTEST_ONLY=test_npc_rig` 通過、兩個 `--check` 0、全套通過（`MIN_PASS` 用 Task 1 的通過數）
- [ ] **Step 7：Commit** `Cut the healer couple into walking rigs (MV-SLICE-001b2b2)`

---

### Task 3：老鼠

**Files:**
- Create: `tools/rig_src/rat_joints.json`、`game/rig/rat_anims.json`
- Modify: `tools/import_rig.py`（`CUT_CHARS`）、`game/tests/test_npc_rig.gd`
- Regenerate: rat 的 rig json、分件、`MANIFEST.md`

**Interfaces:**
- Produces: `rat` 的 `idle`、`run`（Task 6 用）

- [ ] **Step 1：測試**：`NPCS` 加 `"rat": ["chr_rat_reference", 40.0]`、`ANIMS` 加 `"rat": {"idle": true, "run": true}`
- [ ] **Step 2：跑** → `rat` 失敗
- [ ] **Step 3：joints json**：`body`（根）、`head`、`tail`（可兩節 `tail`、`tail_tip`）、近側 `front_leg`、`hind_leg`，`far` 複製兩隻腳；原點 `center`、腳
- [ ] **Step 4：動作**：`run` 循環約 0.33 秒（4 格，前後腳交替、身體起伏、尾巴擺）；`idle` 循環約 1.0 秒（頭嗅聞、尾巴擺）
- [ ] **Step 5：切與匯入**；`CUT_CHARS` 加 `"rat"`
- [ ] **Step 6：跑** 通過。若關節覆蓋測試因 40 px 太小、取樣點落在背景而無法成立：照 `bone_coverage` 的 `k` 換算確認後，對 `rat` 只略過覆蓋項、在測試註解與帳本寫明（Ruling），靜止對齊與動作清單照測
- [ ] **Step 7：Commit** `Cut the rat into a running rig (MV-SLICE-001b2b2)`

---

### Task 4：Chimalmat

**Files:**
- Create: `tools/rig_src/chimalmat_joints.json`、`game/rig/chimalmat_anims.json`
- Modify: `tools/import_rig.py`（`CUT_CHARS`）、`game/tests/test_npc_rig.gd`
- Regenerate: chimalmat 的 rig json、分件、`MANIFEST.md`

- [ ] **Step 1：測試**：`NPCS` 加 `"chimalmat": ["chr_chimalmat_reference", 340.0]`、`ANIMS` 加 `"chimalmat": {"idle": true}`
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：joints json**：參考 `sevenmacaw_joints.json` 的鳥形骨頭表（`pelvis`、`tail`、`torso`、`neck`、`head`、`wing`（收著的翅膀一件，掛 `torso`）、近側與遠側的腿）；不需要 `layers`；原點 `feet` 關節、腳爪
- [ ] **Step 4：動作**：`idle` 循環約 1.5 秒（軀幹呼吸、頭微轉、尾羽微擺）
- [ ] **Step 5：切與匯入**；`CUT_CHARS` 加 `"chimalmat"`
- [ ] **Step 6：跑** 通過、兩個 `--check`、全套
- [ ] **Step 7：Commit** `Cut Chimalmat into an idle rig (MV-SLICE-001b2b2)`

---

### Task 5：共用 animator；祖母、老夫婦、Chimalmat 換上骨架

**Files:**
- Create: `game/world/npc_animator.gd`
- Modify: `game/world/room.gd:84`、`game/world/scenery_view.gd:248`、`game/core/boss/boss_fight.gd:113-118,244-251`、`game/tests/test_npc_rig.gd`
- Delete: `game/world/portrait.gd`（與 `.uid`），三處 `preload`

**Interfaces:**
- Consumes: Task 1～4 的 rig 與動作
- Produces（`res://world/npc_animator.gd`，Task 6 也用）：
  - `static func attach(node: Node2D, char_id: String) -> Node`：在 `node` 底下加 `RigView`（name `"Rig"`）與 animator（name `"NpcAnimator"`），預設 `play("idle")`；回傳 animator
  - `var rig: Node2D`、`var anim: String`、`var t: float`、`var facing := 1`
  - `func play(name: String, then := "") -> void`：`name == anim` 時不重來；否則 `t = 0`；非循環動作播完停最後一格，`then != ""` 就接 `play(then)`
  - `_process(delta)`：`t += delta`、`rig.scale.x = facing * rig.faces`、`rig.pose(anim, t)`

- [ ] **Step 1：失敗測試**（`test_npc_rig.gd`）：
  - `test_npc_animator_plays_then`：`attach` 祖母，`play("give", "idle")`，推進超過 `give` 長度 → `anim == "idle"`
  - `test_npc_give_not_restarted`：`play("give","idle")`、推進 0.2 秒、再 `play("give","idle")` → `t ≥ 0.2`
  - `test_npc_facing_flips_rig`：`facing = -1` 一幀後 `rig.scale.x == -rig.faces`
  - `test_grandma_rig_in_room_and_gives`：載入有 `npc` 的房間 → `Npc` 底下有 `NpcAnimator`、沒有 `Portrait`；角色站到祖母旁按互動 → `anim == "give"`
  - `test_npc_single_rig`：同一房間載入兩次（離開再進）→ `Npc` 底下剛好一個 `Rig`
  - `test_couple_walks_only_when_moving`：Boss 戰 `couple_following = true`，角色往右移動一幀 → 兩人 `anim == "walk"`、`facing == 1`；角色不動一幀 → `idle`；`palace.couple_static` → `idle`
  - `test_chimalmat_rig_in_palace`：宮殿場景的 `Chimalmat` 底下有 `NpcAnimator`、`anim == "idle"`
  - `test_no_portrait_left`：`ResourceLoader.exists("res://world/portrait.gd") == false`
- [ ] **Step 2：跑** `SELFTEST_ONLY=test_npc_rig` → 這些失敗
- [ ] **Step 3：實作 `npc_animator.gd`**（介面如上；單次動作長度用 `RigView.anims_at` 的 `length` 或最後一格 `t + 1/fps`，同 `rig_showcase.anim_length`）
- [ ] **Step 4：接上**：`room.gd` 祖母 `NpcAnimator.attach(npc, "xmucane")`，`_on_interact` 目標 `"npc"` 時 `play("give", "idle")`（兌換照舊）；`scenery_view.gd` `NpcAnimator.attach(chimalmat, "chimalmat")`（仍先加、畫在寶座後面）；`boss_fight.gd` 老夫婦 `NpcAnimator.attach(n, "healer_man"/"healer_woman")`，`_update_couple` 記上一幀的 x：`couple_following` 且 x 改變 → `play("walk")`、`facing` ＝ 移動方向，否則 `play("idle")`
- [ ] **Step 5：移除** `world/portrait.gd`（含 `.uid`）與三處 `const Portrait := preload(...)`；`grep -rn "portrait.gd\|Portrait\." game` 只剩註解或沒有
- [ ] **Step 6：跑** `SELFTEST_ONLY=test_npc_rig`、`SELFTEST_ONLY=test_ui`、`SELFTEST_ONLY=test_portraits` → 通過；全套通過、無 `SCRIPT ERROR`
- [ ] **Step 7：Commit** `Animate Xmucane, the healer couple and Chimalmat with rigs (MV-SLICE-001b2b2)`

---

### Task 6：老鼠事件與技能換上骨架

**Files:**
- Modify: `game/world/prop.gd`（kind `"rat"`）、`game/core/player/rat.gd`、`game/tests/test_npc_rig.gd`

**Interfaces:**
- Consumes: Task 5 的 `NpcAnimator.attach(node, "rat")`、`play`、`facing`

- [ ] **Step 1：失敗測試**：
  - `test_night_rat_runs_and_idles`：田地入夜事件開始後，角色在 300 px 外 → 老鼠 `anim == "idle"`；角色靠近 → `run`、`facing` ＝ 逃跑方向；網子罩住後 `idle`
  - `test_night_rat_keeps_colour`：夜晚時老鼠骨架與其祖先（到房間為止）的 `modulate` 都是白色
  - `test_rat_skill_uses_rig`：發動技能後的老鼠節點底下有 `NpcAnimator`、`anim == "run"`、`facing` ＝ 前進方向；沒有自訂 `_draw` 畫梯形（`rat.gd` 不再定義 `_draw`）
  - `test_rat_skill_rig_freed_on_bite`：有目標時跑到咬距 → 目標受傷與暈眩照舊、老鼠節點同幀釋放；之後兩幀沒有錯誤（`is_instance_valid` 為 false）
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：`prop.gd`**：kind `"rat"` 時 `_ready` 裡 `NpcAnimator.attach(self, "rat")`、不載入貼圖；`_process` 用原本的移動判斷：有移動 `play("run")`、`facing` ＝ 移動方向（原本 `_flip` 的反向），沒移動 `play("idle")`；其他 kind 不變
- [ ] **Step 4：`rat.gd`**：刪掉 `_draw` 與 `_process` 的 `queue_redraw`；`launch` 裡 `NpcAnimator.attach(self, "rat")`、`play("run")`；`_physics_process` 每次移動後 `facing` ＝ 移動方向；傷害、暈眩、咬到即 `queue_free` 不動
- [ ] **Step 5：跑** `SELFTEST_ONLY=test_npc_rig`、`SELFTEST_ONLY=test_rat`、`SELFTEST_ONLY=test_events`、`SELFTEST_ONLY=test_guidance` → 通過（既有的老鼠技能、抓老鼠、引導測試照舊）；全套通過
- [ ] **Step 6：Commit** `Run the rat rig in the night field and the burrow strike (MV-SLICE-001b2b2)`

---

### Task 7：展示影片與文件

**Files:**
- Modify: `game/world/rig_showcase.gd`（`CHARS`、`PLACES`、`playlist()`）、`game/README.md`（NPC 骨架段落、影片路徑）、`ART_SPEC.md` 第 6 節（實作狀態）、`todo/spec/MV-SLICE-001b2b2_NPC動作.md`（驗收打勾、Git Commit）、`todo/todo.md`
- Create: `report/MV-SLICE-001b2b2_NPC動作_{YYYY-MM-DD_HHmm}_執行報告.md`（時間戳先跑 `date`）

- [ ] **Step 1：展示**：`CHARS` 在 `sevenmacaw` 前加 `"xmucane", "healer_man", "healer_woman", "rat", "chimalmat"`；`PLACES` 各一個位置（遊戲大小；老鼠另加放大 3 倍並排）；`playlist()` 的「每個動作各 `ROUNDS` 輪」迴圈加這 5 個角色；`r.scale.x` 照既有寫法乘 `faces`（NPC 面向右時 `faces` 1）。（沒有專門測展示畫面的測試；以錄影與抽格驗證）
- [ ] **Step 2：`--shots`**：`godot --path game -- --shots /tmp/b2b2_shots`，每個畫面平均 ≤ 16.7 ms（第一個畫面暖機超過時重跑一次，兩次都寫進報告）
- [ ] **Step 3：錄影**：`godot --path game -- --rig-view --frames /tmp/rig_frames`、`ffmpeg -framerate 30 -i /tmp/rig_frames/%05d.jpg -c:v libx264 -pix_fmt yuv420p -crf 18 assets-test/b2b2_video/b2b2_rigs.mp4`；`ffprobe` 確認長度與格數、完整解碼無錯
- [ ] **Step 4：AI 抽格**：NPC 段落每 0.5 秒一格（含左下標籤）拼縮圖，看動作、接縫、面向；記進報告
- [ ] **Step 5：文件**：照 Files；規格書只勾 AI 有證據的項目，Brian 的兩項留空；`todo.md` 的 b2b2 維持 🔄、說明改成「實作完成，待 Brian 看影片與手把試玩」
- [ ] **Step 6：跑** 全套、兩個 `--check`、`python3 -m unittest tools/test_cut_rig.py tools/test_import_art.py` → 全部通過
- [ ] **Step 7：Commit** `Show the NPC rigs and document them (MV-SLICE-001b2b2)`
