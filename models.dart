class Msg {
  final String role; // user | assistant
  final String text;
  final String? image; // base64 JPEG (kept in memory only, not persisted)
  Msg(this.role, this.text, {this.image});
  Map<String, dynamic> toJson() => {'r': role, 't': text};
  factory Msg.fromJson(Map j) => Msg(j['r'], j['t']);
}

class Chat {
  final String id;
  String title;
  List<Msg> msgs;
  String summary; // rolling long-term summary of older turns
  int upTo; // msgs[0..upTo) are already folded into [summary]
  Chat(this.id, {this.title = 'New chat', List<Msg>? msgs, this.summary = '', this.upTo = 0})
      : msgs = msgs ?? [];
  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'summary': summary, 'upTo': upTo, 'msgs': msgs.map((m) => m.toJson()).toList()};
  factory Chat.fromJson(Map j) => Chat(j['id'],
      title: j['title'],
      summary: j['summary'] ?? '',
      upTo: j['upTo'] ?? 0,
      msgs: (j['msgs'] as List).map((m) => Msg.fromJson(m)).toList());
}
