"""量每個分件的主軸與兩端點，輸出草稿與對照圖（A＝紅、B＝藍），供決定哪一端是軸心。
用法（在 prototypes/p4-art-pipeline/ 執行）：python3 tools/measure_parts.py
輸出：tools/out/parts_axes.png、tools/out/parts_draft.json"""
import json
import math
import os

from PIL import Image, ImageDraw

ART = 'art'
OUT = 'tools/out'
PARTS = [
    'chr_hunahpu_head', 'chr_hunahpu_torso', 'chr_hunahpu_loincloth_flap',
    'chr_hunahpu_upperarm_r', 'chr_hunahpu_forearm_r', 'chr_hunahpu_hand_open_r', 'chr_hunahpu_hand_grip_r',
    'chr_hunahpu_upperarm_l', 'chr_hunahpu_forearm_l', 'chr_hunahpu_hand_open_l', 'chr_hunahpu_hand_grip_l',
    'chr_hunahpu_thigh_r', 'chr_hunahpu_shin_r', 'chr_hunahpu_foot_r',
    'chr_hunahpu_thigh_l', 'chr_hunahpu_shin_l', 'chr_hunahpu_foot_l',
    'wpn_axe',
]
TILE = 360  # 對照圖每格最長邊


def axis_ends(im):
    """主成分分析求主軸；兩端點取主軸方向最外側 3% 像素的平均，再往內收 4%（落在關節圓弧附近）。"""
    w, h = im.size
    a = im.getchannel('A').load()
    pts = [(x, y) for y in range(h) for x in range(w) if a[x, y] >= 128]
    n = len(pts)
    mx = sum(p[0] for p in pts) / n
    my = sum(p[1] for p in pts) / n
    sxx = sum((p[0] - mx) ** 2 for p in pts) / n
    syy = sum((p[1] - my) ** 2 for p in pts) / n
    sxy = sum((p[0] - mx) * (p[1] - my) for p in pts) / n
    ang = 0.5 * math.atan2(2 * sxy, sxx - syy)
    ux, uy = math.cos(ang), math.sin(ang)
    proj = [((p[0] - mx) * ux + (p[1] - my) * uy, p) for p in pts]
    lo = min(t for t, _ in proj)
    hi = max(t for t, _ in proj)
    span = hi - lo

    def end(at_lo):
        edge = [p for t, p in proj if ((t - lo) if at_lo else (hi - t)) <= span * 0.03]
        ex = sum(p[0] for p in edge) / len(edge)
        ey = sum(p[1] for p in edge) / len(edge)
        k = span * 0.04 * (1 if at_lo else -1)
        return [round(ex + ux * k, 1), round(ey + uy * k, 1)]

    return {'size': [w, h], 'A': end(True), 'B': end(False)}


def main():
    os.makedirs(OUT, exist_ok=True)
    draft = {}
    tiles = []
    for name in PARTS:
        im = Image.open(os.path.join(ART, name + '.png')).convert('RGBA')
        r = axis_ends(im)
        draft[name] = r
        f = min(1.0, TILE / max(im.size))
        tile = Image.new('RGBA', (TILE, TILE), (70, 70, 70, 255))
        small = im.resize((max(1, int(im.width * f)), max(1, int(im.height * f))))
        tile.alpha_composite(small)
        d = ImageDraw.Draw(tile)
        for key, col in (('A', (255, 50, 50, 255)), ('B', (60, 140, 255, 255))):
            x, y = r[key][0] * f, r[key][1] * f
            d.ellipse([x - 7, y - 7, x + 7, y + 7], outline=col, width=3)
            d.text((x + 9, y - 6), key, fill=col)
        d.text((4, TILE - 14), name.replace('chr_hunahpu_', ''), fill=(255, 255, 255, 255))
        tiles.append(tile)
    cols = 6
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * TILE, rows * TILE), (30, 30, 30, 255))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % cols) * TILE, (i // cols) * TILE))
    sheet.save(os.path.join(OUT, 'parts_axes.png'))
    with open(os.path.join(OUT, 'parts_draft.json'), 'w') as fp:
        json.dump(draft, fp, indent=1)
    print('MEASURE ok', len(draft), '件')


main()
