# MV-SLICE-001d2a 標題畫面、主選單與製作說明 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把灰盒主選單做成正式標題畫面（夜裡 nance 樹＋Seven Macaw 剪影），加五項主選單、製作說明（含 AI 揭露）與片尾捲動、介面字型，並交出 HUD 檢查清單。

**Architecture:** 製作說明拆成純資料 `ui/credits_text.gd` 與畫面 `ui/credits.gd`（manual／auto 兩種模式），主選單與片尾共用。主選單 `ui/title_menu.gd` 改寫：背景是 `SceneryView.build_boss()` 的 nance 區段＋夜色＋過場替身 `Actor.make("sevenmacaw")` 畫成剪影，選單邏輯保留既有規則再加三項。字型由 `tools/font_subset.py` 新增的 UI 目標產出、進版控，自測比對字表。

**Tech Stack:** Godot 4.7.2 GDScript；Python 3＋fontTools（`tools/font_subset.py`）；自測 `bash /tmp/wt/st_only.sh <片段>`、全套 `bash /tmp/wt/step6.sh`；截圖 `--shots`；影片 `--write-movie`＋ffmpeg。

**Spec:** [MV-SLICE-001d2a_標題與製作說明.md](MV-SLICE-001d2a_標題與製作說明.md)（Brian 2026-10-20 核准）

## Global Constraints

- `const GAME_TITLE := "Popol Vuh 垂直切片"` 放在 `ui/title_menu.gd`，全專案只此一處（MV-TITLE-001 定案後只改這行）。
- `ITEMS := ["新遊戲", "繼續", "繪本", "製作說明", "結束遊戲"]`；「繪本」由 `var book_enabled := false` 控制（d2b 改 true）。
- 標題、選單、製作說明、退出確認用 `res://art/fonts/NotoSerifTC_ui.ttf`；HUD、文字卡、過場字幕不動。
- 製作說明自動捲動 60 px／秒，捲完停 2 秒；攻擊或返回鍵跳過。
- 主選單顯示時 `Audio.set_ambience(&"amb_01")`；介面音效沿用 `ui_move`／`ui_confirm`／`ui_back`。
- 作者署名「Brian」；AI 揭露：美術與音訊由 AI 生成（OpenAI ChatGPT／Codex），每一項經作者審核；程式由作者與 AI 協作。
- 註解、文件繁體中文；commit 英文、結尾 `(MV-SLICE-001d2a)`；全套自測基準 664 項。

## Review Focus

1. **沒有存檔時開主選單**：游標預設落在可選的「新遊戲」，上下移動跳過「繼續」與「繪本」，不會停在不可選的項目上 → Task 2 `test_cursor_skips_disabled`
2. **製作說明開著時按到主選單的鍵**：按返回只關製作說明、不觸發選單（`MenuInput.swallow`） → Task 2 `test_credits_close_does_not_choose`
3. **片尾自動捲動中直接按攻擊**：跳過後只發一次 `closed`、回主選單一次 → Task 1 `test_auto_skip_closes_once`
4. **退出確認中按上下或返回**：取消確認、不會退出 → Task 2 `test_quit_confirm_cancels`
5. **之後改了選單或製作說明的字卻沒重產字型**：自測抓缺字 → Task 3 `test_ui_font_covers_all_text`

---

## 檔案結構

| 檔案 | 責任 | Task |
|---|---|---|
| `game/ui/credits_text.gd`（新） | 製作說明內容（純資料） | 1 |
| `game/ui/credits.gd`（新） | 製作說明畫面（manual／auto） | 1 |
| `game/world/ending.gd` | 結尾卡 → 自動捲動 → done | 1 |
| `game/ui/title_menu.gd` | 標題畫面背景、五項選單、退出確認 | 2 |
| `tools/font_subset.py`、`tools/test_font_subset.py` | UI 字型目標 | 3 |
| `game/art/fonts/NotoSerifTC_ui.ttf`、`OFL_NotoSerifTC.txt`（新） | 介面字型 | 3 |
| `game/world/shots.gd` | HUD 狀態截圖 | 4 |
| `game/world/title_tour.gd`（新）、`launch_args.gd`、`main.gd` | 開發用 `--title-tour` 錄影 | 4 |
| `game/tests/test_d2a.gd`（新） | 本計畫的測試 | 1～3 |
| 文件 | 報告、規格、README、todo | 4 |

---

### Task 1：製作說明與片尾

**Files:** Create `game/ui/credits_text.gd`、`game/ui/credits.gd`、`game/tests/test_d2a.gd`；Modify `game/world/ending.gd`

**Interfaces:**
- Produces（`credits_text.gd`，`extends RefCounted`）：`const LINES := [[style: String, text: String], ...]`，`style` ∈ `"title"`／`"heading"`／`"body"`／`"gap"`；第一列是 `["title", ""]`（標題由畫面填 `GAME_TITLE`，避免互相 preload）。內容照規格書「製作說明」各點。
- Produces（`credits.gd`，`extends Control`）：`signal closed`；`var mode := "manual"`（或 `"auto"`）；`var title := ""`；`var scroll := 0.0`；`func content_height() -> float`；`const AUTO_SPEED := 60.0`、`const AUTO_HOLD := 2.0`；`process_mode = ALWAYS`；manual：`look_up`／`look_down` 捲動、`roll`／`pause` 關閉；auto：每幀捲、捲到 `content_height()` 後停 `AUTO_HOLD` 秒 `closed`，`attack`／`roll`／`pause` 跳過；`closed` 只發一次。
- `ending.gd`：結尾卡文字只留「垂直切片到此結束，謝謝試玩。」；卡片 `closed` 後建 `Credits`（`mode = "auto"`、`title = TitleMenu.GAME_TITLE`）掛同一個 CanvasLayer，`closed` 後 `done.emit()`。

- [ ] **Step 1：失敗測試**（`test_d2a.gd`）
  - `test_credits_text_discloses`：把 `LINES` 的文字接起來，包含「Brian」「AI」「ChatGPT」「Codex」「Christenson」「Tedlock」「Godot」「Open Font License」「協作」
  - `test_credits_manual_scroll_and_close`：manual 模式按 `look_down` 數幀後 `scroll > 0`；按 `roll` 發 `closed`
  - `test_credits_auto_finishes`：auto 模式、把 `AUTO_SPEED` 等效加速（測試設 `scroll = content_height()`）後 `AUTO_HOLD + 0.2` 秒內發 `closed`
  - `test_auto_skip_closes_once`：auto 模式連按兩次 `attack`，`closed` 只發一次
  - `test_ending_runs_credits`：建 `Ending`（`tn.card_min_time = 0`），確認結尾卡後出現 `Credits`（auto），跳過後 `done` 發一次
- [ ] **Step 2：跑** `bash /tmp/wt/st_only.sh test_d2a` → 失敗
- [ ] **Step 3：實作**（`_draw` 依 `style` 畫不同字級；暫用 `ThemeDB.fallback_font`，Task 3 換字型）
- [ ] **Step 4：跑** `test_d2a`、`test_walkthrough`、`test_cutscene` 全過
- [ ] **Step 5：Commit** `Add the credits screen with the AI disclosure and roll it after the ending (MV-SLICE-001d2a)`

### Task 2：標題畫面與五項主選單

**Files:** Modify `game/ui/title_menu.gd`、`game/main.gd`、`game/tests/test_d2a.gd`

**Interfaces:**
- Consumes：Task 1 的 `Credits`
- Produces（`title_menu.gd`）：`const GAME_TITLE`、`const ITEMS`（Global Constraints）；`var book_enabled := false`；`var confirming_quit := false`；`func can_choose(item: String) -> bool`（「繼續」看存檔、「繪本」看 `book_enabled`、其餘 true）；`func move_cursor(dir: int) -> void`（略過不可選）；`func choose_item(item: String)` 擴充：「製作說明」開 `Credits`（manual），關閉時 `MenuInput.swallow()`；「結束遊戲」第一次設 `confirming_quit`、第二次 `quit_requested.emit()`（`signal quit_requested`；`main.gd` 接 `get_tree().quit()`）；上下、返回取消確認。
- 背景：`_ready` 建 `SubViewportContainer`＋`SubViewport`（或直接在 CanvasLayer 下掛 `Node2D` 世界＋`Camera2D`），內放 `SceneryView.build_boss()`、`night = true`；`Actor.make("sevenmacaw")` 放在 `Nance.CANOPY`、`play("idle_perch")`、`set_black(true)`；鏡頭在 nance 區段 x 方向 ±200 px、20 秒一個來回緩移。選單與標題畫在背景之上；`refresh()` 時 `Audio.set_ambience(&"amb_01")`。

- [ ] **Step 1：失敗測試**
  - `test_menu_items_and_book_disabled`：`ITEMS` 五項；`can_choose("繪本") == false`；`book_enabled = true` 後為 true
  - `test_cursor_skips_disabled`：無存檔、`book_enabled = false`，游標起點是 0（新遊戲）；`move_cursor(1)` 到「製作說明」（跳過「繼續」「繪本」）；`move_cursor(-1)` 回「新遊戲」
  - `test_credits_from_menu`：`choose_item("製作說明")` 後有一個 manual `Credits`；它 `closed` 後被移除、選單仍在
  - `test_credits_close_does_not_choose`：開製作說明、按 `roll` 關閉，同一幀 `chosen` 不發、`confirming_quit` 為 false
  - `test_quit_confirm_cancels`：`choose_item("結束遊戲")` → `confirming_quit`；按 `look_down` → false；再選兩次 → `quit_requested` 發一次
  - `test_title_ambience`：主選單 `_ready` 後 `Audio.ambience == &"amb_01"`
  - `test_title_background_built`：主選單底下有 `SceneryView`（`night == true`）與 Seven Macaw 替身（剪影）
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `test_d2a`、`test_walkthrough`（含既有的 `test_title_continue_disabled_without_save`、`test_title_fills_screen_under_canvas_layer`）、`test_menus` 全過
- [ ] **Step 5：Commit** `Turn the main menu into a title screen with the night nance tree and five items (MV-SLICE-001d2a)`

### Task 3：介面字型

**Files:** Modify `tools/font_subset.py`、`tools/test_font_subset.py`、`game/ui/title_menu.gd`、`game/ui/credits.gd`、`game/tests/test_d2a.gd`；Create `game/art/fonts/NotoSerifTC_ui.ttf`、`game/art/fonts/OFL_NotoSerifTC.txt`

**Interfaces:**
- Produces（`font_subset.py`）：`UI_SOURCES = [game/ui/title_menu.gd, game/ui/credits_text.gd]`；`def collect_ui_chars(paths=UI_SOURCES) -> set`（抓 `"…"` 字串常值裡的可列印字＋`BASE`＋`EXTRA`）；`main()` 另產 `game/art/fonts/NotoSerifTC_ui.ttf`（字重 500～700，同繪本設定），並複製 `assets/fonts/OFL_NotoSerifTC.txt` 到同資料夾；UI 缺字也讓結束碼 1。
- `title_menu.gd`、`credits.gd`：`const UI_FONT := preload("res://art/fonts/NotoSerifTC_ui.ttf")` 取代 `ThemeDB.fallback_font`。

- [ ] **Step 1：失敗測試**
  - `tools/test_font_subset.py` `test_collect_ui_chars`：含「製」「說」「離」「▶」，不含換行
  - `test_d2a.gd` `test_ui_font_covers_all_text`：讀 `NotoSerifTC_ui.ttf`（`FontFile` 的 `has_char`），`GAME_TITLE`、`ITEMS`、`LINES` 全部文字、退出確認文字、新遊戲確認文字的每個可列印字都有
- [ ] **Step 2：跑** `python3 -m unittest tools/test_font_subset.py` 與 `test_d2a` → 失敗
- [ ] **Step 3：實作**，跑 `python3 tools/font_subset.py`（結束碼 0），`godot --headless --path game --import`
- [ ] **Step 4：跑** 單元測試、`test_d2a`、`test_walkthrough` 全過；字型檔大小記下（預期 100～300 KB）
- [ ] **Step 5：Commit** `Set the title screen and credits in a subset of Noto Serif TC (MV-SLICE-001d2a)`

### Task 4：HUD 檢查、展示影片與文件

**Files:** Modify `game/world/shots.gd`、`game/launch_args.gd`、`game/main.gd`、`game/README.md`、規格、`todo/todo.md`；Create `game/world/title_tour.gd`、`report/MV-SLICE-001d2a_標題與製作說明_<date>_執行報告.md`

**Interfaces:**
- `shots.gd`：新增 HUD 截圖（名稱 `hud_*`）：`full`（滿血）、`half`（半血＋1 片碎片）、`low`（剩 1 格、熱湯 0／2）、`rich`（可可豆 123、熱湯 2／2）、`skill`（技能槽有老鼠、冷卻中）、`boss`（Boss 破綻條半滿）、`hint`（按鍵提示顯示中）；用既有的 `_setup` 字串擴充；另加 `title`（主選單）、`credits`（製作說明開頭）
- `--title-tour`（開發版，同 `--sound-tour` 做法）：主選單 3 秒 → 上下移動 → 製作說明（manual 捲動 5 秒）→ 返回 → 結束遊戲確認後取消 → 新遊戲 → `dev_start("exit")` → 結尾卡 → 自動捲動完 → 回主選單 3 秒 → 結束

- [ ] **Step 1：截圖**：`godot --path game --resolution 1920x1080 -- --shots assets-test/d2a_shots/1080`，再以 `1280x720` 拍一次；AI 逐張看 HUD（重疊、裁切、字太小、對比、和背景混在一起），寫成問題清單（編號、截圖、說明、建議）
- [ ] **Step 2：影片**：`--write-movie /tmp/wt/d2a_tour.avi -- --title-tour` → mp4（`assets-test/d2a_video/`）；抽格檢查
- [ ] **Step 3：全套** `bash /tmp/wt/step6.sh` → `fail=0`、`errors: 0`
- [ ] **Step 4：文件**：README 加「標題畫面與製作說明」（`GAME_TITLE` 在哪、字型怎麼重產、`--title-tour`）；執行報告（含 HUD 問題清單）；規格勾選；todo
- [ ] **Step 5：Commit** `Shoot the HUD check, record the title tour and document d2a (MV-SLICE-001d2a)`
- [ ] **Step 6**：最終全分支審查 → 修正 → 交 Brian（截圖、影片、製作說明文字、HUD 清單）
