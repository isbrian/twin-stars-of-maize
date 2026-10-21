# MV-SLICE-001d2b2 繪本小修

更新時間：2026-10-21 04:30

## 基本資訊

| 項目 | 內容 |
|------|------|
| 分支 | `feature/MV-SLICE-001d2b2_繪本小修`（從 `develop` `7f15d6c` 開） |
| 影響範圍 | `game/ui/book_reader.gd`、`book_page.gd`、`title_menu.gd`、`game/world/shots.gd`、`tools/book_export.py`、測試（`game/tests/test_d2b.gd`、`tools/test_book_export.py`）、`game/README.md`、d2b 規格的 SLICE-d2b-6 補註 |
| 上層 | [MV-SLICE-001d2b 執行報告「最終審查」](../../report/MV-SLICE-001d2b_繪本前篇_2026-10-20_2317_執行報告.md)延後的 5 個 Minor |
| 狀態 | 進行中 |

## 定案（Brian，2026-10-21）

| ID | Minor | 定案 |
|---|---|---|
| D2B2-1 | 每次翻頁才同步載入插圖（7.6～14.9 ms／張） | 開啟時同步載入當前頁；**用背景執行緒預先載入前後頁**（`ResourceLoader.load_threaded_request`）。建頁時：已經載入完成的就直接拿；還沒完成的退回同步 `load()`，不會出錯 |
| D2B2-2 | 開繪本時 `ui_confirm` 與 `ui_page_open` 同一幀疊在一起 | 開繪本時只播 `ui_page_open`：主選單「繪本」，以及詢問裡選「讀繪本」，都不播 `ui_confirm`。其他選項照舊 |
| D2B2-3 | `_gd_str` 沒處理 `\r` | `\r\n`、`\r` 先統一成 `\n`，再跳脫 |
| D2B2-4 | 詢問中翻滾／暫停＝直接開始 | **改成回主選單**：播 `ui_back`、不寫 `book_asked.json`、不開始遊戲；下次選新遊戲會再問。和覆蓋確認「翻滾＝取消」一致 |
| D2B2-5 | 截圖 `title_book_ask` 假設沒有存檔 | 拍之前把選單的 `_has_save` 設成 false（只影響截圖用的這個選單），保證直接拍到詢問 |

## 實作與驗證步驟

1. 先寫測試，確認它們會失敗：
   - `test_d2b`：
     - 「繪本」不播 `ui_confirm`、`ui_page_open` 加 1。
     - 「製作說明」照舊播 `ui_confirm`。
     - 詢問中按確認鍵選「讀繪本」不播 `ui_confirm`。
     - 詢問中按翻滾回主選單：`asking=false`、沒開始遊戲、沒寫入紀錄檔，再選新遊戲會再問（取代 `test_ask_roll_starts`）。
     - 暫停鍵同上。
     - 開啟後，前後頁都已送出背景載入請求。
     - 翻頁後，新的相鄰頁也已送出請求。
     - 已經載入完成的頁直接使用。
   - `test_book_export`：`_gd_str("a\r\nb\rc")` 的結果是 `"a\nb\nc"`，而且不含 `\r`。
2. 實作。
3. 跑 `SELFTEST_ONLY=test_d2b`，以及 tools 的 `test_book_export`。
4. 跑全套自測（基準 710，新增的項目另計），以及 tools 全套。
5. 截圖驗證：先放一個存檔，再用 `SHOTS_ONLY=book` 拍，`title_book_ask` 要拍到詢問、不是覆蓋確認。拍完把存檔還原。
6. 更新文件：
   - `game/README.md` 的入口說明。
   - d2b 規格 SLICE-d2b-6 加一行補註，指向本工單。
7. 執行報告、`todo.md`，再由獨立 opus 做最終審查。
8. 以下對外動作都要先問 Brian：推送、PR、合併。

## 驗收標準

- [ ] 上述測試全過；全套自測 0 失敗、0 個 `SCRIPT ERROR`
- [ ] 詢問中翻滾＝回主選單、下次再問
- [ ] 打開繪本只響一個聲音（由 `play_count` 驗證；實際聽感交 Brian 試玩）
- [ ] 截圖在已有存檔的情況下拍到詢問
