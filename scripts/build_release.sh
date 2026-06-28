#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is required" >&2
  exit 1
fi

VERSION="$(python3 - <<'PY'
from pathlib import Path
for line in Path('pubspec.yaml').read_text().splitlines():
    if line.startswith('version:'):
        print(line.split(':', 1)[1].strip().split('+', 1)[0])
        break
else:
    print('0.0.0')
PY
)"
BUILD_NUMBER="$(date +%Y%m%d%H%M)"
TAG="${1:-v${VERSION}-${BUILD_NUMBER}}"
RELEASE_NAME="eSIM Tool ${TAG}"
DIST_DIR="$ROOT_DIR/dist"
APK_NAME="esim-tool-${TAG}.apk"
APK_PATH="$DIST_DIR/$APK_NAME"
ANDROID_TARGET_PLATFORM="${ANDROID_TARGET_PLATFORM:-android-arm64}"

mkdir -p "$DIST_DIR"

flutter pub get
flutter analyze
flutter test
# Flutter 3.27.1 on this Intel macOS host fails while generating the
# armeabi-v7a release snapshot, so default to the arm64 ABI that we verified.
flutter build apk --release \
  --target-platform "$ANDROID_TARGET_PLATFORM" \
  --build-name "$VERSION" \
  --build-number "${BUILD_NUMBER:0:10}"

cp "$ROOT_DIR/build/app/outputs/flutter-apk/app-release.apk" "$APK_PATH"

cat > "$DIST_DIR/release-notes-${TAG}.md" <<EOF
Android APK for eSIM Tool.

- Build variant: release
- Target ABI: ${ANDROID_TARGET_PLATFORM}
- Signing: Android debug signing config with v2/v3 signatures, for ad-hoc testing/install only
- Install note: if an older test build was installed from a previous GitHub Action release, uninstall it once first because those old builds used a different temporary debug certificate
- Source tag: ${TAG}
EOF

echo "Built APK: $APK_PATH"

if [[ "${UPLOAD_RELEASE:-1}" == "1" ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh is required to upload the GitHub Release asset" >&2
    exit 1
  fi
  gh release create "$TAG" "$APK_PATH" \
    --repo lkiarest/esim_tools \
    --title "$RELEASE_NAME" \
    --notes-file "$DIST_DIR/release-notes-${TAG}.md" \
    --latest \
    || gh release upload "$TAG" "$APK_PATH" \
      --repo lkiarest/esim_tools \
      --clobber
  echo "Release uploaded: https://github.com/lkiarest/esim_tools/releases/tag/$TAG"
fi
