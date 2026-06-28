#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is required" >&2
  exit 1
fi

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH"

VERSION="$(python3 - <<'PY'
from pathlib import Path
for line in Path('pubspec.yaml').read_text().splitlines():
    if line.startswith('version:'):
        version = line.split(':', 1)[1].strip()
        print(version.split('+', 1)[0])
        break
else:
    print('1.0.0')
PY
)"

BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"

flutter pub get
flutter analyze
flutter build ipa --release --build-name "$VERSION" --build-number "$BUILD_NUMBER"

echo "IPA build completed."
echo "Check output under: $ROOT_DIR/build/ios/ipa"
