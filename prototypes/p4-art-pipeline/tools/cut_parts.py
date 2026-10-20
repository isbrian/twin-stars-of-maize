"""從「分件友善姿勢」的基準圖切出骨架分件（MV-ASSET-010）。

做法：洋紅背景去背 → 每個像素歸給最近的骨段（軀幹、頭的半徑較大）→ 每個分件在兩端關節多帶一圈
圓形重疊（轉動時補住接縫）→ 遠側四肢用近側分件複製、明度降一階 → 握拳的手依張開的手縮放對齊。
同時輸出 p4 原型用的 rig/{角色}_rig.json；因為分件就切自基準圖，縮放比例理論上都是 1。

用法（在 prototypes/p4-art-pipeline 底下）：
  python3 tools/cut_parts.py hunahpu
讀 rig/{角色}_joints.json（人工標的關節）與 assets-test/chr_batch1/ 的原圖，輸出到 assets-test/chr_batch1/parts/。
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent.parent
ROOT = HERE.parent.parent
SRC = ROOT / "assets-test" / "chr_batch1"
OUT = SRC / "parts"
BATCH0 = ROOT / "assets-test" / "batch0" / "art"

MAGENTA = np.array([255, 0, 255], float)
JOINT_CAP = 34          # 關節重疊圓的半徑（基準圖 px）
FAR_DARKEN = 0.72       # 遠側四肢的明度倍數（ART_SPEC：明度降一階）

# 分件：(名稱, 骨頭, 起點關節, 終點關節, 分配半徑, z)
NEAR_PARTS = [
    ("head", "head", "neck", "crown", 95, 1),
    ("upperarm_r", "upperarm_r", "shoulder_r", "elbow_r", 30, 3),
    ("forearm_r", "forearm_r", "elbow_r", "wrist_r", 28, 4),
    ("hand_open_r", "hand_r", "wrist_r", "hand_tip_r", 26, 5),
    ("thigh_r", "thigh_r", "hip_r", "knee_r", 40, 2),
    ("shin_r", "shin_r", "knee_r", "ankle_r", 32, 2),
    ("foot_r", "foot_r", "ankle_r", "toe_r", 26, 2),
]
TORSO = ("torso", "spine", "hip", "neck", 125, 0)
# 遠側腿在基準圖上看得到：直接切它自己的像素（頂端的缺口正好對應自己那側的腰布），再降明度
FAR_LEG = [
    ("thigh_l", "thigh_l", "hip_l", "knee_l", 36, -2),
    ("shin_l", "shin_l", "knee_l", "ankle_l", 30, -2),
    ("foot_l", "foot_l", "ankle_l", "toe_l", 24, -2),
]
# 遠側手臂藏在身後、圖上看不到：用近側複製。(名稱, 骨頭, 複製自, z)
FAR_PARTS = [
    ("upperarm_l", "upperarm_l", "upperarm_r", -3),
    ("forearm_l", "forearm_l", "forearm_r", -3),
    ("hand_open_l", "hand_l", "hand_open_r", -3),
]
FAR_ARM_OFFSET = np.array([-28.0, -8.0])  # 遠側手臂藏在身後：近側手臂的關節往後上方移


INK = np.array([30.0, 15.0, 10.0])  # 輪廓線的顏色（近黑的深褐）


def key_magenta(img):
    """洋紅背景 → 透明；半透明邊緣做反混合，去掉洋紅毛邊。

    角色邊緣幾乎都是「黑色輪廓線 × 洋紅背景」的混色：落在洋紅→輪廓線連線附近的像素，
    alpha＝在連線上的位置（半黑半紅＝半透明）。其他顏色用「離洋紅的距離」估 alpha。
    """
    rgb = np.asarray(img.convert("RGB")).astype(float)
    dist = np.linalg.norm(rgb - MAGENTA, axis=2)
    alpha = np.clip((dist - 40) / 160, 0, 1)
    d = INK - MAGENTA
    t = np.einsum("ijk,k->ij", rgb - MAGENTA, d) / float(np.dot(d, d))
    perp = np.linalg.norm(rgb - (MAGENTA + t[..., None] * d), axis=2)
    on_ink_line = (perp < 45) & (t < 0.97)
    alpha = np.where(on_ink_line, np.clip(t, 0, 1), alpha)
    a = alpha[..., None]
    fg = np.where(a > 0.01, (rgb - (1 - a) * MAGENTA) / np.maximum(a, 0.01), 0)
    return np.dstack([np.clip(fg, 0, 255), alpha * 255]).astype(np.uint8)


OUTLINE_GROW = 22       # 四肢從膚色往外長多少 px 收進自己的輪廓線與半透明邊緣（基準圖輪廓線約 16～18 px，再加邊緣）


def skin_mask(rgba):
    """膚色像素：四肢只用膚色決定歸屬，衣物、配件、別處的輪廓線都不會被四肢帶走。HSV 用 PIL 的 0～255 刻度。"""
    hsv = np.asarray(Image.fromarray(rgba[..., :3]).convert("HSV")).astype(int)
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    return (h >= 10) & (h <= 26) & (s >= 100) & (s <= 205) & (v >= 140) & (rgba[..., 3] > 200)


def grow(mask, n):
    """往外長 n px（8 鄰域，逐步）。"""
    m = mask.copy()
    for _ in range(n):
        p = np.pad(m, 1)
        m = p[1:-1, 1:-1] | p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:] | p[:-2, :-2] | p[:-2, 2:] | p[2:, :-2] | p[2:, 2:]
    return m


def polygon_mask(poly, w, h):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).polygon([tuple(p) for p in poly], fill=1)
    return np.asarray(m).astype(bool)


def seg_dist(px, py, a, b):
    ab = b - a
    t = np.clip(((px - a[0]) * ab[0] + (py - a[1]) * ab[1]) / max(ab @ ab, 1e-6), 0, 1)
    return np.hypot(px - (a[0] + t * ab[0]), py - (a[1] + t * ab[1]))


def crop_part(rgba, mask, pivot, tip):
    ys, xs = np.nonzero(mask)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    part = rgba[y0:y1, x0:x1].copy()
    part[..., 3] = np.where(mask[y0:y1, x0:x1], part[..., 3], 0)
    off = np.array([x0, y0], float)
    return part, (pivot - off).round(1).tolist(), (tip - off).round(1).tolist()


def add_disc(part, pivot, tip, radius, color):
    """在軸心畫一個實心圓（畫在原有像素下面），必要時擴大畫布；回傳新分件與平移後的軸心、末端。"""
    h, w = part.shape[:2]
    cx, cy = pivot
    pad_l = max(0, int(np.ceil(radius - cx)))
    pad_t = max(0, int(np.ceil(radius - cy)))
    pad_r = max(0, int(np.ceil(cx + radius - w)))
    pad_b = max(0, int(np.ceil(cy + radius - h)))
    out = np.zeros((h + pad_t + pad_b, w + pad_l + pad_r, 4), np.uint8)
    yy, xx = np.mgrid[0:out.shape[0], 0:out.shape[1]]
    disc = np.hypot(xx - (cx + pad_l), yy - (cy + pad_t)) < radius
    out[disc] = list(color) + [255]
    src = np.zeros_like(out)
    src[pad_t:pad_t + h, pad_l:pad_l + w] = part
    a = src[..., 3:4] / 255.0
    out = (src * a + out * (1 - a)).astype(np.uint8)
    out[..., 3] = np.maximum(src[..., 3], out[..., 3])
    shift = [pad_l, pad_t]
    return out, [pivot[0] + shift[0], pivot[1] + shift[1]], [tip[0] + shift[0], tip[1] + shift[1]]


def darken(part):
    p = part.copy()
    p[..., :3] = (p[..., :3] * FAR_DARKEN).astype(np.uint8)
    return p


def grip_hand(char, open_part_len, rgba_open):
    """握拳的手：去背、裁到內容，依張開的手的長度（腕到指尖）縮放；軸心在左端中點，末端在右端中點。"""
    img = Image.open(SRC / f"chr_{char}_hand_grip.png")
    g = key_magenta(img)
    ys, xs = np.nonzero(g[..., 3] > 128)
    g = g[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = g.shape[:2]
    k = open_part_len / w
    g = np.asarray(Image.fromarray(g).resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS))
    h, w = g.shape[:2]
    return g, [0.0, h / 2], [float(w), h / 2]


def cut(char):
    spec = json.loads((HERE / "rig" / f"{char}_joints.json").read_text())
    J = {k: np.array(v, float) for k, v in spec["joints"].items()}
    img = Image.open(SRC / f"chr_{char}_reference.png")
    rgba = key_magenta(img)
    H, W = rgba.shape[:2]
    opaque = rgba[..., 3] > 20
    skin = skin_mask(rgba)
    py, px = np.mgrid[0:H, 0:W]
    # 頭：人工圈的多邊形（含馬尾、髮髻），多邊形裡偏下方的衣物色（披肩領口）歸軀幹
    edge = (rgba[..., :3].max(axis=2) < 90) | (rgba[..., 3] < 200)   # 輪廓線、頭髮與半透明邊緣（不是衣物色塊）
    cloth_low = (py > spec["head_cloth_y"]) & ~skin & ~edge
    head = grow(polygon_mask(spec["head_poly"], W, H), 8) & opaque & ~cloth_low

    # 1. 頭以外的膚色像素歸給「距離 − 半徑」最小的骨段（軀幹也競爭，胸口、腹部的膚色歸軀幹）
    segs = [TORSO] + NEAR_PARTS + FAR_LEG
    costs = [seg_dist(px, py, J[a], J[b]) - r for _, _, a, b, r, _ in segs]
    owner = np.argmin(np.stack(costs), axis=0)
    names = [sg[0] for sg in segs]

    # 2. 四肢與遠側腿：自己的膚色往外長 OUTLINE_GROW px，收進緊貼的輪廓線與半透明邊緣（不碰頭）
    base = {}
    for i, name in enumerate(names):
        if name in ("torso", "head"):
            continue
        own = skin & ~head & (owner == i)
        base[name] = grow(own, OUTLINE_GROW) & opaque & ~head & (edge | own)
    taken = np.logical_or.reduce(list(base.values()))
    base["head"] = head
    rest = opaque & ~head & ~taken            # 剩下的全部歸軀幹：衣物、配件、胸腹
    # 軀幹自己的色塊：衣物、配件、胸腹。輪廓線與「墨線→膚色」的反鋸齒過渡色不算；
    # 亮色（紅黃、米白、膚色）或明顯偏離那條混色線的顏色（Xbalanque 的藍綠）才算
    skin_color = np.median(rgba[skin][:, :3], axis=0)
    axis = (skin_color - INK) / np.linalg.norm(skin_color - INK)
    v = rgba[..., :3].astype(float) - INK
    off_line = np.linalg.norm(v - np.einsum("hwc,c->hw", v, axis)[..., None] * axis, axis=2) > 60
    core = rest & ((rgba[..., :3].max(axis=2) >= 150) | off_line) & (rgba[..., 3] >= 200)
    if "torso_poly" in spec:   # 深色配件（Xbalanque 的深褐獵網）達不到亮度門檻，人工圈起來直接算軀幹
        core |= rest & polygon_mask(spec["torso_poly"], W, H) & (rgba[..., 3] >= 200)
    base["torso"] = rest & grow(core, OUTLINE_GROW + 2)   # 只留緊貼色塊的輪廓線；四肢外圈殘留的邊緣不要

    parts, rig_parts = {}, {}
    for name, bone, a, b, r, z in segs:
        mask = base[name].copy()
        # 3. 關節重疊：關節圓內帶進相鄰「四肢」的像素，轉動時補住接縫；不帶衣物
        #    軀幹在肩、髖補一圈四肢的底（四肢轉動時不露洞）；頭在脖子只帶膚色
        joints_here = (a, b) if name != "torso" else ("neck", "shoulder_r", "hip_r")
        for j in joints_here:
            if j == "crown":
                continue
            circle = np.hypot(px - J[j][0], py - J[j][1]) < JOINT_CAP
            if name == "head":
                mask |= circle & skin & ~base["torso"] | circle & head
                continue
            limbs = [n for n, _, aa, bb, _, _ in NEAR_PARTS + FAR_LEG if j in (aa, bb) and n != "head"]
            mask |= circle & np.logical_or.reduce([base[n] for n in limbs])
        part, pivot, tip = crop_part(rgba, mask, J[a], J[b])
        parts[name] = darken(part) if name.endswith("_l") else part
        rig_parts[f"chr_{char}_{name}"] = {"size": [part.shape[1], part.shape[0]], "bone": bone,
                                          "pivot": pivot, "tip": tip, "z": z}

    # 3. 握拳的手（近側）：大小依張開的手
    open_len = float(np.linalg.norm(J["hand_tip_r"] - J["wrist_r"]))
    gp, gpiv, gtip = grip_hand(char, open_len, parts["hand_open_r"])
    parts["hand_grip_r"] = gp
    rig_parts[f"chr_{char}_hand_grip_r"] = {"size": [gp.shape[1], gp.shape[0]], "bone": "hand_r",
                                           "pivot": gpiv, "tip": gtip, "z": 5, "visible": False}

    # 4. 遠側四肢：複製近側、降明度
    skin_color = skin_color.astype(int)
    for name, bone, src, z in FAR_PARTS + [("hand_grip_l", "hand_l", "hand_grip_r", -3)]:
        part = parts[src]
        p = dict(rig_parts[f"chr_{char}_{src}"])
        if name == "upperarm_l":
            # 近側上臂的肩膀端被披肩切掉；遠側手臂在軀幹後面，肩膀補一個膚色圓盤，大角度轉動時才不露縫
            part, p["pivot"], p["tip"] = add_disc(part, p["pivot"], p["tip"], JOINT_CAP, skin_color)
            p["size"] = [part.shape[1], part.shape[0]]
        parts[name] = darken(part)
        p.update({"bone": bone, "z": z})
        if name == "hand_open_l":
            p["visible"] = False
        rig_parts[f"chr_{char}_{name}"] = p

    # 5. 關節：遠側手臂＝近側往後上方移；腰布骨頭沒有分件（腰布畫在軀幹上）
    out_joints = {k: v.round(1).tolist() for k, v in J.items()}
    for a, b in (("shoulder_l", "shoulder_r"), ("elbow_l", "elbow_r"), ("wrist_l", "wrist_r"), ("hand_tip_l", "hand_tip_r")):
        out_joints[a] = (J[b] + FAR_ARM_OFFSET).round(1).tolist()
    out_joints.setdefault("waist", J["hip"].round(1).tolist())
    out_joints.setdefault("loin_tip", (J["hip"] + [0, 120]).round(1).tolist())

    # 6. 武器沿用第 0 批（斧頭）；軸心、末端照第 0 批對照表
    old = json.loads((HERE / "rig" / "hunahpu_rig.batch0.json").read_text())
    rig_parts["wpn_axe"] = old["parts"]["wpn_axe"]

    OUT.mkdir(parents=True, exist_ok=True)
    for name, part in parts.items():
        Image.fromarray(part).save(OUT / f"chr_{char}_{name}.png")
    Image.fromarray(rgba).save(OUT / f"chr_{char}_reference.png")
    rig = {"reference": {"size": [W, H], "joints": out_joints}, "parts": rig_parts}
    (HERE / "rig" / f"{char}_rig.json").write_text(json.dumps(rig, ensure_ascii=False, indent=1))
    unassigned = int(sum(base[n].sum() for n, *_ in FAR_LEG))
    print(f"CUT {char}: {len(parts)} 件 → {OUT.relative_to(ROOT)}；遠側腿 {unassigned} px（切自基準圖、降明度）")
    return rig


if __name__ == "__main__":
    for c in sys.argv[1:] or ["hunahpu", "xbalanque"]:
        cut(c)
