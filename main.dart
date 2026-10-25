import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'state.dart';
import 'ui/chat_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const AgentApp(),
  ));
}

class AgentApp extends ConsumerWidget {
  const AgentApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider.select((s) => s.theme));
    ThemeData theme(Brightness b) => ThemeData(
        useMaterial3: true, colorSchemeSeed: const Color(0xFF6C5CE7), brightness: b);
    return MaterialApp(
      title: 'Nova Agent',
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: mode,
      home: const ChatScreen(),
    );
  }
}
