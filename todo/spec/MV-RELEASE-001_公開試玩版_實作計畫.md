# MV-RELEASE-001 公開試玩版 v0.1.0 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把垂直切片改名「雙子星玉米人」、清掉公開不該有的東西、匯出 Windows／macOS／網頁三版，並備妥公開倉庫 `twin-stars-of-maize` 的快照；外部發佈每一步經 Brian 同意。

**Architecture:** 私人倉庫裡完成所有改動與檢查；發版工具 `tools/release.py` 有三個子指令——`scan`（掃描禁用內容）、`snapshot`（`git archive` 指定 tag＋加入 `release/public/` 的公開專用檔，輸出前必過 `scan`）、`build`（`godot --export-release` 三個預設並打包）。禁用字串在執行時從本機環境取得（家目錄、倉庫所在磁碟路徑、git 作者信箱），原始碼不寫死，所以工具與文件不會掃到自己。英文繪本另有 `tools/quote_check.py` 對照譯本，結果交 Brian。

**Tech Stack:** Godot 4.7.2 匯出範本；Python 3（`unittest`、`zipfile`、`subprocess`）；`gitleaks`（已裝）；`gh`。

**Spec:** [MV-RELEASE-001_公開試玩版.md](MV-RELEASE-001_公開試玩版.md)（Brian 2026-10-21 核准）

## Global Constraints

- 標題 `雙子星玉米人`／`Twin Stars of Maize`；副標「試玩版」；版號 `0.1.0`；倉庫 `isbrian/twin-stars-of-maize`（公開）、`isbrian/twin-stars-of-maize-dev`（私人）。
- 產出檔名：`TwinStarsOfMaize-v0.1.0-windows.zip`、`TwinStarsOfMaize-v0.1.0-macos.zip`、網頁版資料夾（入口 `index.html`）；macOS bundle id `net.isbrian.twinstarsofmaize`，ad-hoc 簽章；網頁版單執行緒。
- 授權：`LICENSE` MIT（`game/` 的 `.gd` 與 `tools/`）；`LICENSE-ASSETS.md` 美術、音訊、文件保留所有權利；字型 OFL 照舊。
- 原典出處的「Popol Vuh」可以留（片尾、文件、下載頁）；**標題、App 名稱、倉庫名不得含聖典名**。
- 不改寫私人倉庫的歷史；快照不帶歷史。
- **外部動作**（下載以外：改倉庫名、建倉庫、推送公開倉庫、Release、Pages）一律先問 Brian，計畫內只準備到「可以按下去」為止（Task 6）。匯出範本下載已核准（REL-10）。
- 註解、文件繁體中文；commit 英文、結尾 `(MV-RELEASE-001)`；全套自測基準 699。

## Review Focus

1. **快照漏掉本機路徑或信箱**（藏在報告、計畫的指令範例裡）：`scan` 掃到任何一個就失敗、列出檔案與行號，快照不輸出 → Task 2 `test_scan_flags_home_path`、`test_scan_flags_author_email`、Task 5 `test_snapshot_refuses_dirty`
2. **快照意外帶進不該公開的資料夾**（`sources/`、`assets-test/`、`.superpowers/`、`build/`）：`snapshot` 只取 `git archive` 的內容，掃描再擋一次 → Task 5 `test_snapshot_excludes_untracked_dirs`
3. **改了 App 名稱後，舊的測試或文件還寫著舊存檔路徑**：遊戲內不再出現舊名 → Task 1 `test_no_sacred_name_in_title`
4. **網頁版在 Compatibility 渲染器下壞掉**（畫面全黑、沒有聲音、手把無效）：本機實測並截圖，壞了就照退路不出網頁版 → Task 4 Step 6（實機，無自動測試）
5. **文件裡寫到禁用字串本身會讓掃描誤判**（規格、計畫描述「本機路徑」時）：禁用字串由執行環境產生、文件只用描述文字 → Task 2 `test_scan_patterns_not_in_source`

---

## 檔案結構

| 檔案 | 責任 | Task |
|---|---|---|
| `game/ui/title_menu.gd`、`game/project.godot`、`game/art/fonts/NotoSerifTC_ui.ttf` | 新標題、App 名稱、版號 | 1 |
| `game/tests/test_release.gd`（新） | 標題與版號的遊戲內測試 | 1 |
| `docs/design/MV-NAME-001_名稱表.md`、`README.md`、`VISION.md`、`CULTURAL_PRINCIPLES.md`、`game/README.md` | 標題定案的文件 | 1 |
| `tools/release.py`（新）、`tools/test_release.py`（新） | `scan`／`snapshot`／`build` | 2、4、5 |
| 5 份文件＋公開評估報告 | 去掉本機路徑與信箱 | 2 |
| `tools/quote_check.py`（新）、`tools/test_quote_check.py`（新）、`report/MV-RELEASE-001_英文繪本對照_<時間>.md`（新） | 英文繪本對照 | 3 |
| `game/export_presets.cfg`（新）、`.gitignore` | 三個匯出預設；`build/` 不進版控 | 4 |
| `release/public/README.md`、`LICENSE`、`LICENSE-ASSETS.md`、`.github/ISSUE_TEMPLATE/playtest.md`（新） | 公開倉庫專用檔 | 5 |
| 報告、規格、todo | 收尾 | 6 |

---

### Task 1：標題、App 名稱、版號

**Files:** Modify `game/ui/title_menu.gd`、`game/project.godot`、`game/world/ending.gd`；Create `game/tests/test_release.gd`；重產字型；文件見檔案結構

**Interfaces:**
- Produces（`title_menu.gd`）：`const GAME_TITLE := "雙子星玉米人"`；`static func display_title() -> String`（回傳 `"%s v%s" % [GAME_TITLE, ProjectSettings.get_setting("application/config/version")]`）。主選單與片尾的製作說明 `credits.title = TitleMenu.display_title()`（主選單畫面上方的大標題仍是 `GAME_TITLE`）。
- Produces（`project.godot`）：`config/name="雙子星玉米人"`、`config/version="0.1.0"`。

- [ ] **Step 1：失敗測試**（`test_release.gd`）
  - `test_title_is_final`：`TitleMenu.GAME_TITLE == "雙子星玉米人"`、`ProjectSettings.get_setting("application/config/name") == "雙子星玉米人"`
  - `test_no_sacred_name_in_title`：`GAME_TITLE`、App 名稱、`display_title()` 都不含 `"Popol"`、`"波波爾"`、`"烏"`
  - `test_display_title_has_version`：`TitleMenu.display_title() == "雙子星玉米人 v0.1.0"`
  - `test_credits_show_version`：建 `Ending`（同 `test_d2a.test_ending_runs_credits` 的做法），確認結尾卡後 `e.credits.title == TitleMenu.display_title()`
  - `test_d2a.test_credits_from_menu` 的斷言改成 `c.title == TitleMenu.display_title()`
- [ ] **Step 2：跑** `bash /tmp/wt/st_only.sh test_release` → 失敗
- [ ] **Step 3：實作**；`python3 tools/font_subset.py`（缺字＝0）；`godot --headless --path game --import`
- [ ] **Step 4：文件**：名稱表第 6 節加「定案（2026-10-21）」：REL-6、REL-7 全文（中英名、和 yo'x 的區別、英文不用 Maize Twins 的理由、列入學者審閱清單）；`README.md` 第 3 行、`VISION.md` 第 11 行、`CULTURAL_PRINCIPLES.md` 第 15 行改成「正式標題：雙子星玉米人（Twin Stars of Maize）；『波波爾·烏』只是內部代號」；`game/README.md` 存檔路徑改 `app_userdata/雙子星玉米人/`；`todo.md` MV-TITLE-001 改 ✅ 完成
- [ ] **Step 5：跑** `test_release`、`test_d2a`、`test_walkthrough` 全過
- [ ] **Step 6：Commit** `Name the game Twin Stars of Maize and stamp v0.1.0 (MV-RELEASE-001)`

### Task 2：禁用內容掃描與清理

**Files:** Create `tools/release.py`、`tools/test_release.py`；Modify 5 份含本機路徑的文件、`report/GITHUB_PUBLIC_REVIEW_2026-10-20_0223.md`、`todo/spec/MV-RELEASE-001_公開試玩版.md`（盤點段落改成描述文字）

**Interfaces:**
- Produces（`release.py`）：
  - `def forbidden_patterns(repo: Path) -> list[str]`：執行時產生——`str(Path.home())`、倉庫所在的磁碟掛載路徑（`repo.resolve()` 的前 3 段，例如 `/Volumes/<磁碟名>`；不在 `/Volumes` 下時略過）、`git log --format=%ae` 的所有信箱裡不是 `users.noreply.github.com` 的那些。不得在原始碼寫任何具體路徑或信箱。
  - `def scan(root: Path, patterns: list[str]) -> list[tuple[str, int, str]]`：逐檔（文字檔，二進位跳過：讀前 8 KB 含 `\0` 就跳過）找 pattern，回傳 `(相對路徑, 行號, pattern)`；另外檢查 `root` 下不得有 `sources/`、`assets-test/`、`.superpowers/`、`build/` 資料夾（回傳 `(資料夾, 0, "forbidden dir")`）。
  - CLI：`python3 tools/release.py scan [資料夾]`（預設掃 `git ls-files` 列出的進版控檔），有發現就印出並結束碼 1。
- Ruling（規格偏差）：規格第 4 節「掃 `refs/codex`」不做——`git archive` 只取檔案內容、不可能帶 ref；改成「快照不得含 `.git`」併入 forbidden dir。

- [ ] **Step 1：失敗測試**（`test_release.py`）
  - `test_scan_flags_home_path`：暫存資料夾寫 `a.md` 內容含 `str(Path.home()) + "/x"` → `scan` 回傳 1 筆、行號正確
  - `test_scan_flags_author_email`：`patterns=["someone@example.com"]`、檔案含它 → 1 筆
  - `test_scan_skips_binary`：含 `\0` 與 pattern 的檔 → 0 筆
  - `test_scan_flags_forbidden_dirs`：建 `sources/x.txt`、`.git/` → 2 筆 forbidden dir
  - `test_forbidden_patterns_from_env`：結果含 `str(Path.home())`；不含任何 `noreply` 信箱
  - `test_scan_patterns_not_in_source`：`release.py` 與 `test_release.py` 的原始碼不含 `forbidden_patterns(ROOT)` 的任何一項
- [ ] **Step 2：跑** `python3 -m unittest tools.test_release` → 失敗
- [ ] **Step 3：實作**
- [ ] **Step 4：跑** `python3 tools/release.py scan` → 列出現有的發現（預期：5 份文件、公開評估報告、本規格書）；逐一改掉：指令範例裡的 `cd '<本機路徑>'` 改成 `cd <repo>`；報告的絕對路徑改成相對路徑；信箱改成「個人信箱」；規格書的盤點改成描述文字（「本機磁碟路徑」「家目錄路徑」）
- [ ] **Step 5：跑** `python3 tools/release.py scan` → 0 筆、結束碼 0；`python3 -m unittest tools.test_release` 全過
- [ ] **Step 6：Commit** `Add the release scan and clear local paths and email from the docs (MV-RELEASE-001)`

### Task 3：英文繪本對照譯本

**Files:** Create `tools/quote_check.py`、`tools/test_quote_check.py`、`report/MV-RELEASE-001_英文繪本對照_<date>.md`

**Interfaces:**
- Produces（`quote_check.py`）：
  - `def words(text: str) -> list[str]`：小寫、只留英文字母與撇號的詞。
  - `def candidates(md: str) -> list[str]`：引號（`“…”`、`"…"`）內的句子，以及正文中 ≥ 12 個詞的句子（以 `.!?` 斷句），去重。
  - `def longest_shared_run(sentence: list[str], source_ngrams: set, source_words: list[str]) -> int`：句子與譯本最長的連續相同詞數；先用 6-gram 集合篩，命中才往兩側延伸算長度（譯本只建一次索引）。
  - CLI：`python3 tools/quote_check.py <譯本.txt> docs/book/MV-BOOK-002_繪本前篇英文版.md docs/book/MV-BOOK-004_繪本後篇英文版.md` → 印 Markdown 表：文件、我們的句子、最長相同詞數、相同的那一串（只印那一串，不印譯本上下文）；只列 ≥ 6 的。
- 譯本路徑由參數給（主 checkout 的 `sources/PopolVuh.txt`），不寫進程式。

- [ ] **Step 1：失敗測試**：`test_words`（`"Heart of Sky’s"` → `["heart","of","sky's"]`，彎撇號正規化）、`test_candidates_quotes_and_long`（一段含引號句與 12 詞長句、一句短句 → 回傳 2 句）、`test_longest_shared_run`（譯本 `a b c d e f g h`、句子 `x b c d e f g y` → 6；句子無 6-gram 命中 → 0）
- [ ] **Step 2：跑** `python3 -m unittest tools.test_quote_check` → 失敗
- [ ] **Step 3：實作**；跑 CLI，結果寫進報告（含方法、門檻 6、筆數、表格）
- [ ] **Step 4：跑** 測試全過；`release.py scan` 仍 0 筆（報告不得含本機路徑：寫「主 checkout 的 sources/PopolVuh.txt」）
- [ ] **Step 5：Commit** `Check the English picture-book text against the translation (MV-RELEASE-001)`
- [ ] **Step 6：交 Brian**：報告連結；Brian 指定要改寫的句子後，改 `docs/book/MV-BOOK-002`／`004`（英文版不進遊戲，不用重跑匯出與字型），再跑一次 CLI 確認，另一個 commit。**等待期間繼續 Task 4、5。**

### Task 4：匯出範本與三個版本

**Files:** Create `game/export_presets.cfg`；Modify `.gitignore`（加 `build/`）、`tools/release.py`、`tools/test_release.py`

**Interfaces:**
- Produces（`export_presets.cfg`）：`[preset.0]` `Windows Desktop`（x86_64、`binary_format/embed_pck=true`，`export_path="../build/windows/TwinStarsOfMaize.exe"`）、`[preset.1]` `macOS`（`application/bundle_identifier="net.isbrian.twinstarsofmaize"`、universal、ad-hoc 簽章、`export_path="../build/macos/TwinStarsOfMaize.zip"`）、`[preset.2]` `Web`（`variant/thread_support=false`、`export_path="../build/web/index.html"`）。欄位名以 4.7.2 實際為準：先寫最小設定、跑匯出，看 Godot 補上的預設與警告再調。
- Produces（`release.py`）：`def zip_name(platform: str, version: str) -> str`（`"TwinStarsOfMaize-v%s-%s.zip"`）；`build <版號>` 子指令依序 `godot --headless --path game --export-release <預設> <路徑>`，Windows 資料夾打成 zip、macOS 的 zip 改名，網頁版留資料夾；印出每個產物的大小與 SHA-256。

- [ ] **Step 1：下載範本**：從 Godot 官方 GitHub Release `4.7.2-stable` 下載 `Godot_v4.7.2-stable_export_templates.tpz` 與 `SHA512-SUMS.txt` 到新的空資料夾；核對 SHA-512（不符就停，改請 Brian 從編輯器安裝）；解壓 `templates/` 到 `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`；記下檔案大小
- [ ] **Step 2：失敗測試**：`test_zip_name`（`zip_name("macos", "0.1.0") == "TwinStarsOfMaize-v0.1.0-macos.zip"`）；`test_presets_exist`（讀 `game/export_presets.cfg`，三個 `name` 是 `Windows Desktop`、`macOS`、`Web`，Web 的 `thread_support=false`，macOS 的 bundle id 正確）
- [ ] **Step 3：跑** → 失敗
- [ ] **Step 4：實作**；`python3 tools/release.py build 0.1.0`；三個產物都在 `build/`
- [ ] **Step 5：macOS 實機**：解壓到新資料夾、打開 App（記下 Gatekeeper 的提示與「仍要打開」或 `xattr` 的步驟，寫進 Task 5 的 README）；從標題開新遊戲、讀繪本一頁、進祖母家；確認存檔資料夾是 `app_userdata/雙子星玉米人/`；截圖
- [ ] **Step 6：網頁版實機**：`python3 -m http.server` 開 `build/web/`，在內建瀏覽器打開；標題、繪本、新遊戲、音效、截圖對照桌機版；手把交 Brian 試。結果寫進報告；畫面或聲音嚴重異常 → 照規格退路不出網頁版（Ruling 寫入帳本）
- [ ] **Step 7：Windows**：解壓 zip 確認 `TwinStarsOfMaize.exe` 存在、大小合理；實機留給 Brian
- [ ] **Step 8：跑** `python3 -m unittest tools.test_release` 全過；**Commit** `Add the export presets and the build command (MV-RELEASE-001)`

### Task 5：公開倉庫內容與快照

**Files:** Create `release/public/README.md`、`release/public/LICENSE`、`release/public/LICENSE-ASSETS.md`、`release/public/.github/ISSUE_TEMPLATE/playtest.md`；Modify `tools/release.py`、`tools/test_release.py`

**Interfaces:**
- Consumes：Task 2 的 `scan`、`forbidden_patterns`；Task 4 的產物路徑（README 的下載連結指向 Release `v0.1.0`、網頁版指向 `https://isbrian.github.io/twin-stars-of-maize/`）
- Produces（`release.py`）：`def snapshot(ref: str, out: Path, patterns: list[str] | None = None) -> list`（`patterns` 預設 `forbidden_patterns(ROOT)`，測試可注入）——`out` 必須不存在或是空的；`git archive <ref>` 解到 `out`；拿掉 `release/` 資料夾本身，把 `release/public/` 的內容複製到 `out` 根目錄（覆蓋同名的 `README.md`）；跑 `scan(out, patterns)`，有發現就刪掉 `out`、回傳發現清單；CLI `snapshot <ref> <out>`，失敗時結束碼 1。
- README 內容照規格第 5 節；截圖用 `assets-test/d2a_shots`、`d2b_shots` 挑 3 張，轉 JPG 放 `release/public/screenshots/`（每張 < 400 KB）。

- [ ] **Step 1：失敗測試**
  - `test_snapshot_puts_public_files_at_root`：對 `HEAD` 做快照 → `out/README.md` 是公開版（含 "Twin Stars of Maize"）、`out/LICENSE` 存在、`out/release/` 不存在
  - `test_snapshot_excludes_untracked_dirs`：`out/sources`、`out/assets-test`、`out/.superpowers`、`out/build`、`out/.git` 都不存在
  - `test_snapshot_refuses_dirty`：用 `patterns` 參數注入一個一定會命中的字串（例如快照中必有的 `"extends"`）→ 回傳非空、`out` 已刪除
  - `test_snapshot_refuses_nonempty_out`：`out` 已有檔 → 丟出例外，不動既有檔
- [ ] **Step 2：跑** → 失敗
- [ ] **Step 3：實作**；寫公開專用檔
- [ ] **Step 4：跑** 測試全過；`python3 tools/release.py snapshot HEAD /tmp/wt/rel/snap` → 0 筆；`gitleaks dir /tmp/wt/rel/snap --redact` → no leaks；快照大小、檔數記下
- [ ] **Step 5：Commit** `Prepare the public repository files and the snapshot command (MV-RELEASE-001)`

### Task 6：收尾與發佈準備

- [ ] **Step 1：全套** `bash /tmp/wt/step6.sh`（SELFTEST 全過、errors 0、unittest OK）；跑完 `git checkout -- game/art/fonts/NotoSerifTC_ui.ttf`
- [ ] **Step 2：文件**：`game/README.md` 加「發版」一節（`release.py scan／build／snapshot` 用法、範本位置、macOS 打開方式）；執行報告（時間戳先跑 `date`）；規格書驗收勾選；todo、總規格狀態
- [ ] **Step 3：Commit** `Document the release flow and record the run (MV-RELEASE-001)`
- [ ] **Step 4：最終全分支審查**（獨立 opus）→ 修正 → 交 Brian：新標題截圖、英文對照清單、公開 README、macOS／網頁版實測結果
- [ ] **Step 5：外部發佈**（每一步先問 Brian，依序）：推送本分支並開 PR → 合併 → 私人倉庫改名 `twin-stars-of-maize-dev`＋本機 remote 改網址（`git remote set-url`）→ tag `v0.1.0` → `snapshot v0.1.0` → 建公開倉庫 `isbrian/twin-stars-of-maize` 並推快照 → GitHub Release 上傳兩個 zip → `gh-pages` 推網頁版、開 Pages → 打開公開頁面、下載、網頁版各確認一次（核對遠端 hash）

## 與規格的差異

- 「掃 `refs/codex`」改成「快照不得含 `.git`」（Task 2 Interfaces 的 Ruling）。
- 規格第 3 節「製作說明的標題列帶版號」做成 `display_title()`；主選單大標題不帶版號（版號放大標題會太擠）。
