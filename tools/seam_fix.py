#!/usr/bin/env python3
"""修背景圖的左右接縫：把接縫移到正中央，重畫中央直條後再移回去。

用法：
  python3 tools/seam_fix.py prepare <原圖.png> <輸出資料夾>
      產生 <名稱>_rolled.png（左右各半對調，接縫在正中央）、<名稱>_rolled_magenta.png（同上，透明處填洋紅）、
      <名稱>_mask.png（白色＝要重畫的直條）與 <名稱>_palette.txt（原圖色盤）
  python3 tools/seam_fix.py finish <原圖.png> <重畫後的_rolled.png> <輸出.png>
      重畫圖的洋紅轉回透明，只取中央直條貼回 rolled 圖並收回平塗（Alpha 只留 0／255、顏色對應原圖色盤），
      再左右對調回原位；直條以外的像素保證與原圖相同
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image


def band_width(width: int) -> int:
    # ponytail: yagni: 固定為寬度的 1/6 | upgrade if: 某張圖的接縫物件比這更寬
    return width // 6


def roll(a: np.ndarray) -> np.ndarray:
    return np.roll(a, a.shape[1] // 2, axis=1)


def unroll(a: np.ndarray) -> np.ndarray:
    return np.roll(a, -(a.shape[1] // 2), axis=1)


def band_slice(width: int) -> slice:
    half, w = width // 2, band_width(width)
    return slice(half - w // 2, half + w // 2)


def blend_center_band(original: np.ndarray, repainted: np.ndarray) -> np.ndarray:
    """在中央帶內羽化補繪，帶外與帶緣維持原像素。"""
    if original.shape != repainted.shape:
        raise ValueError("original and repainted arrays must have the same shape")
    result = original.copy()
    s = band_slice(original.shape[1])
    width = s.stop - s.start
    if width <= 0:
        return result

    # ponytail: yagni: 固定使用帶寬 1/5 作羽化 | upgrade if: 個別素材需要可調羽化寬度
    ramp = max(2, width // 5)
    weights = np.ones(width, dtype=np.float32)
    weights[:ramp] = np.linspace(0.0, 1.0, ramp, dtype=np.float32)
    weights[-ramp:] = np.linspace(1.0, 0.0, ramp, dtype=np.float32)
    weights = weights[None, :, None]

    src = original[:, s].astype(np.float32)
    patch = repainted[:, s].astype(np.float32)
    result[:, s] = np.rint(src * (1.0 - weights) + patch * weights).astype(np.uint8)
    return result


def stitch_center_seam(image: np.ndarray) -> np.ndarray:
    """讓中央接點兩側連續，變更範圍限制在中央帶內。"""
    result = image.copy()
    center = image.shape[1] // 2
    radius = max(2, band_width(image.shape[1]) // 10)
    for distance in range(radius):
        left = center - 1 - distance
        right = center + distance
        weight = (1.0 - distance / (radius - 1)) ** 2
        pair_mean = (
            image[:, left].astype(np.float32) + image[:, right].astype(np.float32)
        ) / 2.0
        result[:, left] = np.rint(
            image[:, left].astype(np.float32) * (1.0 - weight) + pair_mean * weight
        ).astype(np.uint8)
        result[:, right] = np.rint(
            image[:, right].astype(np.float32) * (1.0 - weight) + pair_mean * weight
        ).astype(np.uint8)
    return result


def match_band_tone(original: np.ndarray, repainted: np.ndarray) -> np.ndarray:
    """逐列量直條兩側邊緣「原圖－重畫」的色差，沿直條線性補回，讓重畫的色調在兩側都接上原圖。"""
    result = repainted.copy()
    s = band_slice(original.shape[1])
    width = s.stop - s.start
    k = max(1, min(6, width // 8))

    def edge_diff(cols: slice) -> np.ndarray:
        o, r = original[:, cols].astype(np.float32), repainted[:, cols].astype(np.float32)
        both = (o[..., 3] >= 128).all(axis=1) & (r[..., 3] >= 128).all(axis=1)
        d = (o[..., :3] - r[..., :3]).mean(axis=1)
        d[~both] = 0
        # ponytail: stdlib: 31 列滑動中位數去掉輪廓線造成的單列跳動 | upgrade if: 出現逐列條紋
        pad = np.pad(d, ((15, 15), (0, 0)), mode="edge")
        return np.median(np.lib.stride_tricks.sliding_window_view(pad, 31, axis=0), axis=2)

    left = edge_diff(slice(s.start, s.start + k))
    right = edge_diff(slice(s.stop - k, s.stop))
    t = np.linspace(0.0, 1.0, width, dtype=np.float32)[None, :, None]
    offset = left[:, None, :] * (1 - t) + right[:, None, :] * t
    band = result[:, s].astype(np.float32)
    opaque = band[..., 3] >= 128
    band[..., :3] = np.where(opaque[..., None], band[..., :3] + offset, band[..., :3])
    result[:, s] = np.clip(np.rint(band), 0, 255).astype(np.uint8)
    return result


def snap_band(image: np.ndarray, original: np.ndarray) -> np.ndarray:
    """中央帶收回平塗：Alpha 只留 0／255，顏色對應回原圖帶外的色盤。"""
    result = image.copy()
    s = band_slice(image.shape[1])
    outside = np.ones(original.shape[1], dtype=bool)
    outside[s] = False
    ref = original[:, outside]
    palette = np.unique(ref[ref[..., 3] >= 128][:, :3], axis=0).astype(np.int32)

    band = result[:, s]
    band[..., 3] = np.where(band[..., 3] >= 128, 255, 0)
    opaque = band[..., 3] == 255
    band[~opaque] = (0, 0, 0, 0)
    px = band[opaque][:, :3].astype(np.int32)
    nearest = ((px[:, None, :] - palette[None, :, :]) ** 2).sum(axis=2).argmin(axis=1)
    band[opaque, :3] = palette[nearest]


    result[:, s] = band
    return result


MAGENTA = np.array([255, 0, 255])


def key_magenta(image: np.ndarray) -> np.ndarray:
    """把洋紅底（含生成圖的近似洋紅）轉回透明。"""
    result = image.copy()
    # ponytail: one-liner: RGB 距離門檻 60 | upgrade if: 素材本身出現接近洋紅的顏色
    near = np.sqrt(((image[..., :3].astype(np.int32) - MAGENTA) ** 2).sum(axis=2)) < 60
    result[near, 3] = 0
    return result


def prepare(src: Path, out_dir: Path) -> None:
    a = np.asarray(Image.open(src).convert("RGBA"))
    out_dir.mkdir(parents=True, exist_ok=True)
    rolled = roll(a)
    Image.fromarray(rolled, "RGBA").save(out_dir / f"{src.stem}_rolled.png")
    # 給重畫用：透明處填洋紅，讓生成工具看得出哪裡要留空
    magenta = np.where(rolled[..., 3:] >= 128, rolled[..., :3], MAGENTA).astype(np.uint8)
    Image.fromarray(magenta, "RGB").save(out_dir / f"{src.stem}_rolled_magenta.png")
    mask = np.zeros(a.shape[:2], dtype=np.uint8)
    mask[:, band_slice(a.shape[1])] = 255
    Image.fromarray(mask, "L").save(out_dir / f"{src.stem}_mask.png")
    palette = np.unique(a[a[..., 3] >= 128][:, :3], axis=0)
    (out_dir / f"{src.stem}_palette.txt").write_text(
        "\n".join("#%02X%02X%02X" % tuple(c) for c in palette) + "\n"
    )


def finish(src: Path, repainted: Path, out: Path) -> None:
    rolled = roll(np.asarray(Image.open(src).convert("RGBA"))).copy()
    fixed = Image.open(repainted).convert("RGBA")
    if fixed.size != (rolled.shape[1], rolled.shape[0]):
        fixed = fixed.resize((rolled.shape[1], rolled.shape[0]), Image.Resampling.LANCZOS)
    original = rolled.copy()
    patch = match_band_tone(original, key_magenta(np.asarray(fixed)))
    rolled = blend_center_band(rolled, patch)
    rolled = stitch_center_seam(rolled)
    rolled = snap_band(rolled, original)
    Image.fromarray(unroll(rolled), "RGBA").save(out)


if __name__ == "__main__":
    cmd, *args = sys.argv[1:] or [""]
    if cmd == "prepare" and len(args) == 2:
        prepare(Path(args[0]), Path(args[1]))
    elif cmd == "finish" and len(args) == 3:
        finish(Path(args[0]), Path(args[1]), Path(args[2]))
    else:
        sys.exit(__doc__)
