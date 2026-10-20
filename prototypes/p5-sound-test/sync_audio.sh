#!/bin/zsh
# 把第 0 批聲音素材複製進專案的 audio/ 並匯入（audio/ 不進版控，素材只存在本機的 assets-test/）
set -euo pipefail
HERE=${0:a:h}
SRC="$HERE/../../assets-test/batch0/audio"
if [[ ! -d "$SRC" ]]; then
  echo "找不到素材資料夾：$SRC" >&2
  exit 1
fi
mkdir -p "$HERE/audio"
cp "$SRC"/*.wav "$HERE/audio/"
godot --headless --path "$HERE" --import
echo "SYNC ok: $(ls "$HERE/audio"/*.wav | wc -l | tr -d ' ') 個 WAV"
