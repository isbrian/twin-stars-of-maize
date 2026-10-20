# MV-RELEASE-002 公開版小修

更新時間：2026-10-21 03:10

## 基本資訊

| 項目 | 內容 |
|------|------|
| 分支 | `feature/MV-RELEASE-002_公開版小修`（從 `develop` `10f5578` 開） |
| 影響範圍 | 發版工具（`tools/release.py`、`tools/test_release.py`）、公開倉庫用的檔（`release/public/README.md`、`LICENSE`、`LICENSE-ASSETS.md`）、自測入口（`game/main.gd`）、Boss 戰紀錄（`game/core/boss/boss_fight.gd`、`fight_log.gd`）、`game/project.godot` 版號 |
| 上層 | MV-RELEASE-001 最終審查延後的 9 個 Minor（[執行報告「最終審查」](../../report/MV-RELEASE-001_公開試玩版_2026-10-21_0118_執行報告.md)） |
| 引擎 | Godot 4.7.2 |
| 狀態 | 進行中 |

## 背景與目的

v0.1.0 公開後，最終審查有 9 個 Minor 延後處理。最明顯的是公開文件裡有 22 個連結指向私人倉庫的 PR，公開版讀者點了會是 404。本工單把需要處理的項目修掉，產生 v0.1.1 的原始碼快照，更新公開倉庫的 `main`；Release 的 zip 和網頁版維持 v0.1.0。

## 定案（Brian，2026-10-21）

| ID | 議題 | 定案 |
|---|---|---|
| R2-1 | 私人連結 | 私人倉庫的正本不動；`snapshot` 產生快照時把連結改成純文字，並在掃描中加規則，確保快照裡沒有私人倉庫網址 |
| R2-2 | 授權範圍 | MIT 擴大到 `game/` 的場景與資料檔（`.tscn`、`.tres`、`.json`、`.cfg`、`project.godot` 等非美術、非音訊、非字型的檔）以及 `prototypes/` 的 `.gd` |
| R2-3 | 發行版行為 | 自測與 Boss 戰紀錄都只在開發版（`OS.is_debug_build()`）生效 |
| R2-4 | 發佈範圍 | 只更新公開倉庫的原始碼（私人倉庫打 `v0.1.1` 標籤 → 產生快照 → 公開倉庫 `main` 提交並推送）；不重新匯出，Release 和網頁版不動。推送、打標籤、更新公開倉庫，每一步都要先問 Brian |

## 實作內容（9 個 Minor 逐項）

| # | Minor | 處理 |
|---|---|---|
| 1 | 快照測試對 README 的斷言太弱（私人 README 也有英文名） | 改成斷言快照的 README 內容等於 `release/public/README.md`，且不等於私人倉庫根目錄的 README |
| 2 | 只在快照根目錄檢查禁用資料夾 | 任何深度的路徑只要有一段是禁用名稱就算；名單加 `.claude`。版控內目前沒有這種路徑（2026-10-21 實查） |
| 3 | 匯出產物不掃描 | `build` 完成後掃描產物：zip 逐一檢查成員，其他檔讀位元組；用精確字串（家目錄、磁碟路徑、作者信箱）比對，二進位檔也要查。發現問題就以結束碼 1 結束 |
| 4 | 授權範圍 | 見 R2-2：`LICENSE` 開頭的範圍說明、`LICENSE-ASSETS.md` 的例外、公開 README 的 License 句要一致 |
| 5 | 發行版仍會跑自測 | `main.gd`：只有 `OS.is_debug_build()` 時才進自測模式；發行版忽略這個參數，直接進主選單 |
| 6 | 發行版會寫 `user://boss_logs` | `boss_fight.gd`：只有開發版才開紀錄檔；`FightLog` 沒開檔時，`close()` 不寫任何檔（目前會寫 `path_base + ".md"`） |
| 7 | 內部代號、私人連結 | 私人連結見 R2-1。「內部代號：波波爾·烏」的標題列：MV-RELEASE-001 規格允許，**不處理** |
| 8 | README「網頁版沒有結束遊戲」；`playtest` 標籤；兩處過時註解 | README 改成「網頁版的『結束遊戲』是灰色的，關掉分頁即可」。`playtest` 標籤 2026-10-21 已在公開倉庫建立，**不用處理**。兩處過時註解：審查報告沒寫位置，舊對話紀錄裡也查不到，**無法追溯**；本工單只確認這次改到的檔裡的註解是正確的 |
| 9 | 7 份報告有 `~/.claude/plans/…` | 看不出使用者名稱，**不處理** |

另外：`game/project.godot` 的 `config/version` 改成 `0.1.1`；公開 README 說明原始碼是 v0.1.1，下載檔仍是 v0.1.0。

### 私人連結的改寫規則（R2-1）

- 私人倉庫：`isbrian/twin-stars-of-maize-dev`、`isbrian/Game-Popol-Vuh-Metroidvania`（舊名，GitHub 會轉址）。名稱比對不分大小寫；公開倉庫 `isbrian/twin-stars-of-maize` 不能誤判（它是 `-dev` 的前綴）。
- Markdown 連結 `[文字](https://github.com/isbrian/<私人倉庫>/...)` → `文字（私人倉庫）`。
- 沒有包在 Markdown 連結裡的網址 → `（私人倉庫連結）`。
- 只改文字檔（前 8 KB 沒有 `\0`）。
- 掃描加 `rule:private-repo`：快照裡還有私人倉庫網址就算不乾淨。這條規則只在掃快照時使用，掃私人倉庫時不用（私人倉庫本來就有這些連結）。

## 驗收標準

- [ ] `python3 -m unittest discover -s tools -p "test_*.py"` 全過，新增的測試涵蓋 #1、#2、#3、私人連結改寫與掃描規則
- [ ] 實際產生快照：`grep` 快照全文沒有私人倉庫網址；`todo/todo.md` 的 PR 連結變成「PR #N（私人倉庫）」
- [ ] 全套自測沒有失敗（基準 707，加上本工單新增的測試）
- [ ] 發行版不跑自測、不寫 `boss_logs`：用 debug／release 兩種匯出各跑一次 `-- --self-test`，或用等效的判斷驗證（實際驗證方式寫在報告裡）
- [ ] `tools/import_art.py --check`、`tools/import_rig.py --check` 通過
- [ ] 公開 README、`LICENSE`、`LICENSE-ASSETS.md` 的授權範圍一致
- [ ] Brian 同意後：推送、PR、合併；打 `v0.1.1` 標籤；更新公開倉庫的 `main`（`ls-remote` 核對 hash）
