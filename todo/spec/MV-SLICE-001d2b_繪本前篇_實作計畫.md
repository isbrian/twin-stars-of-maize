# MV-SLICE-001d2b 繪本前篇 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把原型的繪本閱讀器（前篇 8 頁、繁中）搬進遊戲，開放主選單「繪本」，並在第一次開新遊戲時詢問要不要先讀。

**Architecture:** 文字由 `tools/book_export.py` 從 `docs/book/` 另產 `game/ui/book_text.gd`（純資料常數）；閱讀器拆成 `book_style.gd`（版面數值與字型）、`book_page.gd`（一頁）、`book_reader.gd`（翻頁與輸入），照 `credits.gd` 的模式掛在主選單下當子畫面。插圖轉 WebP 進版控；介面字型 `NotoSerifTC_ui.ttf` 加入繪本的字。主選單新增「新遊戲詢問」狀態，記錄檔 `user://book_asked.json`。

**Tech Stack:** Godot 4.7.2 GDScript；Python 3（`unittest`、Pillow、fontTools）；自測 `bash /tmp/wt/st_only.sh <片段>`、全套 `bash /tmp/wt/step6.sh`；截圖 `--shots`。

**Spec:** [MV-SLICE-001d2b_繪本前篇.md](MV-SLICE-001d2b_繪本前篇.md)（Brian 2026-10-20 核准）

## Global Constraints

- 只有前篇、只有繁中（SLICE-d2-3）；不做語言切換、後篇、讀到第幾頁、繪本音樂、滑鼠點左右半邊（規格「不做」）。
- 版面數值照原型 `prototypes/book-reader/book_style.gd` 的繁中那組原樣搬（W 1920、H 1080、COL 480、FADE 64、MARGIN_L 48、MARGIN_R 36、TOP 96、BOTTOM 72、顏色、字級／行高／字重 title 36/1.35/700、body 28/1.65/500、folio 20/1.0/500、PARA_GAP 0.6、TITLE_GAP 0.9、FADE_TIME 0.3）。
- 插圖 `res://art/book/book_front_%02d.webp`（WebP 品質 90，1920×1080）；匯入設 Lossy、品質 0.9。
- 字型只用 `res://art/fonts/NotoSerifTC_ui.ttf`；繪本以 `FontVariation` 設 `wght`。
- 按鍵：`move_right`／`attack`／`ui_accept` 下一頁；`move_left` 上一頁；`roll`／`pause` 離開；一律 `MenuInput.just()` 輪詢，開關畫面 `MenuInput.swallow()`。
- 聲音：開繪本與翻頁 `ui_page_open`；離開（含讀完）`ui_page_close`；環境音不動（`amb_01`）。
- 詢問文字「要先讀繪本嗎？」，選項「讀繪本」「直接開始」；記錄檔 `user://book_asked.json`，問過一次（不論選哪個）就不再問。
- 原型 `prototypes/book-reader/` 不改。
- 註解、文件繁體中文；commit 英文、結尾 `(MV-SLICE-001d2b)`；全套自測基準 679 項。

## Review Focus

1. **繪本最後一頁按住攻擊鍵連按**：讀完只發一次 `closed`、從詢問進來的只開一次新遊戲 → Task 4 `test_ask_read_starts_once`
2. **關閉繪本那一下按鍵穿透到主選單**（返回鍵是翻滾、攻擊鍵是決定）：不觸發選單、不開確認 → Task 4 `test_book_close_does_not_choose`
3. **轉場 0.3 秒內又翻頁**：直接做完轉場，畫面上只留一頁 → Task 2 `test_turn_during_fade`
4. **有存檔又第一次開新遊戲**：先「再按一次確認」覆蓋，再出現詢問；詢問中按翻滾＝直接開始，不是取消回選單 → Task 4 `test_ask_after_overwrite_confirm`、`test_ask_roll_starts`
5. **之後改了繪本文本卻沒重跑匯出或字型**：工具測試與字型涵蓋測試抓到 → Task 1 `test_game_text_is_current`、Task 3 `test_ui_font_covers_all_text`

---

## 檔案結構

| 檔案 | 責任 | Task |
|---|---|---|
| `tools/book_export.py`、`tools/test_book_export.py`（新） | 另產 `game/ui/book_text.gd` | 1 |
| `game/ui/book_text.gd`（新，產生的） | 前篇 8 頁標題與正文 | 1 |
| `game/art/book/book_front_01～08.webp`（新）＋`.import` | 插圖 | 2 |
| `game/ui/book_style.gd`、`book_page.gd`、`book_reader.gd`（新） | 版面、一頁、翻頁 | 2 |
| `tools/font_subset.py`、`tools/test_font_subset.py`、`game/art/fonts/NotoSerifTC_ui.ttf` | 字型加繪本的字 | 3 |
| `game/ui/title_menu.gd`、`game/tests/test_d2a.gd` | 開放「繪本」、新遊戲詢問 | 4 |
| `game/tests/test_d2b.gd`（新） | 本計畫的遊戲內測試 | 2～4 |
| `game/world/shots.gd` | 繪本與詢問截圖 | 5 |
| 文件 | 報告、規格、README、todo | 5 |

---

### Task 1：文字匯出到遊戲

**Files:** Modify `tools/book_export.py`；Create `tools/test_book_export.py`、`game/ui/book_text.gd`（由工具產生）

**Interfaces:**
- Produces（`book_export.py`）：`GAME_OUT = ROOT / "game" / "ui" / "book_text.gd"`；`def game_text(data) -> str`：吃 `rows()` 的結果，回傳整個 .gd 檔的內容；`main()` 除了 CSV 也寫 `GAME_OUT`。
- Produces（`book_text.gd`，`extends RefCounted`）：`const FRONT := [[title: String, body: String], ...]`（8 項，`body` 段落以 `\n` 分隔），檔頭註解「由 tools/book_export.py 從 docs/book/ 產生，不要手改（MV-SLICE-001d2b）」。字串跳脫 `\\`、`"`、換行（`\n`）。

- [ ] **Step 1：失敗測試**（`test_book_export.py`，載入方式同 `test_font_subset.py`）
  - `test_game_text_has_eight_front_pages`：`game_text(rows())` 內含 8 個 `["`開頭的項目；第 1 項含「世界還沒有真正的太陽」；不含 `BOOK_BACK`、英文欄的「The World Before」
  - `test_game_text_escapes`：`game_text([("BOOK_FRONT_01_TITLE", {"zh": 'a"b\\c', "en": "x"}), ("BOOK_FRONT_01_BODY", {"zh": "一\n二", "en": "y"})])` 含 `"a\"b\\\\c"` 與 `"一\n二"`（字面的反斜線 n）
  - `test_game_text_is_current`：`GAME_OUT.read_text()` == `game_text(rows())`（文本改了忘了重跑會失敗）
- [ ] **Step 2：跑** `python3 -m unittest tools.test_book_export` → 失敗（`game_text` 不存在）
- [ ] **Step 3：實作**；跑 `python3 tools/book_export.py` 產出 `book_text.gd`
- [ ] **Step 4：跑** `python3 -m unittest tools.test_book_export tools.test_book_layout` 全過；`bash /tmp/wt/st_only.sh test_d2a` 仍全過（新檔能被 Godot 解析）
- [ ] **Step 5：Commit** `Export the front picture-book text into the game (MV-SLICE-001d2b)`

### Task 2：閱讀器與插圖

**Files:** Create `game/ui/book_style.gd`、`book_page.gd`、`book_reader.gd`、`game/art/book/*.webp`、`game/tests/test_d2b.gd`

**Interfaces:**
- Consumes：Task 1 的 `BookText.FRONT`
- Produces（`book_style.gd`，`extends RefCounted`）：Global Constraints 的版面常數＋`TEXT_W`、`TEXT_LIMIT`（同原型）；`const TOTAL := 8`；`const FONT_PATH := "res://art/fonts/NotoSerifTC_ui.ttf"`；`static func font(kind: String) -> FontVariation`（快取；`wght` 取 `STYLE[kind][2]`）；`static func label_settings(kind: String, color: Color) -> LabelSettings`（line_spacing 算法同原型）；`static func art_path(n: int) -> String`。`STYLE` 只留 `title`、`body`、`folio`（前篇沒有註記）。
- Produces（`book_page.gd`，`extends Control`）：`func setup(n: int) -> void`（插圖 `TextureRect` 撐滿、左側漸層底板、標題、正文段落、頁碼「前篇 %d／%d」）；`func text_bottom() -> float`；`func title_text() -> String`；`var num`。
- Produces（`book_reader.gd`，`extends Control`）：`signal closed`；`var index := 1`；`var page: Control`；`func open(p_index := 1) -> void`（放 `ui_page_open`）；`func next_page()`（最後一頁再下 → 關閉）；`func prev_page()`（第一頁不動、不出聲）；`func is_fading() -> bool`；關閉一律走 `_close()`：放 `ui_page_close`、`MenuInput.swallow()`、`closed` 只發一次。`_ready` 設 `process_mode = ALWAYS`、`size = Vector2(W, H)`；`_process` 輪詢按鍵（Global Constraints）。翻頁轉場、轉場中再翻頁先做完，照原型。

- [ ] **Step 1：插圖**：用 Pillow 把 `assets-test/book_front/final/book_front_01～08.png` 存成 `game/art/book/book_front_NN.webp`（`quality=90, method=6`）；`godot --headless --path game --import`；把 8 個 `.import` 的 `compress/mode` 改成 `1`（Lossy）、`compress/lossy_quality=0.9`，再 `--import` 一次。轉檔指令寫進 Task 5 的 README。
- [ ] **Step 2：失敗測試**（`test_d2b.gd`，`extends "res://tests/base_test.gd"`；`press()`、`process_frames()` 同 `test_d2a.gd`）
  - `test_book_text_eight_pages`：`BookText.FRONT.size() == 8`，每項標題與正文非空
  - `test_book_art_present`：8 張 `Style.art_path(n)` 都 `ResourceLoader.exists`、載入後 1920×1080
  - `test_every_page_fits`：8 頁各建 `BookPage`、等 2 幀，`text_bottom() <= Style.TEXT_LIMIT`
  - `test_page_shows_title_and_folio`：第 3 頁 `title_text() == BookText.FRONT[2][0]`、頁碼是「前篇 3／8」
  - `test_navigation`：`open()` 後 `prev_page()` 仍 1；`next_page()` 到 2；`prev_page()` 回 1
  - `test_turn_during_fade`：`next_page()` 後立刻 `next_page()` → `index == 3`、`is_fading()`、閱讀器下只剩 2 個頁面節點以內，等 `FADE_TIME` 後只剩 1 個
  - `test_last_page_closes_once`：`open(8)`、`next_page()` 兩次 → `closed` 一次
  - `test_back_key_closes_once`：`press(&"roll")` 兩次 → `closed` 一次
  - `test_keys_turn_pages`：`press(&"move_right")` → 2；`press(&"attack")` → 3；`press(&"move_left")` → 2
  - `test_book_sounds`：記下 `Audio.play_count` 的 `ui_page_open`／`ui_page_close`；`open()` 與 `next_page()` 各 +1 open；第一頁 `prev_page()` 不加；關閉 +1 close
  - `test_book_font_weights`：`Style.font("title")` 的 `base_font.resource_path == FONT_PATH`、`wght` 700；`font("body")` 500
- [ ] **Step 3：跑** `bash /tmp/wt/st_only.sh test_d2b` → 失敗（腳本不存在）
- [ ] **Step 4：實作**（從原型移植，刪掉 volume、語言、`tr()`、缺圖備援、註記、`_gui_input`、`_unhandled_input`）
- [ ] **Step 5：跑** `test_d2b` 全過
- [ ] **Step 6：Commit** `Port the picture-book reader with the eight front illustrations (MV-SLICE-001d2b)`

### Task 3：介面字型加入繪本的字

**Files:** Modify `tools/font_subset.py`、`tools/test_font_subset.py`、`game/tests/test_d2a.gd`；重產 `game/art/fonts/NotoSerifTC_ui.ttf`

**Interfaces:**
- Consumes：Task 1 的 `book_text.gd`、Task 2 的 `book_page.gd`
- Produces：`UI_SOURCES` 加 `game/ui/book_text.gd`、`game/ui/book_page.gd`（Task 4 的詢問字串在 `title_menu.gd`，已在清單裡）；模組文件字串補一句「繪本前篇的字（MV-SLICE-001d2b）」。
- 注意：`collect_ui_chars` 的字串常值正則要能處理 `book_text.gd` 的 `\"`、`\n` 跳脫（`\n` 不能讓「n」以外的字漏收；控制字元本來就濾掉）。

- [ ] **Step 1：失敗測試**
  - `test_font_subset.py::test_collect_ui_chars`：再斷言「胡」「納」「巴」「爾」（繪本正文）與「篇」（頁碼）在字集裡
  - `test_d2a.gd::test_ui_font_covers_all_text`：檢查的文字再加上 `BookText.FRONT` 全部與 `"前篇／"`
- [ ] **Step 2：跑** `python3 -m unittest tools.test_font_subset`、`bash /tmp/wt/st_only.sh test_ui_font` → 失敗（缺字）
- [ ] **Step 3：實作**；`python3 tools/font_subset.py` 重產（輸出缺字＝0；記下新大小，< 1 MB）
- [ ] **Step 4：跑** 兩個測試全過；`test_d2a`、`test_d2b` 全過
- [ ] **Step 5：Commit** `Add the picture-book characters to the UI font (MV-SLICE-001d2b)`

### Task 4：主選單開放繪本與新遊戲詢問

**Files:** Modify `game/ui/title_menu.gd`、`game/tests/test_d2a.gd`、`game/tests/test_d2b.gd`

**Interfaces:**
- Consumes：Task 2 的 `BookReader`（`open`、`closed`）
- Produces（`title_menu.gd`）：
  - 移除 `book_enabled`；`can_choose("繪本")` 一律 true。
  - `const ASK_TEXT := "要先讀繪本嗎？"`、`const ASK_ITEMS := ["讀繪本", "直接開始"]`；`var asking := false`、`var ask_cursor := 0`；`var book`（開著的閱讀器，沒有時 null）；`var book_asked_path := "user://book_asked.json"`。
  - 「繪本」→ `_open_book(false)`；「新遊戲」通過覆蓋確認後 → `_start_new()`：記錄檔存在就 `chosen.emit("new")`，否則 `asking = true`。
  - `func answer_ask(read: bool) -> void`：先寫記錄檔（`{"asked": true}`；寫入失敗忽略），`asking = false`；`read` → `_open_book(true)`，否則 `MenuInput.swallow()`＋`chosen.emit("new")`。
  - `_open_book(then_new: bool)`：建 `BookReader` 掛為子節點、`open()`；`closed` → 移除、`book = null`；`then_new` 時 `chosen.emit("new")`，否則 `queue_redraw()`。
  - `_process`：`credits` 或 `book` 開著時 return；`asking` 時上下切 `ask_cursor`（`ui_move`）、攻擊／Enter → `answer_ask(ask_cursor == 0)`、翻滾／暫停 → `answer_ask(false)`。`_draw`：`book` 開著時不畫；`asking` 時在選單下方畫 `ASK_TEXT` 與兩個選項（游標「▶」），取代確認訊息那一行。
  - `refresh()` 也重設 `asking = false`。

- [ ] **Step 1：失敗測試**（`test_d2b.gd`；建主選單時 `book_asked_path = "user://test_d2b_asked.json"` 並先刪掉）
  - `test_book_item_opens_reader`：`can_choose("繪本")`；`choose_item("繪本")` → `t.book != null`；`press(&"roll")` 後 `t.book == null`、`chosen` 沒發
  - `test_book_close_does_not_choose`：游標停在「新遊戲」時開繪本、按 `attack` 翻到最後一頁再按一次讀完 → `chosen` 沒發、`asking == false`、`confirming == false`
  - `test_first_new_game_asks`：沒有記錄檔 → `choose_item("新遊戲")` 後 `asking == true`、`chosen` 沒發
  - `test_ask_skip_starts_and_records`：`answer_ask(false)` → `chosen("new")` 一次、記錄檔存在
  - `test_ask_read_starts_once`：`answer_ask(true)` → `t.book != null`、記錄檔存在；`t.book.open(8)` 後連按三次 `attack` → `chosen("new")` 只發一次
  - `test_ask_roll_starts`：詢問中 `press(&"roll")` → `chosen("new")`
  - `test_no_ask_when_recorded`：先寫記錄檔 → `choose_item("新遊戲")` 直接 `chosen("new")`、`asking == false`
  - `test_ask_after_overwrite_confirm`：有存檔（`save_path` 指向測試存檔、先寫一份）且沒有記錄檔 → 第一次 `choose_item("新遊戲")` 是 `confirming`；第二次才 `asking`
  - `test_book_keeps_ambience`：開繪本後 `Audio.ambience == &"amb_01"`
  - `test_d2a.gd`：`test_menu_items_and_book_disabled` 改名 `test_menu_items`，斷言「繪本」可選；`test_cursor_skips_disabled` 往下從「新遊戲」到「繪本」（只跳過「繼續」）
- [ ] **Step 2：跑** `bash /tmp/wt/st_only.sh test_d2` → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `test_d2`、`test_walkthrough`、`test_menus` 全過；全套 `bash /tmp/wt/step6.sh`（unittest=0、SELFTEST 全過、errors 0）；跑完 `git checkout -- game/art/fonts/NotoSerifTC_ui.ttf`（工具單元測試會重寫時間戳；內容若有變表示 Task 3 沒產對，先查）
- [ ] **Step 5：Commit** `Open the picture book from the title and offer it before the first new game (MV-SLICE-001d2b)`

### Task 5：截圖、文件

**Files:** Modify `game/world/shots.gd`、`game/README.md`、`todo/spec/MV-SLICE-001d2b_繪本前篇.md`、`todo/spec/MV-SLICE-001_垂直切片.md`、`todo/todo.md`；Create `report/MV-SLICE-001d2b_繪本前篇_<date>_執行報告.md`

**Interfaces:**
- `shots.gd` 的 `_menu_shots` 加：開繪本、每頁等 `SETTLE_FRAMES` 拍 `book_front_01`～`08`（用 `book.open(n)` 直接跳頁，避免轉場）；關掉繪本、`book_asked_path` 設成截圖專用檔並先刪、`choose_item("新遊戲")` 拍 `title_book_ask`，拍完刪檔。`_ready` 的篩選條件加 `"book"`。

- [ ] **Step 1**：`--shots assets-test/d2b_shots` 用 `--resolution 1920x1080` 拍全部繪本與詢問；`SHOTS_ONLY=book_front_01` 用預設 1280×720 視窗拍到 `assets-test/d2b_shots/720/`（改名 `book_front_01_720.png`）
- [ ] **Step 2**：原型 `prototypes/book-reader` 跑 `--screenshot`（需視窗）拍繁中 8 頁，和遊戲版並排比對（標題、段落換行位置、底板、頁碼）；差異記進執行報告
- [ ] **Step 3**：`game/README.md` 補：繪本閱讀器、`book_asked.json`、插圖轉檔指令（Pillow WebP 90＋匯入 Lossy 0.9）、改了 `docs/book/` 要跑 `book_export.py` 與 `font_subset.py`
- [ ] **Step 4**：執行報告（時間戳先跑 `date`）、規格書驗收勾選、總規格與 todo 狀態
- [ ] **Step 5：Commit** `Shoot the picture-book pages and document d2b (MV-SLICE-001d2b)`
- [ ] **Step 6**：最終全分支審查（獨立 opus）→ 修正 → 交 Brian（8 頁截圖、手把試玩）

## 與規格的差異

- 規格「自測 1」要遊戲內比對 CSV；計畫改成在工具測試 `test_game_text_is_current` 直接比對 `book_text.gd` 與 `docs/book/` 匯出的結果（比 CSV 更接近正本，且遊戲內測試不必讀專案外的檔案）。遊戲內只驗 8 頁非空（`test_book_text_eight_pages`）。
