/// The translator: English is the key and the fallback, `{name}` and
/// `{n, plural, …}` are filled per language, packs are only used once added.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/l10n/app_language.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/settings/app_settings.dart';

void main() {
  tearDown(L10n.reset);

  group('tr', () {
    test('English and unknown keys come back as written', () {
      expect(tr('Archive'), 'Archive');
      L10n.activate(AppLanguage.de, {'Archive': 'Archiv'});
      expect(tr('Archive'), 'Archiv');
      expect(tr('Not in the pack'), 'Not in the pack');
    });

    test('fills {name} placeholders, also with an untranslated key', () {
      expect(tr('{n} tasks overdue', {'n': 3}), '3 tasks overdue');
      L10n.activate(AppLanguage.es, {
        '{n} tasks overdue': '{n} tareas atrasadas',
      });
      expect(tr('{n} tasks overdue', {'n': 3}), '3 tareas atrasadas');
      expect(tr('Hello {name}', {'name': 'Asif'}), 'Hello Asif');
    });

    test('a missing argument is empty, a broken brace is kept', () {
      expect(tr('Hi {name}!'), 'Hi !');
      expect(tr('Open { and stay'), 'Open { and stay');
    });
  });

  group('plurals', () {
    const key = '{count, plural, one {# note} other {# notes}}';

    test('English: one and other, exact match wins', () {
      expect(tr(key, {'count': 1}), '1 note');
      expect(tr(key, {'count': 0}), '0 notes');
      expect(tr(key, {'count': 5}), '5 notes');
      expect(
        tr('{n, plural, =0 {No notes} one {# note} other {# notes}}', {'n': 0}),
        'No notes',
      );
    });

    test('a placeholder inside a branch is filled', () {
      expect(
        tr('{n, plural, one {# task in {list}} other {# tasks in {list}}}', {
          'n': 2,
          'list': 'Work',
        }),
        '2 tasks in Work',
      );
    });

    test('Arabic uses its six categories, Chinese has one', () {
      L10n.activate(AppLanguage.ar, {
        key:
            '{count, plural, zero {لا ملاحظات} one {ملاحظة} two {ملاحظتان} few {# ملاحظات} many {# ملاحظة} other {# ملاحظة}}',
      });
      expect(tr(key, {'count': 0}), 'لا ملاحظات');
      expect(tr(key, {'count': 1}), 'ملاحظة');
      expect(tr(key, {'count': 2}), 'ملاحظتان');
      expect(tr(key, {'count': 4}), '4 ملاحظات');
      expect(tr(key, {'count': 11}), '11 ملاحظة');
      expect(tr(key, {'count': 100}), '100 ملاحظة');

      L10n.activate(AppLanguage.zh, {key: '{count, plural, other {# 条笔记}}'});
      expect(tr(key, {'count': 1}), '1 条笔记');
      expect(tr(key, {'count': 7}), '7 条笔记');
    });

    test('Hindi and Bangla treat 0 and 1 as singular', () {
      for (final l in [AppLanguage.hi, AppLanguage.bn]) {
        expect(l.pluralCategory(0), 'one');
        expect(l.pluralCategory(1), 'one');
        expect(l.pluralCategory(2), 'other');
      }
    });
  });

  group('languages', () {
    test('English has no pack, the others have a bundled one', () {
      expect(AppLanguage.en.assetPath, isNull);
      for (final l in AppLanguage.values.where((l) => l != AppLanguage.en)) {
        expect(l.assetPath, 'assets/l10n/${l.code}.json');
      }
    });

    test('only Arabic is right to left; unknown codes are English', () {
      expect(AppLanguage.values.where((l) => l.rtl), [AppLanguage.ar]);
      expect(AppLanguage.fromCode('xx'), AppLanguage.en);
      expect(AppLanguage.fromCode(null), AppLanguage.en);
      expect(AppLanguage.fromCode('bn'), AppLanguage.bn);
    });

    test('the settings keep the added languages through JSON', () {
      final s = const AppSettings().copyWith(
        languageCode: 'de',
        enabledLanguages: ['de', 'es'],
      );
      final back = AppSettings.fromJson(s.toJson());
      expect(back.languageCode, 'de');
      expect(back.enabledLanguages, ['de', 'es']);
      expect(const AppSettings().enabledLanguages, isEmpty);
    });
  });
}
