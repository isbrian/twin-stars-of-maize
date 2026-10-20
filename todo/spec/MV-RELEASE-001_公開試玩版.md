# MV-RELEASE-001 公開試玩版 v0.1.0

更新時間：2026-10-21 00:31

## 基本資訊

| 項目 | 內容 |
|------|------|
| 分支 | `feature/MV-RELEASE-001_公開試玩版`（從 `develop` `8bda63a` 開） |
| 影響範圍 | 遊戲標題與 App 名稱（`game/ui/title_menu.gd`、`game/project.godot`）、匯出設定（`game/export_presets.cfg`，新）、發版工具（`tools/release.py`，新）、5 份文件的本機路徑與 1 份報告的信箱、英文繪本文本（`docs/book/MV-BOOK-002`、`004`，視對照結果）、名稱表、公開倉庫用的 README／LICENSE／Issue 範本（新） |
| 上層 | 插入作業；取代 [MV-SLICE-001 總規格](MV-SLICE-001_垂直切片.md) 的 d3 打包（d3 併入本工單） |
| 前置 | MV-SLICE-001d2b（#30 已合併） |
| 設計依據 | [GitHub 公開上傳評估](../../report/GITHUB_PUBLIC_REVIEW_2026-10-20_0223.md)；[AI 素材條款與揭露](../../docs/legal/AI素材條款與揭露.md) 規則 1、6；[CULTURAL_PRINCIPLES](../../CULTURAL_PRINCIPLES.md)「標題與封面不出現聖典名」；[名稱表第 6 節](../../docs/design/MV-NAME-001_名稱表.md) |
| 引擎 | Godot 4.7.2（`4.7.2.stable.official.ed1daf0bf`） |
| 狀態 | ✅ 已發佈（2026-10-21）：公開倉庫 isbrian/twin-stars-of-maize、Release v0.1.0、GitHub Pages。見[執行報告](../../report/MV-RELEASE-001_公開試玩版_2026-10-21_0118_執行報告.md) |

## 背景與目的

垂直切片已經可以從頭玩到尾（標題 → 繪本 → 森林 → Boss → 片尾）。Brian 要先發一個公開版本「試試水溫」：在 GitHub 公開原始碼與安裝檔，暫不上 itch.io、不主動宣傳。公開評估（2026-10-20）列了 4 件公開後難收回的事；本工單把它們處理完，再出 Windows、macOS、網頁三種版本。

## 盤點（2026-10-21，AI 實查）

- 倉庫：`isbrian/Game-Popol-Vuh-Metroidvania`，Private；1565 個進版控的檔；沒有 LICENSE；沒有 `export_presets.cfg`；本機沒有匯出範本（`~/Library/Application Support/Godot/export_templates/` 是空的）。
- 聖典名：44 個檔含「Popol」、14 個含「波波爾」。遊戲裡的 4 處：`project.godot` 的 `config/name="Popol Vuh MV｜垂直切片"`（App 名稱，也決定存檔資料夾）、`title_menu.gd` 的 `GAME_TITLE := "Popol Vuh 垂直切片"`、製作說明的譯本出處（原則允許）、`game/README.md` 寫的存檔路徑。其餘是文件把它當原典出處引用（原則允許）。
- 本機路徑（外接磁碟的掛載路徑、家目錄路徑）：5 份文件（MV-ASSET-007 執行報告、MV-DESIGN-001 執行報告、MV-PROTO-001／004／005 實作計畫）。
- 信箱：1 份（公開評估報告本身）。歷史裡 408 個 commit 用個人信箱——快照不帶歷史，不會公開。
- 英文繪本：`docs/book/MV-BOOK-002`（前篇，引號 16 處）、`MV-BOOK-004`（後篇，53 處）。遊戲只出繁中（SLICE-d2-3），但文件會隨快照公開。對照用的譯本在主 checkout 的 `sources/PopolVuh.txt`（Christenson 2007 Mesoweb 電子版，不進版控）。
- 渲染：專案用預設的 Forward+；Godot 網頁版只能用 Compatibility 渲染器，畫面可能和桌機版不同。

## 定案（Brian，2026-10-21）

| ID | 議題 | 定案 | 理由 |
|---|---|---|---|
| REL-1 | 發佈位置 | GitHub：原始碼＋Releases 安裝檔；暫不上 itch.io | 先試水溫 |
| REL-2 | 公開程度 | 公開倉庫，不主動宣傳 | 同上 |
| REL-3 | 倉庫方式 | 新開公開倉庫，放**不帶歷史的快照**；私人倉庫繼續當開發用，每次發版同步一次 | 信箱、舊標題、中間版本都不外洩 |
| REL-4 | 快照範圍 | 遊戲、工具、設計文件、規格與報告、原型都放（以 `git archive` 取進版控的檔，`sources/`、`assets-test/` 本來就不在版控裡） | 作品集最有價值的是開發過程 |
| REL-5 | 授權 | 程式與工具 MIT；美術、音訊、文件保留所有權利；字型照 OFL | 不對 AI 素材宣稱比實際更強的權利 |
| REL-6 | 正式標題 | **雙子星玉米人／Twin Stars of Maize**；MV-TITLE-001 結案 | 公開後的名字很難再改 |
| REL-7 | 標題的文化檢查 | 「雙子星玉米人」＝化為星辰的雙胞胎＋玉米造的人，不是被排除的「雙生玉米」（yo'x，仍在進行的農耕儀式用語）；英文不用「Maize Twins」（讀起來就是 twin maize），改用 Twin Stars of Maize。寫進名稱表並列入請學者審閱的清單 | 原則 2「不發明宗教儀式」 |
| REL-8 | 倉庫名 | 公開 `isbrian/twin-stars-of-maize`；私人倉庫改名 `isbrian/twin-stars-of-maize-dev`（GitHub 自動轉址；本機 remote 一併改） | 名字一致 |
| REL-9 | 版本 | Windows、macOS 下載版；網頁版放 GitHub Pages | 試水溫門檻最低的是網頁版 |
| REL-10 | 匯出範本 | 下載 Godot 4.7.2 官方匯出範本（godotengine.org） | 沒有範本產不出安裝檔 |
| REL-11 | macOS 簽章 | ad-hoc 簽章；README 寫明第一次怎麼打開 | 不用 Apple 開發者帳號 |
| REL-12 | 英文繪本 | 公開前逐句對照本機譯本，太像的列清單給 Brian 看再改寫 | 公開評估第 4 項 |
| REL-13 | 本機路徑與信箱 | 在私人倉庫直接改掉（只改當前版本、不改歷史）；發版工具再掃一次，掃到就不輸出快照 | 快照就是乾淨的 |
| REL-14 | README | 繁中為主，開頭一段英文摘要 | 遊戲只有繁中 |
| REL-15 | 回饋 | 公開倉庫的 Issues＋試玩回饋範本 | 不用額外服務 |
| REL-16 | 順序與版號 | #30 先合併（已完成）；本工單取代 d3；版號 `v0.1.0` | 公開版要含繪本 |

## 範圍

### 1. 標題與名稱（私人倉庫）

- `GAME_TITLE := "雙子星玉米人"`；副標「試玩版」不變。重跑 `tools/font_subset.py`（新字「雙子星玉米人」）。
- `project.godot`：`config/name="雙子星玉米人"`。存檔資料夾跟著變成 `app_userdata/雙子星玉米人/`；舊資料夾的存檔不搬（開發中的存檔，不影響玩家）。`game/README.md` 的路徑同步改。
- 名稱表第 6 節：記下定案（REL-6、REL-7），含和 yo'x 的區別、英文不用 Maize Twins 的理由、列入學者審閱清單。`todo.md` 的 MV-TITLE-001 結案。
- 根目錄 `README.md`、`VISION.md` 等提到「標題待定」的地方改成定案名。原典出處的「Popol Vuh」保留（原則允許出處出現在片尾與下載頁）。

### 2. 清理（私人倉庫）

- 5 份文件的本機路徑改成相對路徑或 `<repo>`；公開評估報告的信箱改成「個人信箱」。
- 英文繪本對照（REL-12）：把 `MV-BOOK-002`、`004` 每個引號內的句子與 ≥ 12 個英文字的長句，在譯本 `sources/PopolVuh.txt` 裡找最相近的段落（以連續相同詞串長度判斷），列出「連續 ≥ 6 個字相同」的句子給 Brian；Brian 確認後改寫。工具放 `tools/quote_check.py`（只讀譯本、不輸出譯本原文超過一句）。

### 3. 匯出（私人倉庫）

- 下載官方匯出範本 `Godot_v4.7.2-stable_export_templates.tpz`，安裝到 `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`；核對官方公佈的 SHA-512。
- `game/export_presets.cfg`（進版控）三個預設：
  - `Windows`：x86_64，`.exe`＋內嵌 pck；產出 `TwinStarsOfMaize-v0.1.0-windows.zip`。
  - `macOS`：universal，ad-hoc 簽章（`codesign/codesign=3` 之類的設定以 4.7.2 實際欄位為準），bundle id `net.isbrian.twinstarsofmaize`；產出 `TwinStarsOfMaize-v0.1.0-macos.zip`。
  - `Web`：單執行緒（`variant/thread_support=false`，GitHub Pages 不能設 COOP／COEP 標頭）；產出 `web/` 資料夾。
- 匯出時排除只給開發用的東西：`tests/` 照舊打包（自測入口在發行版不會啟動，`OS.is_debug_build()` 為 false）；開發用啟動參數在發行版本來就忽略。
- 版號：`project.godot` 加 `config/version="0.1.0"`；製作說明的標題列帶版號。

### 4. 發版工具（`tools/release.py`，私人倉庫）

- `python3 tools/release.py snapshot <tag> <輸出資料夾>`：`git archive <tag>` 解到輸出資料夾，再加入公開倉庫專用檔（`release/public/` 下的 README、LICENSE、Issue 範本）；掃描輸出內容，含本機路徑、個人信箱、`refs/codex`、`sources/`、`assets-test/` 任一項就失敗並列出。
- `python3 tools/release.py build <版號>`：用 `godot --headless --export-release` 依序匯出三個預設，打包 zip，印出各檔大小與 SHA-256。
- 單元測試 `tools/test_release.py`：掃描規則（假資料夾含路徑／信箱 → 失敗；乾淨 → 通過）、zip 檔名格式。

### 5. 公開倉庫內容（`release/public/`）

- `README.md`：英文摘要一段（是什麼、遊戲只有繁中、AI 揭露、原典與改編、授權）；繁中本文：簡介、截圖 2～3 張、下載與網頁版連結、Windows SmartScreen 與 macOS「仍要打開」的步驟、操作說明（鍵盤／手把）、AI 使用說明（同製作說明：美術與音訊由 AI 生成，ChatGPT／Codex，每一項經作者審核；程式由作者與 AI 協作）、原典來源（Christenson、Tedlock 譯本）與「本作是改編」、授權、回饋方式、已知問題（HUD H1～H4、d2b 延後的 Minor）。
- `LICENSE`：MIT（適用範圍寫明：`game/` 的 `.gd` 與 `tools/`）；`LICENSE-ASSETS.md`：美術、音訊、文件保留所有權利，AI 素材的著作權說明連到 AI 條款文件；字型的 OFL 文字照舊在原位置。
- `.github/ISSUE_TEMPLATE/playtest.md`：平台、玩到哪裡、卡住或不好玩的地方、有沒有錯誤畫面。

### 6. 發佈（外部動作，每一步做之前先問 Brian）

1. 私人倉庫改名 `twin-stars-of-maize-dev`，本機 remote 改網址。
2. 建 `isbrian/twin-stars-of-maize`（Public），推快照為第一個 commit，tag `v0.1.0`。
3. 建 GitHub Release `v0.1.0`：上傳 Windows、macOS zip；說明寫 AI 揭露與打開方式。
4. GitHub Pages：網頁版推到公開倉庫的 `gh-pages` 分支（或 `docs/`），確認網址能玩。
5. 推送前跑 `gitleaks dir` 掃快照。

### 不做

- itch.io、宣傳。
- Apple 正式簽章與公證、Windows 程式碼簽章。
- 英文版遊戲、Steam。
- 改寫私人倉庫的歷史。
- HUD H1～H4 與 d2b 延後的 Minor（寫進 README 已知問題）。

## 驗收

自測與工具：

1. ✅（707／0）全套自測全過（基準 699）；`tools` 單元測試全過（含 `test_release.py`）。
2. ✅ 字型涵蓋測試含新標題的字（另加：全部遊戲字串）。
3. ✅（對 HEAD；tag 在發佈時打）`release.py snapshot` 對 `v0.1.0` 掃描乾淨；`gitleaks dir` 無發現。

實機（AI）：

4. 🔶 部分（啟動、簽章、存檔資料夾；遊玩交 Brian）macOS 版：本機解壓、ad-hoc 簽章的 App 能開（記下第一次開的提示與步驟）、從標題玩到森林第一間、存檔資料夾是新名稱。
5. 🔶 部分（畫面、繪本、遊戲、選單；聲音與手把交 Brian）網頁版：本機用簡易伺服器開，標題、繪本、進遊戲、音效、手把各試一次；記下 Compatibility 渲染和桌機版的差異（截圖對照）。
6. ✅（zip 內容）Windows 版：本機沒有 Windows，只驗 zip 內容與 exe 存在；**實機要請 Brian 或他人在 Windows 上試**（列在待 Brian）。

Brian：

7. ✅（2026-10-21「試玩可以」；英文第 4 句改寫）標題畫面與製作說明看新標題；英文繪本對照清單；公開 README 文字。
8. ✅ 每一步外部動作（第 6 節）的同意（2026-10-21，六步逐一同意）。
9. 🔶 AI 已點開公開頁面、從 Release 下載核對、網頁版實際打開；瀏覽器下載的 macOS「仍要打開」流程與 Windows 實機待 Brian。

## 風險與退路

| 風險 | 退路 |
|---|---|
| 網頁版在 Compatibility 渲染器下畫面差異大、或音效／手把不正常 | 先不出網頁版，README 標「網頁版之後補」 |
| macOS 新版系統對 ad-hoc 簽章的 App 擋得更嚴 | README 寫終端機 `xattr -dr com.apple.quarantine` 的做法 |
| 改 App 名稱後存檔資料夾換位置 | 只影響開發中的舊存檔；README 的路徑同步 |
| 英文繪本對照找到很多相近句 | 只列清單、Brian 決定；改寫量大時先不在快照放後篇英文版 |
| 公開後才發現漏清的東西 | 快照不帶歷史：修好後推新 commit 即可；若是密鑰類，立刻撤換並刪倉庫重建 |
| 匯出範本下載失敗或雜湊不符 | 改由 Brian 從編輯器「管理匯出範本」安裝 |

## Git Commit

分支 `feature/MV-RELEASE-001_公開試玩版`（從 `develop` `8bda63a` 開）。
