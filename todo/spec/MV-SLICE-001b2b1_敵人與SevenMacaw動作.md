# MV-SLICE-001b2b1 敵人與 Seven Macaw 的骨架與動作

更新時間：2026-10-12

## 基本資訊

| 項目 | 內容 |
|------|------|
| 分支 | `feature/MV-SLICE-001b2b1_敵人與SevenMacaw動作`（從 `develop` `d33145a` 開） |
| 影響範圍 | `game/`（`game/rig/`、`game/art/chr/parts/`、`world/rig_view.gd`、敵人與 Boss 的判定框與光源、`core/player/dart.gd`）、`tools/`；`prototypes/` 只讀（雙胞胎的切件工具不動）；`assets-test/` 只讀（切出的分件寫進 `assets-test/chr_b2b1/`） |
| 上層 | [MV-SLICE-001 總規格](MV-SLICE-001_垂直切片.md)：b2b 拆成 b2b1（本文件）與 b2b2（祖母、老鼠、老夫婦、Chimalmat） |
| 前置 | MV-SLICE-001b2a（雙胞胎骨架，已合併）、MV-TUNE-001（吹針射出點，已合併） |
| 引擎 | Godot 4.7.2 |

## 背景與目的

b1 把敵人與 Seven Macaw 畫成靜態立繪（SLICE-b10），Seven Macaw 的判定框與光源只粗略對到立繪（SLICE-b12）。b2b1 把爬行型、飛行型、Seven Macaw 換成**骨架與動作**，並把 Seven Macaw 的判定框與光源對到骨架。

Brian 試玩 b2a（2026-10-11）的前置問題：從 Seven Macaw 背後永遠射不到光源——飛鏢碰到受擊框時只往裡找 60 px（`dart.gd` `BODY_LOOKAHEAD`），正面另有 420 px 的特例（`light_reach_front`）。設計文件沒有規定背後不能射，是程式的副作用。

**不做**：祖母、老鼠、老夫婦、Chimalmat（b2b2）；開場、換牙、死亡、覺醒等演出動作（c）；擊倒特效（c）；「通關時間不足 30 分鐘」（總規格待處理）。

## 盤點（2026-10-12，AI 實查）

| 項目 | 結果 |
|---|---|
| 素材 | 只有基準圖：`assets-test/batch2/chr/enm_falselight_crawler_reference.png`、`enm_falselight_flyer_reference.png`、`enm_sevenmacaw_reference.png`（皆 1536×1024 或 1254×1254、洋紅底）＋三個受傷頭特寫（`head_jawhurt`、`head_maize`、`head_blind`）；**沒有分件** |
| 基準圖姿勢 | 爬行型：多條細腿的珠寶甲蟲型、側面；飛行型：寶石身體＋上下兩組羽翼；Seven Macaw：面向左站姿、近側翅膀高舉張開、長尾羽往右拖、兩腳著地 |
| 骨架程式 | `world/rig_view.gd` 的 `BONES` 寫死人形 16 根骨頭；`cut_parts.py` 也只認人形骨段 |
| 目前畫法 | `world/portrait.gd`：整張立繪依面向翻面；Seven Macaw 換頭＝特寫縮小疊上（`HEADS`） |
| Seven Macaw 判定 | 有立繪時：受擊框 `ART_HURT` 230×320（腳底往上）、光源 `ART_LIGHT_OFFSETS`（下顎 −358、玉牙 −372、眼睛 −405）、`ART_LIGHT_REACH` 420；攻擊框與俯衝、光束等仍用灰盒 `SIZE` 180×140 |
| Seven Macaw 狀態 | `State`：DOWN、INTRO、GAP、MOVE、INTERRUPTED、BROKEN；10 招（召喚、擲果、吃果子、俯衝、假光閃耀、亂揮翅膀、哀嚎、撞寶座、失衡撲擊、光束），各招有移動／前搖／判定／收招等階段 |
| 敵人狀態 | `Enemy.State`：IDLE、TELEGRAPH、ATTACK、RECOVER、STAGGER、DEAD（死亡立刻移除） |

## 定案（Brian，2026-10-12）

| ID | 議題 | 決定 | 理由 |
|---|---|---|---|
| SLICE-b2b-1 | 拆法 | b2b 拆成 b2b1 敵人＋Seven Macaw、b2b2 NPC（祖母、老鼠、老夫婦、Chimalmat）；先做 b2b1 | 8 個角色一份太長；b2b1 影響手感、含判定框與光源 |
| SLICE-b2b-2 | 非人形骨架 | 骨頭表改成資料驅動（每個角色的 rig json 自帶骨頭表）；組裝、擺姿勢、動作檔全部共用；雙胞胎改讀資料、行為不變（自測核對） | 一套系統；翅膀、尾羽、多條腿都能表達 |
| SLICE-b2b-3 | 分件來源 | 從現有基準圖整張切件、人工標關節；被擋住切不出的（遠側翅膀、遠側腿）先複製近側、明度乘 0.72；不好看再開工單請 ChatGPT 補 | 不必等新素材；ART_SPEC 第 4 節已驗證的做法 |
| SLICE-b2b-4 | 背後射光源 | 所見即所得 | 與 MV-TUNE-001 的原則一致 |
| SLICE-b2b-5 | 身體擋不擋往光源的箭 | **不擋**：箭的路線（到射程或地形為止）經過該 Boss 的光源就算打中光源，前面、後面、近距離往上射都一樣；路線上沒有光源才算打到身體。地形（平台）照舊擋。拿掉 `BODY_LOOKAHEAD` 60 px 與 `light_reach_front` 420 px 兩個特例 | 同時解決「背後射不到」與 2026-10-11「近距離往上射被胸口擋」 |
| SLICE-b2b-6 | Seven Macaw 判定框 | 從骨架站姿量「身體＋腳」（不含頭、翅膀、尾羽），受擊框與攻擊框（打到角色）都用它；招式裡用到身體大小的地方一併核對；重驗手感 | 畫面上撞到就受傷、打到就算 |
| SLICE-b2b-7 | 光源位置 | 掛在頭骨上，跟著低頭、抬頭、俯衝移動 | 光點不和畫面上的下顎、牙、眼睛分開 |
| SLICE-b2b-8 | 受傷的頭 | 三張特寫縮到頭件大小、切成與完整頭相同的範圍，掛在同一根頭骨上直接替換；接縫不好看再開工單 | 不再疊一張比頭大的圖蓋到脖子 |
| SLICE-b2b-9 | Seven Macaw 動作範圍 | 只做遊戲裡已有的狀態（見動作清單）；開場、換牙、死亡、覺醒留給 c | 同 b2a（SLICE-b3） |
| SLICE-b2b-10 | 爬行型、飛行型判定框 | 不動（SLICE-b4） | 差距小；試玩覺得不對再另開任務 |
| SLICE-b2b-11 | 爬行型、飛行型動作 | 只做已有狀態；死亡維持立刻消失 | 擊倒特效屬 c |

沿用 b2a 的決定：約 12 fps、不內插（SLICE-b2a-3）；AI 寫關鍵姿勢、程式產生動作，Brian 看影片提意見（SLICE-b2a-2）；執行時從資料組出骨架、不產生 `.tscn`（SLICE-b2a-8）；骨架畫在角色節點後面、程式畫的訊號（前搖圓形／鋸齒、裂紋、硬直色）照舊在上面；受擊閃白等顏色規則用 `world/tint.gd`。

## 範圍

### 分件（從基準圖切）

| 角色 | 骨頭（初稿，實作時依圖調整） | 遠側件 |
|---|---|---|
| 爬行型 | 身體（含寶石頭）、每條看得到的腿各 1～2 節 | 圖上看得到的腿直接切；看不到的不補 |
| 飛行型 | 身體（寶石）、上翼、下翼（各 1～2 節） | 兩組翼都在圖上 |
| Seven Macaw | 骨盆、軀幹、脖子、頭、近側翅膀（上臂、前臂、翼尖）、尾羽、近側腿（大腿、小腿、腳爪）、遠側腿 | 遠側翅膀：複製近側、明度 ×0.72、關節往後偏移（同雙胞胎的遠側手臂） |
| Seven Macaw 受傷的頭 | 三張特寫各切一個頭件，範圍與完整頭相同 | — |

切件：新寫通用工具 `tools/cut_rig.py`，讀 `tools/rig_src/{角色}_joints.json` 裡的骨頭表（骨段＝兩個關節），其餘做法同 ART_SPEC 第 4 節（去背、像素分給最近的骨段、兩端關節多帶一圈重疊）；雙胞胎的 `cut_parts.py` 依賴膚色判斷四肢，不適用珠寶甲蟲與鸚鵡，也不改它以免動到已驗收的分件。分件寫進 `assets-test/chr_b2b1/parts/`，`import_art.py` 縮到遊戲尺寸進 `game/art/chr/parts/{角色}/`（爬行型高 70、飛行型高 60、Seven Macaw 高 450，同 b1 立繪）。

### 動作清單

全部約 12 fps、不內插。

| 角色 | 動作 | 對應遊戲裡的狀態 |
|---|---|---|
| 爬行型 | 巡邏走 | IDLE（循環） |
| | 前搖、撲、收招、硬直 | TELEGRAPH、ATTACK、RECOVER、STAGGER |
| 飛行型 | 盤旋拍翅 | IDLE（循環） |
| | 前搖、俯衝、收招、硬直 | TELEGRAPH、ATTACK、RECOVER、STAGGER |
| Seven Macaw | 待機（樹上、地面） | GAP、DOWN、INTRO（依位置） |
| | 飛行 | 各招的移動階段、`fly_to` |
| | 吃果子 | `eat_fruit` |
| | 擲果 | `throw_fruit` 前搖與擲出 |
| | 俯衝（俯衝、撞寶座、失衡撲擊共用） | `dive`、`throne_charge`、`stagger_pounce` 的前搖、衝刺、落地 |
| | 亂揮翅膀 | `flail` |
| | 展翅聚光（假光閃耀、召喚共用） | `false_flash`、`summon` |
| | 捧下顎哀嚎 | `wail` |
| | 光束蓄力與掃射 | `beam` |
| | 硬直 | INTERRUPTED、BROKEN |
| | 從樹上跌落 | BROKEN 的跌落（第 1 段在樹冠時） |
| | 倒下 | 段落結束（DOWN），只做姿勢、不做演出 |

外觀：完整頭、下顎受傷、白玉米牙、失明四種頭件，依 `set_appearance(stage)` 替換。

## 架構

```
assets-test/batch2/chr/{角色}_reference.png ──AI 標關節──▶ tools/rig_src/{角色}_joints.json（含骨頭表）
   ──tools/cut_rig.py──▶ assets-test/chr_b2b1/parts/ ＋ tools/rig_src/{角色}_rig.json
   ──import_art.py／import_rig.py──▶ game/art/chr/parts/{角色}/、game/rig/{角色}_rig.json
game/rig/{角色}_anims.json（AI 編寫；雙胞胎沿用 twin_anims.json）
敵人／Boss（狀態、招式階段、面向、外觀）──▶ world/{enemy,macaw}_animator.gd ──▶ world/rig_view.gd（讀骨頭表）
```

- `rig_view.gd`：骨頭表、人形專用的部分（近側手勢、斷臂、吹射覆寫）改成依資料決定有沒有；雙胞胎的組裝結果與 b2a 相同（自測核對骨頭變換與分件位置）。
- 光源：`light_source.gd` 的節點每幀放到頭骨上光點的位置（光點座標在頭件上標）。
- 受擊框與攻擊框：從 rig 的站姿量「身體＋腳」寫成常數（自測核對與骨架一致），不每幀跟著骨頭變。
- 飛鏢：SLICE-b2b-5 改 `dart.gd`：碰到 Boss 受擊框時，沿剩下的射程找同一個 Boss 的光源（地形擋住就停）；找到就打光源。
- `--rig-view`：展示畫面加上三個新角色。

## 自測（新增）

| 項目 | 內容 |
|---|---|
| 雙胞胎不變 | 改成資料驅動後，雙胞胎每個動作每一格的骨頭變換與分件位置和改之前相同；既有 306 項照舊通過 |
| 組裝 | 三個角色每個分件都在；站姿高度與 b1 立繪相同（±5%）；腳底對齊角色原點（飛行型：整隻的下緣對齊原點，與原點上方不變的 90×60 受擊框一致）；站姿與基準圖疊合差距 ≤ 2 px |
| 關節不露縫 | 每個動作的每一格，關節處都有分件蓋住 |
| 狀態對應 | 敵人每個狀態、Seven Macaw 每個狀態與每招每個階段對到正確的動作；面向翻轉 |
| 光源 | 三個光源在每個動作的每一格都落在頭件上對應的位置（±4 px） |
| 射光源 | 從正面、背後、近距離往上、遠距離射都打得中光源；路線上沒有光源只打到身體；平台擋得住 |
| 判定框 | 受擊框與攻擊框等於骨架站姿量出的「身體＋腳」；招式（俯衝、撞寶座、失衡撲擊、光束、亂揮翅膀）照舊能打到角色、也閃得掉 |
| 換頭 | 四種外觀各換到對應的頭件 |
| 玩法不變 | 爬行型、飛行型的判定與數值不變；自動走完全程照舊通過 |

截圖與效能：`--shots` 照拍；每個畫面平均幀時間仍 ≤ 16.7 ms。

## 風險與退路

| 風險 | 退路 |
|---|---|
| 基準圖的姿勢不適合切件（Seven Macaw 翅膀高舉、蓋住身體；爬行型細腿重疊） | 先切、看截圖；切不乾淨的部位開工單請 ChatGPT 畫分件友善姿勢的基準圖（只重畫該角色） |
| 遠側翅膀複製看起來不對 | 同上，開工單 |
| 判定框變大讓 Boss 變難 | Brian 手把試玩；過難再開任務調數值（本任務不改數值） |
| 身體不擋光源讓 Boss 變簡單 | 同上 |
| 受傷的頭與脖子接縫明顯 | 開工單請 ChatGPT 畫對應的頭件 |

## 驗收標準

實作完成（AI）：

- [x] 自測全部通過（306 項＋新增），沒有 `SCRIPT ERROR`／`Parse Error`／`flushing queries`（2026-10-13：332 項 fail=0）
- [x] 動作清單每個動作都有資料、在 `--rig-view` 播得出來（`test_showcase_playlist_covers_all`：四個動作檔每個動作、Seven Macaw × 四種頭都在展示清單；錄影 7528 格無 SCRIPT ERROR）
- [x] 驗收影片（彩色與灰階，同 b2a 的錄影流程），AI 抽格檢查接縫、光源位置（`assets-test/b2b1_video/b2b1_rigs.mp4`，1920×1080、30 fps、250.9 秒；抽格結果見 Task 8 報告）
- [x] `--shots` 每個畫面平均 60 fps（11 個畫面 16.18～16.37 ms）
- [x] `import_art.py --check`、`import_rig.py --check`、`tools/test_import_art.py` 通過（連同 `tools/test_cut_rig.py` 共 29 項 OK）

驗收（Brian）：

- [ ] 看動作展示影片
- [ ] 手把試玩：森林的爬行型、飛行型；Seven Macaw 三段（判定框、背後與近距離射光源、換頭）

## Git Commit

分支 `claude/priceless-mclean-98442e`，`git log --oneline d33145a..HEAD`（舊到新）：

- `3ae8b01` Spec MV-SLICE-001b2b1: enemy and Seven Macaw rigs (MV-SLICE-001b2b1)
- `1333ed0` Plan MV-SLICE-001b2b1 in eight tasks (MV-SLICE-001b2b1)
- `50d6201` Read the bone table from rig data (MV-SLICE-001b2b1)
- `35224cb` Add a generic rig cutter (MV-SLICE-001b2b1)
- `ba0d1cc` Cut and import the crawler and flyer rigs (MV-SLICE-001b2b1)
- `6540440` Animate the crawler and flyer (MV-SLICE-001b2b1)
- `cd5ab06` Add the enemy animator's uid (MV-SLICE-001b2b1)
- `048f727` WIP: Seven Macaw cutter support, joints draft (MV-SLICE-001b2b1)
- `1c99d79` Pause MV-SLICE-001b2b1 at Task 5 for a new session (MV-SLICE-001b2b1)
- `f4eb3f4` Cut and import the Seven Macaw rig (MV-SLICE-001b2b1)
- `a9f21bd` Animate Seven Macaw and move his lights with the head (MV-SLICE-001b2b1)
- `cddb521` Fit Seven Macaw's boxes to his rig and let darts reach lights past his body (MV-SLICE-001b2b1)
- `c90b306` Test that terrain stops a dart's light search past the body (MV-SLICE-001b2b1)
- （本 commit，無法自我引用 hash）Show the new rigs in the showcase and document them (MV-SLICE-001b2b1)
