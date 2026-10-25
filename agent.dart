import 'dart:convert';
import 'llm.dart';
import 'models.dart';
import 'tools.dart';

/// ReAct-style loop: think -> call tool -> observe -> repeat -> final answer.
/// Works with any provider because tool calls are plain JSON in the text.
class Agent {
  final LlmConfig cfg;
  final List<Tool> tools;
  final Memory mem;
  Agent(this.cfg, this.tools, this.mem);
  static const maxSteps = 6;

  String _system(Chat c) => '''
You are Nova, a capable assistant that solves problems step by step.
Tools:
${tools.map((t) => '- ${t.name}: ${t.description}').join('\n')}
Reply with ONE JSON object and nothing else:
{"thought":"brief reasoning","action":"<tool name>","input":{...}}   to use a tool, or
{"final":"answer for the user (markdown ok)"}   when done.
Break hard problems into steps, use tools when they help, never invent tool results.
Known facts about the user: ${mem.facts.isEmpty ? 'none' : mem.facts.join('; ')}
Summary of earlier conversation: ${c.summary.isEmpty ? 'none' : c.summary}''';

  Future<String> run(Chat chat, void Function(String) onStep) async {
    final sys = _system(chat);
    var hist = await _window(chat);
    for (var i = 0; i < maxSteps; i++) {
      final out = await Llm.complete(cfg, sys, hist);
      final j = _parse(out);
      if (j == null || j['final'] != null) return '${j?['final'] ?? out}';
      final name = '${j['action']}';
      onStep('Using $name…');
      final tool = tools.where((t) => t.name == name).firstOrNull;
      String obs;
      try {
        obs = tool == null ? 'Unknown tool "$name".' : await tool.run(Map<String, dynamic>.from(j['input'] ?? {}));
      } catch (e) {
        obs = 'Tool error: $e';
      }
      hist = [...hist, Msg('assistant', out), Msg('user', 'Observation: $obs')];
    }
    return 'I reached my step limit before finishing. Try a narrower request.';
  }

  /// Long-term memory: fold old turns into a rolling summary.
  Future<List<Msg>> _window(Chat c) async {
    var w = c.msgs.sublist(c.upTo);
    if (w.length > 24) {
      final cut = w.length - 10;
      final text = w.take(cut).map((m) => '${m.role}: ${m.text}').join('\n');
      c.summary = await Llm.complete(cfg, 'Summarize concisely, keeping facts, decisions and open tasks.',
          [Msg('user', '${c.summary}\n$text')]);
      c.upTo += cut;
      w = c.msgs.sublist(c.upTo);
    }
    while (w.length > 1 && w.first.role != 'user') {
      w = w.sublist(1);
    }
    return w;
  }

  Map<String, dynamic>? _parse(String s) {
    final a = s.indexOf('{'), b = s.lastIndexOf('}');
    if (a < 0 || b < a) return null;
    try {
      final j = jsonDecode(s.substring(a, b + 1));
      return j is Map<String, dynamic> ? j : null;
    } catch (_) {
      return null;
    }
  }
}
