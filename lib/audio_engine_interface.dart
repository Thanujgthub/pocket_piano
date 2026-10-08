import 'package:flutter_soloud/flutter_soloud.dart';

enum PianoWaveform {
  sine('Sine', WaveForm.sin, 'sine'),
  triangle('Triangle', WaveForm.triangle, 'triangle'),
  square('Square', WaveForm.square, 'square'),
  saw('Sawtooth', WaveForm.saw, 'sawtooth');

  const PianoWaveform(this.displayName, this.soloudWaveform, this.webType);
  final String displayName;
  final WaveForm soloudWaveform;
  final String webType;
}

abstract class BasePianoAudioEngine {
  bool get isInitialized;
  Future<bool> init();
  void setVolume(double volume);
  Future<void> loadSourcesForOctave({
    required List<({int midi, double frequency})> keys,
    required PianoWaveform waveform,
  });
  Future<void> playKey({
    required int midi,
    required double frequency,
    required PianoWaveform waveform,
  });
  void stopKey({
    required int midi,
    required bool sustain,
    bool immediate = false,
  });
  void stopAll();
  void dispose();
}
