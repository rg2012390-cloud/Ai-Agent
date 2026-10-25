import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models.dart';
import '../state.dart';
import 'settings_screen.dart';
import 'voice_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  String? _img;

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent + 200,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  Future<void> _pick() async {
    final src = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (_) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Camera'), onTap: () => Navigator.pop(context, ImageSource.camera)),
              ListTile(leading: const Icon(Icons.photo_library), title: const Text('Gallery'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
            ])));
    if (src == null) return;
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1024, imageQuality: 70);
    if (x != null) {
      final b = base64Encode(await x.readAsBytes());
      setState(() => _img = b);
    }
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if ((t.isEmpty && _img == null) || ref.read(busyProvider)) return;
    final img = _img;
    _ctrl.clear();
    setState(() => _img = null);
    final f = ref.read(chatsProvider.notifier).send(t.isEmpty ? 'Describe this image.' : t, image: img);
    _toBottom();
    await f;
    _toBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chats = ref.watch(chatsProvider);
    final id = ref.watch(currentIdProvider);
    final chat = chats.where((c) => c.id == id).firstOrNull;
    final busy = ref.watch(busyProvider);
    final step = ref.watch(stepProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(chat?.title ?? 'Nova Agent', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
              tooltip: 'Voice mode',
              icon: const Icon(Icons.graphic_eq),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceScreen()))),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(children: [
            ListTile(
                leading: const Icon(Icons.add),
                title: const Text('New chat'),
                onTap: () {
                  ref.read(chatsProvider.notifier).newChat();
                  Navigator.pop(context);
                }),
            const Divider(),
            Expanded(
              child: ListView(children: [
                for (final c in chats)
                  ListTile(
                    selected: c.id == id,
                    title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      ref.read(currentIdProvider.notifier).state = c.id;
                      Navigator.pop(context);
                    },
                    trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => ref.read(chatsProvider.notifier).delete(c.id)),
                  )
              ]),
            ),
            const Divider(),
            ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                }),
          ]),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: chat == null || chat.msgs.isEmpty
              ? const Center(child: Text('How can I help?', style: TextStyle(fontSize: 20)))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: chat.msgs.length,
                  itemBuilder: (_, i) => _Bubble(chat.msgs[i])),
        ),
        if (busy)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              Text(step.isEmpty ? 'Thinking…' : step),
            ]),
          ),
        if (_img != null)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(_img!), height: 56)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _img = null)),
              ])),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.image_outlined), onPressed: _pick),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                      hintText: 'Message Nova',
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)),
                ),
              ),
              IconButton.filled(icon: const Icon(Icons.arrow_upward), onPressed: _send),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Msg m;
  const _Bubble(this.m);
  @override
  Widget build(BuildContext context) {
    final me = m.role == 'user';
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
            color: me ? cs.primaryContainer : cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (m.image != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(base64Decode(m.image!)))),
          SelectableText(m.text),
        ]),
      ),
    );
  }
}
