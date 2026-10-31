/// A share from another app becomes a note: title from the subject (else the
/// link's site), body with every web link marked as a link.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/platform/share_intake.dart';
import 'package:focusflow/features/notes/domain/services/shared_note.dart';

List<Object?> _ops(SharedNote n) => jsonDecode(n.deltaJson) as List<Object?>;

void main() {
  test('a browser share: page title + URL', () {
    final n = SharedNote.from(
      'https://example.com/articles/42',
      subject: 'How to focus  better',
    )!;
    expect(n.title, 'How to focus better');
    expect(n.plainText, 'https://example.com/articles/42');
    expect(_ops(n), [
      {
        'insert': 'https://example.com/articles/42',
        'attributes': {'link': 'https://example.com/articles/42'},
      },
      {'insert': '\n'},
    ]);
  });

  test('a bare link is named after its site', () {
    final n = SharedNote.from('https://www.youtube.com/watch?v=abc')!;
    expect(n.title, 'youtube.com');
  });

  test('text around a link stays text; sentence punctuation is not linked', () {
    final n = SharedNote.from('Look at www.example.org/page. Nice!')!;
    expect(n.title, '');
    expect(n.plainText, 'Look at www.example.org/page. Nice!');
    expect(_ops(n), [
      {'insert': 'Look at '},
      {
        'insert': 'www.example.org/page',
        'attributes': {'link': 'https://www.example.org/page'},
      },
      {'insert': '. Nice!\n'},
    ]);
  });

  test('a bracket that belongs to the link is kept', () {
    expect(
      SharedNote.linksIn('(see https://en.wikipedia.org/wiki/Foo_(bar)).'),
      ['https://en.wikipedia.org/wiki/Foo_(bar)'],
    );
  });

  test('plain text without a link: no title, the text is the body', () {
    final n = SharedNote.from('Buy milk\nand bread')!;
    expect(n.title, '');
    expect(n.plainText, 'Buy milk\nand bread');
    expect(_ops(n), [
      {'insert': 'Buy milk\nand bread\n'},
    ]);
  });

  test('only a subject, or the same text twice: it becomes the body', () {
    expect(SharedNote.from('', subject: 'Hello')!.plainText, 'Hello');
    final twice = SharedNote.from('Hello', subject: 'Hello')!;
    expect((twice.title, twice.plainText), ('', 'Hello'));
  });

  test('nothing shared: no note', () {
    expect(SharedNote.from('  ', subject: ' '), isNull);
  });

  test('a very long subject is shortened', () {
    final n = SharedNote.from('https://a.com', subject: 'x' * 300)!;
    expect(n.title.length, SharedNote.maxTitle + 1);
    expect(n.title.endsWith('…'), isTrue);
  });

  test('channel payloads: empty or malformed shares are dropped', () {
    expect(SharedText.fromChannel({'text': 'a', 'subject': 'b'})?.subject, 'b');
    expect(SharedText.fromChannel({'text': ' ', 'subject': ''}), isNull);
    expect(SharedText.fromChannel('nope'), isNull);
  });
}
