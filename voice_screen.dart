import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../state.dart';

/// Hands-free loop: listen -> agent -> speak -> listen ...
class VoiceScreen extends ConsumerStatefulWidget {
  const VoiceScreen({super.key});
  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen> {
  final _stt = SpeechToText();
  final _tts = FlutterTts();
  String _mode = 'idle', _heard = '';
  bool _alive = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final ok = await _stt.initialize(onStatus: (s) {
      if (_alive && _mode == 'listening' && (s == 'done' || s == 'notListening')) {
        Future.delayed(const Duration(milliseconds: 400), _listen);
      }
    });
    await _tts.awaitSpeakCompletion(true);
    if (!ok) {
      if (mounted) setState(() => _mode = 'denied');
      return;
    }
    _listen();
  }

  void _listen() {
    if (!_alive || !mounted || _stt.isListening) return;
    setState(() {
      _mode = 'listening';
      _heard = '';
    });
    _stt.listen(
      pauseFor: const Duration(seconds: 2),
      listenFor: const Duration(seconds: 30),
      listenOptions: SpeechListenOptions(partialResults: true, cancelOnError: true),
      onResult: (r) {
        if (!mounted) return;
        setState(() => _heard = r.recognizedWords);
        if (r.finalResult && _mode == 'listening' && r.recognizedWords.trim().isNotEmpty) {
          _handle(r.recognizedWords.trim());
        }
      },
    );
  }

  Future<void> _handle(String text) async {
    setState(() => _mode = 'thinking');
    final reply = await ref.read(chatsProvider.notifier).send(text);
    if (!_alive) return;
    setState(() => _mode = 'speaking');
    await _tts.speak(reply.replaceAll(RegExp(r'[*#`_>]'), ''));
    _listen();
  }

  @override
  void dispose() {
    _alive = false;
    _stt.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = {'listening': 190.0, 'thinking': 130.0, 'speaking': 230.0}[_mode] ?? 150.0;
    final label = {
      'listening': 'Listening…',
      'thinking': 'Thinking…',
      'speaking': 'Speaking…',
      'denied': 'Microphone / speech permission denied',
    }[_mode] ?? 'Starting…';
    return Scaffold(
      appBar: AppBar(title: const Text('Voice mode')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            width: size,
            height: size,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [cs.primary, cs.primary.withOpacity(0.25)]),
                boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.4), blurRadius: 40)]),
            child: _mode == 'thinking' ? const Center(child: CircularProgressIndicator(color: Colors.white)) : null,
          ),
          const SizedBox(height: 40),
          Text(label, style: Theme.of(context).textTheme.titleLarge),
          Padding(padding: const EdgeInsets.all(24), child: Text(_heard, textAlign: TextAlign.center)),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(context), icon: const Icon(Icons.stop), label: const Text('End')),
        ]),
      ),
    );
  }
}
