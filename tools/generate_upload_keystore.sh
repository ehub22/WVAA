#!/usr/bin/env bash
# Generate a Google Play upload keystore for WVAA.
#
# With Play App Signing, Google holds the app signing key and this upload
# key is only used to sign the AAB/APK you upload to Play Console. Back up
# the keystore file and its passwords somewhere safe (password manager +
# offline copy) — losing them means requesting an upload key reset from
# Play Console before you can publish updates.
#
# Usage:
#   ./tools/generate_upload_keystore.sh [output.jks] [alias]
#
# Environment overrides:
#   KEYSTORE_PASSWORD      store password (prompted for if unset)
#   KEYSTORE_KEY_PASSWORD  key password (defaults to KEYSTORE_PASSWORD)
#   KEYSTORE_ALIAS         key alias (default: upload)
#   KEYSTORE_DNAME         certificate DN (default: CN=WVAA, OU=Student Project, O=Westview HS, L=San Diego, ST=CA, C=US)
#
# After generating, add the four GitHub Secrets (see docs/PLAY_RELEASE.md):
#   KEYSTORE_BASE64        base64 of the .jks file (single line)
#   KEYSTORE_PASSWORD      store password
#   KEYSTORE_ALIAS         key alias
#   KEYSTORE_KEY_PASSWORD  key password
set -euo pipefail

OUTPUT="${1:-android/app/upload-keystore.jks}"
ALIAS="${KEYSTORE_ALIAS:-${2:-upload}}"
DNAME="${KEYSTORE_DNAME:-CN=WVAA, OU=Student Project, O=Westview HS, L=San Diego, ST=CA, C=US}"

if ! command -v keytool >/dev/null 2>&1; then
  echo "error: keytool not found. Install a JDK (e.g. Temurin 21) and re-run." >&2
  exit 1
fi

if [ -e "$OUTPUT" ]; then
  echo "error: $OUTPUT already exists. Move it aside or choose a different path —" >&2
  echo "refusing to overwrite an existing keystore." >&2
  exit 1
fi

STORE_PASSWORD="${KEYSTORE_PASSWORD:-}"
if [ -z "$STORE_PASSWORD" ]; then
  # Prompt without echoing.
  read -r -s -p "Store password (min 6 chars): " STORE_PASSWORD
  echo
fi
KEY_PASSWORD="${KEYSTORE_KEY_PASSWORD:-$STORE_PASSWORD}"
if [ -z "$KEY_PASSWORD" ]; then
  read -r -s -p "Key password (Enter to reuse store password): " KEY_PASSWORD
  echo
  KEY_PASSWORD="${KEY_PASSWORD:-$STORE_PASSWORD}"
fi

mkdir -p "$(dirname "$OUTPUT")"

keytool -genkeypair \
  -keystore "$OUTPUT" \
  -storetype JKS \
  -alias "$ALIAS" \
  -keyalg RSA -keysize 2048 \
  -sigalg SHA256withRSA \
  -validity 9125 \
  -dname "$DNAME" \
  -storepass "$STORE_PASSWORD" \
  -keypass "$KEY_PASSWORD"

chmod 600 "$OUTPUT"

echo
echo "Created upload keystore: $OUTPUT (alias: $ALIAS, valid ~25 years)"
echo
echo "Next steps (see docs/PLAY_RELEASE.md):"
echo "  1. Back up $OUTPUT and both passwords offline. Never commit them."
echo "  2. Enroll in Play App Signing in Play Console and register this upload key."
echo "  3. Add GitHub Secrets (repo Settings > Secrets and variables > Actions):"
echo "       KEYSTORE_BASE64        = $(base64 -w0 "$OUTPUT" 2>/dev/null || base64 "$OUTPUT" | tr -d '\n')"
echo "       KEYSTORE_PASSWORD      = (store password above)"
echo "       KEYSTORE_ALIAS         = $ALIAS"
echo "       KEYSTORE_KEY_PASSWORD  = (key password above)"
echo "  4. For local builds, copy android/key.properties.example to android/key.properties"
echo "     and fill in the same values (storeFile=upload-keystore.jks)."
echo "  5. Verify: flutter build appbundle --release"
