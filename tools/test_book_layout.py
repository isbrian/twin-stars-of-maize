import importlib.util
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

SPEC = importlib.util.spec_from_file_location(
    "book_layout", Path(__file__).parent / "book_layout.py"
)
book_layout = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(book_layout)

DRAW = ImageDraw.Draw(Image.new("RGB", (10, 10)))


class WrapZhTest(unittest.TestCase):
    def setUp(self):
        self.font = book_layout.font("zh", "body")
        self.width = self.font.getlength("一" * 10)  # 一行剛好 10 個字

    def test_no_line_starts_with_closing_punctuation(self):
        text = "一二三四五六七八九十，一二三四五六七八九十。一二三四五六七八九十」"
        lines = book_layout.wrap_zh(text, self.font, self.width, DRAW)
        self.assertEqual("".join(lines), text)
        for line in lines[1:]:
            self.assertNotIn(line[0], book_layout.NO_START)

    def test_at_most_one_hanging_punctuation(self):
        text = "一二三四五六七八九十。」一二三"
        lines = book_layout.wrap_zh(text, self.font, self.width, DRAW)
        self.assertEqual("".join(lines), text)
        for line in lines:
            self.assertLessEqual(DRAW.textlength(line, font=self.font), self.width + self.font.getlength("。"))
        self.assertNotIn(lines[1][0], book_layout.NO_START)

    def test_opening_quote_moves_to_next_line(self):
        text = "一二三四五六七八九「一二三」"
        lines = book_layout.wrap_zh(text, self.font, self.width, DRAW)
        self.assertEqual("".join(lines), text)
        for line in lines:
            self.assertNotEqual(line[-1], "「")


class SmartQuotesTest(unittest.TestCase):
    def test_quotes_and_apostrophes(self):
        self.assertEqual(
            book_layout.smart_quotes('He said, "Come." The twins\' ball, the lord\'s dog.'),
            "He said, “Come.” The twins’ ball, the lord’s dog.",
        )


class ParseTest(unittest.TestCase):
    def test_all_cards_parse_with_titles_and_notes(self):
        for volume in ("front", "back"):
            for lang in ("zh", "en"):
                cards = book_layout.parse(volume, lang)
                self.assertEqual(len(cards), book_layout.TOTAL[volume])
                for card in cards.values():
                    self.assertTrue(card["title"])
                    self.assertTrue(card["body"])
                    if volume == "front":
                        self.assertIsNone(card["note"])
        # 後篇第 2、5 張沒有「遊戲裡」，其餘 18 張都有
        back = book_layout.parse("back", "zh")
        self.assertEqual([n for n, c in back.items() if not c["note"]], [2, 5])

    def test_english_title_drops_chinese_gloss(self):
        cards = book_layout.parse("front", "en")
        self.assertEqual(cards[1]["title"], "The World Before the True Sun")


class FitTest(unittest.TestCase):
    def test_every_card_fits_above_folio(self):
        self.assertTrue(book_layout.check_all())


if __name__ == "__main__":
    unittest.main()
