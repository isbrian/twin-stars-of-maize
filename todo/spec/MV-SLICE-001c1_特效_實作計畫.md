# MV-SLICE-001c1 Boss 特效正式化：實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Seven Macaw 的光源、假光閃耀（聚光＋白茫）、反光柱、光束、宮殿假光變暗、身上光點與熄滅，從灰盒換成程式繪製的正式特效。

**Architecture:** 新增 `world/fx/`：共用的光暈貼圖與加亮材質（`fx_kit.gd`）＋每個特效一支外觀腳本，讀 `core/` 節點的狀態來畫；core 節點加 `fx_drawn` 旗標關灰盒；只有遊戲模式（`boss_fight` 的 `gs != null`）掛特效。另加 `--fx-view` 展示畫面錄影。

**Tech Stack:** Godot 4.7.2 GDScript（`GradientTexture2D`、`CanvasItemMaterial` 加亮混合；不用 shader）、Python 3（切件工具加光點）、ffmpeg。

**Spec:** [todo/spec/MV-SLICE-001c1_特效.md](MV-SLICE-001c1_特效.md)

## Global Constraints

- 不改任何玩法數值、時序、判定：`flash_telegraph`、`whiteout_in`／`whiteout_hold`／`whiteout_out`、`Whiteout.MAX_ALPHA` 0.9、`pillar_warn`、`pillar_active`、`Pillar.SIZE` 120×960、`beam_charge`、`beam_active`、`beam_wobble`、`beam_band`、`Scenery.DARKNESS` [1.0, 0.75, 0.5, 0.3]
- 只在遊戲模式掛特效並設 `fx_drawn = true`；原型模式（`gs == null`）照舊畫灰盒
- 顏色：暖白（中心約 `#fffef4`）＋金（約 `#ffe2a0`）；不用紅色；假光閃耀前搖不畫圓形或鋸齒
- 光柱實心寬＝判定寬 120 px、柔光每邊 ≤ 8 px；光束實心矩形＝判定矩形
- 白茫：每個像素、每個時刻的白度 ≥ `Whiteout.alpha_at(s, tn)`；維持段 0.9
- 宮殿假光 3 組；`lights_removed` 0～3 對應亮著 3、2、1、0 組；淡出 0.8 秒；篝火不受影響
- 身上光點約 10 個（`glint_1`…`glint_N`），掛翅膀、軀幹、尾羽骨頭，不在頭上；`extinguish(seconds)` 依離胸口距離由遠到近熄
- 不開美術工單、不用 shader；`--shots` 每個畫面平均 ≤ 16.7 ms
- `assets-test/` 不進版控（檢查圖放 `assets-test/c1/check/`）；`import_rig.py --check`、`import_art.py --check` 要重現同樣位元組
- 註解、文件繁體中文；commit 訊息英文、結尾 `(MV-SLICE-001c1)`，最後一行 `Co-Authored-By: Claude <noreply@anthropic.com>`
- 全套驗證：`MIN_PASS=<目前通過數> bash /tmp/wt/b2a_verify.sh`（起點 357）；多步驟驗證寫成 `.sh` 再跑

## Review Focus

1. **重試或讀檔直接進第 2、3 段**：宮殿假光直接是該段的組數、不播淡出；身上光點照樣在 → Task 4 `test_palace_lights_jump_to_phase`
2. **閃光時 Boss 在畫面外**（樹冠在畫面頂端以上）：白茫照樣蓋滿全畫面，不會因擴散起點在畫面外而變淡 → Task 3 `test_whiteout_source_offscreen`
3. **Boss 面向左右**：光束特效與蓄力虛線要跟著面向翻到正確的一側 → Task 2 `test_beam_fx_matches_hitbox_both_facings`
4. **換成受傷的頭**：光源光暈仍在新頭的光點上（光暈是光源節點的子節點） → Task 1 `test_light_fx_follows_light_after_head_swap`
5. **段落結束清掉光柱**（`boss_fight` 釋放 Pillar）：光柱特效跟著消失、不殘留 → Task 2 `test_pillar_fx_freed_with_pillar`

---

## 檔案結構

| 檔案 | 責任 | Task |
|---|---|---|
| `game/world/fx/fx_kit.gd` | 共用：放射狀光暈貼圖（快取）、加亮混合材質、顏色常數 | 1 |
| `game/world/fx/light_fx.gd` | 光源三種狀態的光暈 | 1 |
| `game/world/fx/pillar_fx.gd` | 光柱落點與光柱 | 2 |
| `game/world/fx/beam_fx.gd` | 光束蓄力虛線、連結亮線、光束 | 2 |
| `game/world/fx/flash_fx.gd`、`whiteout_fx.gd` | 假光閃耀前搖光點與身上光暈；擴散式白茫 | 3 |
| `game/world/fx/palace_lights.gd` | 宮殿假光 3 組 | 4 |
| `game/world/fx/macaw_glints.gd` | 身上光點、光暈、`extinguish` | 5 |
| `game/world/fx_showcase.gd`、`launch_args.gd`、`main.gd` | `--fx-view` | 6 |
| `game/core/boss/light_source.gd`、`pillar.gd`、`moves/beam.gd`、`seven_macaw.gd`、`ui/whiteout.gd` | `fx_drawn` 旗標；`beam.gd` 加 `area()` | 1～3 |
| `game/core/boss/boss_fight.gd` | 遊戲模式掛特效 | 1～5 |
| `game/world/scenery_view.gd` | 宮殿假光節點、`set_darkness` 呼叫假光 | 4 |
| `tools/rig_src/sevenmacaw_joints.json` 與重新產生的 rig json | `glint_*` 光點 | 5 |
| `game/tests/test_fx.gd` | 全部新測試 | 1～6 |

---

### Task 1：特效基底與光源

**Files:**
- Create: `game/world/fx/fx_kit.gd`、`game/world/fx/light_fx.gd`、`game/tests/test_fx.gd`
- Modify: `game/core/boss/light_source.gd`（`fx_drawn`）、`game/core/boss/boss_fight.gd`（遊戲模式掛 LightFx）

**Interfaces:**
- Produces（`res://world/fx/fx_kit.gd`）：`static func glow_texture(size: int) -> Texture2D`（放射狀：中心 `CORE`、30% `GOLD` 半透明、70% 透明；依 size 快取）、`static func add_material() -> CanvasItemMaterial`（`BLEND_MODE_ADD`，共用一份）、`const CORE := Color("#fffef4")`、`const GOLD := Color("#ffe2a0")`
- Produces（`res://world/fx/light_fx.gd`，`extends Node2D`）：`static func attach(light: Node2D) -> Node2D`（加成 `light` 的子節點，name `"LightFx"`，設 `light.fx_drawn = true`）；畫面：OFF＝暗色小點、GLOW＝0.5 秒週期呼吸的小光暈（直徑約 46 px）、BRIGHT＝大光暈（約 190 px）＋柔和擴散光環（約 0.9 秒一圈）
- Produces（core）：`light_source.gd` 的 `var fx_drawn := false`，為 true 時 `_draw` 不畫
- Produces（測試，供後續 Task）：`test_fx.gd` 的 `func fx_fight() -> Array`（同 `test_npc_rig.boss_fight`，回傳 `[f, gs]`）、`func proto_fight() -> Node`（`gs == null` 的 BossFight）、`func set_move(b, mv: String, step: int, t := 0.0) -> void`（同 `test_macaw_rig.set_move`）

- [ ] **Step 1：失敗測試**（`test_fx.gd`）：
  - `test_light_fx_in_game_mode`：遊戲模式 `f.boss.light.get_node_or_null("LightFx") != null` 且 `f.boss.light.fx_drawn`；原型模式沒有 LightFx、`fx_drawn == false`
  - `test_light_fx_follows_light_after_head_swap`：`f.boss.set_appearance(2)`（受傷頭）、等 2 幀 → LightFx 的 `global_position` ＝ `f.boss.light.global_position`（±0.5）
  - `test_light_glow_readable_in_darkest`：`fx_kit.glow_texture(64)` 中心像素灰階亮度 − （宮殿背景貼圖的平均灰階亮度 × 0.3）≥ 0.4（宮殿背景貼圖路徑照 `scenery_view.gd` 的宮殿牆）
- [ ] **Step 2：跑** `SELFTEST_ONLY=test_fx godot --headless --path game -- --self-test` → 失敗（沒有 fx_kit／LightFx）
- [ ] **Step 3：實作** `fx_kit.gd`、`light_fx.gd`（`_process` 累加時間、`queue_redraw`；`_draw` 用 `draw_texture_rect` 畫光暈，材質用 `add_material()`）；`light_source.gd` 加 `fx_drawn`；`boss_fight.gd` 的遊戲模式區塊在 `MacawAnimator.attach(boss)` 後 `LightFx.attach(boss.light)`
- [ ] **Step 4：跑** `SELFTEST_ONLY=test_fx` 通過；`SELFTEST_ONLY=test_portraits`、`test_boss` 通過；全套 `MIN_PASS=357 bash /tmp/wt/b2a_verify.sh`
- [ ] **Step 5：Commit** `Glow the Boss's light sources in soft light (MV-SLICE-001c1)`

---

### Task 2：反光柱與光束

**Files:**
- Create: `game/world/fx/pillar_fx.gd`、`game/world/fx/beam_fx.gd`
- Modify: `game/core/boss/pillar.gd`（`fx_drawn`）、`game/core/boss/moves/beam.gd`（`area()`；`fx_drawn` 時 `draw` 的 FIRE 不畫，WOBBLE 照畫）、`game/core/boss/seven_macaw.gd`（`var fx_drawn := false`）、`game/core/boss/boss_fight.gd`（遊戲模式：`world.child_entered_tree` 遇到 Pillar 就 `PillarFx.attach`；`BeamFx.attach(boss)`；`boss.fx_drawn = true`）、`game/tests/test_fx.gd`

**Interfaces:**
- Consumes: Task 1 的 `fx_kit`、`fx_fight()`
- Produces: `beam.gd` 的 `func area() -> Rect2`（＝`_rect`，Boss 本地座標）；`PillarFx.attach(pillar: Node2D) -> Node2D`（子節點 `"PillarFx"`，設 `pillar.fx_drawn = true`）；`PillarFx.core_rect() -> Rect2`（實心部分，pillar 本地座標）；`BeamFx.attach(boss: Node2D) -> Node2D`（子節點 `"BeamFx"`）；`BeamFx.core_rect() -> Rect2`、`BeamFx.aim_line() -> PackedVector2Array`（兩端點，Boss 本地座標）

- [ ] **Step 1：失敗測試**：
  - `test_pillar_fx_matches_hitbox`：遊戲模式下手動 `Pillar.new()` 加到 world、等一幀 → 有 PillarFx；`core_rect().size.x == Pillar.SIZE.x`、`core_rect()` 的 x 範圍＝判定 x 範圍；柔光每邊寬 ≤ 8
  - `test_pillar_fx_freed_with_pillar`：釋放 Pillar 後兩幀，world 裡沒有 PillarFx
  - `test_beam_fx_matches_hitbox_both_facings`：`facing` 為 1 與 −1 各一次，`set_move` 成 beam 並 `begin()` → `BeamFx.core_rect() == move.area()`；`aim_line()` 兩端點的 y＝`area()` 中線、x 範圍＝`area()` x 範圍
  - `test_beam_gray_box_off_in_game_mode`：遊戲模式 `boss.fx_drawn`；原型模式 `false`
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**：PillarFx 依 `pillar.t` 畫落點（`t < pillar_warn`：光斑寬＝柱寬＋虛線）或光柱（中心白、兩側金、往下流動、外圍柔光 ≤ 8 px）；BeamFx 讀 `boss.move`（是 beam 時）：CHARGE 畫地面虛線，FIRE 畫眼睛到光束起點的連結亮線＋光束（中心白、上下金邊、往前流動）
- [ ] **Step 4：跑** `SELFTEST_ONLY=test_fx`、`test_boss` 通過；全套
- [ ] **Step 5：Commit** `Drop soft light pillars and fire a soft eye beam (MV-SLICE-001c1)`

---

### Task 3：假光閃耀（聚光與白茫）

**Files:**
- Create: `game/world/fx/flash_fx.gd`、`game/world/fx/whiteout_fx.gd`
- Modify: `game/ui/whiteout.gd`（`fx_drawn`）、`game/core/boss/boss_fight.gd`（遊戲模式：`FlashFx.attach(boss)`；`WhiteoutFx` 加在 `whiteout` 同一層、`whiteout.fx_drawn = true`）、`game/tests/test_fx.gd`

**Interfaces:**
- Produces: `FlashFx.attach(boss) -> Node2D`；`FlashFx.strength() -> float`（目前的聚光強度 0～1：`boss.move` 是 false_flash 且在 TELEGRAPH 時＝`move.t / flash_telegraph`，否則 0）
- Produces: `whiteout_fx.gd`（`extends Control`）：`static func alpha_at_point(s: float, p: Vector2, src: Vector2, tn) -> float` ＝ `max(Whiteout.alpha_at(s, tn), bloom(s, p, src))`；`bloom` 只在淡入段讓 `src` 附近更白；`src` 是 Boss 的畫面座標（`boss.get_global_transform_with_canvas().origin`，可在畫面外）

- [ ] **Step 1：失敗測試**：
  - `test_whiteout_never_clearer`：對 `s` 取淡入、維持、淡出各 3 個時刻、畫面 9 個取樣點，`alpha_at_point ≥ Whiteout.alpha_at`；維持段＝0.9
  - `test_whiteout_source_offscreen`：`src = Vector2(960, -600)`（畫面外），淡入中途全畫面 9 點都 ≥ `alpha_at`
  - `test_flash_telegraph_strength_rises`：遊戲模式 `set_move(boss, "false_flash", TELEGRAPH, t)`，t＝0.1／0.5／0.9 秒 → `strength()` 嚴格遞增、介於 0～1
  - `test_whiteout_gray_box_off_in_game_mode`：遊戲模式 `whiteout.fx_drawn` 且有 WhiteoutFx；原型模式沒有
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**：FlashFx 依 `strength()` 畫 8～12 個往 Boss 收攏的小光點（位置由種子固定的角度＋隨強度縮短的半徑）與身上光暈（大小、透明度隨強度）；不畫圓形招架訊號或鋸齒。WhiteoutFx 每幀用 `alpha_at_point` 畫：先畫全畫面 `alpha_at(s)` 的暖白，再在淡入段以 `src` 為中心加一層光暈
- [ ] **Step 4：跑** `SELFTEST_ONLY=test_fx`、`test_boss`（白茫相關）通過；全套
- [ ] **Step 5：Commit** `Gather false light on Seven Macaw and burst the whiteout from him (MV-SLICE-001c1)`

---

### Task 4：宮殿假光逐段熄滅

**Files:**
- Create: `game/world/fx/palace_lights.gd`
- Modify: `game/world/scenery_view.gd`（宮殿段加 PalaceLights；`set_darkness` 同時 `palace_lights.set_level(lights_removed, animate)`）、`game/core/boss/boss_fight.gd`（`_apply_lights` 傳是否要淡出：段落進行中拔掉光源＝淡出，`start_at`／讀檔＝直接）、`game/tests/test_fx.gd`

**Interfaces:**
- Produces: `palace_lights.gd`（`extends Node2D`）：`const GROUPS: Array`（3 組，每組 2～3 個宮殿座標的光暈位置：牆上金飾、寶座；實作時對照宮殿截圖定）、`func set_level(removed: int, animate: bool) -> void`、`func lit_groups() -> int`（目前亮著的組數；淡出中的算熄了）
- Produces: `scenery_view.set_darkness(lights_removed: int, animate := false)`（多一個參數，預設 false；既有呼叫不變）

- [ ] **Step 1：失敗測試**：
  - `test_palace_lights_follow_lights_removed`：遊戲模式，`lights_removed` 0～3 依序 `_apply_lights` → `lit_groups()` 為 3、2、1、0
  - `test_palace_lights_jump_to_phase`：`start_at(3)` 後立刻 `lit_groups() == 1`、沒有淡出中的組（直接對應）
  - `test_palace_fire_untouched`：`lights_removed = 3` 後，宮殿篝火（`rests` 的節點）的 `modulate` 仍是 `Color.WHITE`
  - 既有的 `test_boss_darkness_follows_lights`、`test_fight_background_darkens_per_light` 照過（暗度數值不變）
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**：每盞假光用 `fx_kit.glow_texture` 畫（加亮）、各自輕微閃爍；熄掉的組 0.8 秒淡出；`set_level` 在 `animate == false` 時直接設定
- [ ] **Step 4：跑** `SELFTEST_ONLY=test_fx`、`test_scenery`、`test_ui` 通過；全套
- [ ] **Step 5：Commit** `Put out the palace's false lights one group per light source (MV-SLICE-001c1)`

---

### Task 5：身上光點與熄滅

**Files:**
- Create: `game/world/fx/macaw_glints.gd`
- Modify: `tools/rig_src/sevenmacaw_joints.json`（`points` 加 `glint_1`…`glint_N`）；重新產生 `tools/rig_src/sevenmacaw_rig.json`、`game/rig/sevenmacaw_rig.json`；`game/core/boss/boss_fight.gd`（遊戲模式 `MacawGlints.attach(boss)`）、`game/tests/test_fx.gd`

**Interfaces:**
- Consumes: `rig_view.point(name) -> Vector2`（骨架座標）；`MacawAnimator` 掛的 `boss.get_node("Rig")`
- Produces: `MacawGlints.attach(boss: Node2D) -> Node2D`（子節點 `"MacawGlints"`）；`MacawGlints.NAMES: Array`（`glint_*` 名稱）；`func lit_count() -> int`；`func aura() -> float`（光暈強度 0～1）；`func extinguish(seconds: float) -> void`；`signal extinguished`

- [ ] **Step 1：失敗測試**：
  - `test_glints_follow_rig`：遊戲模式有 MacawGlints、`lit_count() == NAMES.size()`（≥ 8）；Boss 擺 `fly` 第 0 格後，每個光點畫面位置＝`rig.transform * rig.point(name)`（±1）
  - `test_glints_survive_head_swap`：`set_appearance(1..3)` 後 `lit_count()` 不變、沒有光點掛在 `head` 骨頭（讀 rig json 的 `points`）
  - `test_extinguish_far_to_near`：`extinguish(1.0)`，取樣 0.2／0.5／0.8 秒：亮著的數量遞減，且先熄的光點離胸口（`torso` 骨頭起點）都比後熄的遠；1.0 秒後 `lit_count() == 0`、`aura() == 0`、發出 `extinguished`
  - `test_glints_not_on_head_and_smaller_than_light`：光點貼圖直徑 < 光源微亮光暈直徑
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：joints json 加光點**：約 10 個 `glint_i`（翅膀金飾、胸前寶石、尾羽金飾；`{"bone": …, "at": [x, y]}` 來源座標），`python3 tools/cut_rig.py sevenmacaw`、`python3 tools/import_rig.py`、`python3 tools/import_art.py`（分件 PNG 應不變）；檢查圖：光點疊在靜止重組上（`assets-test/c1/check/`）
- [ ] **Step 4：實作** `macaw_glints.gd`：每幀把光點放到 `rig.transform * rig.point(name)`、各自錯開閃爍；全身淡淡光暈；`extinguish` 依距離排序、平均分配到 `seconds` 內逐一熄，光暈線性淡到 0，最後把骨架 `modulate` 調到約 0.5
- [ ] **Step 5：跑** `SELFTEST_ONLY=test_fx`、`test_macaw_rig`、`test_portraits` 通過；`import_rig.py --check`、`import_art.py --check` 0；全套
- [ ] **Step 6：Commit** `Sparkle Seven Macaw's jewelry and let it go out one by one (MV-SLICE-001c1)`

---

### Task 6：`--fx-view` 展示、影片與文件

**Files:**
- Create: `game/world/fx_showcase.gd`、`report/MV-SLICE-001c1_特效_{YYYY-MM-DD_HHmm}_執行報告.md`（時間戳先跑 `date`）
- Modify: `game/launch_args.gd`（`--fx-view` → mode `"fx_view"`）、`game/main.gd`、`game/README.md`（特效段落、影片路徑）、`ART_SPEC.md`（第 5 節之後加 Boss 特效的實作狀態）、`todo/spec/MV-SLICE-001c1_特效.md`（驗收打勾、Git Commit）、`todo/todo.md`、`game/tests/test_fx.gd`

**Interfaces:**
- Consumes: Task 1～5 的所有 `attach`、`extinguish`、`set_level`
- Produces: `fx_showcase.gd` 的 `static func playlist() -> Array`（每項 `{"name": String, "secs": float}`）；名稱依序：`light_off`、`light_glow`、`light_bright`、`flash`、`pillars`、`beam`、`palace_dark`、`glints`、`extinguish`

- [ ] **Step 1：失敗測試**：`test_fx_showcase_playlist`：`playlist()` 名稱恰為上列 9 個、每項 `secs > 0`；`LaunchArgs` 解析 `--fx-view` 為 `"fx_view"`
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**：仿 `rig_showcase.gd`（1920×1080 SubViewport、`--frames` 逐格輸出、彩色一輪＋灰階一輪、下方標籤）；宮殿與 nance 場景圖層＋Seven Macaw 骨架＋各特效，直接設定狀態播放（不跑 Boss AI）
- [ ] **Step 4：跑** 測試通過；`--shots`（每畫面 ≤ 16.7 ms，第一個畫面暖機超過就重跑一次）；錄影 `godot --path game -- --fx-view --frames /tmp/fx_frames`、`ffmpeg … assets-test/c1_video/c1_fx.mp4`，`ffprobe` 與完整解碼確認；AI 每 0.5 秒抽格
- [ ] **Step 5：文件**：照 Files；規格書只勾 AI 有證據的項目；`todo.md` 維持 🔄、說明改「實作完成，待 Brian 看影片與手把試玩」
- [ ] **Step 6：跑** 全套、兩個 `--check`、`python3 -m unittest tools/test_cut_rig.py tools/test_import_art.py` → 全部通過
- [ ] **Step 7：Commit** `Show the Boss effects and document them (MV-SLICE-001c1)`
