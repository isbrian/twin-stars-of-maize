import importlib.util
import unittest
from pathlib import Path

import numpy as np


SPEC = importlib.util.spec_from_file_location(
    "seam_fix", Path(__file__).parent / "seam_fix.py"
)
seam_fix = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(seam_fix)


class BlendCenterBandTest(unittest.TestCase):
    def test_preserves_band_edges_and_uses_repaint_at_center(self):
        original = np.zeros((2, 60, 4), dtype=np.uint8)
        original[..., 3] = 255
        repainted = np.full((2, 60, 4), 200, dtype=np.uint8)
        repainted[..., 3] = 255

        blended = seam_fix.blend_center_band(original, repainted)
        band = seam_fix.band_slice(60)

        np.testing.assert_array_equal(blended[:, : band.start], original[:, : band.start])
        np.testing.assert_array_equal(blended[:, band.stop :], original[:, band.stop :])
        np.testing.assert_array_equal(blended[:, band.start], original[:, band.start])
        np.testing.assert_array_equal(blended[:, 30], repainted[:, 30])

    def test_stitch_makes_center_boundary_identical(self):
        image = np.zeros((2, 60, 4), dtype=np.uint8)
        image[:, :30] = 20
        image[:, 30:] = 220

        stitched = seam_fix.stitch_center_seam(image)

        np.testing.assert_array_equal(stitched[:, 29], stitched[:, 30])
        np.testing.assert_array_equal(stitched[:, 0], image[:, 0])
        np.testing.assert_array_equal(stitched[:, -1], image[:, -1])


class SnapBandTest(unittest.TestCase):
    def setUp(self):
        # 原圖：左半紅、右半藍，全不透明；色盤只有這兩色
        self.original = np.zeros((2, 60, 4), dtype=np.uint8)
        self.original[:, :30] = (200, 0, 0, 255)
        self.original[:, 30:] = (0, 0, 200, 255)

    def test_band_alpha_becomes_binary(self):
        image = self.original.copy()
        image[:, 30, 3] = 100
        image[:, 31, 3] = 180
        snapped = seam_fix.snap_band(image, self.original)
        self.assertEqual(snapped[0, 30, 3], 0)
        self.assertEqual(snapped[0, 31, 3], 255)

    def test_band_colors_map_to_original_palette(self):
        image = self.original.copy()
        image[:, 29, :3] = (170, 20, 10)  # 接近紅
        image[:, 31, :3] = (10, 30, 160)  # 接近藍
        snapped = seam_fix.snap_band(image, self.original)
        np.testing.assert_array_equal(snapped[:, 29, :3], [[200, 0, 0]] * 2)
        np.testing.assert_array_equal(snapped[:, 31, :3], [[0, 0, 200]] * 2)

    def test_outside_band_unchanged(self):
        image = self.original.copy()
        image[:, 0, :3] = (123, 45, 67)
        snapped = seam_fix.snap_band(image, self.original)
        np.testing.assert_array_equal(snapped[:, 0], image[:, 0])


class MagentaTest(unittest.TestCase):
    def test_key_magenta_makes_magenta_transparent(self):
        image = np.zeros((1, 3, 4), dtype=np.uint8)
        image[0, 0] = (255, 0, 255, 255)
        image[0, 1] = (240, 20, 235, 255)  # 生成圖常見的近似洋紅
        image[0, 2] = (30, 90, 60, 255)
        keyed = seam_fix.key_magenta(image)
        self.assertEqual(keyed[0, 0, 3], 0)
        self.assertEqual(keyed[0, 1, 3], 0)
        np.testing.assert_array_equal(keyed[0, 2], image[0, 2])

    def test_prepare_writes_magenta_rolled_and_palette(self):
        import tempfile
        from PIL import Image
        a = np.zeros((4, 60, 4), dtype=np.uint8)
        a[:, :20] = (10, 80, 40, 255)  # 左側不透明，其餘透明
        with tempfile.TemporaryDirectory() as d:
            src = Path(d) / "layer.png"
            Image.fromarray(a, "RGBA").save(src)
            seam_fix.prepare(src, Path(d))
            magenta = np.asarray(Image.open(Path(d) / "layer_rolled_magenta.png").convert("RGB"))
            self.assertEqual(tuple(magenta[0, 0]), (255, 0, 255))   # 對調後透明處
            self.assertEqual(tuple(magenta[0, 30]), (10, 80, 40))   # 對調後原左側
            self.assertIn("#0A5028", (Path(d) / "layer_palette.txt").read_text())


class MatchToneTest(unittest.TestCase):
    def test_uniform_tone_shift_in_band_is_removed(self):
        original = np.zeros((20, 120, 4), dtype=np.uint8)
        original[...] = (100, 140, 120, 255)  # 平坦的天空
        repainted = original.copy()
        repainted[:, seam_fix.band_slice(120), :3] += 30  # 重畫的直條整體偏亮
        matched = seam_fix.match_band_tone(original, repainted)
        np.testing.assert_array_equal(matched[:, seam_fix.band_slice(120)], original[:, seam_fix.band_slice(120)])

    def test_transparent_edges_leave_band_untouched(self):
        original = np.zeros((20, 120, 4), dtype=np.uint8)  # 全透明
        repainted = original.copy()
        repainted[:, 55:65] = (10, 200, 10, 255)
        matched = seam_fix.match_band_tone(original, repainted)
        np.testing.assert_array_equal(matched, repainted)


if __name__ == "__main__":
    unittest.main()
