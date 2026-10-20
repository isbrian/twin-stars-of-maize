#!/usr/bin/env python3
"""通用切件工具：把任意角色的基準圖（洋紅底）依人工標的關節／骨頭表切成骨架分件（MV-SLICE-001b2b1 Task 2）。

雙胞胎的人形切件（prototypes/p4-art-pipeline/tools/cut_parts.py）不動；這支只借它的去背、裁切、降明度等工具函式，
給爬行型、飛行型、Seven Macaw 用。

用法：
  python3 tools/cut_rig.py crawler flyer sevenmacaw
  python3 tools/cut_rig.py crawler --src assets-test --out assets-test/chr_b2b1/parts

輸入 tools/rig_src/{角色}_joints.json（人工標的）：
  src     基準圖路徑，相對 assets-test/
  joints  {關節名: [x, y]}（來源像素）
  bones   [[骨頭, 父骨頭, 起點關節, 終點關節, 分配半徑, z], ...]；父骨頭排在前面，每根骨頭都要有兩個關節
  polys   {分件: [[x, y], ...]}  選填；圈進去的像素直接歸這件（依列出順序，先列的先贏），優先於距離
  far     [[分件, 骨頭, 複製自, z, [dx, dy]], ...]  選填；遠側件＝複製「複製自」骨頭的分件、明度 ×0.72，
          關節＝被複製骨頭的對應關節 + [dx, dy]（寫進輸出的 joints）。「骨頭」也要列在 bones 裡，且自己沒有像素
  cap     關節重疊半徑（來源像素），預設 34
  caps    {關節: 半徑}  選填；個別關節的重疊半徑（切線很長的關節，例如橫切整個脖子的頭關節）
  overlap {分件: [[x, y], ...]}  選填；圈內的不透明像素（同一張圖）也帶進這件、不從原本的分件拿走。
          單向的重疊：墊在會轉開的接縫底下（例如脖子仰起時露出的背），z 較低的件用
  snap    [[x0, y0, x1, y1], ...]  選填；方框內（右、下不含）改成「沿墨線切」：墨線圍出的每一塊整塊歸給塊內多數像素的分件，
          墨線本身歸給它兩旁（沿墨線 INK_REACH px 內）的每個分件，輪廓兩側都留著。用在直線切會切過羽毛的地方
  points  {名稱: {"bone": 骨頭, "at": [x, y]}}  選填；來源座標，輸出換成骨頭座標
  heads   {名稱: {"src": 特寫圖, "marks": [[x, y], [x, y]]}}  選填；替換頭（受傷的頭）。配 head_marks（主圖上同樣兩個特徵點）：
          兩點算縮放＋平移（不旋轉）把特寫貼到主圖座標，用完整頭件（head 骨頭）的不透明範圍往外長 HEAD_GROW px 裁切；
          輸出分件 head_{名稱}，掛 head 骨頭、同樣的關節（軸心、末端）與 z，"visible": false
  layers  {名稱: {"src": 圖, "marks": [[x, y], [x, y]], "ref_marks": [[x, y], [x, y]], "bones": [骨頭, ...]}}  選填；
          某幾根骨頭改從另一張圖切（例如和身體分開畫的翅膀）。圖層先依兩個特徵點縮放＋平移（同 heads）貼回主圖座標
          （marks＝圖層上的點、ref_marks＝同樣兩點在主圖座標）；列在 bones 的骨頭只從這張圖層切、圖層的像素也只分給它們，
          關節重疊圈只帶同一張圖裡的相鄰件。polys 作用在骨頭所在的那張圖；snap 只作用在主圖
  erase   [[[x, y], ...], ...]  選填；主圖在這些多邊形內的像素當背景（例如修圖留下的痕跡）
  origin  原樣帶進輸出
輸出：分件 PNG 與完整基準圖（去背；有 layers 時是主圖＋圖層依骨頭 z 疊成的合成圖）寫進輸出資料夾；來源像素的 rig json 寫進 tools/rig_src/{角色}_rig.json。
分件的檔名與 rig 的 parts 鍵一律 chr_{角色}_{短名}；短名＝一般件是骨頭名、遠側件是 far 的分件名。
同樣的輸入一定產生同樣的位元組。需要 Python 3、Pillow、numpy。
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RIG_SRC = ROOT / "tools" / "rig_src"
ASSETS = ROOT / "assets-test"
OUT = ASSETS / "chr_b2b1" / "parts"
sys.path.insert(0, str(ROOT / "prototypes/p4-art-pipeline/tools"))
from cut_parts import FAR_DARKEN, crop_part, darken, key_magenta, polygon_mask, seg_dist  # noqa: E402

DEFAULT_CAP = 34  # 關節重疊圓的半徑（來源像素）；同 cut_parts 的 JOINT_CAP
ALPHA_OPAQUE = 32  # 算「不透明」的門檻（分件像素與 content_height）；同 import_art 的 ALPHA_MIN：
# 去背後整張圖都有 Alpha 1～32 的淡雜點（爬行型右下角還有一點 21），算進來會讓內容外框變成整張圖、分件被拉大。
# 超過門檻但四周 8 格都不是不透明的單點也不算（Seven Macaw 左下角 (0, 1023) 有一點 34，content_height 會多 40 px）
INK_MAX = 70  # 墨線：RGB 最大值低於這個（Seven Macaw 的墨線 < 50，最暗的羽毛陰影 > 110）
INK_REACH = 6  # 從某塊沿墨線走幾 px 內的墨線歸那塊的分件（墨線粗約 3～5 px）
SNAP_MIN = 30  # 小於這麼多 px 的塊當墨線處理（墨線裡的反鋸齒縫，自己投票會把周圍墨線帶成碎片）
HEAD_BONE = "head"  # 替換頭掛的骨頭
HEAD_GROW = 6  # 替換頭的裁切範圍：完整頭件的不透明範圍往外長幾 px（特寫畫得比較大，邊緣留一點餘裕）


def _fail(msg):
    raise ValueError(msg)


def _opaque(rgba):
    """不透明遮罩：Alpha > ALPHA_OPAQUE，且 8 鄰格裡至少有一格也是（去掉單點雜點）。"""
    o = rgba[..., 3] > ALPHA_OPAQUE
    p = np.pad(o, 1)
    h, w = o.shape
    n = sum(p[1 + dy:1 + dy + h, 1 + dx:1 + dx + w] for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)
    return o & (n > 0)


def _grow(mask, r):
    """遮罩往外長 r px（圓形）。"""
    p = np.pad(mask, r)
    h, w = mask.shape
    out = np.zeros_like(mask)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                out |= p[r + dy:r + dy + h, r + dx:r + dx + w]
    return out


def _regions(mask):
    """4 鄰連通區標號：0, 1, 2, …；不在遮罩內的是 -1。numpy 取最小鄰居＋指標跳躍，反覆到不再變。"""
    h, w = mask.shape
    big = h * w
    lab = np.where(mask, np.arange(big).reshape(h, w), big)
    while True:
        p = np.pad(lab, 1, constant_values=big)
        m = np.minimum.reduce([lab, p[:-2, 1:-1], p[2:, 1:-1], p[1:-1, :-2], p[1:-1, 2:]])
        f = np.where(mask, m, big).ravel()
        f = np.where(f < big, f[np.minimum(f, big - 1)], big).reshape(h, w)
        if (f == lab).all():
            break
        lab = f
    _, idx = np.unique(lab, return_inverse=True)
    return np.where(mask, idx.reshape(h, w), -1)


def _snap(base, rgba, opaque, box):
    """方框內沿墨線重分歸屬（見 docstring 的 snap）；直接改 base（{分件: 遮罩}，蓋滿不透明像素；重疊處算後面的分件）。"""
    x0, y0, x1, y1 = box
    sl = (slice(y0, y1), slice(x0, x1))
    names = list(base)
    own = np.full(opaque[sl].shape, -1)
    for i, n in enumerate(names):
        own[base[n][sl]] = i
    ink = opaque[sl] & (rgba[sl][..., :3].max(axis=-1) < INK_MAX)
    lab = _regions(opaque[sl] & ~ink)
    if lab.max() < 0:
        return
    tiny = np.bincount(lab[lab >= 0]) < SNAP_MIN
    ink |= (lab >= 0) & tiny[lab.clip(0)]
    lab = np.where(ink, -1, lab)
    counts = np.zeros((lab.max() + 1, len(names)), int)
    np.add.at(counts, (lab[lab >= 0], own[lab >= 0]), 1)
    win = np.where(lab >= 0, counts.argmax(axis=1)[lab.clip(0)], -1)
    new = {n: win == i for i, n in enumerate(names) if (win == i).any()}
    for _ in range(INK_REACH):  # 墨線兩旁的塊各自沿墨線往外長：可重疊（輪廓兩側都留著）、不跨過別的塊
        new = {n: m | (_grow(m, 1) & ink) for n, m in new.items()}
    claimed = np.any(list(new.values()), axis=0)
    added = True
    while added:  # 更粗的墨線：剩下的接著沿墨線長，先到先得、不重疊
        added = False
        for n, m in new.items():
            add = _grow(m, 1) & ink & ~claimed
            if add.any():
                new[n], claimed, added = m | add, claimed | add, True
    for i, n in enumerate(names):  # 沒連到任何塊的墨線維持原歸屬
        base[n][sl] = new.get(n, False) | (ink & ~claimed & (own == i))


def _paste_marked(src, marks, ref_marks, size):
    """圖（受傷頭特寫、圖層）去背後依兩個特徵點縮放＋平移（最小平方、不旋轉），貼到主圖大小（size＝[W, H]）的透明畫布上。"""
    v, m = np.array(marks, float), np.array(ref_marks, float)
    dv, dm = v[1] - v[0], m[1] - m[0]
    s = float(dm @ dv) / max(float(dv @ dv), 1e-6)
    t = m.mean(axis=0) - s * v.mean(axis=0)
    img = Image.fromarray(key_magenta(Image.open(src)))
    w, h = img.size
    # 預乘 Alpha 再縮放（同 import_art）：透明處的顏色不混進邊緣
    small = img.convert("RGBa").resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS).convert("RGBA")
    canvas = Image.new("RGBA", tuple(size))
    canvas.paste(small, (int(round(t[0])), int(round(t[1]))))
    return np.asarray(canvas).copy()


def _round(xy):
    return [round(float(c), 1) for c in xy]


def _check_spec(spec, far):
    """骨頭表：父骨頭在前、名稱不重複；遠側件指到存在的一般骨頭。"""
    names = []
    for bone, parent, *_ in spec["bones"]:
        if bone in names:
            _fail(f"骨頭重複：{bone}")
        if parent and parent not in names:
            _fail(f"骨頭 {bone} 的父骨頭 {parent} 沒有排在它前面")
        names.append(bone)
    for part, bone, copy_of, *_ in far:
        if bone not in names:
            _fail(f"遠側件 {part} 的骨頭 {bone} 沒有列在 bones")
        if copy_of not in names or copy_of in {f[1] for f in far}:
            _fail(f"遠側件 {part} 複製自 {copy_of}，必須是一般骨頭")
    for name in spec.get("polys", {}):
        if name not in names or name in {f[1] for f in far}:
            _fail(f"polys 的分件 {name} 不是一般骨頭")
    for name in spec.get("overlap", {}):
        if name not in names or name in {f[1] for f in far}:
            _fail(f"overlap 的分件 {name} 不是一般骨頭")
    for name, p in spec.get("points", {}).items():
        if p["bone"] not in names:
            _fail(f"光點 {name} 的骨頭 {p['bone']} 沒有列在 bones")
    in_layer = set()
    for lname, layer in spec.get("layers", {}).items():
        if len(layer.get("marks", [])) != 2 or len(layer.get("ref_marks", [])) != 2:
            _fail(f"圖層 {lname} 的 marks 與 ref_marks 都要剛好兩個點")
        for bone in layer.get("bones", []):
            if bone not in names or bone in {f[1] for f in far} or bone in in_layer:
                _fail(f"圖層 {lname} 的骨頭 {bone} 不是一般骨頭，或已在別的圖層")
            in_layer.add(bone)
    if spec.get("heads"):
        if HEAD_BONE not in names:
            _fail(f"有 heads 就要有 {HEAD_BONE} 骨頭")
        if len(spec.get("head_marks", [])) != 2 or any(len(h.get("marks", [])) != 2 for h in spec["heads"].values()):
            _fail("head_marks 與每個 heads 的 marks 都要剛好兩個點")


def _bone_point(bone, at, joints):
    """來源座標 → 骨頭座標：原點在起點關節、x 軸沿起點→終點（靜止姿勢）。"""
    a, b = np.array(joints[bone[2]], float), np.array(joints[bone[3]], float)
    u = (b - a) / max(float(np.linalg.norm(b - a)), 1e-6)
    d = np.array(at, float) - a
    return _round([d[0] * u[0] + d[1] * u[1], -d[0] * u[1] + d[1] * u[0]])


def cut(char, src_dir, out_dir, rig_dir=RIG_SRC):
    """切一個角色。src_dir＝基準圖的根（assets-test/）、out_dir＝分件輸出；回傳來源像素的 rig dict。"""
    src_dir, out_dir, rig_dir = Path(src_dir), Path(out_dir), Path(rig_dir)
    spec = json.loads((rig_dir / f"{char}_joints.json").read_text(encoding="utf-8"))
    far = spec.get("far", [])
    _check_spec(spec, far)
    J = {k: np.array(v, float) for k, v in spec["joints"].items()}
    bones = {b[0]: b for b in spec["bones"]}
    far_bones = {f[1] for f in far}
    for bone, _, a, b, *_ in spec["bones"]:  # 遠側骨頭的關節下面才算出來，不在這裡查
        for j in (a, b):
            if bone not in far_bones and j not in J:
                _fail(f"骨頭 {bone} 的關節 {j} 沒有座標")
    for part, bone, copy_of, z, (dx, dy) in far:
        for k in (2, 3):  # 遠側關節＝被複製骨頭的對應關節 + 偏移
            J[bones[bone][k]] = J[bones[copy_of][k]] + np.array([dx, dy], float)

    rgba = key_magenta(Image.open(src_dir / spec["src"]))
    H, W = rgba.shape[:2]
    for poly in spec.get("erase", []):  # 0. 擦除：主圖的這些像素當背景
        rgba[polygon_mask(poly, W, H)] = 0
    opaque = _opaque(rgba)
    py, px = np.mgrid[0:H, 0:W]
    near = [b for b in spec["bones"] if b[0] not in far_bones]
    layers = spec.get("layers", {})
    layer_of = {bone: n for n, layer in layers.items() for bone in layer["bones"]}
    img_of = {b[0]: rgba for b in near}  # 每根骨頭從哪張圖（主圖或對位後的圖層）切

    def assign(bones, img_opaque):
        """每個不透明像素歸給「到骨段的距離 − 分配半徑」最小的骨頭（只在這幾根之間）。"""
        cost = np.stack([seg_dist(px, py, J[a], J[b]) - r for _, _, a, b, r, _ in bones])
        owner = np.argmin(cost, axis=0)
        return {b[0]: img_opaque & (owner == i) for i, b in enumerate(bones)}

    def claim_polys(base, layer, img_opaque):
        """polys 優先於距離：先列的先贏，圈到的不透明像素直接歸那件（只在同一張圖的骨頭之間）。"""
        claimed = np.zeros((H, W), bool)
        claim = {}
        for name, poly in spec.get("polys", {}).items():
            if layer_of.get(name) == layer:
                claim[name] = polygon_mask(poly, W, H) & img_opaque & ~claimed
                claimed |= claim[name]
        for name in base:
            base[name] = (base[name] & ~claimed) | claim.get(name, False)
        return base

    # 1. 主圖的像素只分給不在圖層裡的骨頭；2. polys 優先於距離
    base = claim_polys(assign([b for b in near if b[0] not in layer_of], opaque), None, opaque)
    for box in spec.get("snap", []):  # 2b. 沿墨線切（之後 base 可能互相重疊：墨線兩邊都帶）
        _snap(base, rgba, opaque, box)
    for n, layer in layers.items():  # 2c. 圖層：對位貼回主圖座標，像素只分給圖層自己的骨頭
        img = _paste_marked(src_dir / layer["src"], layer["marks"], layer["ref_marks"], (W, H))
        img_opaque = _opaque(img)
        base.update(claim_polys(assign([b for b in near if layer_of.get(b[0]) == n], img_opaque), n, img_opaque))
        img_of.update({bone: img for bone in layer["bones"]})

    # 3. 關節重疊：兩端關節圓內帶進共用這個關節的相鄰件的像素，轉動時補住接縫
    cap = spec.get("cap", DEFAULT_CAP)
    caps = spec.get("caps", {})
    parts, rig_parts = {}, {}
    for bone, parent, a, b, r, z in near:
        mask = base[bone].copy()
        for j in (a, b):
            circle = np.hypot(px - J[j][0], py - J[j][1]) < caps.get(j, cap)
            for other in near:  # 只帶同一張圖裡的相鄰件
                if other[0] != bone and j in other[2:4] and layer_of.get(other[0]) == layer_of.get(bone):
                    mask |= circle & base[other[0]]
        if bone in spec.get("overlap", {}):  # 3b. 單向重疊：圈內同一張圖的像素也帶進來
            mask |= polygon_mask(spec["overlap"][bone], W, H) & _opaque(img_of[bone])
        if not mask.any():
            if bone in layer_of:
                _fail(f"圖層 {layer_of[bone]} 的骨頭 {bone} 沒有任何像素：檢查 marks／ref_marks")
            _fail(f"分件 {bone} 沒有任何像素：檢查關節座標與分配半徑")
        part, pivot, tip = crop_part(img_of[bone], mask, J[a], J[b])
        parts[bone] = part
        rig_parts[bone] = {"size": [int(part.shape[1]), int(part.shape[0])], "bone": bone,
                           "pivot": pivot, "tip": tip, "z": z}
        if bone == HEAD_BONE:
            head_area = _grow(mask, HEAD_GROW)
    # 4. 遠側件：複製近側、降明度，軸心與末端不變（關節已偏移）
    for part, bone, copy_of, z, _ in far:
        parts[part] = darken(parts[copy_of])
        rig_parts[part] = {**rig_parts[copy_of], "bone": bone, "z": z}
    # 5. 替換頭：特寫對位到主圖、裁成完整頭的範圍，掛同一根頭骨（預設隱藏）
    for name, h in spec.get("heads", {}).items():
        b = bones[HEAD_BONE]
        pasted = _paste_marked(src_dir / h["src"], h["marks"], spec["head_marks"], (W, H))
        mask = head_area & _opaque(pasted)
        if not mask.any():
            _fail(f"替換頭 {name} 對位後和完整頭沒有重疊：檢查 marks")
        part, pivot, tip = crop_part(pasted, mask, J[b[2]], J[b[3]])
        short = f"{HEAD_BONE}_{name}"
        parts[short] = part
        rig_parts[short] = {"size": [int(part.shape[1]), int(part.shape[0])], "bone": HEAD_BONE,
                            "pivot": pivot, "tip": tip, "z": rig_parts[HEAD_BONE]["z"], "visible": False}
    # 輸出順序＝骨頭表順序（一般件）後接 far 順序、heads 順序，檔案與 JSON 才穩定
    key = lambda n: f"chr_{char}_{n}"

    # 完整基準圖：有圖層時，圖層骨頭的像素蓋在 z 比它低的主圖像素上（＝靜止姿勢的樣子）
    reference = rgba
    if layers:
        reference = rgba.copy()
        zmap = np.full((H, W), -np.inf)
        for bone, _, _, _, _, z in near:
            if bone not in layer_of:
                zmap[base[bone]] = np.maximum(zmap[base[bone]], z)
        for bone, _, _, _, _, z in sorted((b for b in near if b[0] in layer_of), key=lambda b: b[5]):
            show = base[bone] & (zmap < z)
            reference[show] = img_of[bone][show]
            zmap[show] = z

    out_dir.mkdir(parents=True, exist_ok=True)
    for name, part in parts.items():
        Image.fromarray(part).save(out_dir / f"{key(name)}.png")
    Image.fromarray(reference).save(out_dir / f"chr_{char}_reference.png")

    joints = {k: _round(v) for k, v in J.items()}
    ys = np.nonzero(_opaque(reference).any(axis=1))[0]
    rig = {
        "reference": {"size": [W, H], "joints": joints, "content_height": int(ys.max() - ys.min() + 1)},
        "bones": [list(b[:4]) for b in spec["bones"]],
        "root_length": 0.0,  # 每根骨頭（含根）都有兩個關節；終點空字串的根骨頭才用得到
        "origin": spec.get("origin", {}),
        "parts": {key(n): p for n, p in rig_parts.items()},
        "points": {n: {"bone": p["bone"], "at": _bone_point(bones[p["bone"]], p["at"], joints)}
                   for n, p in spec.get("points", {}).items()},
    }
    rig_dir.mkdir(parents=True, exist_ok=True)
    (rig_dir / f"{char}_rig.json").write_text(json.dumps(rig, ensure_ascii=False, indent=1), encoding="utf-8")
    return rig


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("chars", nargs="+")
    ap.add_argument("--src", type=Path, default=ASSETS, help="基準圖的根資料夾（joints json 的 src 相對於它）")
    ap.add_argument("--out", type=Path, default=OUT, help="分件輸出資料夾")
    args = ap.parse_args()
    for c in args.chars:
        rig = cut(c, args.src, args.out)
        print(f"CUT {c}: {len(rig['parts'])} 件 → {args.out}")
