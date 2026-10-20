import importlib.util
import unittest
from pathlib import Path

HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location("quote_check", HERE / "quote_check.py")
qc = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(qc)


class QuoteCheckTest(unittest.TestCase):
    """MV-RELEASE-001 REL-12：英文繪本與譯本的相同詞串。"""

    def test_words(self):
        self.assertEqual(qc.words("Heart of Sky’s"), ["heart", "of", "sky's"])

    def test_candidates_quotes_and_long(self):
        md = ("He said, “Come down to us.” It was short.\n"
              "The twins walked along the long road that went down into the dark place below the court.")
        got = qc.candidates(md)
        self.assertEqual(len(got), 2)
        self.assertIn("Come down to us.", got)

    def test_candidates_skip_metadata(self):
        md = "> **建立日期**：2026-10-07 and a very long english sentence that has more than twelve words in it.\n> Short body."
        self.assertEqual(qc.candidates(md), [])

    def test_longest_shared_run(self):
        src = "a b c d e f g h".split()
        idx = qc.ngram_index(src)
        self.assertEqual(qc.longest_shared_run("x b c d e f g y".split(), idx, src), 6)
        self.assertEqual(qc.longest_shared_run("x b c d e y".split(), idx, src), 0)


if __name__ == "__main__":
    unittest.main()
