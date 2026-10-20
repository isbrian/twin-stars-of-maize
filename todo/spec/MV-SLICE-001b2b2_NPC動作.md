# MV-SLICE-001b2b2 NPC 的骨架與動作

更新時間：2026-10-13

## 基本資訊

| 項目 | 內容 |
|------|------|
| 分支 | `feature/MV-SLICE-001b2b2_NPC動作`（從 `develop` `ae28aa2` 開） |
| 影響範圍 | `game/`（`game/rig/`、`game/art/chr/parts/`、新增 `world/npc_animator.gd`；`world/room.gd`、`world/prop.gd`、`core/player/rat.gd`、`core/boss/boss_fight.gd`、`world/scenery_view.gd` 換掉立繪；移除 `world/portrait.gd`；`world/rig_showcase.gd`）、`tools/`（`rig_src/` 新增 5 份 joints json、`import_art.py`、`import_rig.py` 的清單）；`assets-test/` 只讀（切出的分件寫進 `assets-test/chr_b2b1/parts/`） |
| 上層 | [MV-SLICE-001 總規格](MV-SLICE-001_垂直切片.md)：美術整合 b 的最後一塊（b2b 在 2026-10-12 拆成 b2b1 與本文件） |
| 前置 | MV-SLICE-001b2b1（已合併）、MV-TUNE-003（切件工具的 `layers`／`erase`／`overlap`，已合併） |
| 引擎 | Godot 4.7.2 |
| 狀態 | ✅ 完成：Brian 2026-10-14 看影片後指示合併（「動作沒問題，可以合併」），本機合併回 `develop`（未推送）；手把試玩未另外回報 |

## 背景與目的

垂直切片是作品集展示用（SLICE-1）。b2a、b2b1 已把雙胞胎、敵人、Seven Macaw 換成骨架動作；畫面上剩下的靜態立繪與灰盒角色是這 5 個 NPC。本子專案把它們換成同一套資料驅動的骨架與動作，完成美術整合 b。

## 盤點（2026-10-13，AI 實查）

| 角色 | 出現在哪 | 遊戲裡已有的狀態 | 現在怎麼畫 |
|---|---|---|---|
| 祖母 Xmucane | 地面房間（`room.gd`，`data.npc`），按互動鍵開兌換 | 站著；被互動（`interact_target() == "npc"`） | `Portrait.attach(npc, "chr_xmucane_reference")`，面向右 |
| 老鼠（事件） | 入夜抓老鼠（`events/night_rat.gd`，道具 `prop.gd` kind `"rat"`） | 待著；角色靠近 300 px 內往反方向逃（跑速 ×1.1）；被網子罩住到文字卡結束 | 立繪，依移動方向翻面（基準圖面向右） |
| 老鼠（技能） | 鑽地突襲（`core/player/rat.gd`） | 衝向目標、距離 ≤ 咬距就造成傷害並消失；沒目標時跑出射程再跑回 | **灰盒**：`_draw` 畫棕色梯形 |
| 治療者老夫婦 | Boss 戰（`boss_fight.gd`） | 文字卡「couple」後跟著角色走（`couple_following`，跑速 ×0.9）；之後在宮殿站著（`palace.couple_static`） | 兩個 `Portrait.attach`（`chr_healer_man`／`chr_healer_woman`） |
| Chimalmat | 宮殿寶座左邊（`scenery_view.gd`） | 只是背景，沒有任何反應 | `Portrait.attach(chimalmat, "chr_chimalmat_reference")`，面向左 |

- 原始立繪：祖母、老夫婦 1024×1536（`assets-test/chr_batch2/`、`chr_batch3/`），老鼠 1536×1024（`chr_batch2/`），Chimalmat 1536×1024（`batch2/chr/`）。都是側面；祖母手往前伸、腿在裙子裡；老夫婦是跨步姿勢；老鼠四腳行走姿勢；Chimalmat 翅膀收著。
- 遊戲高度（`import_art.py` 的 `fit_height`）：祖母 165、老伯 170、老婆婆 165、老鼠 40、Chimalmat 340。
- 換完後 `world/portrait.gd` 沒有其他使用者（雙胞胎、敵人、Seven Macaw 已是骨架；顏色規則已在 b2a 抽到 `tint.gd`）。目前沒有測試在測 NPC 立繪。

## 定案（Brian，2026-10-13）

| ID | 議題 | 決定 | 理由 |
|---|---|---|---|
| SLICE-b2b2-1 | 老鼠技能 | 和事件的老鼠一起換成骨架（共用同一副） | 遊戲中最後一個看得到的灰盒角色，作品集影片會出現 |
| SLICE-b2b2-2 | Chimalmat 的動作 | 只做待機 | 只做遊戲已有的狀態（沿用 SLICE-b3）；說話、倒下等子專案 c 做演出時再加，骨架已在 |
| SLICE-b2b2-3 | 祖母的動作 | 待機＋遞出物品（互動時播一次） | 遊戲有互動狀態；立繪本身就是手往前伸的姿勢 |
| SLICE-b2b2-4 | 老夫婦的動作 | 走路＋待機 | 跟隨時走路，否則會像在飄；兩張立繪都是跨步姿勢 |
| SLICE-b2b2-5 | 鑽地突襲的呈現 | 地面跑，咬到就消失（傷害與消失的時間不變） | 鑽進土裡要土塊特效，留給子專案 c |
| SLICE-b2b2-6 | 網子底下的老鼠 | 播待機 | 網子蓋在上面、文字卡很快出來 |
| SLICE-b2b2-7 | 遠側手腳 | 複製近側、明度 ×0.72，和近側反向擺動 | 同 b2b1；走路時才看得出兩隻腳交替 |
| SLICE-b2b2-8 | 驗收 | 影片＋手把試玩 | 遊戲裡的面向、位置、疊放順序要有人看 |
| SLICE-b2b2-9 | 架構 | 共用一個 `npc_animator.gd`：呼叫端決定動作與面向 | 狀態本來就在各自的程式裡；程式最少、五個角色同一組測試 |

沿用的決定：12 fps、不內插、AI 寫成資料、執行時組出骨架（SLICE-b2a）；用 `tools/cut_rig.py` 從現有立繪切件、不開新美術工單（SLICE-b2b）；不改任何玩法與數值。

## 範圍

### 分件（從原始立繪切）

- 每個角色一份 `tools/rig_src/{角色}_joints.json`，角色 id：`xmucane`、`rat`、`healer_man`、`healer_woman`、`chimalmat`；`python3 tools/cut_rig.py` 切到 `assets-test/chr_b2b1/parts/`，`import_rig.py`／`import_art.py` 匯入 `game/rig/`、`game/art/chr/parts/{角色}/`。
- 遊戲高度同現在的立繪（上表）；靜止姿勢要和現有立繪對齊（`MATCH_PX` 2 px、`MIN_IOU` 0.9，同 b2b1），換上後位置不跳。
- 骨頭表依立繪標（實作計畫定）：
  - 祖母：腿在裙子裡、不走路 → 不切腿，裙子跟著骨盆；近側手臂（上臂、前臂、手）＋遠側複製
  - 老伯：近側腿（大腿、小腿、腳）、手臂＋遠側複製
  - 老婆婆：長裙蓋住腿 → 走路時只看得到腳（腳掛在裙下）；背上的陶罐跟著軀幹；近側手臂＋遠側複製
  - 老鼠：近側前腳、後腳＋遠側複製；尾巴、頭
  - Chimalmat：同 Seven Macaw 的鳥形骨頭表（不必和身體分開的翅膀，只做待機）
- 面向：祖母、老夫婦、老鼠的基準圖面向右，Chimalmat 面向左；rig json 寫 `faces`（同 b2b1）。
- 切出來露縫時先用 `overlap`／`caps` 補；補不了才停下來回報 Brian（附檢查圖），不擅自開美術工單。

### 動作清單（`game/rig/{角色}_anims.json`）

| 角色 | 動作 | 循環 | 什麼時候播 |
|---|---|---|---|
| 祖母 | `idle`（呼吸） | 是 | 平常 |
| 祖母 | `give`（手往前遞再收回，約 0.75 秒） | 否 | 互動開兌換時播一次，播完回 `idle` |
| 老鼠 | `idle`（嗅聞、尾巴擺） | 是 | 事件中沒在逃、網子底下 |
| 老鼠 | `run`（奔跑） | 是 | 事件中逃跑；技能全程 |
| 老伯、老婆婆 | `idle` | 是 | 宮殿站著、沒在移動 |
| 老伯、老婆婆 | `walk` | 是 | 跟隨中而且這一幀有移動 |
| Chimalmat | `idle`（呼吸、頭與尾羽微動） | 是 | 一直 |

## 架構

- 新增 `world/npc_animator.gd`（`extends Node`）：
  - `static func attach(node: Node2D, char_id: String) -> Node`：在 `node` 底下建 `RigView`（腳底對齊原點，同現在的立繪）與 animator，預設播 `idle`
  - `play(anim: String, then := "")`：換動作時從第 0 格開始；同一個動作重複呼叫不重來；非循環動作播完停在最後一格，有 `then` 就接著播 `then`
  - `facing`（±1）：整副骨架 `scale.x = facing × faces`
  - 自己累加時間，每幀 `rig.pose(anim, t)`（12 fps、不內插由 `rig_view` 決定）
- 呼叫端（只換掉立繪、加一兩行；狀態邏輯不動）：
  - `room.gd`：祖母 `NpcAnimator.attach(npc, "xmucane")`；`_on_interact` 目標是 `"npc"` 時 `play("give", "idle")`
  - `prop.gd`：kind `"rat"` 時建骨架、不畫貼圖；`_process` 依位置變化：有移動 `run`、沒移動 `idle`；面向沿用原本的翻面規則
  - `core/player/rat.gd`：拿掉梯形 `_draw`，建骨架播 `run`，面向＝移動方向；咬到照舊立刻消失
  - `boss_fight.gd`：老夫婦換成兩副骨架；`_update_couple` 中 `couple_following` 且這一幀 x 有變化 → `walk`、面向移動方向，否則 `idle`
  - `scenery_view.gd`：Chimalmat `NpcAnimator.attach(chimalmat, "chimalmat")`（她站在寶座左邊、先加，畫在寶座後面，照舊）
- 移除 `world/portrait.gd` 與各處的 `preload`。
- 展示畫面 `world/rig_showcase.gd` 的 `playlist()` 加入 5 個 NPC 的每個動作。
- 不改：互動距離、逃跑距離與速度、技能的射程、速度、傷害、暈眩與時機、老夫婦跟隨速度、文字卡流程、夜晚只調場景的規則。

## 自測（新增 `game/tests/test_npc_rig.gd`）

1. 五個角色的骨架組得起來、每個分件都在；rig json 的 `faces`、`anims` 路徑正確
2. 靜止姿勢與現有立繪對齊（`MATCH_PX` 2、`MIN_IOU` 0.9）；腳底在原點
3. 每個動作每一格，關節都蓋得住（同 b2b1 的 `bone_coverage`：靜止蓋得住的取樣點每一格都還蓋得住）
4. 動作清單：每個角色只有上表的動作，循環與否正確，12 fps
5. 整合：
   - 祖母：互動後播 `give`，播完回 `idle`
   - 抓老鼠：角色靠近、老鼠逃跑時 `run`；角色遠離時 `idle`；網子罩住後 `idle`
   - 老鼠技能：有骨架、不畫梯形；咬到目標後照舊消失、傷害與暈眩照舊
   - 老夫婦：跟隨時 `walk`、面向移動方向；宮殿站著時 `idle`
   - Chimalmat：宮殿場景有她的骨架、播 `idle`
   - 全遊戲沒有 `Portrait` 節點
6. 全套自測照舊全過（目前 336 項＋新增），沒有 `SCRIPT ERROR`／`Parse Error`／`flushing queries`

## 風險與退路

| 風險 | 退路 |
|---|---|
| 立繪只畫了近側手臂，遠側複製後在軀幹前後露出 | 遠側件 z 放軀幹後面；看檢查圖，必要時給遠側偏移（`far` 的 `[dx, dy]`） |
| 老婆婆的長裙、祖母的裙子在走路或遞物時露縫 | 祖母不走路；老婆婆只動腳、裙子跟著骨盆；露縫先用 `overlap`／`caps`，補不了回報 |
| 老鼠只有 40 px 高，切件與關節覆蓋測試的取樣點太小 | 取樣半徑依 `rig.scale` 換算（同 b2b1）；不行就只測靜止對齊與動作清單，在報告寫明 |
| Chimalmat 寬 476 px、尾巴在寶座後面，換骨架後疊放順序變了 | 沿用「先加、畫在寶座後面」；截圖確認 |
| 夜晚抓老鼠時，骨架的顏色跟著場景變暗 | 夜晚只調場景圖層（現狀），骨架掛在房間、不在場景圖層；整合測試確認 |

## 驗收標準

實作完成（AI）：

- [x] `tools/test_cut_rig.py`、`tools/test_import_art.py` 全部通過；`python3 tools/import_art.py --check`、`python3 tools/import_rig.py --check` 結束碼 0；既有角色（雙胞胎、爬行型、飛行型、Seven Macaw）的分件逐位元組不變
- [x] 自測全部通過（336 項＋新增），沒有 `SCRIPT ERROR`／`Parse Error`／`flushing queries`
- [x] 檢查圖：5 個角色的靜止重組 vs 立繪、每個動作抽格（遊戲尺寸 ×2）
- [x] `--shots` 每個畫面平均 60 fps
- [x] 重錄展示影片（彩色與灰階，含 NPC 段落），AI 抽格看動作、接縫、面向

驗收（Brian）：

- [x] 看影片的 NPC 段落：動作自然、沒有露縫（Brian 2026-10-14：「動作沒問題，可以合併」）
- [ ] （未另外回報）手把試玩：祖母兌換時遞出物品、入夜抓老鼠時老鼠會跑、老鼠技能、老夫婦跟著走、Chimalmat 在寶座旁（可和 b2b1、MV-TUNE-003 欠的試玩一起做）

## Git Commit

分支 `feature/MV-SLICE-001b2b2_NPC動作`（從 `develop` `ae28aa2` 開），未推送：

- `8d00d14` Spec MV-SLICE-001b2b2: rigs and actions for the NPCs
- `37109b9` Plan MV-SLICE-001b2b2 in seven tasks
- `67d99b7` Cut Xmucane into a rig and let the importer face NPCs right
- `ac4f22b` Cut the healer couple into walking rigs
- `62afae4` Cut the rat into a running rig
- `1775397` Cut Chimalmat into an idle rig
- `4385b7a` Animate Xmucane, the healer couple and Chimalmat with rigs
- `05ab1fc` Run the rat rig in the night field and the burrow strike
- Show the NPC rigs and document them（本次）

執行報告：[MV-SLICE-001b2b2_NPC動作_2026-10-14_0227_執行報告.md](../../report/MV-SLICE-001b2b2_NPC動作_2026-10-14_0227_執行報告.md)
