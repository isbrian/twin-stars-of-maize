# MV-TUNE-003 Seven Macaw 翅膀換新素材：實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 MV-ASSET-016 的身體圖（W-01）與單獨翅膀圖（W-02）重切 Seven Macaw，讓近側翅膀能上抬約 30° 明顯拍翅。

**Architecture:** `tools/cut_rig.py` 加 `layers`（某幾根骨頭改從另一張圖切，先兩點對位貼回主圖座標）與 `erase`（主圖指定多邊形當背景）；Seven Macaw 的 joints json 改用兩張新圖，切件輸出的合成圖匯入遊戲當靜止姿勢的比對基準；動作檔加大翅膀上抬角度。

**Tech Stack:** Python 3（numpy、Pillow）、Godot 4.7.2 GDScript、ffmpeg。

**Spec:** [todo/spec/MV-TUNE-003_SevenMacaw翅膀換新素材.md](MV-TUNE-003_SevenMacaw翅膀換新素材.md)

## Global Constraints

- 素材：W-01 `assets-test/b2b1_wing/enm_sevenmacaw_body_nowing.png`、W-02 `assets-test/b2b1_wing/enm_sevenmacaw_wing_near.png`（都是 1536×1024 洋紅底；W-02 對位起始值縮放 0.72、平移 (272, 0)）
- 沒有 `layers`／`erase` 的 joints json，輸出逐位元組不變（爬行型、飛行型；雙胞胎不經過 `cut_rig.py`）
- 頭、三張受傷頭、光點、原點、招式數值不變；判定框 `MacawAnimator.BODY`（目前 `Rect2(-153, -317, 271, 317)`）只在骨架外框差 > 2 px 時照骨架更新
- 角度慣例：負值往上抬；近側 `wing_arm` 上抬目標約 −30°（拍翅、張翅的動作），待機類 ≥ −8°；實際上限以肩膀不露洞為準
- 遠側翅膀照舊複製近側、明度 ×0.72、偏移 `[0, 0]`、和近側反向擺動
- 約 12 fps、不內插；不用 AnimationPlayer、不產生 `.tscn`
- 靜止姿勢比對基準改成切件輸出的合成圖 `game/art/chr/enm_sevenmacaw_rest.png`，容忍 2 px；原圖 `enm_sevenmacaw_reference.png` 保留
- `assets-test/` 不進版控；`import_art.py --check`、`import_rig.py --check` 要重現同樣位元組
- 註解、文件繁體中文；commit 訊息英文、結尾 `(MV-TUNE-003)`，最後一行 `Co-Authored-By: Claude <noreply@anthropic.com>`

## Review Focus

1. **翅膀抬到最高時肩膀露洞**：任何動作的任何一格、兩個面向，肩膀附近都不該有被輪廓包住的透明洞 → Task 3 的 `test_macaw_no_shoulder_hole`
2. **圖層的 marks 標錯**（對位後翅膀骨頭一個像素都沒有）應該明確報錯，不是切出空分件 → Task 1 的 `test_layer_without_pixels_is_an_error`
3. **主圖換成 W-01 後頭偏了**：受傷頭換頭、光點落在畫上的下顎／牙／眼要照舊成立 → Task 2 跑既有的 `test_macaw_lights_on_art`、`test_macaw_light_on_head_every_frame`，並看換頭檢查圖
4. **有圖層時輸出不穩定**（每次切出不同位元組，`--check` 失敗）→ Task 1 的 `test_layer_deterministic`
5. **判定框跟著新身體變了**，射程與命中測試要一起過 → Task 2 跑全套（`test_portraits`、`test_boss`、`test_macaw_rig`）

---

## 檔案結構

| 檔案 | 責任 | Task |
|---|---|---|
| `tools/cut_rig.py` | `layers`、`erase`、合成圖輸出；`_paste_head` 改成共用的 `_paste_marked` | 1 |
| `tools/test_cut_rig.py` | 新增 5 項 | 1 |
| `tools/rig_src/sevenmacaw_joints.json` | 改用 W-01＋`layers.wing`＋`erase` | 2 |
| `tools/rig_src/sevenmacaw_rig.json`、`game/rig/sevenmacaw_rig.json`、`game/art/chr/parts/sevenmacaw/*` | 重新產生 | 2 |
| `tools/import_art.py`、`game/art/chr/enm_sevenmacaw_rest.png`、`game/art/MANIFEST.md` | 合成圖匯入 | 2 |
| `game/tests/test_macaw_rig.gd` | 比對基準改合成圖；新增翅膀幅度與肩膀洞的測試 | 2、3 |
| `game/world/macaw_animator.gd` | `BODY`（只在需要時） | 2 |
| `game/rig/sevenmacaw_anims.json` | 翅膀角度 | 3 |
| `game/README.md`、`ART_SPEC.md`、規格書、`todo/todo.md`、`report/` | 文件 | 4 |

---

### Task 1：切件工具支援圖層與擦除

**Files:**
- Modify: `tools/cut_rig.py`（docstring、`_paste_head` → `_paste_marked`、`cut()`）
- Test: `tools/test_cut_rig.py`

**Interfaces:**
- Produces（joints json 欄位，Task 2 使用）：
  - `layers`: `{名稱: {"src": str, "marks": [[x, y], [x, y]], "ref_marks": [[x, y], [x, y]], "bones": [str, ...]}}`
  - `erase`: `[[[x, y], ...], ...]`（主圖座標的多邊形清單）
- Produces（函式）：`_paste_marked(src: Path, marks, ref_marks, size: tuple[int, int]) -> np.ndarray`（RGBA，主圖大小；即現在的 `_paste_head`，改名後受傷頭與圖層共用）
- Produces（輸出）：`{out}/chr_{角色}_reference.png` 有 `layers` 時是「主圖（擦除後）＋各圖層」的合成圖，圖層的不透明像素依骨頭的 z 疊在主圖上（z 較大者在上）；`reference.content_height` 從合成圖量

- [ ] **Step 1：寫失敗的測試**（沿用檔內 `make_image`／`make_spec` 的合成圖做法）
  - `test_layer_aligned_by_marks`：圖層圖＝翅膀放大 1.5 倍並平移；對位後翅膀分件的兩個特徵點（標成單色小方塊）回到主圖座標，誤差 ≤ 1 px
  - `test_layer_bones_take_only_layer_pixels`：主圖在翅膀位置也畫了一塊顏色 A、圖層翅膀是顏色 B → 翅膀分件只有 B、沒有 A；身體分件沒有 B
  - `test_erase_makes_background`：`erase` 圈住主圖一塊顏色 C → 所有分件與合成圖都沒有 C
  - `test_layer_without_pixels_is_an_error`：`ref_marks` 把圖層貼到畫面外 → `ValueError`，訊息含圖層名
  - `test_layer_deterministic`：同樣輸入切兩次，所有分件與 rig json 逐位元組相同
- [ ] **Step 2：跑** `python3 -m unittest tools/test_cut_rig.py` → 新的 5 項失敗（KeyError／AssertionError），舊的 17 項通過
- [ ] **Step 3：實作**：`erase` 在去背後、算 `opaque` 前把主圖多邊形內設為透明；主圖的距離分配只在「不屬於任何圖層」的骨頭之間做；每個圖層各自 `_paste_marked`、各自在自己的 `bones` 之間做距離分配與關節重疊圈（polys、snap 只作用在主圖）；某根圖層骨頭沒有像素時 `_fail(f"圖層 {名稱} 的骨頭 {骨頭} 沒有任何像素：檢查 marks／ref_marks")`。docstring 補兩個欄位
- [ ] **Step 4：跑** `python3 -m unittest tools/test_cut_rig.py tools/test_import_art.py` → 全部 OK；`python3 tools/cut_rig.py crawler flyer` 後 `git status --short tools/rig_src game/art` 沒有變更（逐位元組不變），`python3 tools/import_rig.py --check`、`python3 tools/import_art.py --check` 結束碼 0
- [ ] **Step 5：Commit** `Let the rig cutter take extra layers and erase areas (MV-TUNE-003)`

---

### Task 2：Seven Macaw 改用新素材重切

**Files:**
- Modify: `tools/rig_src/sevenmacaw_joints.json`、`tools/import_art.py`、`game/tests/test_macaw_rig.gd`
- Regenerate: `tools/rig_src/sevenmacaw_rig.json`、`game/rig/sevenmacaw_rig.json`、`game/art/chr/parts/sevenmacaw/*`、`game/art/MANIFEST.md`
- Create: `game/art/chr/enm_sevenmacaw_rest.png`（＋`.import`）
- Maybe modify: `game/world/macaw_animator.gd:15`（`BODY`）

**Interfaces:**
- Consumes: Task 1 的 `layers`、`erase`
- Produces: `res://art/chr/enm_sevenmacaw_rest.png`（遊戲尺寸的合成圖，Task 3 的測試與 Task 4 的文件引用）；`game/rig/sevenmacaw_rig.json` 的骨頭與分件名稱不變（`wing_arm`、`wing_fore`、`wing_tip`、`wing_*_l`、`head*` 等）

- [ ] **Step 1：改測試基準**：`test_macaw_rig.gd` 的 `PORTRAIT` 改成 `res://art/chr/enm_sevenmacaw_rest.png`（`test_macaw_rig_rest_matches_reference` 的斷言、`MATCH_PX` 2 px、`MIN_IOU` 不變）
- [ ] **Step 2：跑** `SELFTEST_ONLY=test_macaw_rig godot --headless --path game -- --self-test` → 失敗（檔案不存在）
- [ ] **Step 3：joints json**：`src` → `b2b1_wing/enm_sevenmacaw_body_nowing.png`；`layers.wing` → `src` `b2b1_wing/enm_sevenmacaw_wing_near.png`、`bones` `["wing_arm", "wing_fore", "wing_tip"]`、`marks`／`ref_marks` 取翼尖兩根最長飛羽的尖端（W-02 上量、原圖上量；起始值縮放 0.72、平移 (272, 0)，用 `/tmp` 的檢查腳本確認兩點誤差 ≤ 1 px）；`erase` 圈住 W-01 脖子後方的暗紫色痕跡（約 (420～445, 295～330)，以實際像素為準，只圈痕跡、不圈羽毛）；原本為了分開翅膀和身體的 `snap` 框、`polys`、`caps` 依新圖刪改（骨盆／尾羽交界照舊）；頭、`heads`、`head_marks`、`points`、`origin`、`far` 不動
- [ ] **Step 4：匯入**：`import_art.py` 在 Seven Macaw 原圖那筆之後加 `{"src": "chr_b2b1/parts/chr_sevenmacaw_reference.png", "dst": "chr/enm_sevenmacaw_rest.png", "scale_like": "chr/enm_sevenmacaw_reference.png"}`；跑 `python3 tools/cut_rig.py sevenmacaw`、`python3 tools/import_rig.py`、`python3 tools/import_art.py`，再 `godot --headless --path game --import`
- [ ] **Step 5：檢查圖（不進版控，放 `assets-test/tune003/check/`）**：靜止姿勢重組 vs 合成圖；換頭（4 種頭）；光點位置；遊戲尺寸 ×2 與灰階。看縮圖或裁切，不看整張大圖
- [ ] **Step 6：跑全套** `MIN_PASS=334 bash /tmp/wt/b2a_verify.sh` → 通過（`test_macaw_rig` 的靜止姿勢、光點、判定框；`test_portraits`、`test_boss`）。`test_macaw_body_matches_rig` 若失敗只因外框差 > 2 px：把 `BODY` 更新成測試量到的外框、重跑，報告寫明新舊數值
- [ ] **Step 7：確認** `python3 tools/import_rig.py --check`、`python3 tools/import_art.py --check` 結束碼 0；`crawler`、`flyer` 檔案沒有變更
- [ ] **Step 8：Commit** `Cut Seven Macaw from the separated body and wing art (MV-TUNE-003)`

---

### Task 3：翅膀拍起來

**Files:**
- Modify: `game/rig/sevenmacaw_anims.json`
- Test: `game/tests/test_macaw_rig.gd`

**Interfaces:**
- Consumes: Task 2 的骨架（骨頭名不變）、既有 helpers（`helpers()`、`make_rig()`、`h.rig_mask(r)`）
- Produces: 新的動作資料；動作名與每個動作的長度不變（`macaw_animator.gd` 的段落時間與狀態對應不受影響）

- [ ] **Step 1：寫失敗的測試**
  - `test_macaw_wings_flap`：從動作檔讀 `wing_arm` 每格角度：`fly`、`flail` 最小值 ≤ −20 且最大−最小 ≥ 35；`dive`、`spread`、`wail`、`fall`、`stagger` 最小值 ≤ −15；`idle_perch`、`idle_ground`、`eat`、`throw`、`beam`、`down` 最小值 ≥ −8
  - `test_macaw_no_shoulder_hole`：13 個動作的每一格、面向 ±1，擺姿勢後取骨架遮罩，從邊界填滿背景，**肩膀關節周圍 60 px（遊戲尺寸）方框內**被輪廓包住的透明像素 ≤ 4 px（兩腿之間的空隙在方框外）
- [ ] **Step 2：跑** `SELFTEST_ONLY=test_macaw_rig godot --headless --path game -- --self-test` → `test_macaw_wings_flap` 失敗（目前 `wing_arm` 最小 −3），`test_macaw_no_shoulder_hole` 通過（現在的角度不露洞）
- [ ] **Step 3：改動作檔**：照規格第 4 節的表加大 `wing_arm` 上抬（`fly`、`flail` 約 −30° ↔ +20°，`wing_fore`、`wing_tip` 跟著甩；`dive` 約 −25°；`spread`、`wail` 張到上限附近；`fall`、`stagger` 往上張；待機類 ≥ −8°）；遠側 `wing_arm_l` 維持反向；其他骨頭不動。上抬最高的那一格畫肩膀檢查圖（遊戲尺寸 ×2），露縫就先加 `caps`（Task 2 的 joints json，重切重匯入）、仍不夠就降角度；**降到達不到 `test_macaw_wings_flap` 的門檻時停下來回報 BLOCKED（附肩膀檢查圖），不要放寬測試**——那表示素材不夠，要由 Brian 決定
- [ ] **Step 4：跑** `SELFTEST_ONLY=test_macaw_rig ...` → 全部通過；再跑全套 `MIN_PASS=336 bash /tmp/wt/b2a_verify.sh`（光源每格跟頭、關節覆蓋、狀態對應、`test_portraits` 的射程照舊）
- [ ] **Step 5：Commit** `Let Seven Macaw flap his near wing (MV-TUNE-003)`；報告列出每個動作最後的 `wing_arm` 範圍

---

### Task 4：影片與文件

**Files:**
- Modify: `game/README.md`（`cut_rig.py` 欄位表加 `layers`、`erase`；Seven Macaw 的來源改成兩張）、`ART_SPEC.md` 第 6 節（翅膀上抬上限、R10 已由 MV-ASSET-016／MV-TUNE-003 處理）、`todo/spec/MV-TUNE-003_SevenMacaw翅膀換新素材.md`（驗收打勾、Git Commit）、`todo/todo.md`（MV-TUNE-003 說明）
- Create: `report/MV-TUNE-003_SevenMacaw翅膀換新素材_{YYYY-MM-DD_HHmm}_執行報告.md`（時間戳先跑 `date`）

- [ ] **Step 1：`--shots`**：`godot --path game -- --shots /tmp/tune003_shots`，每個畫面平均 ≤ 16.7 ms（60 fps）
- [ ] **Step 2：錄影**：照 `game/README.md` 第 107～108 行的流程，`--rig-view --frames` 逐格存、ffmpeg 合成彩色＋灰階到 `assets-test/tune003_video/tune003_rigs.mp4`
- [ ] **Step 3：AI 抽格**：Seven Macaw 段落每 0.5 秒一格做縮圖拼版，看翅膀拍動、肩膀接縫、四種頭、光點；記進報告
- [ ] **Step 4：文件**：照上面的 Files；規格書只勾 AI 有證據的項目，Brian 的項目留空；`todo.md` 的 MV-TUNE-003 維持 🔄 進行中、說明改成「實作完成，待 Brian 看影片」
- [ ] **Step 5：跑** `MIN_PASS=336 bash /tmp/wt/b2a_verify.sh`、兩個 `--check`、Python 單元測試 → 全部通過
- [ ] **Step 6：Commit** `Record the flapping Seven Macaw and document the wing layers (MV-TUNE-003)`
