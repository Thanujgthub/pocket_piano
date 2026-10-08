import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'audio_engine.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PocketPianoApp());
}

class PocketPianoApp extends StatelessWidget {
  const PocketPianoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF8B5CF6);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pocket Piano',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        fontFamily: 'sans-serif',
      ),
      home: const PianoHomePage(),
    );
  }
}

class PianoHomePage extends StatefulWidget {
  const PianoHomePage({super.key});

  @override
  State<PianoHomePage> createState() => PianoHomePageState();
}

enum WaveformOption {
  sine('Sine', PianoWaveform.sine, Icons.waves_rounded),
  triangle('Triangle', PianoWaveform.triangle, Icons.change_history_rounded),
  square('Square', PianoWaveform.square, Icons.crop_square_rounded),
  saw('Sawtooth', PianoWaveform.saw, Icons.show_chart_rounded);

  const WaveformOption(this.displayName, this.engineWaveform, this.icon);
  final String displayName;
  final PianoWaveform engineWaveform;
  final IconData icon;
}

class PianoHomePageState extends State<PianoHomePage> {
  final PianoAudioEngine _audio = PianoAudioEngine();

  final Set<int> _pressedKeys = <int>{};
  final List<String> _history = <String>[];

  int _baseOctave = 4;
  double _volume = 0.75;
  bool _sustain = true;
  bool _audioReady = false;
  bool _loading = true;
  WaveformOption _selectedWaveform = WaveformOption.sine;
  String _audioStatus = 'Starting audio engine...';
  String _selectedNote = 'Ready to play';
  String _selectedFrequency = 'Tap a key or use keyboard to begin';

  final FocusNode _focusNode = FocusNode();

  static const List<String> _noteNames = <String>[
    'C',
    'C♯',
    'D',
    'D♯',
    'E',
    'F',
    'F♯',
    'G',
    'G♯',
    'A',
    'A♯',
    'B',
  ];

  static const Set<int> _blackPitchClasses = <int>{
    1,
    3,
    6,
    8,
    10,
  };

  // Keyboard shortcut mappings by PhysicalKeyboardKey
  static final Map<PhysicalKeyboardKey, int> _keyToMidiOffset = {
    PhysicalKeyboardKey.keyA: 0,
    PhysicalKeyboardKey.keyW: 1,
    PhysicalKeyboardKey.keyS: 2,
    PhysicalKeyboardKey.keyE: 3,
    PhysicalKeyboardKey.keyD: 4,
    PhysicalKeyboardKey.keyF: 5,
    PhysicalKeyboardKey.keyT: 6,
    PhysicalKeyboardKey.keyG: 7,
    PhysicalKeyboardKey.keyY: 8,
    PhysicalKeyboardKey.keyH: 9,
    PhysicalKeyboardKey.keyU: 10,
    PhysicalKeyboardKey.keyJ: 11,
    PhysicalKeyboardKey.keyK: 12,
    PhysicalKeyboardKey.keyO: 13,
    PhysicalKeyboardKey.keyL: 14,
    PhysicalKeyboardKey.keyP: 15,
    PhysicalKeyboardKey.semicolon: 16,
    PhysicalKeyboardKey.quote: 17,
    PhysicalKeyboardKey.bracketLeft: 18,
    PhysicalKeyboardKey.keyZ: 19,
    PhysicalKeyboardKey.bracketRight: 20,
    PhysicalKeyboardKey.keyX: 21,
    PhysicalKeyboardKey.backslash: 22,
    PhysicalKeyboardKey.keyC: 23,
  };

  // Keyboard shortcut mappings by LogicalKeyboardKey
  static final Map<LogicalKeyboardKey, int> _logicalKeyToMidiOffset = {
    LogicalKeyboardKey.keyA: 0,
    LogicalKeyboardKey.keyW: 1,
    LogicalKeyboardKey.keyS: 2,
    LogicalKeyboardKey.keyE: 3,
    LogicalKeyboardKey.keyD: 4,
    LogicalKeyboardKey.keyF: 5,
    LogicalKeyboardKey.keyT: 6,
    LogicalKeyboardKey.keyG: 7,
    LogicalKeyboardKey.keyY: 8,
    LogicalKeyboardKey.keyH: 9,
    LogicalKeyboardKey.keyU: 10,
    LogicalKeyboardKey.keyJ: 11,
    LogicalKeyboardKey.keyK: 12,
    LogicalKeyboardKey.keyO: 13,
    LogicalKeyboardKey.keyL: 14,
    LogicalKeyboardKey.keyP: 15,
    LogicalKeyboardKey.semicolon: 16,
    LogicalKeyboardKey.quote: 17,
    LogicalKeyboardKey.bracketLeft: 18,
    LogicalKeyboardKey.keyZ: 19,
    LogicalKeyboardKey.bracketRight: 20,
    LogicalKeyboardKey.keyX: 21,
    LogicalKeyboardKey.backslash: 22,
    LogicalKeyboardKey.keyC: 23,
  };

  // Keyboard shortcut mappings by character label
  static final Map<String, int> _charToMidiOffset = {
    'A': 0, 'W': 1, 'S': 2, 'E': 3, 'D': 4, 'F': 5, 'T': 6,
    'G': 7, 'Y': 8, 'H': 9, 'U': 10, 'J': 11, 'K': 12, 'O': 13,
    'L': 14, 'P': 15, ';': 16, "'": 17, '[': 18, 'Z': 19,
    ']': 20, 'X': 21, '\\': 22, 'C': 23,
  };

  static final Map<int, String> _midiOffsetToKeyLabel = {
    0: 'A',
    1: 'W',
    2: 'S',
    3: 'E',
    4: 'D',
    5: 'F',
    6: 'T',
    7: 'G',
    8: 'Y',
    9: 'H',
    10: 'U',
    11: 'J',
    12: 'K',
    13: 'O',
    14: 'L',
    15: 'P',
    16: ';',
    17: "'",
    18: '[',
    19: 'Z',
    20: ']',
    21: 'X',
    22: '\\',
    23: 'C',
  };

  int get _baseMidi => (_baseOctave + 1) * 12;

  List<PianoKeyData> get _keys {
    return List<PianoKeyData>.generate(24, (index) {
      final midi = _baseMidi + index;
      return PianoKeyData(
        midi: midi,
        label: noteNameForMidi(midi),
        frequency: frequencyForMidi(midi),
        isBlack: _isBlackMidi(midi),
        shortcutLabel: _midiOffsetToKeyLabel[index],
      );
    });
  }

  List<PianoKeyData> get whiteKeys =>
      _keys.where((key) => !key.isBlack).toList(growable: false);

  List<PianoKeyData> get blackKeys =>
      _keys.where((key) => key.isBlack).toList(growable: false);

  bool _isBlackMidi(int midi) =>
      _blackPitchClasses.contains(midi % 12);

  String noteNameForMidi(int midi) {
    final octave = (midi ~/ 12) - 1;
    return '${_noteNames[midi % 12]}$octave';
  }

  double frequencyForMidi(int midi) {
    return 440 * math.pow(2, (midi - 69) / 12).toDouble();
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onGlobalKeyEvent);
    unawaited(_initializeAudio());
  }

  bool _onGlobalKeyEvent(KeyEvent event) {
    // Arrow keys control octave changes
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        unawaited(_changeOctave(1));
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                 event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        unawaited(_changeOctave(-1));
        return true;
      }
    }

    int? offset = _keyToMidiOffset[event.physicalKey] ??
        _logicalKeyToMidiOffset[event.logicalKey];

    if (offset == null && event.character != null && event.character!.isNotEmpty) {
      final char = event.character!.toUpperCase();
      offset = _charToMidiOffset[char];
    }

    if (offset == null) return false;

    final midi = _baseMidi + offset;
    final keyData = _keys.firstWhere(
      (k) => k.midi == midi,
      orElse: () => PianoKeyData(
        midi: midi,
        label: noteNameForMidi(midi),
        frequency: frequencyForMidi(midi),
        isBlack: _isBlackMidi(midi),
      ),
    );

    if (event is KeyDownEvent) {
      if (!_pressedKeys.contains(midi)) {
        _playKey(keyData);
      }
      return true;
    } else if (event is KeyUpEvent) {
      _releaseKey(keyData);
      return true;
    }

    return false;
  }

  Future<void> _initializeAudio() async {
    try {
      final success = await _audio.init();
      if (success) {
        await _loadSourcesForOctave();
      }

      if (!mounted) return;
      setState(() {
        _audioReady = success;
        _loading = false;
        _audioStatus = success
            ? 'Audio ready'
            : 'Tap anywhere to enable audio';
      });
    } catch (error) {
      debugPrint('Audio initialization error: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _audioReady = false;
        _audioStatus = 'Tap anywhere to enable audio';
      });
    }
  }

  Future<void> _loadSourcesForOctave() async {
    final keysData = _keys
        .map((k) => (midi: k.midi, frequency: k.frequency))
        .toList();

    await _audio.loadSourcesForOctave(
      keys: keysData,
      waveform: _selectedWaveform.engineWaveform,
    );
  }

  Future<void> _changeWaveform(WaveformOption newWaveform) async {
    if (newWaveform == _selectedWaveform) return;

    _audio.stopAll();

    if (mounted) {
      setState(() {
        _pressedKeys.clear();
        _selectedWaveform = newWaveform;
        _loading = true;
        _audioStatus = 'Updating timbre...';
      });
    }

    if (_audioReady) {
      await _loadSourcesForOctave();
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _audioStatus = _audioReady ? 'Audio ready' : 'Tap anywhere to enable audio';
    });
  }

  Future<void> _changeOctave(int delta) async {
    final next = (_baseOctave + delta).clamp(2, 6).toInt();
    if (next == _baseOctave) return;

    _audio.stopAll();

    if (mounted) {
      setState(() {
        _pressedKeys.clear();
        _baseOctave = next;
        _loading = true;
        _audioStatus = 'Loading octave $_baseOctave...';
        _selectedNote = 'Ready to play';
        _selectedFrequency = 'Tap a key or use keyboard to begin';
      });
    }

    if (_audioReady) {
      await _loadSourcesForOctave();
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _audioStatus = _audioReady ? 'Audio ready' : 'Tap anywhere to enable audio';
    });
  }

  void _playKey(PianoKeyData key) {
    if (_loading) return;

    if (!_audioReady) {
      unawaited(_initializeAudio());
    }

    _audio.playKey(
      midi: key.midi,
      frequency: key.frequency,
      waveform: _selectedWaveform.engineWaveform,
    );

    if (!mounted) return;
    setState(() {
      _pressedKeys.add(key.midi);
      _selectedNote = key.label;
      _selectedFrequency = '${key.frequency.toStringAsFixed(2)} Hz';

      _history.remove(key.label);
      _history.insert(0, key.label);
      if (_history.length > 10) {
        _history.removeLast();
      }
    });
  }

  void _releaseKey(PianoKeyData key) {
    if (mounted) {
      setState(() {
        _pressedKeys.remove(key.midi);
      });
    }

    _audio.stopKey(
      midi: key.midi,
      sustain: _sustain,
    );
  }

  void _clearHistory() {
    setState(() {
      _history.clear();
      _selectedNote = 'Ready to play';
      _selectedFrequency = 'Tap a key or use keyboard to begin';
    });
  }

  void _setVolume(double value) {
    setState(() {
      _volume = value;
    });
    _audio.setVolume(value);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onGlobalKeyEvent);
    _focusNode.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 920;

            return Focus(
              focusNode: _focusNode,
              autofocus: true,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(isWide),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isWide ? 34 : 18,
                        8,
                        isWide ? 34 : 18,
                        18,
                      ),
                      child: _buildMainContent(isWide),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool isWide) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isWide ? 34 : 18,
        18,
        isWide ? 34 : 18,
        10,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF9F67FF),
                  Color(0xFF5B21B6),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x553C1A78),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.piano_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pocket Piano',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'A pocket-sized piano for every screen',
                  style: TextStyle(
                    color: Color(0xFF9EA0AA),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _StatusChip(
            text: _audioStatus,
            ready: _audioReady,
            onTap: !_audioReady ? () => unawaited(_initializeAudio()) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isWide) {
    final keyboardCard = _buildKeyboardCard(isWide);
    final controlsCard = _buildControlsCard();

    if (isWide) {
      return Column(
        children: [
          _buildHeroDisplay(),
          const SizedBox(height: 18),
          keyboardCard,
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: controlsCard),
              const SizedBox(width: 18),
              Expanded(child: _buildHistoryCard()),
            ],
          ),
          const SizedBox(height: 8),
          _buildFooter(),
        ],
      );
    }

    return Column(
      children: [
        _buildHeroDisplay(),
        const SizedBox(height: 16),
        keyboardCard,
        const SizedBox(height: 16),
        controlsCard,
        const SizedBox(height: 16),
        _buildHistoryCard(),
        const SizedBox(height: 8),
        _buildFooter(),
      ],
    );
  }

  Widget _buildHeroDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF191225),
            Color(0xFF0F1017),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF2A2337),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFF241838),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: Color(0xFFCBB7FF),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Column(
                key: ValueKey<String>(_selectedNote),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedNote,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedFrequency,
                    style: const TextStyle(
                      color: Color(0xFF9EA0AA),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_audioReady)
            ElevatedButton.icon(
              onPressed: () => unawaited(_initializeAudio()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Enable Audio'),
            )
          else if (_selectedNote != 'Ready to play')
            OutlinedButton.icon(
              onPressed: _clearHistory,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Reset'),
            ),
        ],
      ),
    );
  }

  Widget _buildKeyboardCard(bool isWide) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF111217),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF24262E),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Piano Keyboard',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _SmallTag(text: 'C$_baseOctave → B${_baseOctave + 1}'),
                const SizedBox(width: 8),
                const _SmallTag(text: '24 keys'),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _PianoKeyboard(
              keys: _keys,
              pressedMidi: _pressedKeys,
              enabled: true,
              onKeyDown: _playKey,
              onKeyUp: _releaseKey,
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 7),
            child: Text(
              'Tap keys or use physical keyboard keys (A-J, W/E/T/Y/U for Octave 1). Use Up/Down arrows for Octave changes.',
              style: TextStyle(
                color: Color(0xFF777A85),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsCard() {
    return _Panel(
      title: 'Controls',
      icon: Icons.tune_rounded,
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: _ControlLabel(
                  title: 'Octave',
                  subtitle: 'Move the keyboard range',
                  icon: Icons.swap_vert_rounded,
                ),
              ),
              _RoundIconButton(
                icon: Icons.remove_rounded,
                onPressed: _baseOctave > 2
                    ? () => unawaited(_changeOctave(-1))
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  width: 44,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1822),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    '$_baseOctave',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              _RoundIconButton(
                icon: Icons.add_rounded,
                onPressed: _baseOctave < 6
                    ? () => unawaited(_changeOctave(1))
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFF282A31), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: _ControlLabel(
                  title: 'Timbre',
                  subtitle: 'Change synthesizer waveform',
                  icon: Icons.graphic_eq_rounded,
                ),
              ),
              DropdownButton<WaveformOption>(
                value: _selectedWaveform,
                underline: const SizedBox.shrink(),
                dropdownColor: const Color(0xFF1B1822),
                borderRadius: BorderRadius.circular(12),
                items: WaveformOption.values.map((option) {
                  return DropdownMenuItem<WaveformOption>(
                    value: option,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(option.icon, size: 16, color: const Color(0xFFCBB7FF)),
                        const SizedBox(width: 8),
                        Text(
                          option.displayName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    unawaited(_changeWaveform(val));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFF282A31), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.volume_down_rounded,
                color: Color(0xFF8C8E98),
                size: 21,
              ),
              Expanded(
                child: Slider(
                  value: _volume,
                  onChanged: _setVolume,
                ),
              ),
              const Icon(
                Icons.volume_up_rounded,
                color: Color(0xFF8C8E98),
                size: 21,
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 34,
                child: Text(
                  '${(_volume * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFFB7BAC4),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFF282A31), height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: _ControlLabel(
                  title: 'Sustain',
                  subtitle: 'Let notes ring after release',
                  icon: Icons.graphic_eq_rounded,
                ),
              ),
              Switch.adaptive(
                value: _sustain,
                onChanged: (value) {
                  setState(() {
                    _sustain = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    return _Panel(
      title: 'Recent Notes',
      icon: Icons.history_rounded,
      trailing: TextButton(
        onPressed: _history.isEmpty ? null : _clearHistory,
        child: const Text('Clear'),
      ),
      child: _history.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    color: Color(0xFF626572),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your played notes will appear here.',
                      style: TextStyle(
                        color: Color(0xFF777A85),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _history
                  .map(
                    (note) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1822),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF2A2633),
                        ),
                      ),
                      child: Text(
                        note,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: Color(0xFF626572),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Pocket Piano • Responsive Flutter UI • Android • iOS • Web',
              style: TextStyle(
                color: Color(0xFF626572),
                fontSize: 11,
              ),
            ),
          ),
          Text(
            'Octave $_baseOctave',
            style: const TextStyle(
              color: Color(0xFF626572),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class PianoKeyData {
  const PianoKeyData({
    required this.midi,
    required this.label,
    required this.frequency,
    required this.isBlack,
    this.shortcutLabel,
  });

  final int midi;
  final String label;
  final double frequency;
  final bool isBlack;
  final String? shortcutLabel;
}

class _PianoKeyboard extends StatelessWidget {
  const _PianoKeyboard({
    required this.keys,
    required this.pressedMidi,
    required this.enabled,
    required this.onKeyDown,
    required this.onKeyUp,
  });

  final List<PianoKeyData> keys;
  final Set<int> pressedMidi;
  final bool enabled;
  final ValueChanged<PianoKeyData> onKeyDown;
  final ValueChanged<PianoKeyData> onKeyUp;

  @override
  Widget build(BuildContext context) {
    final whiteKeys =
        keys.where((key) => !key.isBlack).toList(growable: false);
    final blackKeys =
        keys.where((key) => key.isBlack).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        const minWhiteWidth = 52.0;
        const maxWhiteWidth = 88.0;
        final whiteWidth = (constraints.maxWidth / whiteKeys.length)
            .clamp(minWhiteWidth, maxWhiteWidth)
            .toDouble();

        final keyboardWidth =
            math.max(constraints.maxWidth, whiteWidth * whiteKeys.length);
        const keyboardHeight = 286.0;
        const blackWidth = 48.0;
        const blackHeight = 182.0;

        int whiteBefore(int midi) {
          return keys
              .where(
                (key) => key.midi < midi && !key.isBlack,
              )
              .length;
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            width: keyboardWidth,
            height: keyboardHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final key in whiteKeys)
                      SizedBox(
                        width: whiteWidth,
                        child: _PianoKey(
                          keyData: key,
                          active: pressedMidi.contains(key.midi),
                          enabled: enabled,
                          black: false,
                          onKeyDown: onKeyDown,
                          onKeyUp: onKeyUp,
                        ),
                      ),
                  ],
                ),
                for (final key in blackKeys)
                  Positioned(
                    left:
                        whiteWidth * whiteBefore(key.midi) - blackWidth / 2,
                    top: 0,
                    width: blackWidth,
                    height: blackHeight,
                    child: _PianoKey(
                      keyData: key,
                      active: pressedMidi.contains(key.midi),
                      enabled: enabled,
                      black: true,
                      onKeyDown: onKeyDown,
                      onKeyUp: onKeyUp,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PianoKey extends StatelessWidget {
  const _PianoKey({
    required this.keyData,
    required this.active,
    required this.enabled,
    required this.black,
    required this.onKeyDown,
    required this.onKeyUp,
  });

  final PianoKeyData keyData;
  final bool active;
  final bool enabled;
  final bool black;
  final ValueChanged<PianoKeyData> onKeyDown;
  final ValueChanged<PianoKeyData> onKeyUp;

  @override
  Widget build(BuildContext context) {
    final radius = black
        ? const BorderRadius.vertical(
            bottom: Radius.circular(8),
          )
        : const BorderRadius.vertical(
            bottom: Radius.circular(10),
          );

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: enabled ? (_) => onKeyDown(keyData) : null,
      onPointerUp: enabled ? (_) => onKeyUp(keyData) : null,
      onPointerCancel: enabled ? (_) => onKeyUp(keyData) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        curve: Curves.easeOut,
        margin: black
            ? const EdgeInsets.symmetric(horizontal: 0)
            : const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: black
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: active
                      ? const [
                          Color(0xFFB18CFF),
                          Color(0xFF7442D8),
                        ]
                      : const [
                          Color(0xFF3C3D45),
                          Color(0xFF111217),
                        ],
                )
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: active
                      ? const [
                          Color(0xFFF0E9FF),
                          Color(0xFFD0C1FF),
                        ]
                      : const [
                          Color(0xFFF8F8FA),
                          Color(0xFFD6D7DD),
                        ],
                ),
          boxShadow: black
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
          border: Border.all(
            color: black
                ? const Color(0xFF08090B)
                : const Color(0xFF9A9CA4),
            width: black ? 1.1 : 0.8,
          ),
        ),
        padding: black
            ? const EdgeInsets.only(bottom: 9)
            : const EdgeInsets.only(bottom: 12),
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (keyData.shortcutLabel != null)
              Text(
                '[${keyData.shortcutLabel}]',
                style: TextStyle(
                  color: black
                      ? (active ? Colors.white70 : const Color(0xFF888A92))
                      : const Color(0xFF9EA0AA),
                  fontWeight: FontWeight.w600,
                  fontSize: black ? 8 : 9,
                ),
              ),
            const SizedBox(height: 2),
            Text(
              keyData.label,
              style: TextStyle(
                color: black
                    ? (active ? Colors.white : const Color(0xFFD1D3DA))
                    : const Color(0xFF454751),
                fontWeight: FontWeight.w800,
                fontSize: black ? 9 : 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111217),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF24262E),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1822),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFCBB7FF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ControlLabel extends StatelessWidget {
  const _ControlLabel({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF8E7AD4),
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF777A85),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1820),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: const Color(0xFF292630),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFB5B0C1),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.text,
    required this.ready,
    this.onTap,
  });

  final String text;
  final bool ready;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dotColor = ready
        ? const Color(0xFF66D69A)
        : const Color(0xFFF0B35C);

    final chipChild = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF15171D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ready ? const Color(0xFF262831) : const Color(0xFF5B3A1A),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              color: ready ? const Color(0xFFAEB1BA) : const Color(0xFFF5C06B),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!ready) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.touch_app_rounded,
              size: 13,
              color: Color(0xFFF5C06B),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: chipChild,
      );
    }

    return chipChild;
  }
}
