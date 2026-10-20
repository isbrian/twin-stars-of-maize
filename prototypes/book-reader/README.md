# 繪本閱讀器｜MV-BOOK-006

> 規格：[todo/spec/MV-BOOK-006_繪本閱讀器.md](../../todo/spec/MV-BOOK-006_繪本閱讀器.md)
> 排版：[ART_SPEC 第 15 節「排版」](../../ART_SPEC.md)；數值在 `book_style.gd`，與 [tools/book_layout.py](../../tools/book_layout.py) 是同一組
> 文字：[docs/book/](../../docs/book/) 的 4 份繪本文本（唯一來源），由 [tools/book_export.py](../../tools/book_export.py) 轉成 `text/book_text.csv`

## 第一次執行

需要 Godot 4.7。插圖與字型不進版控，先同步：

```bash
prototypes/book-reader/sync_assets.sh
```

腳本會把 `assets-test/book_{front,back}/final/` 的插圖複製到 `art/`、重新匯出文字、用 `tools/font_subset.py` 從 `assets/fonts/` 的完整字型產生只含用到的字的精簡字型到 `fonts/`（繁中約 726 KB），然後匯入專案。精簡需要 fontTools：`python3 -m pip install --user fonttools`。插圖還沒生成的頁用素色底，右下角標「插圖製作中」。

## 執行

```bash
godot --path prototypes/book-reader
```

| 參數（放在 `--` 之後） | 作用 |
|---|---|
| `--open front 2` | 略過選單，直接開到前篇第 2 頁；後面可再接 `en` 或 `zh_TW` |
| `--self-test` | 自動測試（可加 `--headless`），最後印出 `SELFTEST SUMMARY pass=N fail=M` |
| `--screenshot <資料夾>` | 輸出選單、前篇 02、後篇 20（繁中、英文）、後篇 08（缺圖）的 1920×1080 截圖；需要視窗，不能加 `--headless` |

## 操作

| 動作 | 鍵盤＋滑鼠 | 手把 |
|---|---|---|
| 下一頁 | →、D、點畫面右半 | 十字鍵右、RB、X |
| 上一頁 | ←、A、點畫面左半 | 十字鍵左、LB |
| 回選單 | Esc | B |
| 切換語言（開發功能） | L | — |
| 選單上下、確認 | ↑↓、Enter | 十字鍵、A |

最後一頁再往下翻回選單。翻頁有 0.3 秒交叉淡入淡出，轉場中再按會直接跳到下一頁。

## 修改文本之後

```bash
python3 tools/book_export.py
python3 tools/font_subset.py
godot --headless --path prototypes/book-reader --import
godot --headless --path prototypes/book-reader -- --self-test
```

自動測試會檢查 28 頁 × 2 種語言的文字都在頁碼上方（底部 ≤ 992 px），以及每個字在精簡字型裡都有字形（文字改了卻沒重產字型，會在這裡被抓到）。Godot 的換行不懸掛標點，所以會比 `tools/book_layout.py` 的預覽多排一兩行；目前最長的後篇第 16 頁（繁中）剛好排到 992，**沒有餘裕**，再加字就要調字級或改文本。
