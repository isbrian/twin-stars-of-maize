import importlib.util
import unittest
from pathlib import Path

HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location("book_export", HERE / "book_export.py")
book_export = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(book_export)


class GameTextTest(unittest.TestCase):
    """MV-SLICE-001d2b：遊戲用的 game/ui/book_text.gd（前篇繁中）。"""

    def test_game_text_has_eight_front_pages(self):
        s = book_export.game_text(book_export.rows())
        self.assertEqual(s.count('\t["'), 8)
        self.assertIn("世界還沒有真正的太陽", s)
        self.assertNotIn("The World Before", s)
        self.assertNotIn("BACK", s)  # 只放前篇

    def test_game_text_escapes(self):
        data = [
            ("BOOK_FRONT_01_TITLE", {"zh": 'a"b\\c', "en": "x"}),
            ("BOOK_FRONT_01_BODY", {"zh": "一\n二", "en": "y"}),
        ]
        s = book_export.game_text(data)
        self.assertIn('"a\\"b\\\\c"', s)
        self.assertIn('"一\\n二"', s)

    def test_game_text_is_current(self):
        self.assertEqual(book_export.GAME_OUT.read_text(encoding="utf-8"), book_export.game_text(book_export.rows()),
                         "docs/book/ 改了：重跑 python3 tools/book_export.py")


if __name__ == "__main__":
    unittest.main()
