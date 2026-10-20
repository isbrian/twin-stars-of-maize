# MV-SLICE-001c3b 地面事件的素材與動作

更新時間：2026-10-19

## 基本資訊

| 項目 | 內容 |
|------|------|
| 分支 | `feature/MV-SLICE-001c3b_地面事件素材與動作`（從 `develop` `667696e` 開） |
| 影響範圍 | `docs/assets/MV-ASSET-020_素材工單_地面事件.md`（新）、`tools/import_art.py`；`game/art/prop/`（7 張新圖）；`game/rig/twin_anims.json`、`rat_anims.json`、`xmucane_anims.json`（新動作）；`game/world/cutscene/silhouette.gd`、`field_dusk.gd`、`field_animals.gd`、`rat_deal.gd`、`gear_rope.gd`、`gear_drop.gd`；`game/world/room.gd`（祖母打盹） |
| 上層 | [MV-SLICE-001 總規格](MV-SLICE-001_垂直切片.md)：c3 拆成 [c3a 演出](MV-SLICE-001c3a_地面事件演出.md)（PR #25 已合併）→ c3b（本文件） |
| 前置 | MV-SLICE-001c3a（五段過場與佔位）、MV-SLICE-001b2b2（祖母、老鼠的骨架） |
| 設計依據 | ART_SPEC 第 1～3 節（畫風、色盤）、[MV-ASSET-019](../../docs/assets/MV-ASSET-019_素材工單_反光型.md)（Codex 工單格式）；[MV-DESIGN-002 原典核對](../../docs/design/MV-DESIGN-002_原典核對.md) 第 4、5 項 |
| 引擎 | Godot 4.7.2 |
| 狀態 | ✅ 完成：影片與手把試玩通過（Brian 2026-10-19），合併：PR #26（私人倉庫） |

## 背景與目的

c3a 把地面三個事件換成五段過場，外觀用佔位：動物、尾巴、食物是程式畫的剪影，祖母睡著只有「Z z z」，雙胞胎插工具用 `interact`、抓尾巴用 `lunge`，老鼠爬繩與咬繩只是位移加抖動，工具自己工作是工具飛過去、灌木淡出。c3b 換成正式素材與動作，讓過場可以放進作品集影片。

## 盤點（2026-10-19，AI 實查）

- 佔位：`world/cutscene/silhouette.gd`（`kind`：`deer`、`rabbit`、`critter`、`tail_deer`、`tail_rabbit`、`corn`、`beans`、`cacao`；`cacao` 已用正式圖 `prop_cacao_bean.png`）；`field_animals.gd` 把剪影 `place()` 進過場、用位置移動；尾巴掛在雙胞胎替身底下的固定位置。
- 骨架：雙胞胎（人形，27 個動作，含 `lunge`、`interact`、`dart`、`walk`）；老鼠 8 根骨頭（`body`、`head`、`tail`、`tail_tip`、四條腿），動作 `idle`、`run`；祖母 9 根骨頭（`pelvis`、`torso`、`head`、雙臂各 3 節，沒有腿、是長袍），動作 `idle`、`give`。動作檔 12 fps、不內插。
- 祖母睡著：`room.npc_asleep`（c3a）只畫「Z z z」、不開兌換；骨架照播 `idle`。
- 素材流程：Codex 生成到 `assets-test/` → `tools/import_art.py`（`fit_height`、去洋紅）→ `game/art/`；`--check` 核對。
- c3a 延後的小問題：咬繩過場交還後約 0.4 秒地上沒有球具（落下的球具在交還時釋放，可撿的球具等黑邊收完才放）。

## 定案（Brian，2026-10-19）

| ID | 議題 | 定案 | 理由 |
|---|---|---|---|
| SLICE-c3b-1 | 動物素材 | Codex 生成彩色側面圖（鹿、兔子、長鼻浣熊），遊戲裡調成夜色；跑的時候上下彈跳 | 和場景畫風一致，看得出是什麼動物 |
| SLICE-c3b-2 | 食物與尾巴 | 玉米、豆子、鹿尾、兔尾一起交 Codex；可可沿用現有圖 | 一次生成 |
| SLICE-c3b-3 | 祖母睡姿 | 用現有骨架擺坐著打盹（`doze`，循環），「Z z z」保留 | 不必新素材 |
| SLICE-c3b-4 | 雙胞胎新動作 | `plant`（插工具）、`grab`（撲完起身握著尾巴，尾巴掛在手上）；撲沿用 `lunge` | 收工與動物復原的關鍵動作 |
| SLICE-c3b-5 | 老鼠新動作 | `climb`（爬）、`gnaw`（咬）、`talk`（後腳站起、頭與前腳比劃） | 咬繩與交換有角色感 |
| SLICE-c3b-6 | 工具自己工作 | 斧頭飛到灌木旁來回揮兩三下、掉葉片碎屑後灌木消失；掘棒上下翻土、掉土屑；程式擺動＋內建粒子，不必新素材 | 看得出「工具自己在工作」 |
| SLICE-c3b-7 | c3a 延後的小問題 | 只修「球具落地後約 0.4 秒看不到」 | 玩家看得到；其他 4 個維持延後 |

沿用：動作 12 fps、不內插；AI 寫關鍵姿勢；行為、旗標、過場的流程與長度（每段 12～28 秒、天亮 4～10 秒）不改。

## 範圍

### 素材工單 MV-ASSET-020（Codex）

| # | 檔名 | 內容 | 遊戲大小（高） |
|---|---|---|---|
| A-01 | `prop_animal_deer.png` | 鹿（側面、面向左、奔跑中的姿勢） | 約 170 px |
| A-02 | `prop_animal_rabbit.png` | 兔子（同上） | 約 60 px |
| A-03 | `prop_animal_coati.png` | 長鼻浣熊（同上；原典的動物之一） | 約 70 px |
| A-04 | `prop_food_corn.png` | 一根帶葉的玉米 | 約 50 px |
| A-05 | `prop_food_beans.png` | 一小把豆子 | 約 25 px |
| A-06 | `prop_tail_deer.png` | 鹿的短尾巴（握在手裡的一撮） | 約 30 px |
| A-07 | `prop_tail_rabbit.png` | 兔子的毛球尾巴 | 約 30 px |

- 畫風照現有角色基準圖：平塗色塊、粗輪廓、有限色盤、洋紅底（去背用）；不畫投影、漸層、光暈；不要文字、類文字符號、東亞紋樣（ART_SPEC 文化限制）。
- 輸出到 `assets-test/c3b_art/`（不進版控）；每張最多生成 3 次；AI 驗收（畫風、去背、面向、縮到遊戲大小看得出是什麼），結果寫回工單。
- `import_art.py` 加 7 列（`fit_height` 照上表、去洋紅）→ `game/art/prop/`；`--check` 涵蓋。

### 新動作（12 fps、不內插）

| 角色 | 動作 | 姿勢要點 | 用在 |
|---|---|---|---|
| 雙胞胎 | `plant`（單次） | 舉起手上的工具 → 往前下方一插 → 收手站直 | 收工 |
| 雙胞胎 | `grab`（單次，停在最後一格） | 從 `lunge` 的最後一格起身，近側手伸在胸前握著東西 | 動物復原（尾巴掛在近側手上，跟著手動） |
| 老鼠 | `climb`（循環） | 身體轉成直立、四腳交替往上 | 咬繩（爬上屋梁） |
| 老鼠 | `gnaw`（循環） | 身體貼著繩子，頭快速前後點 | 咬繩 |
| 老鼠 | `talk`（循環） | 後腳站起、頭上下、前腳比劃 | 交換（老鼠開口時） |
| 祖母 | `doze`（循環） | 頭垂下、身體前傾、雙手放在身前，約 2 秒一次輕微起伏 | 祖母睡著（過場與平時） |

### 換掉 c3a 的佔位

- `silhouette.gd`：`kind` 不變，改畫對應的正式圖（`critter` 對到長鼻浣熊）；腳底中央在原點、`facing` 翻面照舊。動物的顏色調成夜色但比場景亮（場景夜色和白色之間），才認得出；田裡的灌木、土塊、老鼠照舊原色。
- `field_animals.gd`：動物移動時上下彈跳（鹿的步伐大、兔子小跳）；撲完播 `grab`，尾巴掛在雙胞胎替身近側手的位置、跟著手動。
- `field_dusk.gd`：兄弟倆插工具播 `plant`；工具飛到每叢演出灌木旁，斧頭來回揮兩三下、掘棒上下翻兩三下，每下掉碎屑（葉片綠、土屑褐，`CPUParticles2D`），之後灌木淡出。過場長度仍在 12～28 秒。
- `rat_deal.gd`：老鼠說話（`say`）時播 `talk`，其餘 `idle`。
- `gear_rope.gd`：爬上屋梁播 `climb`、咬繩播 `gnaw`（取代抖動）；落地後在 `end_state` 就放出可撿的球具（SLICE-c3b-7），`gear_drop.gd` 只在進門時已經 `gear_dropped` 的情況放。
- 祖母：`npc_asleep` 為 true 時播 `doze`，false 時回 `idle`。

### 不做

- 行為、旗標、過場流程與台詞；c3a 其他 4 個延後的小問題。
- 動物的骨架動畫（單張圖＋彈跳）。

## 自測

1. 素材：7 張圖都在 `game/art/prop/`，高度符合上表（±10%），四角透明（去背成功）。
2. 動作：`plant`、`grab`（雙胞胎兩人都有）、`climb`、`gnaw`、`talk`（老鼠）、`doze`（祖母）存在；循環與否照上表；接縫覆蓋測試照舊通過。
3. 剪影：每個 `kind` 畫的是正式圖（不再走程式多邊形）；動物有夜色、比場景亮。
4. 過場：收工裡雙胞胎播過 `plant`、工具揮動時有碎屑；動物復原裡播過 `grab`、尾巴跟著手；交換時老鼠播 `talk`；咬繩時播 `climb`、`gnaw`。各段長度仍在範圍內，看完與跳過的結果不變（c3a 的自測照舊通過）。
5. 祖母：`npc_asleep` 為 true 時播 `doze`、天亮後播 `idle`。
6. 球具：咬繩過場交還的那一幀地上就有可撿的球具；離開再回來仍只有一個（c3a 自測照舊）。
7. 全套自測全過（基準 588＋新增），沒有 `SCRIPT ERROR`／`Parse Error`／`flushing queries`／`body->get_space`；`import_art.py --check`、`import_rig.py --check` 結束碼 0。

## 風險與退路

| 風險 | 退路 |
|---|---|
| Codex 的動物畫風和角色不一致，或姿勢不像在跑 | 附上雙胞胎與老鼠的基準圖當畫風參考；最多 3 次，仍不行就挑最接近的、在工單記下差異請 Brian 決定 |
| 動物調成夜色後太暗看不出 | 夜色強度可調（常數），抽格檢查 |
| 祖母沒有腿，坐姿看起來像站著彎腰 | 用骨盆下沉＋軀幹前傾表現；抽格檢查，不像就改成站著打盹 |
| 新動作讓接縫露出 | 照現有的每格接縫測試 |

## 驗收標準

實作完成（AI）：

- [x] 自測全部通過，沒有 `SCRIPT ERROR`／`Parse Error`／`flushing queries`／`body->get_space`；`import_art.py --check`、`import_rig.py --check` 結束碼 0（審查修正後 602 項：588＋新增 14）
- [x] MV-ASSET-020 七張圖 AI 驗收通過（結果寫回工單，附總覽圖）：第一輪 7 張全部通過；總覽 `assets-test/c3b_art/c3b_check.jpg`
- [x] 重錄五段過場影片（`assets-test/c3b_video/`），AI 抽格檢查新素材、新動作、碎屑、夜色：`field.mp4`、`deal.mp4`、`rope.mp4`、`morning.mp4`、`c3b_all.mp4`、抽格 `c3b_frames.jpg`、新動作 `c3b_poses.jpg`

驗收（Brian）：

- [x] 看影片——2026-10-19「影片可以」
- [x] 手把試玩——2026-10-19「整體遊玩體驗不錯」；試玩紀錄沒有錯誤

## Git Commit

分支 `feature/MV-SLICE-001c3b_地面事件素材與動作`（從 `develop` `667696e` 開）：

| Commit | 內容 |
|---|---|
| `9a179ec` | 規格書 |
| `f8be86e` | 實作計畫 |
| `15b6999` | Task 1：MV-ASSET-020 工單、7 張素材匯入 |
| `d9bd2d6` | Task 2：6 個新動作 |
| `0e8f5a6` | Task 3：過場換上正式素材與動作 |
| `edf6650`＋文件 commit | 最終審查修正：收工長度、長鼻浣熊去背；README、文件 |
