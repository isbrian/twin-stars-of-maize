# MV-TUNE-003 Seven Macaw 翅膀換新素材

更新時間：2026-10-13

## 基本資訊

| 項目 | 內容 |
|------|------|
| 分支 | `feature/MV-TUNE-003_SevenMacaw翅膀換新素材`（從 `develop` `9232b5b` 開） |
| 前置 | MV-SLICE-001b2b1（已合併）、MV-ASSET-016（素材已驗收，在 `assets-test/b2b1_wing/`） |
| 影響範圍 | `tools/cut_rig.py`、`tools/test_cut_rig.py`、`tools/rig_src/sevenmacaw_joints.json`、`tools/import_art.py`、`game/rig/sevenmacaw_rig.json`、`game/rig/sevenmacaw_anims.json`、`game/art/chr/parts/sevenmacaw/*`、`game/art/chr/enm_sevenmacaw_rest.png`（新）、`game/tests/test_macaw_rig.gd`；可能 `game/world/macaw_animator.gd`（`BODY` 常數） |
| 狀態 | ✅ 完成：Brian 2026-10-13 看影片驗收通過，本機合併回 `develop`（未推送） |

## 背景與目的

b2b1 的 Seven Macaw 是從一張原圖（`enm_sevenmacaw_reference.png`）整張切的。原圖的近側翅膀蓋住了肩背、脖子底部與身體，被蓋住的地方沒有畫，翅膀抬到 6° 就露出洞，所以只能抬約 3°（裁定 R10），Brian 看影片覺得翅膀「僵硬的抖動、不像拍翅」。MV-ASSET-016 補了兩張圖：

- **W-01** `enm_sevenmacaw_body_nowing.png`：拿掉近側翅膀、補完肩背的身體；外框和原圖完全相同（翅膀以外的輪廓 IoU 0.997）
- **W-02** `enm_sevenmacaw_wing_near.png`：單獨的近側翅膀，根部在肩膀處圓弧收口；**畫大了**，要縮放約 0.72、平移約 (272, 0) 才對得上原圖（對上後兩張疊回原圖的輪廓 IoU 0.968）

本任務用這兩張重切，讓近側翅膀明顯拍動。成功標準：Brian 看重錄的影片，覺得 Seven Macaw 在拍翅。

## 定案（Brian，2026-10-13）

| ID | 議題 | 決定 | 理由 |
|---|---|---|---|
| TUNE3-1 | 上抬幅度 | 近側翅膀（`wing_arm`）目標上抬約 **30°**；實際上限以肩膀接縫為準，露縫就往下調，報告寫明最後用了多少 | 遊戲尺寸下一眼看得出拍翅；根部圓弧蓋得住多少要實際切出來才知道 |
| TUNE3-2 | 改哪些動作 | 有拍翅或張翅的動作（`fly`、`dive`、`flail`、`spread`、`wail`、`fall`、`stagger`）改成真的往上拍／張開；`idle_perch`、`idle_ground`、`eat`、`throw`、`beam`、`down` 只稍微放寬（上抬約 8° 以內） | 拍翅集中在移動與大動作；待機保留一點呼吸感就好 |
| TUNE3-3 | 靜止姿勢的比對基準 | 改比「W-01＋W-02 對位後的合成圖」，容忍維持 2 px；原圖保留 | 骨架現在由新圖組成，合成圖才是它該長的樣子；放寬容忍會讓測試變鈍 |
| TUNE3-4 | W-01 脖子後方的修圖痕跡 | 切件時用多邊形排除（當成背景） | 程式內、可重現，不動素材檔 |

沿用的決定：遠側翅膀照舊複製近側、明度 ×0.72（MV-ASSET-016）；遠側偏移 `[0, 0]`、和近側反向擺動（R7）；頭、三張受傷頭、光點、招式數值不變。

## 設計

### 1. 切件工具 `tools/cut_rig.py`

新增兩個選填欄位（舊的 joints json 不用改，爬行型、飛行型、雙胞胎的輸出逐位元組不變）：

| 欄位 | 格式 | 做法 |
|---|---|---|
| `layers` | `{名稱: {"src": 圖, "marks": [[x, y], [x, y]], "ref_marks": [[x, y], [x, y]], "bones": [骨頭, ...]}}` | 圖層先用兩點對位（縮放＋平移、不旋轉）貼回主圖座標：`marks` 是圖層上的兩個特徵點，`ref_marks` 是同樣兩點在主圖座標的位置。列在 `bones` 的骨頭**只從這張圖層**切（主圖的像素不分給它們，圖層的像素也只分給它們）；關節重疊圈只帶同一張圖裡的相鄰件。受傷頭的 `_paste_head` 改成兩者共用的對位函式（受傷頭輸出不變） |
| `erase` | `[[[x, y], ...], ...]`（多邊形清單，主圖座標） | 切件前把主圖在這些多邊形內的像素當成背景（透明）；只作用在主圖 |

輸出的 `chr_{角色}_reference.png` 改成「主圖＋各圖層（依骨頭的 z 疊）」的合成圖；沒有 `layers` 時和現在一樣。`content_height` 從合成圖量。

單元測試（`tools/test_cut_rig.py`，先寫、看它失敗）：

- `test_layer_aligned_by_marks`：合成「圖層放大 1.5 倍、平移」的翅膀，對位後特徵點誤差 ≤ 1 px
- `test_layer_bones_take_only_layer_pixels`：主圖在翅膀位置也有像素時，翅膀分件只含圖層的像素、身體分件不含圖層的像素
- `test_erase_makes_background`：`erase` 圈到的主圖像素不出現在任何分件
- 既有 17 項照舊通過；`crawler`、`flyer` 重切後分件與 rig json 逐位元組不變

### 2. `tools/rig_src/sevenmacaw_joints.json`

- `src` 改成 `b2b1_wing/enm_sevenmacaw_body_nowing.png`（W-01）
- 新增 `layers.wing`：`src` 是 W-02，`bones` 是 `wing_arm`、`wing_fore`、`wing_tip`；`marks`／`ref_marks` 在翼尖取兩個清楚的特徵點（例如最長兩根飛羽的尖端），以縮放 0.72、平移 (272, 0) 當起始值，用特徵點精修
- `erase`：圈住 W-01 脖子後方的暗紫色痕跡（約 (420～445, 295～330)，以實際像素為準）
- 原本為了把翅膀和身體分開的 `snap`、`polys`、`caps` 依新圖重看：翅膀已經分層的部分刪掉，骨盆／尾羽交界照舊
- 頭（`head_marks`、三張受傷頭的 `marks`）、光點（`points`）、原點（`origin`）不動；實作時要驗證 W-01 的頭與原圖對齊（受傷頭換頭檢查圖照舊乾淨、光點仍落在下顎／牙／眼）

### 3. 匯入與比對基準

- `tools/import_art.py` 新增一筆：`chr_b2b1/parts/chr_sevenmacaw_reference.png`（切件輸出的合成圖）→ `game/art/chr/enm_sevenmacaw_rest.png`，縮放沿用原圖（`scale_like: chr/enm_sevenmacaw_reference.png`）
- `game/tests/test_macaw_rig.gd`：`test_macaw_rig_rest_matches_reference` 改比 `enm_sevenmacaw_rest.png`，容忍維持 2 px；其餘測試照舊
- 原圖 `enm_sevenmacaw_reference.png` 保留（受傷頭的縮放基準）
- 判定框 `MacawAnimator.BODY` 由既有測試 `test_macaw_body_matches_rig` 重新驗證（軀幹、骨盆、兩腿的外框 ±2 px）；超過就照骨架更新常數（判定框本來就跟骨架走，SLICE-b2b-6），招式數值不動

### 4. 動作 `game/rig/sevenmacaw_anims.json`

角度慣例：負值往上抬（目前 `wing_arm` 最多 −3°、往下壓到 +26°）。

| 動作 | 近側翅膀 |
|---|---|
| `fly`、`flail` | 拍翅循環約 −30° ↔ +20°（下壓保留現在的幅度），`wing_fore`、`wing_tip` 跟著甩 |
| `dive` | 衝刺時往上收、張開（約 −25° 以上） |
| `spread`、`wail` | 張開到上限附近 |
| `fall`、`stagger` | 慌亂地往上張 |
| `idle_perch`、`idle_ground`、`eat`、`throw`、`beam`、`down` | 上抬放寬到約 −8° 以內 |

- 遠側翅膀照舊和近側反向擺動（R7）
- 上限 −30° 是目標：在「上抬最高的那一格」畫肩膀接縫檢查圖，露縫就往下調，報告寫明每個動作最後用的角度
- 其他骨頭不動；`frame_at` 不內插、12 fps 不變

### 5. 驗收標準

實作完成（AI）：

- [x] `tools/test_cut_rig.py`、`tools/test_import_art.py` 全部通過；`python3 tools/import_art.py --check`、`python3 tools/import_rig.py --check` 結束碼 0；`crawler`、`flyer` 分件逐位元組不變
- [x] 自測全部通過（334 項＋新增），沒有 `SCRIPT ERROR`／`Parse Error`／`flushing queries`；光源每格跟著頭、關節覆蓋、狀態對應、判定框等既有測試照舊通過
- [x] 接縫檢查圖：上抬最高的那一格、遊戲尺寸 ×2，肩膀沒有露洞；受傷頭換頭檢查圖照舊乾淨
- [x] `--shots` 每個畫面平均 60 fps
- [x] 重錄展示影片（同 b2b1 流程，彩色與灰階），AI 抽格看翅膀拍動、接縫、光點

驗收（Brian）：

- [x] 看影片的 Seven Macaw 段落：翅膀像在拍翅（Brian 2026-10-13：「翅膀有在拍了，可以合併」）

## 風險與退路

| 風險 | 退路 |
|---|---|
| W-02 對位後翼尖和合成圖差太多，2 px 比對過不了 | 合成圖本身就是用同樣的對位產生，比的是骨架組裝 vs 合成圖，不受 W-02 和原圖的差異影響 |
| 抬到 30° 肩膀露縫 | 先加大肩膀關節的重疊半徑（`caps`）；仍不夠就降角度並在報告寫明，Brian 看影片判斷要不要再開工單 |
| W-01 的頭和原圖有 1～2 px 偏差，受傷頭或光點對不上 | 以換頭檢查圖與光點測試為準；超出就在 `layers` 之外另給頭一組對位（只在需要時做） |
| `BODY` 外框改變 | 照骨架更新常數；`test_portraits` 的射程與命中測試會一起驗證 |

## Git Commit

分支 `feature/MV-TUNE-003_SevenMacaw翅膀換新素材`（從 `develop` `9232b5b` 開），未推送：

- `e06e72b` Spec MV-TUNE-003: cut Seven Macaw's wing from the new art
- `84599b9` Plan MV-TUNE-003 in four tasks
- `4d97b5e` Let the rig cutter take extra layers and erase areas
- `6472a99` Cut Seven Macaw from the separated body and wing art
- `d359dc8` Let Seven Macaw flap his near wing
- Record the flapping Seven Macaw and document the wing layers（本次）

執行報告：[MV-TUNE-003_SevenMacaw翅膀換新素材_2026-10-13_1649_執行報告.md](../../report/MV-TUNE-003_SevenMacaw翅膀換新素材_2026-10-13_1649_執行報告.md)
