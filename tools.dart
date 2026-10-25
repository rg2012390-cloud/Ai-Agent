import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Long-term facts about the user, injected into every system prompt.
class Memory {
  final SharedPreferences p;
  Memory(this.p);
  List<String> get facts => p.getStringList('facts') ?? [];
  Future<void> add(String f) => p.setStringList('facts', [...facts, f]);
  Future<void> clear() => p.remove('facts');
}

/// Extend the agent: subclass Tool and add it to [defaultTools].
abstract class Tool {
  String get name;
  String get description; // include the JSON input shape
  Future<String> run(Map<String, dynamic> args);
}

List<Tool> defaultTools(Memory m) => [WebSearch(), FetchUrl(), Clock(), Remember(m)];

String _strip(String s) => s
    .replaceAll(RegExp(r'<(script|style)[^>]*>.*?</\1>', dotAll: true), ' ')
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&#x27;', "'")
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class WebSearch extends Tool {
  @override
  String get name => 'web_search';
  @override
  String get description => 'Search the web. input: {"query": "..."}';
  @override
  Future<String> run(Map<String, dynamic> a) async {
    // Swap for Tavily / Brave / SerpAPI for production-grade results.
    final r = await http.post(Uri.parse('https://html.duckduckgo.com/html/'),
        headers: {'User-Agent': 'Mozilla/5.0'}, body: {'q': '${a['query']}'}).timeout(const Duration(seconds: 15));
    final rx = RegExp(r'class="result__a"[^>]*>(.*?)</a>.*?class="result__snippet"[^>]*>(.*?)</a>', dotAll: true);
    final out = rx.allMatches(utf8.decode(r.bodyBytes)).take(5).map((m) => '- ${_strip(m[1]!)}: ${_strip(m[2]!)}').join('\n');
    return out.isEmpty ? 'No results.' : out;
  }
}

class FetchUrl extends Tool {
  @override
  String get name => 'fetch_url';
  @override
  String get description => 'Read a web page as text. input: {"url": "https://..."}';
  @override
  Future<String> run(Map<String, dynamic> a) async {
    final r = await http.get(Uri.parse('${a['url']}'), headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 15));
    final t = _strip(utf8.decode(r.bodyBytes, allowMalformed: true));
    return t.length > 3000 ? t.substring(0, 3000) : t;
  }
}

class Clock extends Tool {
  @override
  String get name => 'current_time';
  @override
  String get description => 'Current local date and time. input: {}';
  @override
  Future<String> run(Map<String, dynamic> a) async => DateTime.now().toString();
}

class Remember extends Tool {
  final Memory mem;
  Remember(this.mem);
  @override
  String get name => 'remember';
  @override
  String get description => 'Save a durable fact about the user for future chats. input: {"fact": "..."}';
  @override
  Future<String> run(Map<String, dynamic> a) async {
    await mem.add('${a['fact']}');
    return 'Saved.';
  }
}
