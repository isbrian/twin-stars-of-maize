"""把 rig/hunahpu_rig.json 的點畫回圖上，輸出到 tools/out/ 供目視確認。
python3 tools/mark_points.py                      → reference_joints.png、parts_points.png
python3 tools/mark_points.py --grid               → reference_grid.png（每 50 px 一條格線，每 100 px 標原始座標）
python3 tools/mark_points.py --zoom X0 Y0 X1 Y1   → reference_zoom.png（裁切後放大 2 倍，含格線與已標的關節）"""
import json
import os
import sys

from PIL import Image, ImageDraw

ART = 'art'
OUT = 'tools/out'
RIG = 'rig/hunahpu_rig.json'
TILE = 360


def reference():
    return Image.open(os.path.join(ART, 'chr_hunahpu_reference.png')).convert('RGBA')


def draw_grid(im):
    d = ImageDraw.Draw(im)
    for x in range(0, im.width, 50):
        d.line([(x, 0), (x, im.height)], fill=(0, 255, 255, 170 if x % 100 == 0 else 70), width=1)
        if x % 100 == 0:
            d.text((x + 2, 2), str(x), fill=(0, 255, 255, 255))
    for y in range(0, im.height, 50):
        d.line([(0, y), (im.width, y)], fill=(0, 255, 255, 170 if y % 100 == 0 else 70), width=1)
        if y % 100 == 0:
            d.text((2, y + 2), str(y), fill=(0, 255, 255, 255))


def draw_joints(im, rig):
    d = ImageDraw.Draw(im)
    for name, (x, y) in rig['reference']['joints'].items():
        d.ellipse([x - 6, y - 6, x + 6, y + 6], outline=(0, 255, 0, 255), width=3)
        d.text((x + 8, y - 8), name, fill=(0, 255, 0, 255))


def main():
    os.makedirs(OUT, exist_ok=True)
    args = sys.argv[1:]
    if args[:1] == ['--grid']:
        im = reference()
        draw_grid(im)
        im.save(os.path.join(OUT, 'reference_grid.png'))
        print('MARK grid')
        return
    rig = json.load(open(RIG)) if os.path.exists(RIG) else None
    if args[:1] == ['--zoom']:
        x0, y0, x1, y1 = map(int, args[1:5])
        im = reference()
        draw_grid(im)
        if rig:
            draw_joints(im, rig)
        im = im.crop((x0, y0, x1, y1)).resize(((x1 - x0) * 2, (y1 - y0) * 2))
        im.save(os.path.join(OUT, 'reference_zoom.png'))
        print('MARK zoom')
        return
    im = reference()
    draw_joints(im, rig)
    im.save(os.path.join(OUT, 'reference_joints.png'))
    tiles = []
    for name, p in rig['parts'].items():
        part = Image.open(os.path.join(ART, name + '.png')).convert('RGBA')
        f = min(1.0, TILE / max(part.size))
        tile = Image.new('RGBA', (TILE, TILE), (70, 70, 70, 255))
        tile.alpha_composite(part.resize((max(1, int(part.width * f)), max(1, int(part.height * f)))))
        d = ImageDraw.Draw(tile)
        for key, col in (('pivot', (0, 255, 0, 255)), ('tip', (255, 230, 0, 255))):
            x, y = p[key][0] * f, p[key][1] * f
            d.ellipse([x - 6, y - 6, x + 6, y + 6], outline=col, width=3)
        d.text((4, TILE - 14), name.replace('chr_hunahpu_', '') + ' -> ' + p['bone'], fill=(255, 255, 255, 255))
        tiles.append(tile)
    cols = 6
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * TILE, rows * TILE), (30, 30, 30, 255))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % cols) * TILE, (i // cols) * TILE))
    sheet.save(os.path.join(OUT, 'parts_points.png'))
    print('MARK ok')


main()
