"""把繪本文本匯出成 Godot 翻譯表 CSV（MV-BOOK-006）。

文件（docs/book/MV-BOOK-001～004）是唯一來源；修改文本後重跑：
  python3 tools/book_export.py
輸出 prototypes/book-reader/text/book_text.csv，欄位 keys、zh_TW、en；
另產遊戲用的 game/ui/book_text.gd（前篇繁中的標題與正文，MV-SLICE-001d2b）。
"""
import csv
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "prototypes" / "book-reader" / "text" / "book_text.csv"
GAME_OUT = ROOT / "game" / "ui" / "book_text.gd"
LOCALES = {"zh": "zh_TW", "en": "en"}

_spec = importlib.util.spec_from_file_location("book_layout", Path(__file__).with_name("book_layout.py"))
book_layout = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(book_layout)

# 介面字串：(鍵, 繁中, 英文)；FOLIO 與 MISSING_ART 用 Godot 的 % 格式化
UI = [
    ("UI_MENU_TITLE", "繪本", "Picture Book"),
    ("UI_MENU_FRONT", "前篇", "Part One"),
    ("UI_MENU_BACK", "後篇", "Part Two"),
    ("UI_MENU_LANG", "語言：繁體中文", "Language: English"),
    ("UI_MENU_QUIT", "結束", "Quit"),
    ("UI_NOTE_LABEL", book_layout.NOTE_LABEL["zh"], book_layout.NOTE_LABEL["en"] + " "),
    ("UI_FOLIO_FRONT", "前篇 %d／%d", "Part One · %d/%d"),
    ("UI_FOLIO_BACK", "後篇 %d／%d", "Part Two · %d/%d"),
    ("UI_MISSING_ART", "插圖製作中：%s", "Illustration in progress: %s"),
]


def rows():
    """依 (鍵, {語言: 文字}) 產生每一列；缺任何一種語言就報錯。"""
    out = [(key, {"zh": zh, "en": en}) for key, zh, en in UI]
    for volume in ("front", "back"):
        cards = {lang: book_layout.parse(volume, lang) for lang in LOCALES}
        for num in range(1, book_layout.TOTAL[volume] + 1):
            prefix = f"BOOK_{volume.upper()}_{num:02d}"
            for field in ("title", "body", "note"):
                values = {}
                for lang in LOCALES:
                    v = cards[lang][num][field]
                    values[lang] = "\n".join(v) if isinstance(v, list) else v
                if all(v is None for v in values.values()):
                    continue  # 這一頁沒有「遊戲裡」
                missing = [lang for lang, v in values.items() if not v]
                if missing:
                    raise ValueError(f"{prefix}_{field.upper()} 缺少 {missing}")
                out.append((f"{prefix}_{field.upper()}", values))
    return out


def _gd_str(s):
    s = s.replace("\r\n", "\n").replace("\r", "\n")  # CRLF 存檔也一樣（MV-SLICE-001d2b2）
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def game_text(data):
    """rows() 的結果 → game/ui/book_text.gd 的內容：前篇各頁 [標題, 正文]，只取繁中。"""
    zh = {key: values["zh"] for key, values in data}
    pages = []
    n = 1
    while f"BOOK_FRONT_{n:02d}_TITLE" in zh:
        pages.append(f'\t[{_gd_str(zh[f"BOOK_FRONT_{n:02d}_TITLE"])}, {_gd_str(zh[f"BOOK_FRONT_{n:02d}_BODY"])}],')
        n += 1
    return ("extends RefCounted\n"
            "# 由 tools/book_export.py 從 docs/book/ 產生，不要手改（MV-SLICE-001d2b）。\n"
            "# 繪本前篇各頁：[標題, 正文（段落以 \\n 分隔）]。\n\n"
            "const FRONT := [\n" + "\n".join(pages) + "\n]\n")


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    data = rows()
    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, quoting=csv.QUOTE_ALL, lineterminator="\n")
        w.writerow(["keys", *LOCALES.values()])
        for key, values in data:
            w.writerow([key, *(values[lang] for lang in LOCALES)])
    GAME_OUT.write_text(game_text(data), encoding="utf-8")
    print(f"EXPORT ok: {len(data)} 列 → {OUT.relative_to(ROOT)}；遊戲文字 → {GAME_OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
