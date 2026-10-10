#!/usr/bin/env bash
# Gera o APK de Android: love-android 11.5a com o jogo embutido (app/src/embed/assets/game.love) e
# tools/love-android.patch (seletor de arquivo para escolher a ROM e "Abrir com" num .gbc).
# Nada da ROM vai junto: o jogador escolhe a própria ROM na tela de configuração.
#
#   tools/build_android.sh <versão> <jogo.love>   ->  dist/SaphireRecomp-<versão>-android.apk
#
# Precisa de JDK 17, Android SDK (ANDROID_HOME) com a plataforma 34 e o NDK 25.2.9519653.
# Assinatura: com ANDROID_KEYSTORE_B64 (keystore em base64), ANDROID_KEYSTORE_PASSWORD e
# ANDROID_KEY_ALIAS no ambiente, usa a mesma chave sempre (o APK novo instala por cima do antigo);
# sem elas, cria uma chave descartável (para atualizar é preciso desinstalar a versão anterior).
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?versão}"
LOVEFILE="${2:?jogo.love}"
LOVE_ANDROID_TAG=11.5a
NDK=25.2.9519653
NAME=SaphireRecomp
APP_ID=io.github.theusrsilva.saphirerecomp
ROOT=$PWD
mkdir -p dist
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

: "${ANDROID_HOME:=${ANDROID_SDK_ROOT:-}}"
test -n "$ANDROID_HOME" || { echo "ANDROID_HOME não definido"; exit 1; }
export ANDROID_HOME ANDROID_SDK_ROOT="$ANDROID_HOME"
sdkm=$(ls "$ANDROID_HOME"/cmdline-tools/*/bin/sdkmanager 2>/dev/null | head -1)
if [ ! -d "$ANDROID_HOME/ndk/$NDK" ] && [ -n "$sdkm" ]; then
  ( yes 2>/dev/null || true ) | "$sdkm" --licenses >/dev/null || true
  "$sdkm" --install "ndk;$NDK" "platforms;android-34" "build-tools;34.0.0" | tail -3
fi

git clone -q --depth 1 --branch "$LOVE_ANDROID_TAG" --recurse-submodules --shallow-submodules \
  https://github.com/love2d/love-android "$work/la"
cd "$work/la"
git apply "$ROOT/tools/love-android.patch"

# versão: v1.02.00 -> código 10200 (dev-xxxx -> 1)
code=$(echo "$VERSION" | sed -n 's/^v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\).*/\1 \2 \3/p' | awk '{ print $1 * 10000 + $2 * 100 + $3 }')
code=${code:-1}
sed -i -e '/^app.name_byte_array=/d' -e '/^#app.name=/d' \
  -e "s/^app.application_id=.*/app.application_id=$APP_ID\napp.name=Saphire Recomp/" \
  -e "s/^app.version_code=.*/app.version_code=$code/" \
  -e "s/^app.version_name=.*/app.version_name=${VERSION#v}/" gradle.properties
grep '^app\.' gradle.properties
cp "$ROOT/$LOVEFILE" app/src/embed/assets/game.love

chmod +x gradlew
./gradlew --no-daemon -q assembleEmbedNoRecordRelease
apk=$(find app/build/outputs/apk -name '*embed*noRecord*release*.apk' | head -1)
test -n "$apk"

bt=$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)
"$bt/zipalign" -f -p 4 "$apk" "$work/aligned.apk"
ks="$work/key.jks"
if [ -n "${ANDROID_KEYSTORE_B64:-}" ]; then
  echo "$ANDROID_KEYSTORE_B64" | base64 -d > "$ks"
  pass="$ANDROID_KEYSTORE_PASSWORD"
  alias="${ANDROID_KEY_ALIAS:-saphire}"
else
  echo "aviso: sem ANDROID_KEYSTORE_B64, assinando com uma chave descartável"
  pass=descartavel
  alias=saphire
  keytool -genkeypair -keystore "$ks" -storepass "$pass" -keypass "$pass" -alias "$alias" \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Saphire Recomp" >/dev/null 2>&1
fi
out="$ROOT/dist/$NAME-$VERSION-android.apk"
"$bt/apksigner" sign --ks "$ks" --ks-pass "pass:$pass" --key-pass "pass:$pass" --ks-key-alias "$alias" \
  --out "$out" "$work/aligned.apk"
"$bt/apksigner" verify --print-certs "$out" | grep -i "SHA-256"   # confere a chave usada
ls -la "$out"
