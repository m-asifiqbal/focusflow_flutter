/// ============================================================
/// SHARED NOTE — the note a share from another app becomes
/// ============================================================
///
/// What: turns what another app shared (its text and subject — a browser
/// sends the page URL and the page title, YouTube "Watch … on YouTube" and
/// the link, a chat app a message with a link in it) into a note: a title,
/// the body as Quill Delta with every web link marked as a link (tappable in
/// the editor), and its plain text.
/// Why: pure Dart, so the rules are unit-tested. No network: the title is
/// the subject the other app sent, else the link's site ("youtube.com"),
/// else empty (the note then shows its first line, like any note).
/// ============================================================
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class SharedNote {
  const SharedNote({
    required this.title,
    required this.plainText,
    required this.deltaJson,
  });

  /// Longest title kept from a subject.
  static const int maxTitle = 120;

  static final RegExp _link = RegExp(
    r'''(?:https?://|www\.)[^\s<>"']+''',
    caseSensitive: false,
  );

  /// Punctuation that ends a sentence rather than the link ("see x.com/a.").
  static final RegExp _trailing = RegExp(r'[.,;:!?)\]}]+$');

  final String title;
  final String plainText;
  final String deltaJson;

  /// The note for [text] shared with [subject]; null when both are empty.
  static SharedNote? from(String text, {String subject = ''}) {
    final body = text.replaceAll('\r\n', '\n').trim();
    var title = subject.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (body.isEmpty && title.isEmpty) return null;
    // Nothing but the subject (or the same text twice): it is the body.
    if (body.isEmpty || body == title) {
      return SharedNote(
        title: '',
        plainText: body.isEmpty ? title : body,
        deltaJson: _delta(body.isEmpty ? title : body),
      );
    }
    if (title.isEmpty) {
      final links = linksIn(body);
      // Only a link: name the note after its site.
      if (links.length == 1 && body == links.single) {
        title = siteOf(links.single) ?? '';
      }
    }
    if (title.length > maxTitle) {
      title = '${title.substring(0, maxTitle).trimRight()}…';
    }
    return SharedNote(title: title, plainText: body, deltaJson: _delta(body));
  }

  /// The web links in [text], in order.
  static List<String> linksIn(String text) => [
    for (final m in _link.allMatches(text)) _clean(m.group(0)!),
  ];

  /// "https://www.youtube.com/watch?v=…" → "youtube.com"; null when it has
  /// no host.
  static String? siteOf(String link) {
    final uri = Uri.tryParse(_absolute(link));
    final host = uri?.host ?? '';
    if (host.isEmpty) return null;
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  static String _clean(String link) {
    var l = link.replaceFirst(_trailing, '');
    // Keep a closing bracket that belongs to the link (wiki/Foo_(bar)).
    final tail = link.substring(l.length);
    if (tail.startsWith(')') && l.contains('(') && !l.contains(')')) {
      l = '$l)';
    }
    return l;
  }

  static String _absolute(String link) =>
      link.toLowerCase().startsWith('www.') ? 'https://$link' : link;

  /// [text] as Delta ops: plain runs, and each link run with a `link`
  /// attribute; ends with the newline every Quill document ends with.
  static String _delta(String text) {
    final ops = <Map<String, Object>>[];
    var at = 0;
    for (final m in _link.allMatches(text)) {
      final link = _clean(m.group(0)!);
      if (m.start > at) ops.add({'insert': text.substring(at, m.start)});
      ops.add({
        'insert': link,
        'attributes': {'link': _absolute(link)},
      });
      at = m.start + link.length;
    }
    ops.add({'insert': '${text.substring(at)}\n'});
    return jsonEncode(ops);
  }
}
