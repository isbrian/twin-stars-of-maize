# MV-SLICE-001d2a 標題畫面、主選單與製作說明

更新時間：2026-10-20

## 基本資訊

| 項目 | 內容 |
|------|------|
| 分支 | `feature/MV-SLICE-001d2_外圍`（從 `develop` `0786d0f` 開） |
| 影響範圍 | `game/ui/title_menu.gd`（改寫）、`game/ui/credits.gd`（新）、`game/ui/credits_text.gd`（新，製作說明內容）、`game/world/ending.gd`、`game/main.gd`、`game/art/fonts/`（新，精簡字型）、`tools/font_subset.py`；`game/tests/test_d2a.gd`（新） |
| 上層 | [MV-SLICE-001 總規格](MV-SLICE-001_垂直切片.md)：d2 拆成 d2a（本文件）→ d2b 繪本前篇（SLICE-d2-1） |
| 前置 | MV-SLICE-001d1a、d1b（`Audio`、介面音效） |
| 設計依據 | [AI 素材條款與揭露](../../docs/legal/AI素材條款與揭露.md) 規則 1、6；[CULTURAL_PRINCIPLES](../../CULTURAL_PRINCIPLES.md)「遊戲標題」與「改編清單」；ART_SPEC 第 15 節（字型）；MV-BOOK-007（字型精簡） |
| 引擎 | Godot 4.7.2 |
| 狀態 | 🔄 手把試玩通過（Brian 2026-10-20「試玩可以」），推送並開 PR；HUD H1～H4 與製作說明兩點待 Brian 決定 |

## 背景與目的

主選單還是灰盒：純色背景、Godot 內建字型、標題是內部代號，只有「新遊戲／繼續」。結尾畫面的片尾只寫「美術 AI 生成」，音訊與程式的 AI 使用都沒揭露。AI 素材條款規則 1 要求主選單的「製作說明」與片尾都註明 AI 生成。d2a 把標題畫面、主選單、製作說明、片尾做成正式品質，並檢查 HUD。

## 盤點（2026-10-20，AI 實查）

- `ui/title_menu.gd`：`ITEMS := ["新遊戲", "繼續"]`、`TITLE := "Popol Vuh 垂直切片"`；`_draw()` 畫純色底與內建字型；讀不到存檔時「繼續」不可選；有存檔時「新遊戲」要再按一次確認。d1b 已加介面音效。
- `main.gd`：`_show_title()` → `TitleMenu.chosen` → 開 `GameWorld`；`quit_to_title` 回主選單。
- `world/ending.gd`：結尾房，一張 `TextCard` 寫「垂直切片到此結束，謝謝試玩。製作 Brian／故事依據 Christenson 英譯本／美術 AI 生成」，按掉後 `done` → 回主選單。
- 場景：`world/scenery_view.gd` 有 nance 樹的分層與 `night`（夜色）；Seven Macaw 有骨架（`macaw_animator`），過場替身可 `set_black(true)` 畫成剪影。
- 字型：正本在 `assets/fonts/`（Noto Serif TC／Noto Serif，附 OFL）；`tools/font_subset.py` 依繪本文本產生精簡版到原型資料夾（不進版控）。遊戲介面目前全用 `ThemeDB.fallback_font`。
- `Audio`：環境音 `set_ambience`、介面音效 `ui_move`／`ui_confirm`／`ui_back`。

## 定案（Brian，2026-10-20）

| ID | 議題 | 定案 | 理由 |
|---|---|---|---|
| SLICE-d2-1 | d2 的拆法 | d2a 標題、主選單、製作說明、HUD 檢查 → d2b 繪本前篇（閱讀器＋補齊 B 組插圖）；素材工單 MV-ASSET-022 與 d2a 同時進行 | B 組要先生基準圖再生插圖，素材時間長，不卡 d2a |
| SLICE-d2-2 | 繪本 B 組 | 開工單補齊：先 4 張角色基準圖（一胡納普、七胡納普、巴茲、丘文），再 4 張插圖；生不好就退回只用 4 張 | 作品集版的繪本要完整；基準圖之後也能用在全作 |
| SLICE-d2-3 | 繪本語言 | 只出繁中 | 和遊戲介面一致（SLICE-4 不做語言切換） |
| SLICE-d2-4 | 正式標題 | 標題字串做成一個常數 `GAME_TITLE`；MV-TITLE-001 在 d3 打包前定案 | 不讓取名卡住開發；定案後只改一行 |
| SLICE-d2a-1 | 標題背景 | 現有場景：夜裡的 nance 樹＋樹冠上 Seven Macaw 的剪影（骨架待機），緩慢視差；標題用文字排版 | 不用新素材，一眼點出切片的對手 |
| SLICE-d2a-2 | 標題聲音 | 森林環境音 AMB-01＋介面音效 | 不用新素材；和「探索段沒有配樂」一致 |
| SLICE-d2a-3 | 選單項目 | 新遊戲、繼續、繪本、製作說明、結束遊戲；「繪本」在 d2a 不可選（灰色），d2b 接上閱讀器後開放 | 桌機版要能從選單離開 |
| SLICE-d2a-4 | AI 揭露範圍 | 美術、音訊、程式都寫；程式寫「由作者與 AI 協作」 | AI 素材條款規則 1、6；誠實 |
| SLICE-d2a-5 | 片尾 | 結尾畫面之後自動捲動「製作說明」（可按鍵跳過），再回主選單；和主選單的製作說明同一份內容、同一個畫面 | 一份內容兩處用 |
| SLICE-d2a-6 | 作者署名 | Brian | — |
| SLICE-d2a-7 | 字型 | 標題、選單、製作說明用思源宋體（Noto Serif TC 精簡版）；HUD、文字卡、過場字幕先不動 | 正式感主要在標題畫面；HUD 改字型影響版面大，留到 HUD 檢查再評估 |
| SLICE-d2a-8 | HUD 檢查 | 截圖檢查各狀態（1280×720、1920×1080），列出問題給 Brian 挑，只修選的 | b1 已驗收過，只補漏 |

## 範圍

### 標題畫面（改寫 `ui/title_menu.gd`）

- 背景：`SceneryView` 建 nance 樹的分層、`night = true`；樹冠位置放 Seven Macaw 骨架（待機動作）、畫成黑色剪影；鏡頭以約 20 秒一個來回的速度左右緩移（視差照各層係數）。
- 標題：`const GAME_TITLE := "Popol Vuh 垂直切片"`（內部代號，MV-TITLE-001 定案後改這一行）；思源宋體、置中偏上，下方一行小字副標「垂直切片」。
- 選單：`ITEMS := ["新遊戲", "繼續", "繪本", "製作說明", "結束遊戲"]`；上下移動略過不可選的項目；不可選的畫成半透明。沿用「繼續」與「新遊戲確認」的既有規則。
  - 「繪本」：d2a 一律不可選（`book_enabled := false`，d2b 改）。
  - 「製作說明」：開 `Credits`（手動捲動），按返回回到選單。
  - 「結束遊戲」：`get_tree().quit()`（確認一次：「確定要離開嗎？」再按一次）。
- 聲音：顯示主選單時 `Audio.set_ambience(&"amb_01")`；進遊戲時由房間換掉。介面音效沿用 d1b。
- `chosen` 訊號照舊（`"new"`／`"continue"`）；新增 `credits_opened`（測試與 d2b 用不到可不接）。

### 製作說明（新增 `ui/credits.gd`、`ui/credits_text.gd`）

- `credits_text.gd`：純資料 `const LINES := [...]`，每項是 `[樣式, 文字]`（樣式：`title`／`heading`／`body`／`gap`）。內容（定稿前由 Brian 審）：
  - 標題 `GAME_TITLE`（由 `title_menu.gd` 的常數帶入）
  - 製作：Brian
  - 故事依據：《Popol Vuh》Allen J. Christenson 英譯本；Dennis Tedlock 英譯本（交叉參照）
  - 改編說明：本作是改編，非原典的忠實重述；摘 3～5 條 CULTURAL_PRINCIPLES 改編清單裡切片看得到的（例如：以溫和的交換取代燒老鼠尾巴、祖母睡著取代蚊子支開、世界沒有影子直到第一道真光）
  - AI 使用說明：美術（角色、場景、物件、插圖）與音訊（音效、環境音、配樂）由 AI 生成（OpenAI ChatGPT／Codex），每一項都經作者審核後採用；程式由作者與 AI 協作完成
  - 引擎：Godot Engine 4（MIT 授權）
  - 字型：Noto Serif TC、Noto Serif（SIL Open Font License 1.1）
  - 謝謝遊玩
- `credits.gd`（Control）：兩種模式
  - `manual`：上下鍵捲動，返回鍵（`roll`／`pause`）關閉並發 `closed`。
  - `auto`：每秒約 60 px 往上捲，捲完停 2 秒後發 `closed`；攻擊或返回鍵可跳過。
  - 背景深色半透明；用思源宋體。

### 片尾（`world/ending.gd`）

- 結尾卡只留「垂直切片到此結束，謝謝試玩。」；按掉後接 `Credits`（`auto`），`closed` 後 `done`。
- 移除舊片尾卡裡的製作資訊（已搬到製作說明）。

### 字型（`tools/font_subset.py`、`game/art/fonts/`）

- 字型精簡工具加一個輸出目標：遊戲用的 `game/art/fonts/NotoSerifTC_ui.ttf`（字重 500～700），字集＝`BASE`＋標題、選單、製作說明、退出確認用到的字（工具掃 `title_menu.gd`、`credits_text.gd` 的字串常值）。
- 產出的字型**進版控**（約 100～300 KB；打包時不用再跑工具）；OFL 授權文字一併複製到 `game/art/fonts/OFL_NotoSerifTC.txt`。

### HUD 檢查

- 用 `--shots` 加一組 HUD 狀態截圖（滿血、半血、剩 1 格、碎片 1／2、熱湯 0／2、可可豆 0 與三位數、技能槽有老鼠與冷卻中、Boss 破綻條半滿、按鍵提示），在 1280×720 與 1920×1080 各拍一次。
- AI 逐張檢查：重疊、裁切、字太小、對比不足、和背景混在一起；列成清單交 Brian 挑。**本規格不預先修 HUD**，修的項目在 Brian 挑完後補進計畫（或另開調整工單）。

### 不做

- 正式標題（MV-TITLE-001）、標題字圖、主視覺圖。
- 繪本閱讀器（d2b）。
- HUD、文字卡、過場字幕換字型。
- 設定選單、語言切換（SLICE-4）。

## 自測

1. 主選單：五個項目、「繪本」不可選、無存檔時「繼續」不可選；上下移動略過不可選的項目；「新遊戲」有存檔時要確認；「結束遊戲」要確認（測試只驗確認狀態，不真的 quit）。
2. 主選單顯示時環境音是 `amb_01`。
3. 製作說明：`manual` 模式上下捲動、返回關閉；`auto` 模式捲完自動 `closed`、按鍵可跳過。
4. 製作說明內容：含「Brian」「AI」「ChatGPT」「Christenson」「Godot」「Open Font License」；標題取自 `GAME_TITLE`。
5. 片尾：結尾卡按掉 → 製作說明（`auto`）→ `done`。
6. 字型：標題、選單、製作說明、確認文字用到的每個字都在 `NotoSerifTC_ui.ttf` 的字表裡（讀字型的 cmap 比對）；`tools` 單元測試涵蓋新的收字邏輯。
7. 既有的主選單測試（`test_walkthrough`、`test_menus`）照舊通過。
8. 全套自測全過（基準 664＋新增），沒有 `SCRIPT ERROR`／`Parse Error`／`flushing queries`／`body->get_space`。

## 風險與退路

| 風險 | 退路 |
|---|---|
| 夜色 nance 樹太暗、剪影看不清 | 夜色強度可調；剪影加一圈淡淡的月光描邊 |
| 標題畫面同時跑場景＋骨架，載入變慢 | 截圖模式量幀時間；太慢就改成靜態截圖當背景 |
| 精簡字型缺字（之後改字忘了重跑工具） | 自測比對字表；缺字就失敗 |
| HUD 檢查發現的問題很多 | 只修 Brian 挑的；其餘列進待處理 |

## 驗收標準

實作完成（AI）：

- [x] 自測全部通過（679／0）
- [x] 截圖：標題畫面（1920×1080、1280×720）、製作說明（`assets-test/d2a_shots/`）
- [x] 影片（`assets-test/d2a_video/d2a_title_tour.mp4`）：主選單 → 製作說明 → 返回 → 新遊戲 → 直接跳到結尾 → 片尾捲動 → 回主選單（`assets-test/d2a_video/`）
- [x] HUD 檢查清單（截圖＋問題列表）交 Brian（執行報告 H1～H4）

驗收（Brian）：

- [ ] 看截圖與影片；審製作說明的文字——未另外回報；製作說明「改編說明」兩點待決定
- [ ] 挑 HUD 要修的項目——待決定（H1～H4）
- [x] 手把操作主選單、看一次片尾——2026-10-20「試玩可以」（試玩紀錄沒有新錯誤）

## Git Commit

分支 `feature/MV-SLICE-001d2_外圍`（從 `develop` `0786d0f` 開）：
