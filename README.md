# Pocket Piano

A responsive Flutter piano for Android, iOS and the web, with 24 keys,
computer-keyboard shortcuts, four waveforms, volume and sustain controls.

## Vercel deployment

The Vercel project connects to this repository. Pushes to `main` build and
deploy the web application automatically. `vercel.json` selects `build/web`
as the output directory. `scripts/vercel-build.sh` downloads Flutter 3.47.6,
installs the locked dependencies and runs `flutter build web --release`.

Browser audio starts after a user gesture. Click or tap a piano key to begin.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
