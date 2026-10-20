#!/usr/bin/env python3
"""把 assets-test/ 的定稿素材處理成遊戲尺寸，寫進 game/art/（MV-SLICE-001b1，SLICE-b2）。

用法：
  python3 tools/import_art.py          寫入全部並重寫 game/art/MANIFEST.md
  python3 tools/import_art.py --check  只比對、不寫；有差異時退出碼 1

ENTRIES 每筆：src（相對 repo）、dst（相對 game/art/），加上一種處理：
  height       整張縮到這個高度
  fit_height   裁到內容外框（Alpha > 0）後縮到這個高度
  fit_width    同上，縮到這個寬度
  fit_size     裁到內容外框後縮到 [w, h]
  scale_like   沿用另一筆（以 dst 指名）的縮放比例
  scale        整張乘上這個比例（不裁切；雙胞胎分件用 import_rig.rig_scale，和關節資料同源）
選填：key（洋紅背景去背：True＝p4 的 key_magenta；"hard"＝只看離洋紅的距離，給大面積深褐色的物件用）、crop（來源像素 [x, y, w, h]，先裁再處理）、
  mirror（"h"／"v"：縮好的圖接上它的左右／上下鏡像，成為兩倍寬／高；接縫天生為 0，MV-ASSET-014）。
輸出固定：同樣的來源一定產生同樣的位元組（PNG 不寫時間戳）。需要 Python 3、Pillow、numpy。
"""
import io
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "game" / "art"
SRC = ROOT / "assets-test"
sys.path.insert(0, str(ROOT / "prototypes/p4-art-pipeline/tools"))
from cut_parts import key_magenta  # noqa: E402

sys.path.insert(0, str(ROOT / "tools"))
from import_rig import CHARS as TWINS, CUT_CHARS, cut_game_rig, cut_scale, game_rig, rig_scale  # noqa: E402

B1, B2, B0 = "batch1/art", "batch2/art", "batch0/art"
ALPHA_MIN = 32  # 內容外框只算 Alpha 大於這個值的像素：生成圖與去背後的透明區有肉眼看不見的雜點（球具護腰去背後整張都是 8～32）
ENTRIES = [
    # 場景（畫面高 1080）
    *[{"src": f"{B1}/{n}.png", "dst": f"bg/{n}.png", "height": 1080} for n in (
        "bg_forest_far_01", "bg_forest_mid_01", "bg_forest_mid_02", "bg_forest_mid_03", "bg_forest_fore_01",
        "bg_field_mid_01", "bg_home_mid_01", "bg_ballcourt_far_01")],
    {"src": f"{B1}/bg_forest_ground_tile.png", "dst": "bg/bg_forest_ground_tile.png", "scale_like": "bg/bg_forest_far_01.png"},
    {"src": f"{B2}/bg_nance_mid_01.png", "dst": "bg/bg_nance_mid_01.png", "height": 1080},
    # 宮殿後牆：地板線（來源第 745 列）要對齊 900、圖頂要蓋到 Boss 段落的畫面上緣 -60 → 第 745 列落在 960 → 高 1320
    {"src": f"{B2}/bg_palace_back_01.png", "dst": "bg/bg_palace_back_01.png", "height": 1320},
    # 物件（遊戲中的大小）
    # 宮殿的寶座與兩塊低台（MV-SLICE-001b1 Task 6）：從宮殿中景切出；寶座沿用後牆的比例，低台縮到碰撞框寬 320
    {"src": f"{B2}/bg_palace_mid_01.png", "dst": "prop/prop_palace_throne.png", "crop": [895, 461, 310, 330], "scale_like": "bg/bg_palace_back_01.png"},
    {"src": f"{B2}/bg_palace_mid_01.png", "dst": "prop/prop_palace_platform_l.png", "crop": [60, 726, 260, 70], "fit_width": 320},
    {"src": f"{B2}/bg_palace_mid_01.png", "dst": "prop/prop_palace_platform_r.png", "crop": [1289, 726, 201, 70], "fit_width": 320},
    {"src": f"{B1}/prop_bonfire_lit.png", "dst": "prop/prop_bonfire_lit.png", "fit_height": 150},
    {"src": f"{B1}/prop_bonfire_unlit.png", "dst": "prop/prop_bonfire_unlit.png", "fit_height": 150},
    {"src": f"{B1}/prop_cacao_bean.png", "dst": "prop/prop_cacao_bean.png", "fit_height": 36},
    {"src": f"{B1}/prop_soup_bowl.png", "dst": "prop/prop_soup_bowl.png", "fit_height": 64},
    {"src": f"{B2}/prop_nance_fruit.png", "dst": "prop/prop_nance_fruit.png", "fit_height": 36},
    # 平放在地上的武器：橫長的東西用寬度縮（以 180 px 高的角色為準）
    {"src": f"{B0}/wpn_axe.png", "dst": "prop/wpn_axe.png", "fit_width": 80},
    {"src": f"{B1}/wpn_digging_stick.png", "dst": "prop/wpn_digging_stick.png", "fit_width": 130},
    {"src": "chr_batch2/wpn_ballgear_yoke.png", "dst": "prop/wpn_ballgear_yoke.png", "fit_width": 70, "key": True},
    # HUD
    {"src": f"{B1}/ui_health_pip_full.png", "dst": "ui/ui_health_pip_full.png", "fit_height": 40},
    {"src": f"{B1}/ui_health_pip_empty.png", "dst": "ui/ui_health_pip_empty.png", "fit_height": 40},
    {"src": f"{B1}/ui_heal_pip_full.png", "dst": "ui/ui_heal_pip_full.png", "fit_height": 32},
    {"src": f"{B1}/ui_heal_pip_empty.png", "dst": "ui/ui_heal_pip_empty.png", "fit_height": 32},
    {"src": f"{B1}/ui_resource_frame.png", "dst": "ui/ui_resource_frame.png", "fit_height": 24},
    {"src": f"{B1}/ui_resource_fill.png", "dst": "ui/ui_resource_fill.png", "fit_height": 24},
    {"src": f"{B1}/ui_skill_slot_frame.png", "dst": "ui/ui_skill_slot_frame.png", "fit_height": 72},
    *[{"src": f"{B1}/{n}.png", "dst": f"ui/{n}.png", "fit_height": 40} for n in ("ui_icon_axe", "ui_icon_digging_stick", "ui_icon_blowgun")],
    {"src": "hud_batch2/ui_icon_ballgear.png", "dst": "ui/ui_icon_ballgear.png", "fit_height": 40},
    {"src": f"{B1}/ui_icon_cacao.png", "dst": "ui/ui_icon_cacao.png", "fit_height": 32},
    {"src": f"{B1}/ui_icon_soup.png", "dst": "ui/ui_icon_soup.png", "fit_height": 32},
    {"src": "hud_batch2/ui_icon_rat.png", "dst": "ui/ui_icon_rat.png", "fit_height": 56},
    # MV-ASSET-014（b1 補件）
    {"src": "b1_props/bg_yard_mid_01.png", "dst": "bg/bg_yard_mid_01.png", "height": 1080, "mirror": "h"},
    {"src": "b1_props/prop_platform_log.png", "dst": "prop/prop_platform_log.png", "fit_height": 40, "key": True},
    {"src": "b1_props/prop_thorns_wall.png", "dst": "prop/prop_thorns_wall.png", "fit_width": 120, "key": True, "mirror": "v"},
    {"src": "b1_props/prop_arena_gate.png", "dst": "prop/prop_arena_gate.png", "fit_width": 40, "key": True, "mirror": "v"},
    {"src": "b1_props/prop_palace_ledge.png", "dst": "prop/prop_palace_ledge.png", "fit_width": 700, "key": True},
    {"src": "b1_props2/prop_palace_barrier.png", "dst": "prop/prop_palace_barrier.png", "fit_width": 60, "key": "hard", "mirror": "v"},  # MV-ASSET-015 Q-03 取代 P-06（像梯子）
    # MV-ASSET-017（MV-SLICE-001c4a、c4b）：下劈水晶、血量碎片、森林木障
    {"src": "c4a_art/prop_pogo_crystal.png", "dst": "prop/prop_pogo_crystal.png", "fit_height": 96, "key": True},
    {"src": "c4a_art/prop_health_fragment.png", "dst": "prop/prop_health_fragment.png", "fit_height": 64, "key": True},
    {"src": "c4a_art/ui_health_pip_half.png", "dst": "ui/ui_health_pip_half.png", "fit_height": 40, "key": True},
    {"src": "c4a_art/prop_forest_barrier.png", "dst": "prop/prop_forest_barrier.png", "fit_width": 60, "key": "hard", "mirror": "v"},
    {"src": "c4a_art/prop_thorns_ground.png", "dst": "prop/prop_thorns_ground.png", "fit_height": 60, "key": True, "mirror": "h"},  # MV-ASSET-018（MV-TUNE-004）
    {"src": "b1_props/prop_waymark.png", "dst": "prop/prop_waymark.png", "fit_height": 140, "key": True},
    {"src": "c3b_art/prop_animal_deer.png", "dst": "prop/prop_animal_deer.png", "fit_height": 170, "key": True},  # MV-ASSET-020（MV-SLICE-001c3b）
    {"src": "c3b_art/prop_animal_rabbit.png", "dst": "prop/prop_animal_rabbit.png", "fit_height": 60, "key": True},
    {"src": "c3b_art/prop_animal_coati.png", "dst": "prop/prop_animal_coati.png", "fit_height": 70, "key": "hard"},  # 紅褐毛色離洋紅近，一般去背會把身體吃成半透明
    {"src": "c3b_art/prop_food_corn.png", "dst": "prop/prop_food_corn.png", "fit_height": 50, "key": True},
    {"src": "c3b_art/prop_food_beans.png", "dst": "prop/prop_food_beans.png", "fit_height": 25, "key": True},
    {"src": "c3b_art/prop_tail_deer.png", "dst": "prop/prop_tail_deer.png", "fit_height": 30, "key": True},
    {"src": "c3b_art/prop_tail_rabbit.png", "dst": "prop/prop_tail_rabbit.png", "fit_height": 30, "key": True},
    {"src": "b1_props/prop_field_bush.png", "dst": "prop/prop_field_bush.png", "fit_height": 140, "key": True},
    {"src": "b1_props/prop_field_clod.png", "dst": "prop/prop_field_clod.png", "fit_height": 70, "key": True},
    {"src": "b1_props/prop_net.png", "dst": "prop/prop_net.png", "fit_width": 120, "key": True},
    # MV-ASSET-015（Brian 試玩 b1，2026-10-11）：宮殿入口外牆、nance 樹的粗枝
    {"src": "b1_props2/prop_palace_entrance.png", "dst": "prop/prop_palace_entrance.png", "fit_height": 1150, "key": "hard"},
    {"src": "b1_props2/prop_nance_branch.png", "dst": "prop/prop_nance_branch.png", "fit_width": 620, "key": True},
    # 靜態立繪（SLICE-b10；腳底對齊碰撞框底，高度＝遊戲中的身高）
    {"src": "chr_batch1/chr_hunahpu_reference.png", "dst": "chr/chr_hunahpu_reference.png", "fit_height": 180, "key": True},
    {"src": "chr_batch1/chr_xbalanque_reference.png", "dst": "chr/chr_xbalanque_reference.png", "fit_height": 180, "key": True},
    {"src": "chr_batch2/chr_xmucane_reference.png", "dst": "chr/chr_xmucane_reference.png", "fit_height": 165, "key": True},
    {"src": "chr_batch3/chr_healer_man_reference.png", "dst": "chr/chr_healer_man_reference.png", "fit_height": 170, "key": True},
    {"src": "chr_batch3/chr_healer_woman_reference.png", "dst": "chr/chr_healer_woman_reference.png", "fit_height": 165, "key": True},
    {"src": "chr_batch2/chr_rat_reference.png", "dst": "chr/chr_rat_reference.png", "fit_height": 40, "key": True},
    {"src": "batch2/chr/enm_falselight_crawler_reference.png", "dst": "chr/enm_falselight_crawler_reference.png", "fit_height": 70, "key": True},
    {"src": "batch2/chr/enm_falselight_flyer_reference.png", "dst": "chr/enm_falselight_flyer_reference.png", "fit_height": 60, "key": True},
    {"src": "c4c_art/enm_falselight_reflector_reference.png", "dst": "chr/enm_falselight_reflector_reference.png", "fit_height": 150, "key": True},  # MV-SLICE-001c4c2
    {"src": "batch2/chr/enm_sevenmacaw_reference.png", "dst": "chr/enm_sevenmacaw_reference.png", "fit_height": 450, "key": True},
    # 骨架靜止姿勢的比對基準：切件輸出的合成圖（身體＋對位後的翅膀圖層，MV-TUNE-003）；和骨架同一個規則（內容高 450）
    {"src": "chr_b2b1/parts/chr_sevenmacaw_reference.png", "dst": "chr/enm_sevenmacaw_rest.png", "fit_height": 450},
    {"src": "batch2/chr/chr_chimalmat_reference.png", "dst": "chr/chr_chimalmat_reference.png", "fit_height": 340, "key": True},
    *[{"src": f"batch2/chr/enm_sevenmacaw_head_{n}.png", "dst": f"chr/enm_sevenmacaw_head_{n}.png",
       "scale_like": "chr/enm_sevenmacaw_reference.png", "key": True} for n in ("jawhurt", "maize", "blind")],
    # 雙胞胎骨架的分件（MV-SLICE-001b2a）：p4 已切好、透明背景；和關節資料同一比例縮放，不裁切
    *[{"src": f"chr_batch1/parts/{n}.png", "dst": f"chr/parts/{c}/{n[len(f'chr_{c}_'):]}.png", "scale": rig_scale(c)}
      for c in TWINS for n in game_rig(c)["parts"]],
    # 爬行型、飛行型的骨架分件（MV-SLICE-001b2b1）：tools/cut_rig.py 從基準圖切出、已去背；和關節資料同一比例縮放，不裁切
    *[{"src": f"chr_b2b1/parts/{n}.png", "dst": f"chr/parts/{c}/{n[len(f'chr_{c}_'):]}.png", "scale": cut_scale(c)}
      for c in CUT_CHARS for n in cut_game_rig(c)["parts"]],
    # 握在手上、穿在身上的側面附件（以 180 px 高的角色為準，長邊）
    {"src": f"{B0}/wpn_axe.png", "dst": "chr/parts/wpn_axe.png", "fit_width": 90},
    {"src": f"{B1}/wpn_digging_stick.png", "dst": "chr/parts/wpn_digging_stick.png", "fit_width": 130},
    {"src": f"{B0}/wpn_blowgun.png", "dst": "chr/parts/wpn_blowgun.png", "fit_width": 110},
    {"src": "chr_batch2/wpn_ballgear_yoke.png", "dst": "chr/parts/wpn_ballgear_yoke.png", "fit_width": 60, "key": True},
    {"src": "chr_batch2/wpn_ballgear_armguard.png", "dst": "chr/parts/wpn_ballgear_armguard.png", "fit_width": 40, "key": True},
    {"src": f"{B1}/prop_soup_bowl.png", "dst": "chr/parts/prop_soup_bowl.png", "fit_height": 32},
]


def _key_hard(im) -> np.ndarray:
    """洋紅去背，只用「離洋紅的距離」估 Alpha（key_magenta 去掉「輪廓墨色連線」那一段）。

    key_magenta 把落在洋紅→輪廓墨色連線附近的顏色當成邊緣混色做反混合；大面積的深褐色剛好落在那條線附近，
    整片變半透明、又被扣掉洋紅而偏綠（木障 29%、宮殿入口 44% 的內部，Brian 試玩 b1 2026-10-11）。"""
    magenta = np.array([255.0, 0.0, 255.0])
    rgb = np.asarray(im.convert("RGB")).astype(float)
    alpha = np.clip((np.linalg.norm(rgb - magenta, axis=2) - 40) / 160, 0, 1)
    a = alpha[..., None]
    fg = np.where(a > 0.01, (rgb - (1 - a) * magenta) / np.maximum(a, 0.01), 0)
    return np.dstack([np.clip(fg, 0, 255), alpha * 255]).astype(np.uint8)


def _load(e) -> np.ndarray:
    im = Image.open(SRC / e["src"])
    if e.get("crop"):
        x, y, w, h = e["crop"]
        im = im.crop((x, y, x + w, y + h))
    if e.get("key"):
        a = _key_hard(im) if e["key"] == "hard" else key_magenta(im)
        hot = (a[..., 0] > 200) & (a[..., 1] < 60) & (a[..., 2] > 200)  # key_magenta 偶爾留下的純洋紅殘點
        a[hot | (a[..., 3] <= ALPHA_MIN), 3] = 0
        return a
    return np.asarray(im.convert("RGBA"))


def _trim(a: np.ndarray) -> np.ndarray:
    ys, xs = np.nonzero(a[..., 3] > ALPHA_MIN)
    return a[ys.min(): ys.max() + 1, xs.min(): xs.max() + 1]


def _resize(a: np.ndarray, sx: float, sy: float, keyed) -> np.ndarray:
    h, w = a.shape[:2]
    size = (max(1, round(w * sx)), max(1, round(h * sy)))
    # 預乘 Alpha 再縮放：透明像素的顏色（洋紅、黑）不會混進邊緣
    out = np.array(Image.fromarray(a, "RGBA").convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA"))
    if keyed:
        hot = (out[..., 0] > 200) & (out[..., 1] < 60) & (out[..., 2] > 200)
        out[hot, 3] = 0
    return out


def _content(a: np.ndarray) -> tuple:
    """內容外框的 (寬, 高)。"""
    ys, xs = np.nonzero(a[..., 3] > ALPHA_MIN)
    return xs.max() - xs.min() + 1, ys.max() - ys.min() + 1


def _process(e, scale_of: dict) -> tuple:
    """回傳 (PNG 位元組, 縮放比例, 輸出尺寸)。"""
    a = _load(e)
    trims = any(k in e for k in ("fit_height", "fit_width", "fit_size")) or ("scale_like" in e and e.get("key"))
    if trims:
        a = _trim(a)
    h, w = a.shape[:2]
    if "height" in e:
        sx = sy = e["height"] / h
    elif "fit_height" in e:
        sx = sy = e["fit_height"] / h
    elif "fit_width" in e:
        sx = sy = e["fit_width"] / w
    elif "fit_size" in e:
        sx, sy = e["fit_size"][0] / w, e["fit_size"][1] / h
    elif "scale" in e:
        sx = sy = e["scale"]
    else:
        sx = sy = scale_of[e["scale_like"]]
    out = _resize(a, sx, sy, e.get("key"))
    # 細的尖端（羽毛、枝條）縮小後 Alpha 變低、掉出內容外框：量一次實際大小，差超過 1 px 就依比例重縮一次
    target = e.get("fit_height") or e.get("fit_width")
    if target:
        got = _content(out)[1 if "fit_height" in e else 0]
        if abs(got - target) > 1:
            k = target / got
            sx, sy = sx * k, sy * k
            out = _resize(a, sx, sy, e.get("key"))
    if e.get("key") and not e.get("mirror"):
        out = _trim(out)  # 縮放後邊緣多出的淡像素也裁掉：立繪以圖的底邊對齊腳底，不能墊高
    if e.get("mirror") == "h":
        out = np.concatenate([out, out[:, ::-1]], axis=1)
    elif e.get("mirror") == "v":
        out = np.concatenate([out, out[::-1]], axis=0)
    im = Image.fromarray(out, "RGBA")
    size = im.size
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    return buf.getvalue(), max(sx, sy), size


def build() -> dict:
    """dst → (位元組, 縮放, 尺寸)，依 ENTRIES 順序（scale_like 只能指向前面的項目）。"""
    out, scale_of = {}, {}
    for e in ENTRIES:
        data, scale, size = _process(e, scale_of)
        scale_of[e["dst"]] = scale
        out[e["dst"]] = (data, scale, size)
    return out


def scales() -> dict:
    return {dst: v[1] for dst, v in build().items()}


def manifest(built: dict) -> str:
    lines = ["# game/art 素材清單", "", "由 `tools/import_art.py` 產生，不要手動修改。來源在 `assets-test/`（不進版控）。", "",
             "| 檔案 | 來源 | 處理 | 尺寸 | 縮放 |", "|---|---|---|---|---|"]
    for e in ENTRIES:
        how = ", ".join(f"{k}={e[k]}" for k in ("height", "fit_height", "fit_width", "fit_size", "scale", "scale_like", "crop", "key", "mirror") if k in e)
        _, scale, size = built[e["dst"]]
        lines.append(f"| `{e['dst']}` | `assets-test/{e['src']}` | {how} | {size[0]}×{size[1]} | {scale:.3f} |")
    return "\n".join(lines) + "\n"


def main(argv) -> int:
    check = "--check" in argv
    built = build()
    files = {dst: v[0] for dst, v in built.items()}
    files["MANIFEST.md"] = manifest(built).encode()
    drift = [p for p, data in files.items() if not (ART / p).exists() or (ART / p).read_bytes() != data]
    if check:
        for p in drift:
            print(f"差異：{p}")
        return 1 if drift else 0
    for p in drift:
        (ART / p).parent.mkdir(parents=True, exist_ok=True)
        (ART / p).write_bytes(files[p])
    print(f"寫入 {len(drift)} 個檔案（共 {len(files)}）")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
