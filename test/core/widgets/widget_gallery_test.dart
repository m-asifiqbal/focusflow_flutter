// Gallery sweep: every design-system demo must lay out without exceptions or
// overflow in light AND dark mode, at text scale 1.3 on a 360 pt-wide phone
// (the default test font is wider than our real fonts, so this is a strict
// check). Also pumps the full dev gallery screen and scrolls through it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/widgets/dev/gallery_demos.dart';
import 'package:focusflow/core/widgets/dev/widget_gallery_screen.dart';
import 'package:focusflow/core/widgets/ff_scaffold.dart';

import 'ff_test_harness.dart';

void main() {
  for (final dark in [false, true]) {
    group(dark ? 'dark' : 'light', () {
      for (final demo in galleryDemos) {
        testWidgets('${demo.name} lays out at 360 pt / 1.3x', (tester) async {
          await pumpFF(tester, Builder(builder: demo.builder), dark: dark);
          await tester.pump(const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull);
        });
      }
    });
  }

  testWidgets('every demo also lays out in RTL with reduce motion', (
    tester,
  ) async {
    await pumpFF(
      tester,
      Column(
        children: [for (final d in galleryDemos) Builder(builder: d.builder)],
      ),
      textDirection: TextDirection.rtl,
      disableAnimations: true,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('WidgetGalleryScreen scrolls through every demo, light → dark', (
    tester,
  ) async {
    await pumpFF(tester, const WidgetGalleryScreen(), scroll: false);
    await tester.pump();

    Future<void> scrollAll() async {
      for (var i = 0; i < 60; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
      }
    }

    await scrollAll();
    expect(find.text('FFBOTTOMNAV'), findsOneWidget);

    // Back to the top and switch to dark mode.
    tester
        .state<ScrollableState>(
          find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .first,
        )
        .position
        .jumpTo(0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Dark'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      Theme.of(tester.element(find.byType(FFScaffold))).brightness,
      Brightness.dark,
    );
    await scrollAll();
    expect(tester.takeException(), isNull);
  });
}
