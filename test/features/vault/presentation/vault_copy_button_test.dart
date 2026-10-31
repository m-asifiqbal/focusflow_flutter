/// The vault copy button turns into a tick after a real copy, holds it, and
/// turns back; a refused copy shows no tick.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_copy_button.dart';

Finder _glyph(IconData icon) =>
    find.text(String.fromCharCode(icon.codePoint), skipOffstage: false);

Widget _app(Future<bool> Function() onCopy) => MaterialApp(
  theme: AppTheme.vault(AccentColor.emerald),
  home: Scaffold(
    body: Center(
      child: VaultCopyButton(semanticLabel: 'Copy password', onCopy: onCopy),
    ),
  ),
);

void main() {
  testWidgets('a copy pops a tick, then the copy glyph comes back', (
    tester,
  ) async {
    var copies = 0;
    await tester.pumpWidget(
      _app(() async {
        copies++;
        return true;
      }),
    );
    expect(_glyph(FontAwesomeIcons.solidCopy), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Copy password'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(copies, 1);
    expect(_glyph(FontAwesomeIcons.check), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Copy password')).value,
      'Copied',
    );

    await tester.pump(VaultCopyButton.hold);
    await tester.pumpAndSettle();
    expect(_glyph(FontAwesomeIcons.check), findsNothing);
    expect(_glyph(FontAwesomeIcons.solidCopy), findsOneWidget);
  });

  testWidgets('a refused copy shows no tick', (tester) async {
    await tester.pumpWidget(_app(() async => false));
    await tester.tap(find.bySemanticsLabel('Copy password'));
    await tester.pumpAndSettle();
    expect(_glyph(FontAwesomeIcons.check), findsNothing);
  });
}
