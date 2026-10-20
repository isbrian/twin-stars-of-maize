---
type: task-report
task_id: MV-ASSET-007
status: completed
generated_at: 2026-10-07_0135
---

# MV-ASSET-007 Seven Macaw 一戰的音訊 執行報告

## 結果

✅ 完成（Brian 2026-10-07 試聽「都可以」）。工單見 [MV-ASSET-007](../docs/assets/MV-ASSET-007_素材工單_SevenMacaw音訊.md)；同時把 MV-PROTO-005 結案（Brian 2026-10-07 決定）。

## 做了什麼

| 項目 | 內容 |
|---|---|
| 範圍（Brian 決定） | 卡在 MV-PROTO-005 的 AMB-01 假光玻璃顫音層、MUS-B01、Seven Macaw 招式與演出音效，加上覺醒短句 MUS-S01：23 則工單、39 個 WAV |
| 生成方式（Brian 決定） | AI 以 Codex CLI 交派、Python／NumPy 程式合成；4 組（G1 先跑確認流程，G2～G4 平行），全部 `exit 0` |
| 設計決定（AI，未被推翻） | 各招前兆沿用第 0 批的通用前兆，不另做 Seven Macaw 專用的（MV-PROTO-005 學過之後前兆↔危險誤判 0／72） |
| 文件同步 | MV-ASSET-002／003 的 B 部分改指向本工單；MV-BOSS-001 第 7 節的不可招架前兆描述改成 AUDIO_SPEC 修訂後的「蓄力後一記低沉重擊」；MV-PROTO-005 todo 與規格改 ✅ |

## 驗證

- 寫入範圍：`find -newer` 只有指定資料夾；`git status` 沒有已追蹤檔案被改；腳本沒有讀外部音檔、沒有網路。
- 量測（`ffprobe`、`ffmpeg ebur128`、NumPy）：格式、長度、響度 ±1 LU、峰值 ≤ -1 dBTP、循環接縫、200 Hz 以下能量、音高不上揚、沒有 40～150 Hz 的單音重擊，全部符合；例外是擲果 -22.0 LUFS（0.3 秒檔短於 R128 量測窗，補靜音後量），接受。
- Brian 試聽全部檔案與兩個疊加預覽：都可以。

## 給之後的提醒

- **混音**：MUS-B01 疊上第 0 批前兆時，有 3 個前兆只比配樂大約 0 dB。接進遊戲（垂直切片）時要照 AUDIO_SPEC 第 7 節在前兆播放時壓低配樂（例如 -6 dB）。
- **Codex 平行交派可行**：輸出檔名不重疊時，3 組同時跑沒有互相干擾；G4 曾在家目錄底下 `find` numpy 的位置（只讀）。
- **短音效的響度**：短於 0.4 秒的檔案，`ebur128` 的整合響度會顯示 -70 LUFS，要補靜音再量。
