# MV-RELEASE-002 公開版小修：實作計畫

更新時間：2026-10-21 03:15　規格書：[MV-RELEASE-002_公開版小修.md](MV-RELEASE-002_公開版小修.md)

每個 Task 先寫測試、確認失敗，再實作、確認通過，最後 commit（英文、結尾 `(MV-RELEASE-002)`）。

## Task 1：快照改寫私人連結＋掃描規則（R2-1）

- `tools/test_release.py`：
  - `scrub_private_links` 處理 Markdown 連結、裸網址、兩個倉庫名稱（大小寫不同也要處理），公開倉庫網址不改。
  - 快照掃描對殘留的私人網址報 `rule:private-repo`；掃私人倉庫（給 `files=`）時不報。
  - 對 HEAD 產生快照後，全文沒有私人網址。
- `tools/release.py`：
  - 新增 `PRIVATE_REPOS`、`PRIVATE_URL` 正規式、`scrub_private_links(text)`。
  - `snapshot` 在掃描前逐一改寫文字檔。
  - `scan` 只在掃資料夾時套用 `rule:private-repo`。

## Task 2：巢狀禁用資料夾＋README 斷言（Minor 1、2）

- 測試：在 `a/b/.claude/x`、`game/build/y` 放檔，掃描要報出來；快照的 README 等於 `release/public/README.md`，且不等於根目錄的 README。
- 實作：
  - `FORBIDDEN_DIRS` 加 `.claude`。
  - `scan` 掃資料夾時逐一檢查每個路徑的每一段；同一個禁用資料夾只報一次（回報它的相對路徑），裡面的檔不再掃內容。

## Task 3：掃描匯出產物（Minor 3）

- 測試：
  - 建一個含禁用字串的 zip 與二進位檔，`scan_artifacts` 要報出來。
  - 乾淨的 zip 與二進位檔不報。
- 實作：
  - `scan_artifacts(paths, patterns)`：zip 逐一讀成員的位元組，其他檔直接讀位元組；以 UTF-8 精確比對。
  - `build` 結束前呼叫，有發現就印出來並 `sys.exit(1)`。

## Task 4：發行版不跑自測、不寫 Boss 紀錄（R2-3）

- 測試：`game/tests/` 新增一個 GDScript 測試：
  - 沒開檔的 `FightLog` 呼叫 `close()` 不建立任何檔。
  - `boss_fight` 的紀錄開關由一個可注入的布林值決定（預設 `OS.is_debug_build()`）；設為 false 時不開檔。
- 實作：
  - `main.gd`：自測改成 `OS.is_debug_build() and opts.mode == "selftest"`。
  - `boss_fight.gd`：新增 `var write_log := OS.is_debug_build()`，只有 true 時才 `log.open` 與印 `BOSSLOG`。
  - `fight_log.gd`：`close()` 在 `path_base` 為空時直接回傳。
  - 更新 `main.gd` 開頭的參數說明註解。
- 實機驗證：
  - 匯出 macOS release 到 `/tmp/wt/r2/`，解壓後用 `--headless -- --self-test` 啟動 10 秒，確認沒有 `SELFTEST` 輸出。
  - debug 版（編輯器的 `godot`）照常會跑自測。

## Task 5：授權、README、版號（R2-2、Minor 8）

- `release/public/LICENSE` 的範圍段落：
  - MIT 涵蓋 `game/` 與 `prototypes/` 的 `.gd`、`game/` 的場景與資料檔（`.tscn`、`.tres`、`.json`、`.cfg`、`.godot`、`.gdshader`），以及 `tools/` 全部。
  - 不涵蓋美術、音訊、字型、文件。
- `LICENSE-ASSETS.md`：例外清單同步更新。
- 公開 README：
  - English summary 的 License 句同步更新。
  - 網頁版那格改成「『結束遊戲』是灰色的，關掉分頁即可」。
  - 版本說明：原始碼 v0.1.1、下載檔 v0.1.0。
- `game/project.godot`：`config/version="0.1.1"`。
- 測試：`test_release` 新增斷言，三份檔都提到 `.tscn` 與 `prototypes`。

## Task 6：全套驗證

1. `tools/import_art.py --check`、`tools/import_rig.py --check`。
2. tools 單元測試；跑完 `git checkout -- game/art/fonts/NotoSerifTC_ui.ttf`。
3. 字串有改就重跑 `python3 tools/font_subset.py`（本工單預期沒有改遊戲字串）。
4. 全套自測：在背景跑約 20 分鐘，數 `SELFTEST (FAIL|SUMMARY)|SCRIPT ERROR|Parse Error`。
5. 對 HEAD 產生快照到 `/tmp/wt/r2/snap`，用 `rtk proxy grep` 確認沒有私人網址，並抽看 `todo/todo.md` 的改寫結果。

## Task 7：報告、todo、最終審查

- 執行報告：`report/MV-RELEASE-002_公開版小修_<date>_執行報告.md`。
- `todo/todo.md`：新增一列。
- 由獨立 opus 做最終審查。
- 以下對外動作都要先問 Brian：推送、開 PR、合併、`v0.1.1` 標籤、更新公開倉庫。
