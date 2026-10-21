---
type: task-report
id: MV-RELEASE-003
name: v0.1.2
status: 🔄 待 Brian 同意對外動作
retry_count: 0
pause_reason: "-"
started_at: 2026-10-21_0700
generated_at: 2026-10-21_1716
---

# MV-RELEASE-003 公開試玩版 v0.1.2：執行報告

## 基本資訊

| 項目 | 內容 |
|---|---|
| 分支 | `feature/MV-RELEASE-003_v0.1.2`（從 `develop` `ed14702` 開） |
| 內容 | 帶給玩家的修改：[繪本小修](MV-SLICE-001d2b2_繪本小修_2026-10-21_0438_執行報告.md)（#36）、[HUD 調整](MV-SLICE-001d2c_HUD調整_2026-10-21_0511_執行報告.md)（#37）、[製作說明的改編例子](MV-SLICE-001d2d_改編說明_2026-10-21_0637_執行報告.md)（#38） |
| 流程 | 照 MV-RELEASE-001：私人倉庫打標籤 → 快照 → 更新公開倉庫 → Release → GitHub Pages |

## 修改

- 版號 0.1.2：`project.godot`、`export_presets.cfg` 的 4 個欄位、`test_release.gd`（製作說明的標題）。
- 公開 README：
  - 版本說明與下載檔名改成 v0.1.2。
  - 已知問題拿掉「HUD 的幾處排版還在調整」。
  - 新增「版本紀錄」一節（v0.1.0～v0.1.2）。
- `release/public/screenshots/play.jpg`：用新 HUD 重拍（720p 的 `hud_full`，JPG 156.6 KB）。
- `tools/test_release.py`：README 斷言改成 v0.1.2，並檢查已經沒有 `v0.1.0-` 檔名。

## 驗證（AI 實測，2026-10-21）

| 項目 | 結果 |
|---|---|
| `test_release`（GDScript） | 11／0 |
| `tools/test_release.py` | OK |
| 匯出 `release.py build 0.1.2` | 結束碼 0；產物掃描乾淨 |
| Windows | `TwinStarsOfMaize-v0.1.2-windows.zip`，65.2 MB，sha256 `91cc085be1aa16b645d8f19e810901c4d99ede8ac091bfc90dcd876e40fe2dc4` |
| macOS | `TwinStarsOfMaize-v0.1.2-macos.zip`，87.7 MB，sha256 `7cab6bbab7ff44b4c8672a90e0fca2cbd4b191f2b8f0b0ceb08a361ebe21ed3b` |
| 網頁版 | `build/web/`，70.8 MB |
| macOS 實機 | 解壓後 `CFBundleShortVersionString` = 0.1.2，裡面附 `THIRD_PARTY_NOTICES.txt`；啟動 12 秒仍在執行，輸出沒有 error |
| 網頁版實機 | 本機 127.0.0.1:8791，用內建瀏覽器打開：主選單正常、中文正常、「結束遊戲」是灰的；主控台沒有錯誤 |

全套自測沒有在這張工單重跑。上次全套 716／0 是在 `6e9a539` 跑的；之後 `game/` 只改了版號，以及 d2d 審查時修的 `test_d2a` 關鍵字（已單獨跑過 16／0）。

**沒有驗到**：Windows 實機（沒有 Windows 電腦），以及從瀏覽器下載 macOS 版時 Gatekeeper 的實際流程。
