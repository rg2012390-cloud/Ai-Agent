import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../llm.dart';
import '../state.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _editKey(BuildContext context, WidgetRef ref, LlmProvider p) async {
    final c = TextEditingController();
    final v = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
              title: Text('${p.label} API key'),
              content: TextField(controller: c, obscureText: true, autocorrect: false, decoration: const InputDecoration(hintText: 'Paste key')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Save')),
              ],
            ));
    if (v != null && v.isNotEmpty) {
      await ref.read(keyStoreProvider).set(p, v);
      ref.invalidate(keyStatusProvider(p));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    Widget h(String t) => Padding(padding: const EdgeInsets.fromLTRB(0, 20, 0, 8), child: Text(t, style: Theme.of(context).textTheme.titleMedium));
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        h('Active model provider'),
        SegmentedButton<LlmProvider>(
          segments: [for (final p in LlmProvider.values) ButtonSegment(value: p, label: Text(p.label))],
          selected: {s.provider},
          onSelectionChanged: (v) => n.setProvider(v.first),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey(s.provider),
          initialValue: s.model,
          decoration: const InputDecoration(labelText: 'Model name', border: OutlineInputBorder()),
          onChanged: n.setModel,
        ),
        h('API keys (stored encrypted on this device)'),
        for (final p in LlmProvider.values)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(ref.watch(keyStatusProvider(p)).value == true ? Icons.check_circle : Icons.key_off,
                color: ref.watch(keyStatusProvider(p)).value == true ? Colors.green : null),
            title: Text(p.label),
            subtitle: Text(ref.watch(keyStatusProvider(p)).value == true ? 'Saved' : 'Not set'),
            onTap: () => _editKey(context, ref, p),
            trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await ref.read(keyStoreProvider).remove(p);
                  ref.invalidate(keyStatusProvider(p));
                }),
          ),
        h('Appearance'),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.system, label: Text('System')),
            ButtonSegment(value: ThemeMode.light, label: Text('Light')),
            ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
          ],
          selected: {s.theme},
          onSelectionChanged: (v) => n.setTheme(v.first),
        ),
        h('Long-term memory'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${ref.watch(memoryProvider).facts.length} saved facts'),
          trailing: TextButton(
              onPressed: () async {
                await ref.read(memoryProvider).clear();
                ref.invalidate(memoryProvider);
              },
              child: const Text('Clear')),
        ),
      ]),
    );
  }
}
