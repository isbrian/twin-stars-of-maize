# MV-SLICE-001d2b 繪本前篇

更新時間：2026-10-20 17:26

## 基本資訊

| 項目 | 內容 |
|------|------|
| 分支 | `feature/MV-SLICE-001d2b_繪本前篇`（從 `develop` `dcabc8e` 開） |
| 影響範圍 | `game/ui/book_reader.gd`、`book_page.gd`、`book_style.gd`、`book_text.gd`（新）、`game/ui/title_menu.gd`、`game/main.gd`、`game/art/book/`（新，8 張 WebP）、`tools/book_export.py`、`tools/font_subset.py`、`game/art/fonts/NotoSerifTC_ui.ttf`、`game/world/shots.gd`、`game/tests/test_d2b.gd`（新） |
| 上層 | [MV-SLICE-001 總規格](MV-SLICE-001_垂直切片.md)：d2 拆成 [d2a](MV-SLICE-001d2a_標題與製作說明.md) → d2b（本文件）（SLICE-d2-1） |
| 前置 | MV-SLICE-001d2a（主選單五個項目、`book_enabled`、介面字型）；MV-ASSET-022（B 組 4 張插圖） |
| 設計依據 | 原型 [prototypes/book-reader/](../../prototypes/book-reader/README.md)（MV-BOOK-006）；ART_SPEC 第 15 節「排版」；繪本文本 `docs/book/`（MV-BOOK-001～004） |
| 引擎 | Godot 4.7.2 |
| 狀態 | 🔄 手把試玩通過（Brian 2026-10-20「試玩可以」），推送並開 PR；見[執行報告](../../report/MV-SLICE-001d2b_繪本前篇_2026-10-20_2317_執行報告.md) |

## 背景與目的

d2a 做完了正式的標題畫面，但主選單的「繪本」還是灰色、不能選。繪本前篇（8 頁）是給沒讀過《Popol Vuh》的玩家看的前情：雙胞胎的父輩怎麼打球、怎麼驚動西巴爾巴。前篇的閱讀器在原型裡已經做好、也校過稿（MV-BOOK-006、007），插圖 8 張也都定稿了（A 組 4 張；B 組 4 張是 MV-ASSET-022）。d2b 把前篇搬進遊戲，並在玩家第一次開新遊戲時問一句要不要先讀。

## 盤點（2026-10-20，AI 實查）

- 原型 `prototypes/book-reader/`（獨立 Godot 專案）：
  - `book_reader.gd`：翻頁（0.3 秒交叉淡入淡出）、轉場中再翻頁就直接做完轉場、語言切換、最後一頁再往下翻或按返回發 `closed`；輸入用 `_unhandled_input`（`page_next`／`page_prev`／`book_back`／`lang_toggle`）＋滑鼠點左右半邊。
  - `book_page.gd`：插圖（`res://art/book_{volume}_{NN}.png`，缺圖時用素色底＋「插圖製作中」）、左側 1/4 半透明底板（右緣 64 px 淡出）、標題、正文（依 `\n` 分段）、「遊戲裡：」註記（前篇沒有）、頁碼「前篇 N／8」。文字用 `tr()` 讀翻譯表。
  - `book_style.gd`：ART_SPEC 第 15 節的版面數值（1920×1080、直欄 480、邊距、顏色、字級／行高／字重）；字型用 `FontVariation` 設字重（繁中標題 700、正文 500、頁碼 500）。
  - `text/book_text.csv`：`tools/book_export.py` 從 `docs/book/` 匯出（keys／zh_TW／en）；前篇 8 頁各有 `_TITLE`、`_BODY`，沒有 `_NOTE`。前篇繁中標題＋正文共用 293 個不同的字。
  - `tests/self_test.gd`：版面（文字不超出頁碼線）、翻頁、轉場、語言切換等。
- 插圖：`assets-test/book_front/final/book_front_01～08.png`（1920×1080，每張約 2 MB，不進版控）；B 組 4 張 Brian 2026-10-20 接受（BF-05 地上的笑臉石雕＝丘文的雕刻作品，不算神像）。WebP 品質 90 實測每張 119～319 KB、8 張合計約 1.8 MB。
- 遊戲：
  - `ui/title_menu.gd`：`book_enabled := false`、`can_choose("繪本")`；`chosen(mode)` 發 `"new"`／`"continue"`；新遊戲有存檔時要再按一次確認。
  - `ui/menu_input.gd`：選單用 `MenuInput.just()` 輪詢、開關畫面時 `swallow()`；按鍵是 `look_up`／`look_down`／`move_left`／`move_right`／`attack`／`ui_accept`／`roll`／`pause`。
  - `ui/credits.gd`：開在主選單上的子畫面（`closed` 訊號、`process_mode = ALWAYS`），d2b 的閱讀器照同一個模式。
  - 介面字型 `art/fonts/NotoSerifTC_ui.ttf`：字重 500～700 的可變字型，字集來自 `tools/font_subset.py` 掃 `title_menu.gd`、`credits_text.gd` 的字串常值（目前 275 字）。
  - 音效表已有 `ui_page_open`、`ui_page_close`。

## 定案（Brian，2026-10-20）

| ID | 議題 | 定案 | 理由 |
|---|---|---|---|
| SLICE-d2b-1 | B 組插圖 | 4 張都接受；BF-05 的石雕不算神像（丘文的雕刻作品） | 笑臉、簡單的小石人像工匠的練習作，沒有神祇的頭飾或符號 |
| SLICE-d2b-2 | 入口 | 主選單「繪本」＋第一次選新遊戲時問「要先讀繪本嗎？」 | VISION：前篇在第一次開始前可選擇閱讀；對馬雅神話零基礎的玩家最有幫助 |
| SLICE-d2b-3 | 插圖格式 | WebP 品質 90，進版控（`game/art/book/`） | 8 張約 1.8 MB；平塗畫風壓縮後看不出差別 |
| SLICE-d2b-4 | 字型 | 整併成一個介面字型：`NotoSerifTC_ui.ttf` 加入前篇繁中文本的字 | 只維護一個字型檔；字型涵蓋測試一起檢查 |
| SLICE-d2b-5 | 翻頁按鍵 | 左右鍵翻頁、攻擊鍵／Enter 下一頁、翻滾／暫停鍵離開；最後一頁再往下翻＝讀完 | 沿用遊戲的選單按鍵；滑鼠左鍵就是攻擊鍵，已經是下一頁，不移植原型的點左右半邊 |
| SLICE-d2b-6 | 詢問方式 | 主選單下方出現兩個選項「讀繪本／直接開始」；問過一次（不論選哪個）就不再問，記在 `user://book_asked.json` | 和存檔分開，新遊戲蓋掉存檔也不會重問；之後想讀走主選單「繪本」 |
| SLICE-d2b-7 | 讀完去向 | 從主選單進來 → 回主選單；從新遊戲詢問進來 → 直接開始新遊戲。讀完與中途離開一樣處理；不記錄讀到第幾頁 | 8 頁很短 |
| SLICE-d2b-8 | 聲音 | 保留主選單的森林環境音；開繪本、翻頁放 `ui_page_open`，離開放 `ui_page_close` | 不用新素材 |
| SLICE-d2b-9 | 文字來源 | `tools/book_export.py` 另產 `game/ui/book_text.gd`（前篇繁中的標題與正文常數）；自測比對它與 CSV 一致 | 和 `credits_text.gd` 同一種做法；字型工具本來就掃 .gd 字串；不用載入翻譯表 |
| SLICE-d2b-10 | 缺圖備援 | 不移植；自測檢查 8 張都在 | 8 張都定稿且進版控，缺圖是不該發生的狀態 |
| SLICE-d2b-11 | 原型 | `prototypes/book-reader/` 保留不動 | 後篇 20 頁與英文版還在用它校稿 |
| SLICE-d2b-12 | 驗收 | 自測＋8 頁截圖（比對原型版面）＋Brian 手把試玩 | 截圖驗排版與字型；試玩驗兩個入口、翻頁手感、詢問只出現一次 |

（沿用 d2a：SLICE-d2-3 只出繁中；SLICE-4 不做語言切換。）

## 範圍

### 文字匯出（`tools/book_export.py`）

- 原本的 CSV 照舊輸出；另寫 `game/ui/book_text.gd`：

  ```gdscript
  extends RefCounted
  # 由 tools/book_export.py 從 docs/book/ 產生，不要手改（MV-SLICE-001d2b）。
  const FRONT := [
  	["世界還沒有真正的太陽", "最初，一切都靜悄悄的。…"],  # [標題, 正文（段落以 \n 分隔）]
  	…（8 項）
  ]
  ```
- 只放前篇繁中；字串用 GDScript 的跳脫規則（`\n`、`\"`、`\\`）。

### 字型（`tools/font_subset.py`）

- `UI_SOURCES` 加 `game/ui/book_text.gd`，以及閱讀器裡會顯示的字串（頁碼「前篇 %d／%d」、詢問文字）所在的檔案；重產 `NotoSerifTC_ui.ttf`（預估約 400～500 KB）。
- 字重範圍照舊 500～700。

### 閱讀器（新增 `game/ui/book_reader.gd`、`book_page.gd`、`book_style.gd`）

- 從原型移植，改動：
  - **只有前篇、只有繁中**：拿掉 `volume`、語言切換、英文字型、`tr()`、缺圖備援、「遊戲裡」註記；文字讀 `BookText.FRONT`。
  - **字型**：用 `NotoSerifTC_ui.ttf` 建 `FontVariation`，字重照 `book_style.gd` 的繁中數值（標題 700、正文 500、頁碼 500）；版面數值（直欄、邊距、顏色、字級、行高、段距）原樣保留，和原型的截圖一致。
  - **插圖**：`res://art/book/book_front_%02d.webp`。
  - **輸入**：每幀用 `MenuInput.just()` 輪詢（同 `credits.gd`）——`move_right`／`attack`／`ui_accept` 下一頁；`move_left` 上一頁；`roll`／`pause` 離開。開啟時 `MenuInput.swallow()`，關閉時也 `swallow()`，按鍵不穿透到主選單。
  - **縮放**：版面固定 1920×1080；專案已設 `canvas_items` 等比縮放（基準 1920×1080），1280×720 視窗由引擎縮小，閱讀器不另做縮放。
- 介面：`signal closed`、`open(index := 1)`、`next_page()`、`prev_page()`、`index`；`closed` 只發一次。
- 聲音：開啟與翻頁 `Audio.play(&"ui_page_open")`；離開（含讀完）`ui_page_close`。第一頁往前翻不出聲、不動作。

### 主選單（`game/ui/title_menu.gd`）

- `book_enabled` 拿掉，「繪本」一律可選；選了就開閱讀器（同製作說明：子畫面、關閉後回選單）。
- 新遊戲詢問：選「新遊戲」時（有存檔的話，在「再按一次確認」之後），若 `user://book_asked.json` 不存在，就在選單下方出現兩個選項「讀繪本」「直接開始」（上下選，攻擊／Enter 決定，翻滾＝直接開始），文字「要先讀繪本嗎？」；不論選哪個，先寫入 `book_asked.json`。
  - 讀繪本 → 開閱讀器；`closed` 之後 `chosen.emit("new")`。
  - 直接開始 → `chosen.emit("new")`。
- 記錄檔路徑做成變數 `book_asked_path`（自測改成 `user://test_*`，不碰正式的檔）。寫入失敗時照常開始新遊戲（下次再問一次即可）。

### 截圖（`game/world/shots.gd`）

- `_menu_shots` 加：繪本 8 頁（1920×1080）、第 1 頁（1280×720）、新遊戲詢問。檔名 `book_front_01`～`08`、`book_front_01_720`、`title_book_ask`。

### 不做

- 繪本後篇（20 頁、還沒有插圖）。
- 英文版、語言切換（SLICE-4）。
- 記錄讀到第幾頁、繪本專用音樂。
- 滑鼠點左右半邊翻頁。
- 改動原型。

## 自測（`game/tests/test_d2b.gd`）

1. 文字：`BookText.FRONT` 有 8 項，每項標題與正文非空；和 `prototypes/book-reader/text/book_text.csv` 的 `BOOK_FRONT_NN_TITLE`／`_BODY` 繁中欄逐字相同（匯出後忘了重跑會被抓到）。
2. 插圖：`res://art/book/book_front_01～08.webp` 都存在、可載入、1920×1080。
3. 字型：`BookText.FRONT` 與閱讀器、詢問用到的每個字都在 `NotoSerifTC_ui.ttf` 裡（d2a 的字型涵蓋測試一併擴充）。
4. 版面：每一頁的文字底部不超過 `TEXT_LIMIT`（原型同名測試的移植）。
5. 翻頁：下一頁、上一頁、第一頁往前不動、轉場中再翻頁直接做完轉場；最後一頁再往下 → `closed` 一次；返回鍵 → `closed` 一次；連按兩次只發一次。
6. 輸入穿透：從主選單開繪本、按返回關閉，那一下不觸發主選單的選項。
7. 主選單：「繪本」可選、選了開閱讀器、關閉後回選單（`chosen` 沒有發）。
8. 新遊戲詢問：
   - 沒有記錄檔 → 出現詢問；選「直接開始」→ 寫入記錄檔並 `chosen("new")`。
   - 選「讀繪本」→ 開閱讀器，關閉後 `chosen("new")`。
   - 有記錄檔 → 不問，直接 `chosen("new")`。
   - 有存檔時：先確認覆蓋，再詢問。
9. 聲音：開啟與翻頁放 `ui_page_open`、離開放 `ui_page_close`；繪本開著時環境音仍是 `amb_01`。
10. 既有測試照舊通過（d2a 的 `test_menu_items_and_book_disabled`、`test_cursor_skips_disabled` 依新規則改預期）；全套自測全過，沒有 `SCRIPT ERROR`／`Parse Error`。

## 風險與退路

| 風險 | 退路 |
|---|---|
| 介面字型換成可變字型的 `FontVariation` 後，標題畫面的字變粗或變細 | 標題與製作說明照舊直接用字型檔（預設字重）；只有繪本用 `FontVariation`；截圖比對 d2a |
| WebP 匯入後 Godot 又存成無損，打包變大 | 匯入設定設 Lossy（品質 0.9）；d3 打包時量檔案大小 |
| 字型加了 293 字後變大 | 預估仍在 500 KB 內；超過 1 MB 再評估改成兩個檔 |
| 截圖和原型版面不同（字型、行高） | 和原型 `--screenshot` 的輸出並排比對；不同時以原型為準 |
| `user://` 寫不進去 | 照常開始新遊戲，下次再問一次 |

## 驗收標準

實作完成（AI）：

- [x] 自測全部通過（699／0）
- [x] 截圖：繪本 8 頁（1920×1080）、第 1 頁（1280×720）、新遊戲詢問（`assets-test/d2b_shots/`），並和原型截圖並排比對（第 2 頁平均像素差 1.1）
- [x] `tools` 單元測試涵蓋 `book_text.gd` 的產生（`tools/test_book_export.py`）

驗收（Brian）：

- [x] 看 8 頁截圖——2026-10-21「試玩看圖像沒什麼問題」
- [x] 手把試玩（2026-10-20「試玩可以」，試玩日誌沒有錯誤）：主選單「繪本」讀完回選單；第一次新遊戲出現詢問、讀完直接開始；第二次新遊戲不再問

## Git Commit

分支 `feature/MV-SLICE-001d2b_繪本前篇`（從 `develop` `dcabc8e` 開）。
