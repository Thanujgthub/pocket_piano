import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'audio_engine_interface.dart';

class PianoAudioEngine implements BasePianoAudioEngine {
  web.AudioContext? _webCtx;
  final Map<int, web.OscillatorNode> _webOscillators = {};
  final Map<int, web.GainNode> _webGains = {};

  bool _initialized = false;
  double _volume = 0.75;

  @override
  bool get isInitialized => _initialized && _webCtx != null && _webCtx!.state == 'running';

  @override
  Future<bool> init() async {
    try {
      _webCtx ??= web.AudioContext();
      if (_webCtx!.state == 'suspended') {
        await _webCtx!.resume().toDart;
      }
      _initialized = _webCtx!.state == 'running';
      return _initialized;
    } catch (e) {
      debugPrint('Web Audio API init error: $e');
      _initialized = false;
      return false;
    }
  }

  @override
  void setVolume(double volume) {
    _volume = volume;
  }

  @override
  Future<void> loadSourcesForOctave({
    required List<({int midi, double frequency})> keys,
    required PianoWaveform waveform,
  }) async {
    // Web Audio synth creates oscillators dynamically per key press
  }

  @override
  Future<void> playKey({
    required int midi,
    required double frequency,
    required PianoWaveform waveform,
  }) async {
    if (!isInitialized) {
      await init();
      if (!isInitialized) return;
    }

    stopKey(midi: midi, sustain: false, immediate: true);

    try {
      final osc = _webCtx!.createOscillator();
      final gain = _webCtx!.createGain();

      osc.type = waveform.webType;
      osc.frequency.value = frequency;

      final now = _webCtx!.currentTime;
      gain.gain.setValueAtTime(_volume * 0.8, now);

      osc.connect(gain);
      gain.connect(_webCtx!.destination);

      osc.start(now);

      _webOscillators[midi] = osc;
      _webGains[midi] = gain;
    } catch (e) {
      debugPrint('Error playing web oscillator: $e');
    }
  }

  @override
  void stopKey({
    required int midi,
    required bool sustain,
    bool immediate = false,
  }) {
    final osc = _webOscillators.remove(midi);
    final gain = _webGains.remove(midi);

    if (osc == null || gain == null || _webCtx == null) return;

    try {
      final now = _webCtx!.currentTime;
      if (immediate || !sustain) {
        gain.gain.setValueAtTime(0, now);
        osc.stop(now);
        osc.disconnect();
      } else {
        gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.9);
        osc.stop(now + 0.92);
      }
    } catch (_) {}
  }

  @override
  void stopAll() {
    for (final midi in _webOscillators.keys.toList()) {
      stopKey(midi: midi, sustain: false, immediate: true);
    }
    _webOscillators.clear();
    _webGains.clear();
  }

  @override
  void dispose() {
    stopAll();
  }
}
