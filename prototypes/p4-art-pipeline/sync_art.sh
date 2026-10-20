#!/bin/zsh
# 把角色分件與武器複製進專案的 art/ 並匯入（art/ 不進版控，素材只存在本機的 assets-test/）。
# MV-ASSET-010 起：角色分件由 tools/cut_parts.py 從基準圖切出（assets-test/chr_batch1/parts/）；
# 武器沿用第 0 批（assets-test/batch0/art/）。
set -euo pipefail
HERE=${0:a:h}
PARTS="$HERE/../../assets-test/chr_batch1/parts"
BATCH0="$HERE/../../assets-test/batch0/art"
for d in "$PARTS" "$BATCH0"; do
  if [[ ! -d "$d" ]]; then
    echo "找不到素材資料夾：$d（角色分件要先執行 python3 tools/cut_parts.py）" >&2
    exit 1
  fi
done
mkdir -p "$HERE/art"
rm -f "$HERE/art"/chr_*.png
cp "$PARTS"/chr_*.png "$HERE/art/"
cp "$BATCH0"/wpn_*.png "$HERE/art/"
godot --headless --path "$HERE" --import
echo "SYNC ok: $(ls "$HERE/art"/*.png | wc -l | tr -d ' ') 個 PNG"
