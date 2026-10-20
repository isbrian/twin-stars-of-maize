import importlib.util
import subprocess
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location("font_subset", HERE / "font_subset.py")
font_subset = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(font_subset)


class CollectCharsTest(unittest.TestCase):
    def test_includes_text_base_and_cursor(self):
        chars, by_lang = font_subset.collect_chars()
        self.assertEqual(set(by_lang), {"zh_TW", "en"})
        self.assertIn("巴", chars)          # 繁中正文
        self.assertIn("“", chars)          # 英文彎引號
        self.assertIn(font_subset.EXTRA, chars)
        self.assertNotIn("\n", chars)


class CollectUiCharsTest(unittest.TestCase):
    def test_collect_ui_chars(self):
        chars = font_subset.collect_ui_chars()
        for c in "製說離▶垂":            # 製作說明、退出確認、游標、標題
            self.assertIn(c, chars)
        for c in "胡納巴爾篇":            # 繪本正文、頁碼（MV-SLICE-001d2b）
            self.assertIn(c, chars)
        for c in "鸚鵡鏢":                # HUD、文字卡等遊戲字串（MV-RELEASE-001）
            self.assertIn(c, chars)
        self.assertNotIn("\n", chars)


class BuildTest(unittest.TestCase):
    def test_build_succeeds_without_missing_glyphs_and_shrinks(self):
        r = subprocess.run([sys.executable, str(HERE / "font_subset.py")], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        for name in ("NotoSerifTC.ttf", "NotoSerif.ttf"):
            out = font_subset.OUT / name
            self.assertTrue(out.exists())
        self.assertLess((font_subset.OUT / "NotoSerifTC.ttf").stat().st_size, 2_000_000)


if __name__ == "__main__":
    unittest.main()


class UiBuildTest(unittest.TestCase):
    def test_ui_font_built(self):
        r = subprocess.run([sys.executable, str(HERE / "font_subset.py")], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertTrue(font_subset.UI_OUT.exists())
        self.assertLess(font_subset.UI_OUT.stat().st_size, 1_000_000)
        self.assertTrue((font_subset.UI_OUT.parent / "OFL_NotoSerifTC.txt").exists())
