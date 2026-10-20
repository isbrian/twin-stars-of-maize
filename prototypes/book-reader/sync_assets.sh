#!/bin/zsh
# 把繪本插圖（1920×1080 定稿）複製進專案、匯出文字、產生精簡字型，然後匯入。art/、fonts/ 不進版控：
# 插圖只存在本機的 assets-test/；字型的正本是 repo 的 assets/fonts/（完整版），這裡只放用到的字（MV-BOOK-007）。
set -euo pipefail
HERE=${0:a:h}
ROOT="$HERE/../.."
mkdir -p "$HERE/art" "$HERE/fonts"
for v in front back; do
  SRC="$ROOT/assets-test/book_$v/final"
  if [[ -d "$SRC" ]]; then
    for f in "$SRC"/book_${v}_[0-9][0-9].png(N); do cp "$f" "$HERE/art/"; done
  fi
done
python3 "$ROOT/tools/book_export.py"
python3 "$ROOT/tools/font_subset.py"   # 需要 fontTools：python3 -m pip install --user fonttools
godot --headless --path "$HERE" --import
echo "SYNC ok: 插圖 $(ls "$HERE/art"/*.png(N) | wc -l | tr -d ' ') 張、字型 2 個"
