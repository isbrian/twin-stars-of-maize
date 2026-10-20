# MV-SLICE-001c4c2 反光型的美術與動作 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把反光型的程式佔位換成從 MV-ASSET-019 基準圖切出的 8 根骨頭骨架與 7 個動作，光點掛在反光面寶石上、光束沿用 Boss 光束特效。

**Architecture:** 走 b2b1 的骨架管線（`*_joints.json` → `cut_rig.py` → `import_rig.py` → `game/rig/`），動作檔照 `crawler_anims.json` 的格式。`enemy_animator.gd` 為反光型多處理轉身（中途翻面）與擋下一震，每幀把光點位置寫回反光型（`glow_at`）；`beam_fx.gd` 改成也能讀反光型的光束。房間生成時反光型改掛骨架，佔位只留給沒有場景的測試房間。

**Tech Stack:** Godot 4.7.2 GDScript；Python 3＋Pillow＋numpy（`tools/cut_rig.py`、`import_rig.py`、`import_art.py`）；自測 `godot --headless --path game -- --self-test`（`bash /tmp/wt/st_only.sh ...`、全套 `bash /tmp/wt/step6.sh`）；截圖 `--shots`；動作影片 `godot --path game -- --rig-view --frames <資料夾>`＋ffmpeg。

**Spec:** [MV-SLICE-001c4c2_反光型美術與動作.md](MV-SLICE-001c4c2_反光型美術與動作.md)（Brian 2026-10-16 核准）

## Global Constraints

- 骨頭 8 根：`body`（根）、`head`、`arm`、`mirror`（父＝`arm`）、`thigh_near`、`shin_near`、`thigh_far`、`shin_far`；`faces` −1（基準圖面向左）；`humanoid` false；`anims` `res://rig/reflector_anims.json`。
- 遊戲高約 150（`import_rig.TARGETS["reflector"] = 150`），站姿底部在原點 y 0。
- 動作 12 fps、不內插：`idle`（循環）、`turn`、`telegraph`、`attack`、`recover`、`stagger`（不循環、停在最後一格）；擋下一震＝`spark_left > 0` 時反光面骨頭疊加往後轉 `THUD_DEG` 8 度。
- 轉身：`turn_left` 從 `reflector_turn_time`（0.8）倒數；`turn_left < 0.4` 起畫面翻向玩家那一側。
- 光點：反光面骨頭上的點 `glow`（反光面中央寶石）；蓄力時由暗到亮。
- 判定：骨架站姿的寬、高和 160×140 差超過 20% 才改 `reflector.gd` 的 `size`。
- 行為與數值不改；Seven Macaw 的光束外觀不變。
- 註解、文件繁體中文；commit 英文、結尾 `(MV-SLICE-001c4c2)`；全套自測基準 558 項。

## Review Focus

1. **轉身到一半玩家又繞回原本那側**：畫面翻面的方向要跟著玩家當下的位置，轉完時畫面朝向＝邏輯朝向（不會轉完再閃一下）→ Task 2 `test_turn_display_matches_final_facing`
2. **連續被擋好幾下**：反光面的一震不會累積偏轉（每次都從動作的角度加 8 度、0.15 秒後回到動作角度）→ Task 2 `test_thud_shake_no_drift`
3. **光束途中反光型被打倒**：光束特效跟著釋放，不留殘影、不報錯 → Task 2 `test_beam_fx_freed_with_reflector`
4. **沒有場景的測試房間**：反光型仍畫佔位與光點、c4c1 的測試全過 → Task 2 Step 4 跑 `test_c4c1`
5. **Seven Macaw 的光束**：改共用後外觀與判定不變 → Task 2 Step 4 跑 `test_fx`、`test_boss`

---

## 檔案結構

| 檔案 | 責任 | Task |
|---|---|---|
| `tools/rig_src/reflector_joints.json`（新） | 人工標的關節、骨頭表、多邊形、光點 | 1 |
| `tools/import_rig.py`、`tools/import_art.py` | 加反光型 | 1 |
| `game/rig/reflector_rig.json`、`reflector_anims.json`、`game/art/chr/parts/reflector/`（產出／新） | 骨架、動作、分件 | 1 |
| `game/tests/test_enemy_rig.gd` | `ENEMIES` 加反光型；`rigged_enemy` 認得反光型 | 1 |
| `game/world/enemy_animator.gd` | 轉身、擋下一震、光點寫回 | 2 |
| `game/core/enemies/reflector.gd` | `glow_at`；光點在佔位與骨架都畫；必要時改 `size` | 2 |
| `game/world/fx/beam_fx.gd` | 也能讀反光型 | 2 |
| `game/world/room.gd` | 反光型掛骨架與光束特效 | 2 |
| `game/tests/test_c4c2.gd`（新） | 本計畫的測試 | 1、2 |
| `game/world/rig_showcase.gd` | 展示加反光型 | 3 |
| 報告、規格、`game/README.md`、`todo/todo.md` | 文件 | 3 |

---

### Task 1：分件、骨架與動作檔

**Files:** Create `tools/rig_src/reflector_joints.json`、`game/rig/reflector_anims.json`、`game/tests/test_c4c2.gd`；Modify `tools/import_rig.py`、`tools/import_art.py`、`game/tests/test_enemy_rig.gd`；產出 `tools/rig_src/reflector_rig.json`、`game/rig/reflector_rig.json`、`game/art/chr/parts/reflector/*.png`（含 `.import`）、`assets-test/c4c_art/parts/`

**Interfaces:**
- Produces（`reflector_joints.json`，格式同 `crawler_joints.json`）：`src` `c4c_art/enm_falselight_reflector_reference.png`；`bones` 為 Global Constraints 的 8 根（`[骨頭, 父, 起點關節, 終點關節, 半徑, z]`；`mirror` 的 z 最高、`thigh_far`／`shin_far` 最低）；`polys` 至少圈出 `mirror`、`arm`（反光面和手臂不分給身體）；`points` 有 `glow`（`{"bone": "mirror", "at": 反光面中央寶石的來源座標}`）；`origin` 以兩腳腳底為準。
- Produces（`import_rig.py`）：`TARGETS["reflector"] = 150`、`CUT_CHARS` 加 `"reflector"`；`import_art.py` 加基準圖縮圖一列（`fit_height` 150、`key: True`，同爬行型）。
- Produces（`reflector_anims.json`）：`fps` 12；`idle`（`loop` true）、`turn`、`telegraph`、`attack`、`recover`、`stagger`（`loop` false）；姿勢照規格「動作」表；`turn` 長約 0.8 秒（前半放低反光面、身體後縮，後半抬回）。
- 指令：`python3 tools/cut_rig.py reflector --src assets-test --out assets-test/c4c_art/parts` → `python3 tools/import_rig.py` → `python3 tools/import_art.py` → `godot --headless --path game --import`。

- [ ] **Step 1：失敗測試**
  - `test_enemy_rig.gd`：`ENEMIES` 加 `"reflector": ["enm_falselight_reflector_reference", 150.0]`；`rigged_enemy` 依角色建 Crawler／Flyer／Reflector（反光型站在地面 `Vector2.ZERO`）。既有的 `test_enemy_rig_assembles`、`test_enemy_rig_rest_matches_reference`、`test_enemy_rest_centred_on_origin`、`test_enemy_anims_present`、`test_enemy_state_to_anim`、`test_enemy_joints_covered_in_every_frame`、`test_enemy_rig_faces_and_tints`、`test_enemy_rig_freed_with_enemy` 自動涵蓋反光型
  - `test_c4c2.gd` `test_reflector_rig_bones`：`reflector_rig.json` 的骨頭正好是那 8 根、`mirror` 的父是 `arm`；`points` 有 `glow` 掛在 `mirror`
  - `test_c4c2.gd` `test_reflector_turn_anim`：`reflector_anims.json` 有 `turn`（不循環、最後一格時間 0.6～0.8）
- [ ] **Step 2：跑** `bash /tmp/wt/st_only.sh test_enemy_rig test_c4c2` → 失敗（rig 不存在）
- [ ] **Step 3：標關節與切件**：看基準圖（縮圖＋裁切放大）標關節與多邊形 → 切件 → 抽看分件（反光面、手臂是否完整、接縫）→ 調 `polys`／`cap` 直到靜止姿勢和基準圖疊合（`test_enemy_rig_rest_matches_reference` 的門檻）
- [ ] **Step 4：寫動作檔**，跑 `test_enemy_joints_covered_in_every_frame`，接縫露縫就調角度
- [ ] **Step 5：跑** `bash /tmp/wt/st_only.sh test_enemy_rig test_c4c2 test_rig` 全過；`python3 tools/import_rig.py --check`、`python3 tools/import_art.py --check` 結束碼 0
- [ ] **Step 6：Commit** `Cut the reflector into an eight-bone rig and write its animations (MV-SLICE-001c4c2)`

### Task 2：動作接上遊戲

**Files:** Modify `game/world/enemy_animator.gd`、`game/core/enemies/reflector.gd`、`game/world/fx/beam_fx.gd`、`game/world/room.gd`、`game/tests/test_c4c2.gd`

**Interfaces:**
- Consumes：Task 1 的骨架（`rig.point("glow")`、`rig.bone("mirror")`、動作 `turn`）
- Produces（`reflector.gd`）：`var glow_at := Vector2.ZERO`（本地座標；佔位時＝反光板中心，骨架時由 animator 寫入）；`_draw` 在 TELEGRAPH 時於 `glow_at` 畫由暗到亮的光點（佔位與骨架都畫；佔位的其他部分照舊只在 `portrait_drawn` false 時畫）。
- Produces（`enemy_animator.gd`）：
  - `const THUD_DEG := 8.0`
  - `func display_facing(e) -> int`：反光型 `turn_left > 0` 且 `< reflector_turn_time / 2` 時回玩家那一側（`sign(target.x - x)`，target 為 null 時回 `-facing`）；其他情況回 `facing`
  - `choose(e)`：反光型 `turn_left > 0` → `["turn", reflector_turn_time - turn_left]`；其餘照舊
  - `_apply()`：`rig.scale.x` 用 `display_facing`；擺姿勢後若 `spark_left > 0`，`mirror` 骨頭在動作角度上再往後轉 `THUD_DEG`；反光型時 `e.glow_at = rig 座標轉成敵人本地座標的 rig.point("glow")`
- Produces（`beam_fx.gd`）：`attach(b)` 也接受反光型；內部用 `_charging() -> bool`、`_firing() -> bool`、`core_rect() -> Rect2`、`_light() -> Vector2`、`_flow_t() -> float` 分兩種來源：Seven Macaw 照舊讀 `boss.move`；反光型讀 `state == TELEGRAPH`／`ATTACK`、`beam_rect`、`glow_at`、`state_time`。
- Produces（`room.gd`）：反光型也 `EnemyAnimator.attach(n, "reflector")`，並 `BeamFx.attach(n)`（有場景時）。
- 判定：量 `rig` 靜止姿勢的可見範圍（同 `test_enemy_rig.visible_bounds`）；寬或高和 160×140 差超過 20% 才改 `size`（並記 Ruling、重跑 `test_c4c1`）。

- [ ] **Step 1：失敗測試**（`test_c4c2.gd`，用 `test_enemy_rig.gd` 的做法建有骨架的反光型）：
  - `test_reflector_anim_states`：前搖、光束、收招、硬直、待機各播對應動作；`turn_left = 0.5` → `choose` 回 `turn`、時間 0.3
  - `test_turn_display_matches_final_facing`（Review Focus 1）：面向右、玩家在左 → 轉身；`turn_left` 0.5 時畫面仍朝右、0.3 時朝左；轉身途中把玩家移回右邊 → 0.3 時畫面朝右；轉完 `facing` 和最後一幀的畫面朝向一致
  - `test_thud_shake_no_drift`（Review Focus 2）：待機時記下 `mirror` 角度；連續 5 次 `spark_left = 0.15`（每次間隔 0.05 秒）→ 一震時角度＝動作角度 ± 8 度（依朝向）；最後一次 0.2 秒後角度回到動作角度（±0.5 度）
  - `test_glow_follows_mirror`：前搖時 `e.glow_at` 等於 `rig.point("glow")` 轉成本地座標（±1），且前搖中（反光面舉起）比待機時高
  - `test_beam_fx_on_reflector`：反光型有 `BeamFx` 子節點；前搖時 `aim_line()` 兩端的 x 範圍等於 `beam_rect`；光束時 `core_rect() == beam_rect`；待機時兩者為空
  - `test_beam_fx_freed_with_reflector`（Review Focus 3）：光束中 `e.kill()` → 下一幀沒有殘留的 BeamFx、沒有錯誤
  - `test_reflector_size_vs_rig`：骨架靜止範圍和 `e.size` 的寬、高差都 ≤ 20%
  - `test_room_reflector_has_rig`：森林 3 生成的反光型有 `Rig`、`EnemyAnimator`、`BeamFx`，`portrait_drawn` true；`_test_b`（沒有 theme）生成的反光型 `portrait_drawn` false
- [ ] **Step 2：跑** `bash /tmp/wt/st_only.sh test_c4c2` → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `bash /tmp/wt/st_only.sh test_c4c2 test_c4c1 test_enemy_rig test_fx test_boss test_rooms test_c4a` 全過
- [ ] **Step 5：Commit** `Drive the reflector rig from its states and share the boss beam effect (MV-SLICE-001c4c2)`

### Task 3：展示影片、截圖與文件

**Files:** Modify `game/world/rig_showcase.gd`（`CHARS` 加 `reflector`，依序播全部動作：待機、轉身、前搖、光束、收招、硬直、擋下一震）、`game/README.md`、`todo/spec/MV-SLICE-001c4c2_反光型美術與動作.md`（驗收、Git Commit）、`todo/todo.md`；Create `report/MV-SLICE-001c4c2_反光型美術與動作_{YYYY-MM-DD_HHmm}_執行報告.md`（時間戳先跑 `date`）

- [ ] **Step 1：展示**：`rig_showcase.gd` 加反光型；跑 `bash /tmp/wt/st_only.sh test_rig test_enemy_rig` 全過（`test_rig.gd` 涵蓋 `rig_showcase`）
- [ ] **Step 2：影片**：`godot --path game -- --rig-view --frames /tmp/wt/c4c2_frames` → ffmpeg 合成 `assets-test/c4c2_video/reflector_rig.mp4`（彩色、灰階各一）；AI 抽格看接縫、光點、轉身翻面時機
- [ ] **Step 3：截圖**：`--shots` 全部存 `assets-test/c4c2_shots/`；森林 3、5、6 縮圖，AI 檢查骨架位置、朝向、和其他敵人不重疊；幀時間 ≤ 16.7 ms
- [ ] **Step 4：文件**：照 Files；規格書只勾 AI 有證據的項目；`todo.md` c4c2 維持 🔄、改「實作完成，待 Brian 看影片與手把試玩」
- [ ] **Step 5：跑** `bash /tmp/wt/step6.sh`（558＋新增、`--check`、unittest）
- [ ] **Step 6：Commit** `Show the reflector in the rig viewer and document its animations (MV-SLICE-001c4c2)`
