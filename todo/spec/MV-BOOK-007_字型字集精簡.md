# MV-BOOK-007 字型字集精簡

更新時間：2026-10-07

## 基本資訊

| 項目 | 內容 |
|---|---|
| 分支 | `feature/MV-BOOK-007_字型字集精簡` |
| 影響範圍 | `tools/font_subset.py`（新）、`prototypes/book-reader/`（sync 流程、選單游標、自動測試） |
| 依據 | [ART_SPEC 第 15 節「排版」](../../ART_SPEC.md)；[MV-BOOK-006 繪本閱讀器](MV-BOOK-006_繪本閱讀器.md) |

## 背景與目的

完整的思源宋體繁中可變字型有 16.9 MB，繪本只用到幾百個字。內嵌進遊戲前，只保留實際用到的字與字重範圍。

## Brian 的決定（2026-10-07）

| 項目 | 決定 |
|---|---|
| 工具 | 同意 `pip install --user fonttools`（MIT） |
| 字集 | 只保留實際用到的字（翻譯表 CSV＋ASCII＋常用全形標點），文字改了就重產 |
| 可變軸 | 縮到用到的範圍：繁中字重 500～700；英文字重 450～700、字寬固定 87.5 |
| 位置 | 完整字型留在 `assets/fonts/` 當正本；精簡版由 `sync_assets.sh` 產生到原型的 `fonts/`（不進版控） |

## 實作內容

| 檔案 | 變更 |
|---|---|
| `tools/font_subset.py` | 從 CSV 收集字、`fontTools.subset` 精簡（保留全部 OpenType 功能與名稱表的授權資訊）、`varLib.instancer` 縮軸；分語言檢查缺字，缺字時結束碼 1 |
| `tools/test_font_subset.py` | 收集字集、產出成功且無缺字、繁中小於 2 MB |
| `prototypes/book-reader/sync_assets.sh` | 複製完整字型改為執行 `font_subset.py` |
| `prototypes/book-reader/start_menu.gd` | 游標「▸」改「▶」（思源宋體沒有 ▸），固定用思源宋體 |
| `prototypes/book-reader/tests/self_test.gd` | 新增 `test_j`：翻譯表每個字在該語言字型都有字形、繁中字型有游標 |

## 驗收標準

- [x] 繁中字型 16.9 MB → 726 KB、英文 1.9 MB → 55 KB
- [x] 軸範圍：繁中 wght 500～700；英文 wght 450～700，wdth 已固定（移除）
- [x] 名稱表保留 OFL 授權文字
- [x] Godot 自動測試全部通過（10 項，含缺字檢查）；文字底部最低值與完整字型相同（992 px）
- [x] 截圖與完整字型時逐像素比對：字形、換行、行距相同，差異只在反鋸齒邊緣
- [x] Python 測試全部通過

## Git Commit

（見執行報告）
