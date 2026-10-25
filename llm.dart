import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

enum LlmProvider {
  openai('OpenAI'),
  gemini('Gemini'),
  claude('Claude');
  final String label;
  const LlmProvider(this.label);
}

class LlmConfig {
  final LlmProvider provider;
  final String model, key;
  LlmConfig(this.provider, this.model, this.key);
}

/// One interface over OpenAI, Gemini and Claude. Add a provider = add a case.
class Llm {
  static const defaults = {
    LlmProvider.openai: 'gpt-4o-mini',
    LlmProvider.gemini: 'gemini-2.0-flash',
    LlmProvider.claude: 'claude-sonnet-5-5',
  };
  static const _json = {'Content-Type': 'application/json'};

  static Future<String> complete(LlmConfig c, String system, List<Msg> h) async {
    switch (c.provider) {
      case LlmProvider.openai:
        final r = await http.post(Uri.parse('https://api.openai.com/v1/chat/completions'),
            headers: {..._json, 'Authorization': 'Bearer ${c.key}'},
            body: jsonEncode({
              'model': c.model,
              'messages': [
                {'role': 'system', 'content': system},
                for (final m in h)
                  {
                    'role': m.role,
                    'content': m.image == null
                        ? m.text
                        : [
                            {'type': 'text', 'text': m.text},
                            {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,${m.image}'}}
                          ]
                  }
              ]
            }));
        return _parse(r, (j) => j['choices'][0]['message']['content']);
      case LlmProvider.claude:
        final r = await http.post(Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {..._json, 'x-api-key': c.key, 'anthropic-version': '2023-06-01'},
            body: jsonEncode({
              'model': c.model,
              'max_tokens': 2048,
              'system': system,
              'messages': [
                for (final m in h)
                  {
                    'role': m.role,
                    'content': [
                      if (m.image != null)
                        {'type': 'image', 'source': {'type': 'base64', 'media_type': 'image/jpeg', 'data': m.image}},
                      {'type': 'text', 'text': m.text}
                    ]
                  }
              ]
            }));
        return _parse(r, (j) => j['content'][0]['text']);
      case LlmProvider.gemini:
        final r = await http.post(
            Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${c.model}:generateContent'),
            headers: {..._json, 'x-goog-api-key': c.key},
            body: jsonEncode({
              'system_instruction': {'parts': [{'text': system}]},
              'contents': [
                for (final m in h)
                  {
                    'role': m.role == 'assistant' ? 'model' : 'user',
                    'parts': [
                      {'text': m.text},
                      if (m.image != null) {'inline_data': {'mime_type': 'image/jpeg', 'data': m.image}}
                    ]
                  }
              ]
            }));
        return _parse(r, (j) => j['candidates'][0]['content']['parts'][0]['text']);
    }
  }

  static String _parse(http.Response r, String Function(dynamic) pick) {
    final body = utf8.decode(r.bodyBytes);
    if (r.statusCode >= 300) {
      throw 'API error ${r.statusCode}: ${body.length > 300 ? body.substring(0, 300) : body}';
    }
    return pick(jsonDecode(body));
  }
}
