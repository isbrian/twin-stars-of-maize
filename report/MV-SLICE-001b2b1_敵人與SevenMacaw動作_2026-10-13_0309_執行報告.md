---
type: task-report
id: MV-SLICE-001b2b1
name: 垂直切片 b2b1：敵人與 Seven Macaw 的骨架與動作
status: ✅ 完成（已合併進 develop，手把試玩未回報）
retry_count: 0
pause_reason: "-"
started_at: 2026-10-12_0345
completed_at: 2026-10-13_0418
generated_at: 2026-10-13_0309
---

# MV-SLICE-001b2b1 敵人與 Seven Macaw 的骨架與動作：執行報告

> started_at 取交接文件 `~/.claude/plans/session-handoff-2026-10-12_0345.md` 的時間。中間換過兩次 session：一次 context 超限（0621），一次因為 app 的 worktree 防護（2330）。Task 5～8 和最終審查都在 app worktree `.claude/worktrees/priceless-mclean-98442e` 裡完成。

## 基本資訊

| 項目 | 內容 |
|---|---|
| 任務 ID | MV-SLICE-001b2b1（總任務 MV-SLICE-001 的子專案 b2 的後半之一） |
| 分支 | Task 1～4 在 `feature/MV-SLICE-001b2b1_敵人與SevenMacaw動作`（從 `develop` `d33145a` 開，停在 `1c99d79`）；Task 5～8 和最終修正在 worktree 分支 `claude/priceless-mclean-98442e`（從 `1c99d79` 接續，HEAD `d719fde`）。兩條都還沒推送；feature 分支要怎麼帶到 `d719fde`，由 Brian 決定 |
| 規格 | [規格書](../todo/spec/MV-SLICE-001b2b1_敵人與SevenMacaw動作.md)（SLICE-b2b-1～11）、[實作計畫](../todo/spec/MV-SLICE-001b2b1_敵人與SevenMacaw動作_實作計畫.md)（8 個 Task） |
| 做法 | subagent-driven-development：每個 Task 派一位新的實作者（opus），完成後由另一位審查員檢查「是否符合規格」與「程式品質」，有問題就修正、再做範圍限定的複審；最後由 opus 審查整條分支。偏離計畫的決定都記在 ledger（`Ruling:`），共 R1～R13 |

## 結果

| 部分 | 內容 |
|---|---|
| 切件工具 | 新的通用工具 `tools/cut_rig.py`，讀 `tools/rig_src/{角色}_joints.json`。支援：多邊形分界、遠側件（複製近側，明度 ×0.72）、各關節自己的重疊半徑、沿墨線切（`snap`，整根羽毛歸同一件）、受傷頭對位（`heads`／`head_marks`）、光點（`points`）。Python 測試 17 項 |
| 骨架資料 | 骨頭表改成由資料決定（雙胞胎快照逐位元組不變）；新增 `crawler`、`flyer`、`sevenmacaw` 的 rig 與動作檔（爬行型 5、飛行型 5、Seven Macaw 13 個動作） |
| 素材 | 爬行型、飛行型共 18 張分件，Seven Macaw 20 張（含三顆受傷頭）；全部從現有基準圖切，**沒有開新的 ChatGPT 工單** |
| 遊戲裡 | 森林的爬行型、飛行型換成骨架；Seven Macaw 換成骨架：依受傷程度換頭、光源掛在頭骨上跟著動、判定框改成從骨架量出的「軀幹＋骨盆＋兩腿」（271×317）、飛鏢碰到身體後沿剩下的射程找光源（地形擋住就停） |
| 不變的部分 | 爬行型、飛行型的判定框與數值；Seven Macaw 的招式數值；沒有骨架時（原型模式、`make_fight` 測試）的判定框與光源位置 |
| 自測 | 306 → **334 項**全部通過，沒有 `SCRIPT ERROR`／`Parse Error`／`flushing queries`（2026-10-13 02:57 在 worktree 重跑）；`tools/test_cut_rig.py`＋`tools/test_import_art.py` 29 項 OK；`import_art.py --check`、`import_rig.py --check` 結束碼 0 |
| 效能 | `--shots` 11 個畫面平均 16.18～16.37 ms（維持 60 fps） |
| 驗收影片 | `.claude/worktrees/priceless-mclean-98442e/assets-test/b2b1_video/b2b1_rigs.mp4`（不進版控）：1920×1080、30 fps、250.9 秒，先彩色一輪、再灰階一輪。比 b2a 長，因為 Seven Macaw 每種頭都把 13 個動作播一次 |

### AI 抽格檢查（Task 8 實作者）

- 三個新角色看不到接縫。
- 光點在 Seven Macaw 13 個動作、4 種頭下都貼在下顎／牙／眼；長玉米牙那顆頭的眼睛光點偏高 4～5 px（落在眼睛上緣）。
- 近側翅膀幾乎不抬，`fly` 看起來是「僵硬的抖動」，不像拍翅（見裁定 R10）。

## 和計畫不同的地方（重要的裁定）

| # | 計畫或規格 | 實際 | 判斷錯的代價 |
|---|---|---|---|
| R7 | 遠側翅膀「往後偏移」 | 偏移 `[0, 0]`，靠動作讓它和近側反向擺動才露出來 | 遠側翅膀很少被看到；只改資料 |
| R8 | 受傷頭用兩點對位 | 兩組量測（兩點法、喙形 IoU）都畫了換頭檢查圖，量輪廓 IoU 與接縫色差後選兩點法 | 換頭時頭的大小差 5～8%；只改 joints json |
| R9 | 動作對照表沒寫到的狀態 | `down` 只在「階段結束、設局成功」後播；開場的飛行段播 `fly` | 改一列對照與測試 |
| R10 | 翅膀照常拍動 | 近側上臂最多抬約 3°（原圖翅膀根部被擋住，抬到 6° 就露出底色），拍翅改成往下拍、遠側反向 | 翅膀看起來僵，要補美術才能改善 |
| R11 | 各招的移動階段播 `fly` | 照做，包括亂揮翅膀時在地上走的追擊段 | 看起來像收腳低飛；補一個走路動作或改播地面待機 |
| R12 | 地形照舊擋飛鏢 | 照做。第 2、3 段 Boss 站在 HOME 時頭穿過宮殿低台，從平台底下射會被擋：正面要 200 px 以外、背後幾乎射不到。測試的近距離、背後案例改在空地跑 | 第 2、3 段起始位置很難近距離打光源，要改關卡或規則 |
| R13 | 「地形擋住就停」的測試 | 原本 150 px 的案例沒走到新程式；另外加了牆擋在身體與光源之間的假 Boss 案例，並證明拿掉地形檢查時它會失敗 | 多一個測試 |

R1～R6 是執行前檢查與 Task 4 的裁定（新骨架的欄位、`point()` 放在 Task 5、每個 Task 都要全綠、比對前先裁到不透明範圍、面向左的角色 `faces: -1`、根骨頭可以旋轉），細節在 ledger。

## 審查與修正

- Task 1～4：Task 4 修正 1 輪（補 `.uid`），其餘一次通過。
- Task 5、6、8：一次通過。
- Task 7：修正 1 輪（R13 的地形測試）。
- 最終整體審查（opus）：「可以合併」，0 個 Critical／Important；它把雙胞胎快照測試放回重構前的 `d33145a` 跑，也通過，證明雙胞胎沒變。帳本裡延後的小問題全部判定為「繼續延後」或「已解決」。順手修了兩個小問題（`d719fde`）：失衡撲擊、亂揮翅膀撞左牆時改用骨架判定框的半寬；飛行型原點的註解與規格改成「整隻的下緣」。這兩項經複審確認已解決。

## 踩到的雷

- **app 的 worktree 防護**：session 被綁在 app 自動建的 worktree，Edit／Write 寫原 repo 會被 hook 擋。最後在 worktree 內做：分支移到 `1c99d79`，git 忽略的 `assets-test/`（731 MB）、p4 art、帳本都要複製進來，`/tmp` 的驗證腳本也要改成 worktree 版，否則會驗到原 repo。
- **context-monitor 會把子 agent 的輸出也算進同一個 session**：Task 5 第一位實作者、Task 8 實作者和主 session 都在約 70% 被攔。派工時要提醒子 agent 控制輸出、看縮圖。
- **API 額度上限**：Task 8 中途碰到 session 額度上限。

## 驗收進度

實作完成（AI）：規格書「驗收標準」的 5 項都已打勾（自測、動作清單、驗收影片與抽格、60 fps、匯入檢查）。

驗收（Brian）：

- [x] 看動作展示影片（Brian 2026-10-13）：翅膀要補美術，開 [MV-ASSET-016](../docs/assets/MV-ASSET-016_素材工單_SevenMacaw翅膀分層.md)，新素材到了由 MV-TUNE-003 重切；b2b1 先合併
- [ ] （未回報）手把試玩：森林的爬行型、飛行型；Seven Macaw 三段（判定框、背後與近距離射光源、換頭）

## 給 Brian 的驗收步驟

1. 看影片：`.claude/worktrees/priceless-mclean-98442e/assets-test/b2b1_video/b2b1_rigs.mp4`，特別看翅膀（R10）、受傷頭的接縫、光點位置。
2. 試玩時注意：第 2、3 段在 HOME 近距離往上射（R12）；亂揮翅膀的追擊段（R11）；前搖輪廓、破綻裂紋、光束晃動線仍是舊灰盒的大小；果實從腳邊丟出、光束貼近地面（招式數值未改，出發點還是灰盒的位置）；`boss_nance` 畫面裡 Seven Macaw 的頭超出畫面上緣。

## 已知限制（等 Brian 決定）

- R10 翅膀僵硬：Brian 2026-10-13 決定補美術 → MV-ASSET-016（拆成身體＋單獨翅膀兩張）→ MV-TUNE-003 重切、放大拍翅角度。
- R12 HOME 近距離射不到頭：可移 HOME、移低台，或讓飛鏢從下往上穿過單向平台。
- 程式畫的訊號（前搖輪廓、裂紋、光束晃動線）與果實、光束的出發點仍對著舊灰盒。
- `throne_charge.gd` 撞左牆時用 `LEFT + 10`，沒有算身體寬度（只有被引到左牆時才有影響）。

## 合併

Brian 2026-10-13 看完影片後指示合併：在 worktree 切到 `develop`，`git merge --no-ff` 合併 `feature/MV-SLICE-001b2b1_敵人與SevenMacaw動作`（`eaef9ed`），合併 commit `6a96ffc`，無衝突；合併後全套自測 334／0、無 `SCRIPT ERROR`，`import_art.py --check` 結束碼 0。未推送，feature 分支保留。

## 待辦（不在本次範圍）

- MV-SLICE-001b2b2（NPC 動作），b2b1 驗收後開規格書。
- worktree 分支帶回 feature 分支、合併回 `develop`、推送。
- 原 repo 的 `assets-test/` 沒有這次的影片與 Seven Macaw 分件檢查圖（只在 worktree 裡）；清掉 worktree 前要先搬過去。

## Commit

```
3ae8b01 Spec MV-SLICE-001b2b1: enemy and Seven Macaw rigs
1333ed0 Plan MV-SLICE-001b2b1 in eight tasks
50d6201 Read the bone table from rig data
35224cb Add a generic rig cutter
ba0d1cc Cut and import the crawler and flyer rigs
6540440 Animate the crawler and flyer
cd5ab06 Add the enemy animator's uid
048f727 WIP: Seven Macaw cutter support, joints draft
1c99d79 Pause MV-SLICE-001b2b1 at Task 5 for a new session
f4eb3f4 Cut and import the Seven Macaw rig
a9f21bd Animate Seven Macaw and move his lights with the head
cddb521 Fit Seven Macaw's boxes to his rig and let darts reach lights past his body
c90b306 Test that terrain stops a dart's light search past the body
47622d4 Show the new rigs in the showcase and document them
d719fde Clamp pounce and flail to the rig body half-width and fix flyer origin wording
```
