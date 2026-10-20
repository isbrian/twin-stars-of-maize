"""把繪本用的字型精簡成「實際用到的字」（MV-BOOK-007）。

正本是 assets/fonts/ 的完整字型；本工具產生精簡版到 prototypes/book-reader/fonts/（不進版控）。
MV-SLICE-001d2a：另產遊戲介面用的 game/art/fonts/NotoSerifTC_ui.ttf（**進版控**，打包時不用再跑），
字集＝標題畫面、製作說明程式裡的字串常值；改了那些字串就要重跑（自測 test_d2a 會抓缺字）。
MV-SLICE-001d2b：再加繪本前篇的字（game/ui/book_text.gd，由 book_export.py 產生）與頁碼（book_style.gd）。
文字改了就要重跑（sync_assets.sh 已包含）：
  python3 tools/font_subset.py
需要 fontTools（python3 -m pip install --user fonttools）。
"""
import csv
import re
import shutil
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "fonts"
OUT = ROOT / "prototypes" / "book-reader" / "fonts"
CSV = ROOT / "prototypes" / "book-reader" / "text" / "book_text.csv"

# MV-RELEASE-001：網頁版沒有系統字型可借，這個字型也當全遊戲預設字型的中文後備（main.gd），所以收全部遊戲 .gd（tests 除外）
UI_SOURCES = sorted(p for p in (ROOT / "game").rglob("*.gd") if "tests" not in p.relative_to(ROOT / "game").parts)
UI_OUT = ROOT / "game" / "art" / "fonts" / "NotoSerifTC_ui.ttf"

# ponytail: yagni: 程式裡直接寫死、會顯示在畫面上的字元只有選單游標 | upgrade if: UI 字串多了就改成掃描 .gd
EXTRA = "▶"
# ASCII 可見字元＋常用全形標點與符號：之後零星改字不會一改就缺字
BASE = "".join(chr(c) for c in range(0x20, 0x7F)) + "，。、；：？！「」『』（）《》〈〉…—–·／～％＋－＝　‘’“”"

# 依 ART_SPEC 第 15 節實際用到的字重與字寬；之後要別的字重就放寬範圍重產
FONTS = {
    "NotoSerifTC[wght].ttf": ("NotoSerifTC.ttf", {"wght": (500, 700)}),
    "NotoSerif[wdth,wght].ttf": ("NotoSerif.ttf", {"wght": (450, 700), "wdth": 87.5}),
}


def collect_chars(csv_path=CSV):
    """回傳 (全部要保留的字, {語言欄位: 該欄用到的字})；不含換行等控制字元。"""
    with open(csv_path, encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))
    by_lang = {lang: set() for lang in rows[0][1:]}
    for row in rows[1:]:
        for lang, cell in zip(rows[0][1:], row[1:]):
            by_lang[lang].update(c for c in cell if c.isprintable())
    chars = set(BASE + EXTRA).union(*by_lang.values())
    return {c for c in chars if c.isprintable() or c == "　"}, by_lang


def collect_ui_chars(paths=UI_SOURCES):
    """標題畫面、製作說明程式裡 "…" 字串常值用到的字＋BASE＋EXTRA。"""
    chars = set(BASE + EXTRA)
    for p in paths:
        for lit in re.findall(r'"((?:[^"\\\n]|\\.)*)"', Path(p).read_text(encoding="utf-8")):
            chars.update(c for c in lit if c.isprintable())
    return {c for c in chars if c.isprintable() or c == "　"}


def build(src_name, out_name, axes, chars, out_dir=None):
    font = TTFont(SRC / src_name)
    opts = subset.Options()
    opts.layout_features = ["*"]       # 保留全部 OpenType 功能（標點寬度、連字等）
    opts.name_IDs = ["*"]              # 保留名稱表，含授權與版權資訊（OFL 要求）
    opts.name_languages = ["*"]
    opts.notdef_outline = True
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=[ord(c) for c in chars])
    sub.subset(font)
    font = instancer.instantiateVariableFont(font, axes)
    out_dir = out_dir or OUT
    out_dir.mkdir(parents=True, exist_ok=True)
    font.save(out_dir / out_name)
    return (out_dir / out_name).stat().st_size, set(font.getBestCmap())


def main():
    chars, by_lang = collect_chars()
    cmaps = {}
    for src_name, (out_name, axes) in FONTS.items():
        size, cmaps[out_name] = build(src_name, out_name, axes, chars)
        before = (SRC / src_name).stat().st_size
        print(f"SUBSET {out_name}: {before / 1e6:.1f} MB → {size / 1e3:.0f} KB（{len(chars)} 字）")
    # 繁中欄與游標要在繁中字型裡；英文欄要在英文字型裡（英文不設後備字型，見 book_style.gd）
    tc, en = cmaps["NotoSerifTC.ttf"], cmaps["NotoSerif.ttf"]
    missing = {c for c in by_lang["zh_TW"] | set(EXTRA) if ord(c) not in tc and c != " "}
    missing |= {c for c in by_lang["en"] if ord(c) not in en and c != " "}
    # 遊戲介面（MV-SLICE-001d2a）：繁中字型、同繪本的字重範圍；OFL 授權文字一併放在旁邊
    ui_chars = collect_ui_chars()
    tc_src, (_, tc_axes) = "NotoSerifTC[wght].ttf", FONTS["NotoSerifTC[wght].ttf"]
    size, ui_cmap = build(tc_src, UI_OUT.name, tc_axes, ui_chars, UI_OUT.parent)
    shutil.copyfile(SRC / "OFL_NotoSerifTC.txt", UI_OUT.parent / "OFL_NotoSerifTC.txt")
    print(f"SUBSET {UI_OUT.name}: {size / 1e3:.0f} KB（{len(ui_chars)} 字）")
    missing |= {c for c in ui_chars if ord(c) not in ui_cmap and c not in " 　"}
    if missing:
        print(f"SUBSET 缺字：{''.join(sorted(missing))}")
    sys.exit(1 if missing else 0)


if __name__ == "__main__":
    main()
