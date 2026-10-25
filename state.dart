import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'agent.dart';
import 'llm.dart';
import 'models.dart';
import 'tools.dart';

final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());

/// API keys live in Keychain (iOS) / EncryptedSharedPreferences (Android).
class KeyStore {
  final _s = const FlutterSecureStorage();
  Future<String?> get(LlmProvider p) => _s.read(key: 'key_${p.name}');
  Future<void> set(LlmProvider p, String v) => _s.write(key: 'key_${p.name}', value: v);
  Future<void> remove(LlmProvider p) => _s.delete(key: 'key_${p.name}');
}

final keyStoreProvider = Provider((_) => KeyStore());
final keyStatusProvider = FutureProvider.family<bool, LlmProvider>(
    (ref, p) async => (await ref.read(keyStoreProvider).get(p))?.isNotEmpty ?? false);
final memoryProvider = Provider((ref) => Memory(ref.read(prefsProvider)));

class Settings {
  final LlmProvider provider;
  final ThemeMode theme;
  final Map<String, String> models;
  Settings(this.provider, this.theme, this.models);
  String get model => models[provider.name] ?? Llm.defaults[provider]!;
  Settings copyWith({LlmProvider? provider, ThemeMode? theme, Map<String, String>? models}) =>
      Settings(provider ?? this.provider, theme ?? this.theme, models ?? this.models);
}

class SettingsN extends Notifier<Settings> {
  SharedPreferences get _p => ref.read(prefsProvider);
  @override
  Settings build() => Settings(LlmProvider.values[_p.getInt('provider') ?? 0],
      ThemeMode.values[_p.getInt('theme') ?? 0], Map<String, String>.from(jsonDecode(_p.getString('models') ?? '{}')));
  void setProvider(LlmProvider v) {
    _p.setInt('provider', v.index);
    state = state.copyWith(provider: v);
  }

  void setTheme(ThemeMode m) {
    _p.setInt('theme', m.index);
    state = state.copyWith(theme: m);
  }

  void setModel(String m) {
    final mm = {...state.models, state.provider.name: m};
    _p.setString('models', jsonEncode(mm));
    state = state.copyWith(models: mm);
  }
}

final settingsProvider = NotifierProvider<SettingsN, Settings>(SettingsN.new);
final currentIdProvider = StateProvider<String?>((_) => null);
final busyProvider = StateProvider<bool>((_) => false);
final stepProvider = StateProvider<String>((_) => '');

class ChatsN extends Notifier<List<Chat>> {
  SharedPreferences get _p => ref.read(prefsProvider);
  @override
  List<Chat> build() {
    final raw = _p.getString('chats');
    return raw == null ? [] : (jsonDecode(raw) as List).map((e) => Chat.fromJson(e)).toList();
  }

  void _save() {
    state = [...state];
    _p.setString('chats', jsonEncode(state.map((c) => c.toJson()).toList()));
  }

  Chat newChat() {
    final c = Chat(DateTime.now().microsecondsSinceEpoch.toString());
    state = [c, ...state];
    ref.read(currentIdProvider.notifier).state = c.id;
    return c;
  }

  void delete(String id) {
    state = state.where((c) => c.id != id).toList();
    if (ref.read(currentIdProvider) == id) ref.read(currentIdProvider.notifier).state = null;
    _save();
  }

  /// Sends a user turn, runs the agent, returns the reply text.
  Future<String> send(String text, {String? image}) async {
    final id = ref.read(currentIdProvider);
    final chat = state.where((c) => c.id == id).firstOrNull ?? newChat();
    chat.msgs.add(Msg('user', text, image: image));
    if (chat.title == 'New chat') chat.title = text.length > 30 ? text.substring(0, 30) : text;
    _save();
    ref.read(busyProvider.notifier).state = true;
    String reply;
    try {
      final s = ref.read(settingsProvider);
      final key = await ref.read(keyStoreProvider).get(s.provider);
      if (key == null || key.isEmpty) throw 'Add your ${s.provider.label} API key in Settings.';
      final mem = ref.read(memoryProvider);
      reply = await Agent(LlmConfig(s.provider, s.model, key), defaultTools(mem), mem)
          .run(chat, (st) => ref.read(stepProvider.notifier).state = st);
    } catch (e) {
      reply = '⚠️ $e';
    }
    chat.msgs.add(Msg('assistant', reply));
    ref.read(busyProvider.notifier).state = false;
    ref.read(stepProvider.notifier).state = '';
    _save();
    return reply;
  }
}

final chatsProvider = NotifierProvider<ChatsN, List<Chat>>(ChatsN.new);
