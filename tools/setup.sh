#!/usr/bin/env bash
# Baixa as ferramentas, gera o disassembly e confere que remonta identico.
set -euo pipefail
cd "$(dirname "$0")/.."
ROM=rom/saphire.gbc
EXPECTED=9fa7da61c61d684f39e43d6899a68309ba8607b3

[ -f "$ROM" ] || { echo "Coloque a ROM em $ROM"; exit 1; }
got=$(sha1sum "$ROM" | cut -d' ' -f1)
[ "$got" = "$EXPECTED" ] || echo "AVISO: SHA-1 diferente ($got). Esperado $EXPECTED"

mkdir -p tools
[ -d tools/mgbdis ] || git clone --depth 1 https://github.com/mattcurrie/mgbdis.git tools/mgbdis
if [ ! -x tools/rgbds/rgbasm ]; then
  mkdir -p tools/rgbds
  curl -sSL https://github.com/gbdev/rgbds/releases/download/v0.9.1/rgbds-0.9.1-linux-x86_64.tar.xz \
    | tar -xJ -C tools/rgbds
fi

mkdir -p disasm
( cd disasm && python3 ../tools/mgbdis/mgbdis.py "../$ROM" --overwrite --output-dir . )
sed -i -E 's#(^|[[:space:]])rgb(asm|link|fix|gfx)#\1../tools/rgbds/rgb\2#g' disasm/Makefile
make -C disasm
cmp disasm/game.gbc "$ROM" && echo "OK: round-trip identico"
