# MV-PROTO-004 美術管線

更新時間：2026-10-02

## 基本資訊

| 項目 | 內容 |
|------|------|
| 分支 | `feature/MV-PROTO-004_美術管線`（從 `develop` 開） |
| 影響範圍 | 新增 `prototypes/p4-art-pipeline/`（獨立、可丟棄，MV-PROTO-000 定案 PROTO-2）；結論寫回 [ART_SPEC.md](../../ART_SPEC.md) 與 [原型驗證計畫](../../docs/design/MV-PROTO-000_原型驗證計畫.md) |
| 優先權 | 垂直切片前的獨立原型，可與戰鬥線並行 |
| 狀態 | 規格已定案，待實作 |
| 引擎 | Godot 4.7.2 |
| 素材 | `assets-test/batch0/art/`（第 0 批，Brian 2026-10-02 交付；17 個 RGBA 分件＋基準圖＋分件總表＋斧頭＋吹箭；不進版控） |

## 背景與目的

依 [原型驗證計畫](../../docs/design/MV-PROTO-000_原型驗證計畫.md) 第 3 節，回答三個問題：

1. ChatGPT 生成的分件，比例、輪廓線、關節能不能一致到可以組裝？
2. 在 Godot 組一個骨架角色要多少工時？
3. 縮到 180 px 戰鬥中看不看得清楚？

上層依據：[ART_SPEC.md](../../ART_SPEC.md) 第 3 節（尺寸）、第 4 節（製作流程、雙胞胎外觀、共用骨架）、第 5 節（戰鬥訊號）、第 6 節（骨架動作清單）、第 11 節（驗收）；[第 0 批素材工單](../../docs/assets/MV-ASSET-001_素材工單_第0批.md)；素材紀錄 `assets-test/batch0/README.md`。

**不做**：Xbalanque（「兩兄弟一眼可分」留待第 1 批素材）、三個動作以外的動作、角色面向左的鏡像、接進 MV-PROTO-001 核心專案。

### 定案（Brian，2026-10-02）

| 編號 | 問題 | 定案 | 理由 |
|---|---|---|---|
| PROTO4-1 | 組裝方式 | **AI 依關節對照表產出可編輯的 `.tscn`，Brian 在編輯器檢查微調**；工時分「AI 組裝」與「Brian 微調」兩欄 | 之後垂直切片也是這個分工，量到的工時才能用來估算；對照表可套用到 Xbalanque（共用骨架）；場景在編輯器看得到、改得動 |
| PROTO4-2 | 影格節奏 | **預設約 12 fps 不內插，按 T 切換平滑內插對照** | 符合 ART_SPEC「少格數、抄本平面感」；切換幾乎沒有額外工；有對照才判斷得了快節奏下看不看得清 |
| PROTO4-3 | 可讀性檢查畫面 | **仿戰鬥畫面＋灰階版** | 一次涵蓋第 11 節的可讀性與戰鬥訊號；背景用實際配色，才判斷得了光暈、漸層要不要重做 |

### 素材現況（實作前已檢查）

- 17 個分件皆為 RGBA；基準圖有暗色漸層背景與色票（素材紀錄註明「透明區仍有半透明光暈」），只用來量關節，不進遊戲畫面。
- 左右的約定照工單：`_r`＝近側原色，`_l`＝遠側明度降一階。實測膚色平均亮度 `_r` 約 160、`_l` 約 130，全部一致。（解剖上面向右時近側是左半身；這是工單的命名約定，素材與工單一致，照檔名對應即可。）
- 各分件繪製角度不同（例如 `upperarm_l` 斜放、`upperarm_r` 直放），組裝時要逐件轉正。

## 實作內容

### 修改檔案

```text
prototypes/p4-art-pipeline/
├── project.godot          1920×1080 基準，stretch canvas_items
├── .gitignore             .godot/、art/
├── README.md              執行、操作、微調流程、工時紀錄、驗收結果
├── sync_art.sh            把 assets-test/batch0/art/ 複製到 art/
├── art/                   （不進版控）分件 PNG
├── rig/
│   ├── hunahpu_rig.json   關節對照表：基準圖關節座標、每件的軸心與末端、父骨頭、前後層次
│   └── build_rig.gd       產生器：讀對照表 → 產出 hunahpu.tscn（Skeleton2D＋Bone2D＋Sprite2D＋AnimationPlayer）
├── hunahpu.tscn           產生器輸出；Brian 可在編輯器微調後存檔
├── showcase.gd / main.tscn  仿戰鬥展示畫面、灰階切換、截圖
└── tests/self_test.gd     --self-test
```

### 具體變更

#### 1. 關節對照表與一致性量測（問題 1）

1. **基準圖關節**：在 `chr_hunahpu_reference.png` 標出頸、肩、肘、腕、髖、膝、踝（近側與遠側各一組，看不到的遠側關節依近側推估），得到每段骨頭的長度與站姿角度。
2. **分件兩點**：每件標出「軸心」（靠近身體的關節）與「末端」。先由透明度算出主軸與兩端，再逐件確認哪一端是軸心；頭、軀幹、腰布、手、腳另標掛點。
3. **縮放比例**：每件的比例＝基準圖骨頭長度 ÷ 分件兩點距離。17 件比例的差距（最大／最小、標準差）就是問題 1 的量化答案；偏離中位數超過 15% 的分件列入「補生成清單」（第 0 批工單 A0-03）。
4. 斧頭依素材紀錄「握持點距手柄末端約 1/5」掛在近側握拳手（`hand_grip_r`）上。

#### 2. 場景產生（PROTO4-1）

- `build_rig.gd` 以 headless 執行（`godot --headless --path prototypes/p4-art-pipeline -- --build-rig`），讀對照表、在程式中建立節點樹後用 `PackedScene` 存成 `hunahpu.tscn`。
- 骨頭層級：根（髖）→ 軀幹 → 頸 → 頭；軀幹 → 近側／遠側上臂 → 前臂 → 手；根 → 近側／遠側大腿 → 小腿 → 腳；腰布掛在根。前後層次：遠側四肢在軀幹後、近側在前。
- 每件的 Sprite2D 依兩點轉正並縮放，讓軸心對齊骨頭原點。
- **微調流程**：Brian 在編輯器開 `hunahpu.tscn`，直接拖曳 Bone2D 或 Sprite2D 的偏移後存檔。**重新執行產生器會覆蓋手動微調**，所以微調後若要重新產生，先把數值回填到對照表（README 說明）。

#### 3. 動作（PROTO4-2）

| 動作 | 內容 | 長度（暫定） |
|---|---|---|
| 待機 | 呼吸起伏，前傾站姿（ART_SPEC：Hunahpu 前傾） | 1.0 秒循環 |
| 跑 | 四肢交替擺動、身體起伏，近側手張開 | 0.5 秒循環 |
| 斧頭側攻 | 出招（舉斧）→ 判定（揮下）→ 收招，對應 MV-PROTO-001 的 0.06／0.08／0.18 秒 | 0.32 秒 |

- 關鍵影格是骨頭旋轉（必要時加位移），影格之間預設不內插（Animation 軌道 `INTERPOLATION_NEAREST`），約 12 fps 的節奏。
- 按 T 把所有軌道切成線性內插，同一組影格直接對照。

#### 4. 仿戰鬥展示畫面（PROTO4-3）

- 1920×1080；背景與地面用 MV-PROTO-001 戰鬥房的配色（背景 `Color(0.1, 0.12, 0.14)`、地面 `Color(0.22, 0.27, 0.25)`）。
- 三個 Hunahpu，高度縮到約 180 px，分別播待機、跑、斧頭側攻；旁邊放爬行型、飛行型的灰盒（珠寶金色方塊）與前搖訊號（白色圓形、暗紫鋸齒）。
- 另一個畫面：組好的站姿與基準圖並排、同比例（一致性對照）。
- 操作：1／2／3 切換主角動作、T 切換內插、G 切換灰階、Tab 切換展示畫面與一致性對照、F12 截圖（同時輸出彩色與灰階）。
- `--screenshot <資料夾>`：自動輸出彩色、灰階、一致性對照三張圖後結束（需有視窗）。

#### 5. 自動驗證（`--self-test`）

| 項目 | 驗證內容 |
|---|---|
| 對照表完整 | 17 個分件＋斧頭都在對照表，檔案都存在於 `art/` |
| 場景結構 | `hunahpu.tscn` 有 Skeleton2D；每個分件的 Sprite2D 都掛在某個 Bone2D 下；斧頭掛在近側握拳手的骨頭下 |
| 動作 | 待機、跑、斧頭側攻三個動作存在、長度正確、循環設定正確 |
| 內插切換 | 切換後所有軌道的內插方式改變；再切回來恢復 |
| 一致性 | 印出每件縮放比例與差距統計；偏離中位數超過 15% 的分件列出名稱（不算失敗，結果寫進報告） |
| 關節不穿幫 | 每個動作的每個關鍵影格，相連兩件的軸心距離不超過 6 px（以 1024 px 基準圖尺度計） |

## 驗收標準

實作完成（AI 執行，可自動驗證）：

- [ ] `godot --headless --path prototypes/p4-art-pipeline -- --self-test` 全部 PASS，無 `SCRIPT ERROR`／`Parse Error`
- [ ] `--build-rig` 產出的 `hunahpu.tscn` 能在 Godot 4.7.2 編輯器開啟（headless 載入不報錯）
- [ ] `--screenshot` 輸出彩色、灰階、一致性對照三張圖，並逐張目視確認
- [ ] 一致性數字、補生成清單、AI 組裝工時寫進執行報告與 README

驗收（MV-PROTO-000 第 3 節）：

- [ ] 1. 符合 ART_SPEC 第 11 節驗收（文化、一致性、風格、180 px 可讀性、戰鬥訊號、技術；「兩兄弟一眼可分」本次不適用）
- [ ] 2. 記錄組裝工時（AI 組裝、Brian 微調兩欄）
- [ ] 3. 若分件一致性不足，回頭修改 ART_SPEC 的製作流程（例如改為整張生成後手動切件）

第 1 項的 180 px 可讀性與第 2 項的微調工時需要 Brian 看截圖、開編輯器；實作完成、Brian 尚未確認時，派工單標 `⏸️ 暫停`（等待人工決策：Brian 檢查截圖與微調）。

## Git Commit

```text
6f23024 Add combat-like 180 px showcase, grayscale and consistency views (MV-PROTO-004)
a2a5b52 Add idle, run and axe side attack with stepped/smooth toggle (MV-PROTO-004)
2696777 Generate editable Skeleton2D scene from the rig table (MV-PROTO-004)
3193929 Compute rest pose and part scale consistency (MV-PROTO-004)
b10d530 Measure Hunahpu joints and part pivots into a rig table (MV-PROTO-004)
9832813 Scaffold art pipeline prototype with asset sync (MV-PROTO-004)
```

執行報告：[MV-PROTO-004_美術管線_2026-10-02_2238_執行報告.md](../../report/MV-PROTO-004_美術管線_2026-10-02_2238_執行報告.md)
