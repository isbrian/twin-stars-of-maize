"""繪本排版預覽（MV-BOOK-005）：把繪本文本排到插圖左側 1/4 直欄。

版面數值即 ART_SPEC 第 15 節「排版」的規格；Godot 閱讀器與下載頁 PDF 照同一組數值。

用法：
  python3 tools/book_layout.py front 1 2 3 7     # 排前篇第 1、2、3、7 張（繁中、英文各一張）
  python3 tools/book_layout.py back 5 20 --check  # 只檢查全部張數的文字高度，不輸出
插圖讀 assets-test/book_{front|back}/final/，輸出到 assets-test/book_layout/。
"""
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
BOOK = ROOT / "docs" / "book"
FONTS = ROOT / "assets" / "fonts"
SOURCES = {
    ("front", "zh"): "MV-BOOK-001_繪本前篇文本.md",
    ("front", "en"): "MV-BOOK-002_繪本前篇英文版.md",
    ("back", "zh"): "MV-BOOK-003_繪本後篇文本.md",
    ("back", "en"): "MV-BOOK-004_繪本後篇英文版.md",
}
TOTAL = {"front": 8, "back": 20}
PART = {("front", "zh"): "前篇", ("back", "zh"): "後篇", ("front", "en"): "Part One", ("back", "en"): "Part Two"}
NOTE_LABEL = {"zh": "遊戲裡：", "en": "In the game:"}

# ---- 版面規格（1920×1080）----
W, H = 1920, 1080
COL = 480            # 左側 1/4 直欄
FADE = 64            # 底板右緣淡出寬度（480～544）
PANEL = (16, 13, 10, 165)  # 深色底板，約 65% 不透明
MARGIN_L, MARGIN_R, TOP, BOTTOM = 48, 36, 96, 72
TEXT_W = COL - MARGIN_L - MARGIN_R
INK = (242, 232, 213, 255)        # 正文、標題
INK_SOFT = (205, 191, 166, 255)   # 「遊戲裡」、頁碼
STYLE = {
    # 字級 px、行高倍數、字重。數值由 28 張實際文字反推：最長的後篇第 16 張（繁中）、第 19 張（英文）都要放得下
    "zh": {"title": (36, 1.35, 700), "body": (28, 1.65, 500), "note": (22, 1.55, 500), "folio": (20, 1.0, 500)},
    "en": {"title": (30, 1.25, 700), "body": (23, 1.45, 450), "note": (18, 1.35, 450), "folio": (18, 1.0, 450)},
}
EN_WIDTH = 87.5     # Noto Serif 字寬軸：半窄體（SemiCondensed），英文一行多放幾個字
PARA_GAP = 0.6      # 段落間距（正文字級的倍數）
TITLE_GAP = 0.9     # 標題下方間距（正文字級的倍數）
NOTE_GAP = 1.2      # 正文與「遊戲裡」分隔線上下的間距（正文字級的倍數）

# 行首禁則：這些標點不放行首，懸掛在上一行行尾；行尾禁則：開引號不放行尾
NO_START = set("，。、；：？！」』）》〉…—")
NO_END = set("「『（《〈")


def font(lang, kind):
    size, _, wght = STYLE[lang][kind]
    name = "NotoSerifTC[wght].ttf" if lang == "zh" else "NotoSerif[wdth,wght].ttf"
    f = ImageFont.truetype(str(FONTS / name), size)
    axes = {a["name"].decode() if isinstance(a["name"], bytes) else a["name"]: a for a in f.get_variation_axes()}
    values = [wght if "eight" in n else EN_WIDTH if "idth" in n else axes[n]["default"] for n in axes]
    f.set_variation_by_axes(values)
    return f


def wrap_zh(text, f, width, draw):
    """逐字換行；行首禁則字懸掛在上一行（最多懸掛一個），行尾的開引號移到下一行。"""
    lines, cur = [], ""
    for ch in text:
        if draw.textlength(cur + ch, font=f) <= width or not cur:
            cur += ch
            continue
        if ch in NO_START:
            if draw.textlength(cur, font=f) <= width:  # 第一個懸掛
                cur += ch
                continue
            i = len(cur) - 1  # 已經懸掛過：把最後一個字連同後面的標點移到下一行
            while i > 0 and cur[i] in NO_START:
                i -= 1
            lines.append(cur[:i])
            cur = cur[i:] + ch
            continue
        if cur[-1] in NO_END:
            lines.append(cur[:-1])
            cur = cur[-1] + ch
        else:
            lines.append(cur)
            cur = ch
    return lines + [cur] if cur else lines


def smart_quotes(text):
    """直引號換成彎引號：字中的 ' 是撇號，雙引號依出現順序開合。"""
    text = re.sub(r"(?<=\w)'(?=\w)", "’", text)
    text = re.sub(r"(?<=\w)'", "’", text)
    text = re.sub(r"'(?=\w)", "‘", text)
    out, opening = [], True
    for ch in text:
        if ch == '"':
            out.append("“" if opening else "”")
            opening = not opening
        else:
            out.append(ch)
    return "".join(out)


def wrap_en(text, f, width, draw):
    lines, cur = [], ""
    for word in text.split():
        trial = f"{cur} {word}".strip()
        if draw.textlength(trial, font=f) <= width or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    return lines + [cur] if cur else lines


def parse(volume, lang):
    """回傳 {張號: {"title", "body": [段落], "note"}}。"""
    text = (BOOK / SOURCES[(volume, lang)]).read_text(encoding="utf-8")
    head = r"^## 第 (\d+) 張：(.+)$" if lang == "zh" else r"^## (\d+)\. (.+?)（.+）$"
    cards = {}
    for m in re.finditer(head, text, re.M):
        block = text[m.end():].split("\n## ", 1)[0].split("\n| ", 1)[0]
        quotes = [ln[1:].strip() for ln in block.splitlines() if ln.startswith(">")]
        note = next((q for q in quotes if q.startswith(NOTE_LABEL[lang])), None)
        body, para = [], []
        for q in quotes:
            if q == note:
                continue
            if q:
                para.append(q)
            elif para:
                body.append(" ".join(para) if lang == "en" else "".join(para))
                para = []
        if para:
            body.append(" ".join(para) if lang == "en" else "".join(para))
        if lang == "en":
            body = [smart_quotes(b) for b in body]
            note = note and smart_quotes(note)
        title = m.group(2).strip() if lang == "zh" else smart_quotes(m.group(2).strip())
        if note:
            note = note[len(NOTE_LABEL[lang]):].strip()
        cards[int(m.group(1))] = {"title": title, "body": body, "note": note}
    return cards


def layout(card, lang, draw):
    """排出每一行的 (y, 文字, 字型, 顏色)；回傳行清單與文字底部 y。"""
    wrap = wrap_zh if lang == "zh" else wrap_en
    body_size = STYLE[lang]["body"][0]
    out, y = [], TOP
    for kind, paras, color in (("title", [card["title"]], INK), ("body", card["body"], INK)):
        f = font(lang, kind)
        size, lh, _ = STYLE[lang][kind]
        for i, para in enumerate(paras):
            for line in wrap(para, f, TEXT_W, draw):
                out.append((y, line, f, color))
                y += size * lh
            if i < len(paras) - 1:
                y += body_size * PARA_GAP
        y += body_size * (TITLE_GAP if kind == "title" else 0)
    if card["note"]:
        y += body_size * NOTE_GAP / 2
        out.append((y, None, None, INK_SOFT))  # 分隔線
        y += body_size * NOTE_GAP / 2
        f = font(lang, "note")
        size, lh, _ = STYLE[lang]["note"]
        for line in wrap(NOTE_LABEL[lang] + (" " if lang == "en" else "") + card["note"], f, TEXT_W, draw):
            out.append((y, line, f, INK_SOFT))
            y += size * lh
    return out, y


def render(volume, num, lang, cards, out_dir):
    src = ROOT / "assets-test" / f"book_{volume}" / "final" / f"book_{volume}_{num:02d}.png"
    base = Image.open(src).convert("RGBA")
    panel = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = panel.load()
    for x in range(COL + FADE):
        a = PANEL[3] if x < COL else int(PANEL[3] * (1 - (x - COL) / FADE))
        for yy in range(H):
            px[x, yy] = PANEL[:3] + (a,)
    img = Image.alpha_composite(base, panel)
    draw = ImageDraw.Draw(img)
    lines, bottom = layout(cards[num], lang, draw)
    for y, text, f, color in lines:
        if text is None:
            draw.line((MARGIN_L, y, MARGIN_L + 96, y), fill=color[:3] + (110,), width=1)
        else:
            draw.text((MARGIN_L, y), text, font=f, fill=color)
    folio = f"{PART[(volume, lang)]} {num}／{TOTAL[volume]}" if lang == "zh" else f"{PART[(volume, lang)]} · {num}/{TOTAL[volume]}"
    draw.text((MARGIN_L, H - BOTTOM + 16), folio, font=font(lang, "folio"), fill=INK_SOFT)
    path = out_dir / f"book_{volume}_{num:02d}_{lang}.png"
    img.convert("RGB").save(path)
    return path, bottom


def check_all():
    """全部張數的文字底部都要在頁碼上方。"""
    draw = ImageDraw.Draw(Image.new("RGB", (W, H)))
    limit = H - BOTTOM - 16
    worst = []
    for volume in ("front", "back"):
        for lang in ("zh", "en"):
            cards = parse(volume, lang)
            assert len(cards) == TOTAL[volume], (volume, lang, len(cards))
            for num, card in cards.items():
                _, bottom = layout(card, lang, draw)
                worst.append((round(bottom), volume, num, lang))
    worst.sort(reverse=True)
    print("文字底部最低的 5 張：", worst[:5], "上限", limit)
    return all(b <= limit for b, *_ in worst)


if __name__ == "__main__":
    volume, args = sys.argv[1], sys.argv[2:]
    ok = check_all()
    print("全部張數放得下：", ok)
    if "--check" in args:
        sys.exit(0 if ok else 1)
    out = ROOT / "assets-test" / "book_layout"
    out.mkdir(exist_ok=True)
    for lang in ("zh", "en"):
        cards = parse(volume, lang)
        for n in map(int, args):
            print(render(volume, n, lang, cards, out))
