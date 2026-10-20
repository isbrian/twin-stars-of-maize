# MV-PROTO-004 美術管線（獨立、可丟棄）

> 規格：[todo/spec/MV-PROTO-004_美術管線.md](../../todo/spec/MV-PROTO-004_美術管線.md)
> 素材（不進版控）：角色基準圖 `assets-test/chr_batch1/`（[MV-ASSET-010](../../docs/assets/MV-ASSET-010_素材工單_角色基準圖第1批.md)，Hunahpu、Xbalanque）；武器沿用第 0 批 `assets-test/batch0/art/`
> 結論：分件改從「分件友善姿勢」的基準圖整張切出（[ART_SPEC 第 4 節](../../ART_SPEC.md)「整張切件」），兩兄弟一致性差距 ≤ 0.1%；第 0 批另外生成的分件表差距 201.8%，已不使用

## 要回答的問題

1. ChatGPT 生成的分件，比例、輪廓線、關節能不能一致到可以組裝？
2. 在 Godot 組一個骨架角色要多少工時？
3. 縮到 180 px 戰鬥中看不看得清楚？

## 第一次執行

```bash
cd prototypes/p4-art-pipeline
python3 tools/cut_parts.py hunahpu xbalanque   # 從基準圖切分件 → assets-test/chr_batch1/parts/，並寫 rig/{角色}_rig.json
./sync_art.sh                                  # 把分件與武器複製進 art/ 並匯入
godot --headless --path . -- --build-rig --force   # 依 rig json 產生 hunahpu.tscn、xbalanque.tscn
godot --path .                                 # 展示畫面
```

`cut_parts.py` 需要 Python 3、numpy、Pillow。

## 新增一個角色（整張切件）

1. 依 [ART_SPEC 第 4 節](../../ART_SPEC.md)「整張切件」生成基準圖與握拳的手，存成 `assets-test/chr_batch1/chr_{角色}_reference.png`、`chr_{角色}_hand_grip.png`。
2. 照 `rig/hunahpu_joints.json` 的格式標 `rig/{角色}_joints.json`：
   - `joints`：基準圖上的關節座標（px）；遠側手臂不用標，由近側往後上方偏移 (-28, -8) 產生
   - `head_poly`：頭部多邊形（含馬尾、髮髻），`head_cloth_y`：多邊形裡這條線以下的衣物色歸軀幹
   - `torso_poly`（選填）：顏色和「輪廓線→膚色」混色相近的深色配件，圈起來直接算軀幹（Xbalanque 的深褐獵網）
   - 用 `python3 tools/mark_points.py --grid`、`--zoom` 輔助讀座標
3. 把角色加進 `rig/rig.gd` 的 `CHARS`，跑上面四行；再跑自測與截圖。
4. 自測的 `test_joints_covered_in_every_key` 不通過時，看是哪個關節露縫：通常是配件顏色被判成別的分件，或關節點標得太靠邊。

除錯提醒：Godot 測試以 `Vector2i(px)` **截斷**座標取像素，用 Python 模擬覆蓋檢查時也要截斷、不要四捨五入，否則會漏抓 1 px 的縫。

畫面基準是 1920×1080，角色約 180 px；預設視窗 1280×720 時角色只有約 120 px。判斷 180 px 可讀性請在 1080p 螢幕全螢幕檢視，或直接看 `--screenshot` 輸出的截圖（固定以 1920×1080 拍攝）。

## 操作

| 按鍵 | 作用 |
|---|---|
| 1／2／3 | 右側放大預覽切換待機／跑／斧頭側攻 |
| T | 切換「不內插（約 12 fps，預設）」與「平滑內插」 |
| G | 灰階（檢查戰鬥訊號） |
| Tab | 切換展示畫面與一致性對照（基準圖／組好的站姿／疊合） |
| F12 | 截圖到 `user://shots/`（只拍目前畫面；要灰階版先按 G 再按一次 F12） |

## 微調流程（PROTO4-1）

整張切件之後，關節座標的來源是 `rig/{角色}_joints.json`，`rig/{角色}_rig.json` 由 `cut_parts.py` 產生；要改關節，改 joints json 後重跑「第一次執行」的前三行。下面是在編輯器手動微調的做法。

1. 用 Godot 編輯器開 `prototypes/p4-art-pipeline`，打開 `hunahpu.tscn`（或 `xbalanque.tscn`）。
2. 在場景樹選骨頭（Bone2D）拖曳位置；分件（`*_art`）可改偏移、旋轉、縮放。改完存檔。
   - **骨頭的旋轉與骨盆（`pelvis`）的位置由動作逐格決定**：在編輯器改了只會出現在不播動作的一致性對照，播動作時會被蓋掉。要改站姿或關節角度，改 `rig/hunahpu_rig.json` 的關節座標後重新產生（見第 3 步）。
   - 在編輯器預覽動作後再存檔，預覽中的姿勢會被存成場景的預設值；存檔前先停止預覽並回到第 0 格。
3. **重新執行 `--build-rig` 會覆蓋手動微調**：產生器發現場景被改過會拒絕覆蓋。要重新產生時，先把微調的數值回填到 `rig/hunahpu_rig.json`，再執行 `godot --headless --path . -- --build-rig --force`。
4. 記下微調花的時間，填進下面的工時表。

## 工時紀錄（驗收 2）

| 項目 | 時間 | 依據 |
|---|---|---|
| AI 組裝（量測到動作完成） | 12 分鐘（2026-10-02 22:23～22:35）；含截圖後調整斧頭角度共 14 分鐘 | Task 2 開始到 Task 5 commit（`b10d530`～`a2a5b52`），斧頭角度在 `6f23024` |
| 不含：規格書與實作計畫 | 最多約 1.6 小時（20:14 因素材未到暫停的 commit → 21:40 規格書 → 21:52 實作計畫；區間含等待素材的時間） | 程式碼大多已寫在實作計畫裡，上一列量的是「照計畫執行＋關節量測（9 分鐘）」 |
| Brian 微調（第 0 批） | 無紀錄 | Brian 2026-10-08 決定改為整張切件，第 0 批的分件不再微調 |
| 整張切件（第 1 批，MV-ASSET-010） | 關節標記與 `cut_parts.py`：Hunahpu 首次、Xbalanque 第 2 輪重標；工具修正 4 處（見下方「第 1 批」） | [MV-ASSET-010 執行報告](../../report/MV-ASSET-010_角色基準圖第1批_2026-10-08_0206_執行報告.md) |

## 自動驗證

```bash
godot --headless --fixed-fps 60 --quit-after 3600 --path . -- --self-test
```

輸出 `SELFTEST PASS|FAIL`、`CONSISTENCY`（每件縮放比例與統計）、最後 `SELFTEST SUMMARY`；出現 `SCRIPT ERROR` 也算失敗。

## 截圖（需有視窗）

```bash
godot --path . -- --screenshot "$PWD/shots"
```

輸出 `showcase.png`、`showcase_gray.png`、`consistency.png`，固定以 1920×1080 拍攝（角色 180 px）。

## 一致性結果（問題 1，2026-10-08 第 1 批：整張切件）

| 角色 | 中位數 | 最小／最大 | 差距 | 自測 |
|---|---|---|---|---|
| Hunahpu | 1.000 | 1.000／1.000 | 0.0% | 23/23 通過（兩個角色合計） |
| Xbalanque | 1.000 | 1.000／1.001 | 0.1% | 同上 |

- 截圖目視（`--screenshot`）：兩兄弟待機、跑、斧頭側攻沒有可見接縫；180 px 與灰階下分得出（頭頂髮髻＋背後獵網 vs 後腦馬尾＋泥彈袋）。
- 靜止姿勢未覆蓋的像素（Hunahpu 982、Xbalanque 892）都是外輪廓最外圈的零星反鋸齒點，不會露洞。
- 切件工具在試組時修正的地方：
  1. 遠側上臂的肩膀端補膚色圓盤（Hunahpu 斧頭側攻的肩膀覆蓋 94% → 100%）。
  2. 軀幹色塊的判準從「亮度 ≥ 150」改為「亮度 ≥ 150，或偏離『輪廓線→膚色』混色線超過 60」：原判準把 Xbalanque 的藍綠整片丟掉（約 2 萬 px 空洞、肩膀 1 px 縫）。
  3. 深褐獵網剛好落在那條混色線上 → joints json 新增選填的 `torso_poly`。
  4. `xbalanque_joints.json` 依第 2 輪基準圖重標；`head_poly` 刻意不含獵網捲。

## 一致性結果（問題 1，2026-10-02 第 0 批，已不使用）

縮放比例＝基準圖骨頭長度 ÷ 分件軸心到末端的距離；1.0 代表分件與基準圖同尺度。

| 統計 | 值 |
|---|---|
| 中位數 | 0.928 |
| 最小／最大 | 0.552（`forearm_r`）／1.664（`loincloth_flap`） |
| 差距（最大 ÷ 最小 − 1） | 201.8% |
| 標準差 ÷ 平均 | 29.6% |
| 沒出現在基準圖、不量 | `hand_grip_r`、`hand_open_l`（比例沿用同側前臂） |

**補生成清單**（偏離中位數超過 15%）：`loincloth_flap`（1.664）、`forearm_r`（0.552）、`forearm_l`（0.585）、`hand_open_r`（0.656）、`hand_grip_l`（0.666）、`upperarm_l`（0.775）、`foot_r`（1.255）、`thigh_l`（1.113）。

- 手臂與手整組偏大（比例 0.55～0.86）：不依賴手肘推估的兩隻手也只有 0.66，表示分件本身比基準圖大，不是量測誤差。
- `thigh_l`、`foot_r` 的偏離有一部分來自推估：兩髖被腰布遮住，前腳比後腳大是基準圖的透視。
- 兩件 `thigh` 下端畫有腳踝骨記號，形狀像小腿；組起來膝部有腳踝形突起。
- 基準圖的近側手是張開的（垂下那隻上臂蓋住軀幹後緣），與工單假設的「近側握拳」相反；組裝時靜止姿勢照基準圖，斧頭與近側握拳手只在斧頭側攻出現。

詳細數字與判斷見執行報告。

**下一個角色的估算**：產生器、動作與展示畫面可以直接沿用（Xbalanque 共用骨架），新角色只需要重做關節量測（本次 9 分鐘）與目視確認，再加上 Brian 微調的時間。
