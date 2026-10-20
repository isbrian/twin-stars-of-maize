# MV-BOOK-006 繪本閱讀器（Godot 原型）

更新時間：2026-10-07

## 基本資訊

| 項目 | 內容 |
|---|---|
| 分支 | `feature/MV-BOOK-006_繪本閱讀器` |
| 位置 | `prototypes/book-reader/`（獨立原型；不用 p 編號，避免與 MV-PROTO-006 撞號） |
| 影響範圍 | 新原型、`tools/book_export.py`（新）、`tools/book_layout.py`（共用解析器） |
| 依據 | [ART_SPEC 第 15 節「排版」](../../ART_SPEC.md)；繪本文本 [MV-BOOK-001](../../docs/book/MV-BOOK-001_繪本前篇文本.md)～[004](../../docs/book/MV-BOOK-004_繪本後篇英文版.md) |

## 背景與目的

繪本要在遊戲內閱讀（VISION 第 7 節）。本原型驗證：Godot 能否照排版規格即時排出 28 張的中英文、翻頁與語言切換的手感，讓整本書現在就能從頭讀到尾（缺插圖的頁用素色替代）。

## Brian 的決定（2026-10-07）

| 項目 | 決定 |
|---|---|
| 位置 | 新的獨立原型；插圖用 sync 腳本從 `assets-test/` 複製、不進版控（同 p4） |
| 文字來源 | 工具把 4 份文本檔轉成 Godot 翻譯表 CSV（欄位 `zh_TW`、`en`），由 Godot 內建翻譯系統讀 |
| 排版 | Godot 即時排版，照 ART_SPEC 數值 |
| 缺圖 | 素色替代底圖，文字照常排；右下角小字開發標記「插圖製作中：book_back_08」 |
| 翻頁 | →／D／十字鍵右／RB／攻擊鍵／點畫面右半＝下一頁；←／A／十字鍵左／LB／點左半＝上一頁；Esc／B＝回選單 |
| 轉場 | 約 0.3 秒交叉淡入淡出；轉場中再按翻頁立即跳到下一頁 |
| 入口 | 開頭選單選前篇／後篇，兩篇都開放；最後一頁再往下翻回選單 |
| 語言 | 選單切換；閱讀中按 L 即時切換（開發功能） |

## 實作內容

### 新增檔案

| 檔案 | 用途 |
|---|---|
| `tools/book_export.py` | 用 `book_layout.parse` 讀 4 份文本，輸出 `prototypes/book-reader/text/book_text.csv`（含選單等介面字串） |
| `prototypes/book-reader/project.godot`、`main.gd`、`main.tscn` | 入口；解析 `--self-test`、`--screenshot <資料夾>`、`--open <front|back> <頁> [zh_TW|en]` |
| `prototypes/book-reader/book_page.gd` | 一頁：插圖或素色底、左側底板、標題、正文、「遊戲裡」、頁碼、缺圖標記 |
| `prototypes/book-reader/book_reader.gd` | 翻頁、轉場、語言切換、輸入 |
| `prototypes/book-reader/start_menu.gd` | 開頭選單：前篇、後篇、語言、結束 |
| `prototypes/book-reader/book_style.gd` | ART_SPEC 第 15 節的數值（與 `tools/book_layout.py` 同一組） |
| `prototypes/book-reader/tests/self_test.gd` | 自動測試 |
| `prototypes/book-reader/sync_assets.sh` | 把 6 張插圖與 `assets/fonts/` 複製進 `art/`、`fonts/` 並匯入（兩者不進版控） |
| `prototypes/book-reader/README.md` | 執行方式與操作 |

### 排版對應

| ART_SPEC | Godot |
|---|---|
| 底板 0～480 px、480～544 淡出 | `TextureRect` ＋ 水平 `GradientTexture2D` |
| 字型與字重、字寬軸 | `FontVariation`（`wght`；英文另設 `wdth` 87.5） |
| 行高 | `Label` 的 `line_spacing` ＝ 字級 × 行高倍數 − 字型自然行高 |
| 換行與禁則 | `Label` 自動換行（ICU 斷行，避開行首標點；不懸掛） |
| 段落、標題、分隔線間距 | `VBoxContainer` 內的間隔節點 |

## 驗收標準

- [x] `python3 tools/book_export.py` 產出 CSV：28 頁的標題與正文、後篇 18 頁的「遊戲裡」、介面字串，兩種語言都不缺
- [x] `--self-test` 全部通過，至少涵蓋：翻譯載入、28 頁 × 2 語言的文字底部 ≤ 992 px、翻頁邊界（第一頁不能再往前、最後一頁回選單）、轉場中按翻頁立即完成、語言切換即時更新、缺圖用素色並顯示標記、有圖時用插圖、字型變體設定正確
- [x] `--screenshot` 輸出：選單、前篇 02（繁中）、後篇 20（繁中、英文）、後篇 08（缺圖）；AI 目視與 `tools/book_layout.py` 預覽比對，差異只限 Godot 不懸掛標點造成的換行位置
- [x] README 寫明執行、操作、sync 步驟
- [x] `tools/test_book_layout.py` 仍全部通過

## Git Commit

（完成後補上）
