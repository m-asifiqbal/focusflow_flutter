/// The vault's avatar sources: the brand catalogue (whole-word title
/// matching, the generic "Bank" last), the glyph library (108 icons, stable
/// keys, search) and how an avatar resolves between them.
library;

import 'package:flutter/widgets.dart' show IconData;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/presentation/vault_brands.dart';
import 'package:focusflow/features/vault/presentation/vault_icons.dart';
import 'package:focusflow/features/vault/presentation/vault_type_style.dart';

void main() {
  group('VaultBrands.match', () {
    String? key(String title, {String? iconKey}) =>
        VaultBrands.match(iconKey, title)?.key;

    test('finds a brand named as a whole word, any case', () {
      expect(key('GitHub'), 'github');
      expect(key('my netflix account'), 'netflix');
      expect(key('Gmail (work)'), 'google');
      expect(key('Outlook.com'), 'microsoft');
      expect(key('HSBC Premier'), 'hsbc');
      expect(key('bKash personal'), 'bkash');
      expect(key('Twitter'), 'x'); // matched through its keyword
    });

    test('does not guess a brand from a fragment of another word', () {
      expect(key('Likewise'), isNull); // "wise"
      expect(key('Shopping list'), isNull); // "ing"
      expect(key('Alliance'), isNull); // "ally"
      expect(key('Boxing'), isNull);
      expect(key('X marks the spot'), isNull); // "X" alone is never guessed
      expect(key(''), isNull);
    });

    test('a specific bank beats the generic "Bank" word, in any order', () {
      expect(key('BRAC Bank savings'), 'brac');
      expect(key('Bank of America'), 'bofa');
      expect(key('Savings at Chase bank'), 'chase');
      // Unknown bank: the generic one.
      expect(key('Local Bank'), 'bank');
      expect(key('Credit union'), 'bank');
    });

    test('an explicit key wins; a glyph key stops title guessing', () {
      expect(key('Netflix', iconKey: 'github'), 'github');
      expect(key('Netflix', iconKey: 'g:key'), isNull);
      expect(key('Netflix', iconKey: 'unknown-brand'), 'netflix');
    });

    test('search covers names and keywords', () {
      expect(VaultBrands.search('hsb').map((b) => b.key), ['hsbc']);
      expect(VaultBrands.search('twitter').map((b) => b.key), ['x']);
      expect(VaultBrands.search('zzz'), isEmpty);
      expect(VaultBrands.search(''), VaultBrands.all);
    });

    test('catalogue keys are unique and every colour parses', () {
      final keys = VaultBrands.all.map((b) => b.key).toList();
      expect(keys.toSet(), hasLength(keys.length));
      for (final b in VaultBrands.all) {
        expect(parseHex(b.bgHex), isNotNull, reason: b.key);
        expect(parseHex(b.fgHex), isNotNull, reason: b.key);
        expect(b.icon != null || (b.letter ?? '').isNotEmpty, isTrue, reason: b.key);
      }
      // "Bank" is the only generic entry, and it is last.
      expect(VaultBrands.all.where((b) => b.generic).map((b) => b.key), ['bank']);
      expect(VaultBrands.all.last.key, 'bank');
    });
  });

  group('VaultIcons', () {
    test('108 glyphs, unique stable keys, 12 per group', () {
      expect(VaultIcons.all, hasLength(108));
      final keys = VaultIcons.all.map((g) => g.key).toList();
      expect(keys.toSet(), hasLength(keys.length));
      for (final k in keys) {
        expect(RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(k), isTrue, reason: k);
      }
      final groups = VaultIcons.groups;
      expect(groups, hasLength(9));
      expect(groups.every((g) => g.glyphs.length == 12), isTrue);
      expect(groups.expand((g) => g.glyphs).toList(), VaultIcons.all);
    });

    test('a glyph key resolves; brands and junk do not', () {
      expect(VaultIcons.iconFor('g:bank'), isNotNull);
      expect(VaultIcons.iconFor('g:nope'), isNull);
      expect(VaultIcons.iconFor('github'), isNull);
      expect(VaultIcons.iconFor(null), isNull);
      expect(VaultIcons.isGlyphKey('g:bank'), isTrue);
      expect(VaultIcons.isGlyphKey('bank'), isFalse);
      for (final g in VaultIcons.all) {
        expect(VaultIcons.iconFor(g.iconKey), g.icon, reason: g.key);
      }
    });

    test('search matches keys and keywords, empty = everything', () {
      expect(VaultIcons.search('passport').map((g) => g.key), contains('passport'));
      expect(VaultIcons.search('PET').map((g) => g.key), contains('paw'));
      expect(VaultIcons.search('  '), VaultIcons.all);
      expect(VaultIcons.search('qqqq'), isEmpty);
    });
  });

  group('VaultBrands.avatarFor', () {
    const fallback = Color(0xFF111111);
    const onFallback = Color(0xFFEEEEEE);
    const tint = Color(0xFF22AA88);

    VaultAvatarSpec spec(
      String title,
      VaultItemType type, {
      String? iconKey,
      String? colorHex,
    }) => VaultBrands.avatarFor(
      title: title,
      type: type,
      fallback: fallback,
      onFallback: onFallback,
      typeColor: tint,
      iconKey: iconKey,
      colorHex: colorHex,
    );

    test('a chosen glyph wears the chosen colour', () {
      final s = spec('x', VaultItemType.login, iconKey: 'g:bank', colorHex: 'FF0000');
      expect(s.icon, VaultIcons.iconFor('g:bank'));
      expect(s.background, const Color(0xFFFF0000));
      expect(s.foreground, onFallback);
      expect(spec('x', VaultItemType.login, iconKey: 'g:bank').background, fallback);
    });

    test('a brand keeps its colours unless the user picked one', () {
      final plain = spec('GitHub', VaultItemType.login);
      expect(plain.icon, isNotNull);
      expect(plain.letter, isNull);
      expect(spec('Netflix', VaultItemType.login).letter, 'N');
      expect(
        spec('Netflix', VaultItemType.login, colorHex: '00FF00').background,
        const Color(0xFF00FF00),
      );
    });

    test('the new types show their own icon, the old ones a letter', () {
      final bank = spec('Savings', VaultItemType.bankAccount);
      expect(bank.icon, vaultTypeIcon(VaultItemType.bankAccount));
      expect(bank.foreground, tint);
      expect(bank.letter, isNull);
      // A user colour or icon turns the default off.
      expect(spec('Savings', VaultItemType.bankAccount, colorHex: 'FF0000').letter, 'S');
      // Original four: unchanged letter avatar.
      final login = spec('zeta', VaultItemType.login);
      expect(login.letter, 'Z');
      expect(login.icon, isNull);
      expect(spec('', VaultItemType.card).letter, '?');
      // A brand in the title still wins for the new types.
      expect(spec('HSBC', VaultItemType.bankAccount).letter, 'H');
    });

    test('every type has an icon', () {
      for (final t in VaultItemType.values) {
        expect(vaultTypeIcon(t), isA<IconData>());
      }
    });
  });
}
