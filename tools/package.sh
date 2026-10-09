#!/usr/bin/env bash
# Empacota o motor para distribuição. Não inclui nada da ROM (o jogador importa a própria ROM).
#   dist/saphire-recomp.love   roda em qualquer LÖVE 11.x (PC) e é o jogo que o LÖVE Potion carrega
#   dist/lovepotion/           pasta pronta para o lovebrew gerar .3dsx (3DS) e .nro (Switch)
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf dist && mkdir -p dist/lovepotion
( cd engine && zip -qr -9 ../dist/saphire-recomp.love . -x '*.DS_Store' )
cp -r engine dist/lovepotion/game
cp tools/lovebrew.toml dist/lovepotion/lovebrew.toml
echo "dist/saphire-recomp.love ($(du -h dist/saphire-recomp.love | cut -f1))"
if command -v lovebrew >/dev/null 2>&1; then
  ( cd dist/lovepotion && lovebrew build ) && echo "binários do LÖVE Potion em dist/lovepotion/build"
else
  echo "lovebrew não encontrado: veja engine/README.md (Console) para gerar .3dsx/.nro"
fi
