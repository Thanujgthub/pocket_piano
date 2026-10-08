#!/usr/bin/env bash
set -euo pipefail

# Pin the SDK so GitHub-triggered builds use a reproducible toolchain.
FLUTTER_VERSION="3.47.6"
FLUTTER_SDK="${VERCEL_CACHE_DIR:-/tmp}/pocket-piano-flutter-${FLUTTER_VERSION}"

if [ ! -x "${FLUTTER_SDK}/bin/flutter" ]; then
  git clone --depth 1 --branch "${FLUTTER_VERSION}" \
    https://github.com/flutter/flutter.git "${FLUTTER_SDK}"
fi

export PATH="${FLUTTER_SDK}/bin:${PATH}"
export CI=true
flutter config --no-analytics --enable-web
flutter pub get --enforce-lockfile
flutter build web --release
