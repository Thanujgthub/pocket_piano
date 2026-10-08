import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'audio_engine_interface.dart';

class PianoAudioEngine implements BasePianoAudioEngine {
  final SoLoud _soloud = SoLoud.instance;

  final Map<int, AudioSource> _soloudSources = {};
  final Map<int, SoundHandle> _soloudActiveHandles = {};

  bool _initialized = false;
  double _volume = 0.75;

  @override
  bool get isInitialized => _initialized && _soloud.isInitialized;

  @override
  Future<bool> init() async {
    try {
      if (!_soloud.isInitialized) {
        await _soloud.init();
      }
      _soloud.setGlobalVolume(_volume);
      _initialized = true;
      return true;
    } catch (error) {
      debugPrint('SoLoud init error on native platform: $error');
      _initialized = false;
      return false;
    }
  }

  @override
  void setVolume(double volume) {
    _volume = volume;
    if (_soloud.isInitialized) {
      _soloud.setGlobalVolume(volume);
    }
  }

  @override
  Future<void> loadSourcesForOctave({
    required List<({int midi, double frequency})> keys,
    required PianoWaveform waveform,
  }) async {
    if (!_soloud.isInitialized) return;

    for (final source in _soloudSources.values) {
      try {
        await _soloud.disposeSource(source);
      } catch (_) {}
    }
    _soloudSources.clear();

    for (final key in keys) {
      try {
        final source = await _soloud.loadWaveform(
          waveform.soloudWaveform,
          false,
          1.0,
          0.0,
        );
        _soloud.setWaveformFreq(source, key.frequency);
        _soloudSources[key.midi] = source;
      } catch (_) {}
    }
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

    final source = _soloudSources[midi];
    if (source == null) return;

    final oldHandle = _soloudActiveHandles.remove(midi);
    if (oldHandle != null && _soloud.isInitialized) {
      unawaited(_soloud.stop(oldHandle));
    }

    try {
      final handle = _soloud.play(source, volume: _volume);
      _soloudActiveHandles[midi] = handle;
    } catch (e) {
      debugPrint('Error playing key via SoLoud: $e');
    }
  }

  @override
  void stopKey({
    required int midi,
    required bool sustain,
    bool immediate = false,
  }) {
    final handle = _soloudActiveHandles.remove(midi);
    if (handle != null && _soloud.isInitialized) {
      if (sustain) {
        _soloud.scheduleStop(handle, const Duration(milliseconds: 900));
      } else {
        unawaited(_soloud.stop(handle));
      }
    }
  }

  @override
  void stopAll() {
    if (_soloud.isInitialized) {
      _soloud.stopAll();
    }
    _soloudActiveHandles.clear();
  }

  @override
  void dispose() {
    stopAll();
    if (_soloud.isInitialized) {
      unawaited(_soloud.deinitAsync());
    }
    for (final source in _soloudSources.values) {
      try {
        if (_soloud.isInitialized) {
          _soloud.disposeSource(source);
        }
      } catch (_) {}
    }
    _soloudSources.clear();
  }
}
