/// Screen-to-screen motion: pushes slide (Cupertino-style, both
/// platforms); a page opened from a card wrapped in FFOpenOriginTracker
/// grows out of that card; reduce motion switches instantly.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/page_transitions.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_open_origin.dart';

Widget _app({required bool tracked, bool reduceMotion = false}) {
  return MaterialApp(
    theme: AppTheme.light(AccentColor.emerald),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: Builder(
      builder: (context) {
        final button = SizedBox(
          width: 160,
          height: 80,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Detail page')),
              ),
            ),
            child: const Text('Open card'),
          ),
        );
        return Scaffold(
          body: Center(
            child: tracked ? FFOpenOriginTracker(child: button) : button,
          ),
        );
      },
    ),
  );
}

/// The slide transition wrapping the page that shows [text].
Finder slideAround(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byType(CupertinoPageTransition),
);

void main() {
  test('claim: nothing pending → null; a fresh record is claimed once', () {
    final a = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    final b = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    expect(FFOpenOrigin.claim(a), isNull);
    FFOpenOrigin.record(const Rect.fromLTWH(10, 20, 100, 50), radius: 12);
    final origin = FFOpenOrigin.claim(b);
    expect(origin?.rect, const Rect.fromLTWH(10, 20, 100, 50));
    expect(origin?.radius, 12);
    // Decided once per route; the pending origin is consumed.
    expect(FFOpenOrigin.claim(b)?.rect, origin?.rect);
    expect(FFOpenOrigin.claim(a), isNull);
  });

  testWidgets('a tracked card opens its page as an open container', (
    tester,
  ) async {
    await tester.pumpWidget(_app(tracked: true));
    await tester.tap(find.text('Open card'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // Mid-flight: the page is clipped to a growing rounded rect, no slide.
    expect(find.text('Detail page'), findsOneWidget);
    expect(slideAround('Detail page'), findsNothing);
    final clip = tester.getRect(
      find
          .ancestor(
            of: find.text('Detail page'),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(
      clip.width,
      lessThan(tester.view.physicalSize.width / tester.view.devicePixelRatio),
    );
    await tester.pumpAndSettle();
    expect(find.text('Detail page'), findsOneWidget);
  });

  testWidgets('an untracked push slides in', (tester) async {
    await tester.pumpWidget(_app(tracked: false));
    await tester.tap(find.text('Open card'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(slideAround('Detail page'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Detail page'), findsOneWidget);
  });

  testWidgets('reduce motion: no transition at all', (tester) async {
    await tester.pumpWidget(_app(tracked: true, reduceMotion: true));
    await tester.tap(find.text('Open card'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(slideAround('Detail page'), findsNothing);
    expect(find.text('Detail page'), findsOneWidget);
  });
}
