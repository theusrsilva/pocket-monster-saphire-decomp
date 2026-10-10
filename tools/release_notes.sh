#!/usr/bin/env bash
# Notas de release: os commits desde a tag anterior (assunto como título, corpo como itens).
#   tools/release_notes.sh <tag|HEAD> [título]   >  notas.md
set -euo pipefail
TAG="${1:?tag}"
TITLE="${2:-$TAG}"
PREV=$(git describe --tags --abbrev=0 "$TAG^" 2>/dev/null || true)
RANGE="${PREV:+$PREV..}$TAG"
echo "## Saphire Recomp $TITLE"
echo
if [ -n "$PREV" ]; then echo "Mudanças desde $PREV:"; else echo "Primeira versão."; fi
echo
git log --reverse --format='%x1e%s%x1f%b' "$RANGE" | awk 'BEGIN{RS="\x1e"; FS="\x1f"} NF {
  printf "### %s\n", $1
  n = split($2, lines, "\n")
  for (i = 1; i <= n; i++) {
    l = lines[i]
    if (l ~ /^(Co-Authored-By|Claude-Session|Signed-off-by):/ || l ~ /^[[:space:]]*$/) continue
    if (l ~ /^[[:space:]]+/) { sub(/^[[:space:]]+/, "  ", l); print l } else print l
  }
  print ""
}'
cat <<'TXT'
### Arquivos

| Arquivo | Para |
|---|---|
| `SaphireRecomp-*-windows-x64.zip` | Windows 10/11: extraia e abra `SaphireRecomp.exe` |
| `SaphireRecomp-*-linux-x86_64.AppImage` | Linux: `chmod +x` e abra |
| `SaphireRecomp-*-macos.zip` | macOS: extraia; na primeira vez, botão direito > Abrir (app sem assinatura) |
| `SaphireRecomp-*-android.apk` | Android 5+: instale o APK (permita fontes desconhecidas); controle Bluetooth ou toque |
| `SaphireRecomp-*-3ds.3dsx` | Nintendo 3DS (Homebrew Launcher), feito com o LÖVE Potion |
| `saphire-recomp.love` | Qualquer sistema com o LÖVE 11.5 |

Nenhum arquivo contém a ROM: na primeira vez, escolha a sua ROM do Pocket Monster Saphire (versão
Fixed, SHA-1 `9fa7da61c61d684f39e43d6899a68309ba8607b3`) na tela de configuração (no Android,
toque em ROM e escolha o .gbc, ou abra o .gbc com o app). Lá também dá para
gerar a ROM traduzida para jogar em GBC/GBA. No 3DS, importe no PC e copie a pasta de dados
(veja o README).
TXT
