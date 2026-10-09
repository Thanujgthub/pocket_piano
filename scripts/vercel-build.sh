#!/usr/bin/env bash
set -e

FLUTTER_SDK="${VERCEL_CACHE_DIR:-/tmp}/pocket-piano-flutter-stable"

if [ ! -x "${FLUTTER_SDK}/bin/flutter" ]; then
  git clone --depth 1 --branch stable \
    https://github.com/flutter/flutter.git "${FLUTTER_SDK}"
fi

export PATH="${FLUTTER_SDK}/bin:${PATH}"
export CI=true
flutter config --no-analytics --enable-web
flutter pub get
flutter build web --release
