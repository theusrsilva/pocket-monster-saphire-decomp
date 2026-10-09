#!/usr/bin/env bash
# Empacota o motor. Não inclui nada da ROM (o jogador importa a própria ROM).
#
#   tools/package.sh                                  -> dist/saphire-recomp.love (qualquer LÖVE 11)
#   tools/package.sh lovepotion.3dsx lovepotion.nro   -> também dist/saphire-recomp.3dsx/.nro
#
# O LÖVE Potion 3 carrega o jogo "fundido": o .love vai grudado no fim do executável
# (boot.lua faz love.filesystem.setSource no próprio executável). Use os binários do LÖVE Potion
# compilados com tools/lovepotion-queueable.patch para ter música.
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf dist && mkdir -p dist
( cd engine && zip -qr -9 ../dist/saphire-recomp.love . -x '*.DS_Store' )
echo "dist/saphire-recomp.love ($(du -h dist/saphire-recomp.love | cut -f1))"
for bin in "$@"; do
  [ -f "$bin" ] || { echo "não encontrei $bin"; exit 1; }
  base="$(basename "$bin")"
  if [[ "$base" == *.* ]]; then out="dist/saphire-recomp.${base##*.}"; else out="dist/saphire-recomp-$base"; fi
  cat "$bin" dist/saphire-recomp.love > "$out"
  chmod +x "$out"
  echo "$out ($(du -h "$out" | cut -f1))"
done
