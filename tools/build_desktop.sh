#!/usr/bin/env bash
# Gera os executáveis de PC fundindo o jogo nos binários oficiais do LÖVE 11.5.
# Nada da ROM vai junto: o jogador escolhe a própria ROM na tela de configuração.
#   tools/build_desktop.sh [versão]   ->  dist/SaphireRecomp-<versão>-{windows-x64.zip,linux-x86_64.AppImage,macos.zip}
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-dev}"
LOVE=11.5
NAME=SaphireRecomp
CACHE=build-cache
mkdir -p dist "$CACHE"
fetch() { [ -f "$CACHE/$2" ] || curl -fsSL -o "$CACHE/$2" "$1"; }

# .love com a versão embutida
rm -f dist/saphire-recomp.love
tmp=$(mktemp -d)
cp -r engine/. "$tmp/"
printf 'return %q\n' "$VERSION" > "$tmp/version.lua"
( cd "$tmp" && zip -qr -9 "$OLDPWD/dist/saphire-recomp.love" . )
rm -rf "$tmp"

# Windows: love.exe + jogo = SaphireRecomp.exe, com as DLLs do LÖVE
fetch "https://github.com/love2d/love/releases/download/$LOVE/love-$LOVE-win64.zip" love-win64.zip
w=$(mktemp -d); unzip -q "$CACHE/love-win64.zip" -d "$w"
src=$(find "$w" -maxdepth 1 -mindepth 1 -type d | head -1)
out="$w/$NAME"; mkdir -p "$out"
cat "$src/love.exe" dist/saphire-recomp.love > "$out/$NAME.exe"
cp "$src"/*.dll "$src/license.txt" "$out/"
( cd "$w" && zip -qr -9 "$OLDPWD/dist/$NAME-$VERSION-windows-x64.zip" "$NAME" )
rm -rf "$w"

# Linux: AppImage do LÖVE com o jogo fundido no binário
fetch "https://github.com/love2d/love/releases/download/$LOVE/love-$LOVE-x86_64.AppImage" love.AppImage
fetch "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" appimagetool.AppImage
chmod +x "$CACHE/love.AppImage" "$CACHE/appimagetool.AppImage"
l=$(mktemp -d)
( cd "$l" && "$OLDPWD/$CACHE/love.AppImage" --appimage-extract >/dev/null )
cat "$l/squashfs-root/bin/love" dist/saphire-recomp.love > "$l/squashfs-root/bin/love.fused"
mv "$l/squashfs-root/bin/love.fused" "$l/squashfs-root/bin/love"
chmod +x "$l/squashfs-root/bin/love"
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$CACHE/appimagetool.AppImage" --no-appstream "$l/squashfs-root" \
  "dist/$NAME-$VERSION-linux-x86_64.AppImage" >/dev/null 2>&1
rm -rf "$l"

# macOS: love.app com o jogo em Resources (sem assinatura: abrir com botão direito > Abrir)
fetch "https://github.com/love2d/love/releases/download/$LOVE/love-$LOVE-macos.zip" love-macos.zip
m=$(mktemp -d); unzip -q "$CACHE/love-macos.zip" -d "$m"
app="$m/$NAME.app"
mv "$m/love.app" "$app"
cp dist/saphire-recomp.love "$app/Contents/Resources/saphire-recomp.love"
plist="$app/Contents/Info.plist"
sed -i.bak -e "s#<string>org.love2d.love</string>#<string>io.github.theusrsilva.saphirerecomp</string>#" \
  -e "s#<string>LÖVE</string>#<string>Saphire Recomp</string>#" "$plist" && rm -f "$plist.bak"
# o LÖVE do Mac abre o .love como documento; tirar a associação evita que ele peça um arquivo
python3 - "$plist" <<'PY'
import plistlib, sys
p = sys.argv[1]
d = plistlib.load(open(p, 'rb'))
d.pop('UTExportedTypeDeclarations', None)
d.pop('CFBundleDocumentTypes', None)
d['CFBundleShortVersionString'] = d.get('CFBundleShortVersionString', '')
plistlib.dump(d, open(p, 'wb'))
PY
( cd "$m" && zip -qry -9 "$OLDPWD/dist/$NAME-$VERSION-macos.zip" "$NAME.app" )
rm -rf "$m"
ls -la dist
