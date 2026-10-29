#!/bin/bash
# Pega a imagem do Gemini baixada por último (mais nova que a anterior usada)
# e gera assets/zombies/<letra>.png
# Uso: tools/zombie_from_gemini.sh <letra> <altura> [linhas, ex.: 0,2,3]
set -e
cd "$(dirname "$0")/.."
mkdir -p gdd/gemini-zumbis
last_used=$(ls -t gdd/gemini-zumbis/*.jpg 2>/dev/null | grep -v "/$1.jpg" | head -1)
for i in $(seq 1 30); do
  src=$(ls -t "$HOME"/Transferências/Gemini_Generated_Image_*.jpeg | head -1)
  if [ -z "$last_used" ] || ! cmp -s "$src" "$last_used"; then
    if [ -z "$last_used" ] || [ "$src" -nt "$last_used" ]; then break; fi
  fi
  sleep 2
done
cp "$src" "gdd/gemini-zumbis/$1.jpg"
python3 tools/slice_gemini_sheet.py "gdd/gemini-zumbis/$1.jpg" "assets/zombies/$1.png" 6 3 "h$2" $3
