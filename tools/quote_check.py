"""英文繪本對照譯本（MV-RELEASE-001 REL-12）：找出和譯本連續 ≥ MIN_RUN 個詞相同的句子。

  python3 tools/quote_check.py <譯本.txt> <繪本英文版.md> [...]

只看繪本文件裡的正文（`> ` 開頭的引用行）：引號內的句子＋≥ 12 個詞的長句。
輸出 Markdown 表，只印「相同的那一串」，不印譯本上下文（譯本有著作權，不進版控）。
"""
import re
import sys
from pathlib import Path

MIN_RUN = 6
LONG = 12


def words(text):
    """小寫、只留英文字母與撇號（彎撇號正規化）的詞。"""
    return re.findall(r"[a-z]+(?:'[a-z]+)*", text.replace("’", "'").replace("‘", "'").lower())


def candidates(md):
    """正文的引號句與長句（去重、保留順序）。沒有 `> ` 行時整份當正文（測試用）。"""
    lines = [l[1:].strip() for l in md.splitlines() if l.startswith(">") and not l.startswith("> **")]  # `> **建立日期**` 等是文件中繼資料
    body = " ".join(lines) if lines else md.replace("\n", " ")
    out = re.findall(r"[“\"]([^”\"]+)[”\"]", body)
    out += [s.strip() for s in re.split(r"(?<=[.!?])\s+", re.sub(r"[“”\"]", "", body)) if len(words(s)) >= LONG]
    return list(dict.fromkeys(out))


def ngram_index(src_words, n=MIN_RUN):
    """譯本的 n-gram → 出現位置。"""
    idx = {}
    for i in range(len(src_words) - n + 1):
        idx.setdefault(tuple(src_words[i:i + n]), []).append(i)
    return idx


def longest_shared_run(sentence, idx, src_words, n=MIN_RUN):
    """句子和譯本最長的連續相同詞數；沒有任何 n-gram 命中時回傳 0。"""
    return len(shared_run_text(sentence, idx, src_words, n))


def shared_run_text(sentence, idx, src_words, n=MIN_RUN):
    """最長的那一串（詞列表）。"""
    best = []
    for i in range(len(sentence) - n + 1):
        for j in idx.get(tuple(sentence[i:i + n]), ()):
            k = n
            while i + k < len(sentence) and j + k < len(src_words) and sentence[i + k] == src_words[j + k]:
                k += 1
            if k > len(best):
                best = sentence[i:i + k]
    return best


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    src = words(Path(argv[1]).read_text(encoding="utf-8", errors="replace"))
    idx = ngram_index(src)
    print("| 文件 | 我們的句子 | 相同詞數 | 相同的那一串 |\n|---|---|---|---|")
    total = hits = 0
    for doc in argv[2:]:
        for s in candidates(Path(doc).read_text(encoding="utf-8")):
            total += 1
            w = words(s)
            run = shared_run_text(w, idx, src)
            if len(run) >= MIN_RUN:
                hits += 1
                print(f"| {Path(doc).name[:11]} | {s} | {len(run)} | {' '.join(run)} |")
    print(f"\n檢查 {total} 句，相同 ≥ {MIN_RUN} 詞的 {hits} 句。")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
