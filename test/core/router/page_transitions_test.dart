/// Screen-to-screen motion: pushes slide (Cupertino-style, both
/// platforms); a page opened from a card wrapped in FFOpenOriginTracker
/// grows out of that card; reduce motion switches instantly.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/page_transitions.dart';
import 'package:focusflow/core/router/route_pages.dart';
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

/// The real route type of the app ([FFPage]) with a card that opens
/// 'Detail page' and can be moved while that page is open (as a list does
/// when an edited note re-sorts).
class _Pages {
  final open = ValueNotifier(false);
  final where = ValueNotifier(Alignment.center);
  final tracked = ValueNotifier(true);

  void dispose() {
    open.dispose();
    where.dispose();
    tracked.dispose();
  }

  Widget app() => MaterialApp(
    theme: AppTheme.light(AccentColor.emerald),
    home: ValueListenableBuilder<bool>(
      valueListenable: open,
      builder: (_, isOpen, _) => Navigator(
        pages: [
          FFPage<void>(
            key: const ValueKey('list'),
            child: Scaffold(
              body: ListenableBuilder(
                listenable: Listenable.merge([where, tracked]),
                builder: (_, _) {
                  final card = SizedBox(
                    width: 120,
                    height: 80,
                    child: ElevatedButton(
                      onPressed: () => open.value = true,
                      child: const Text('Open card'),
                    ),
                  );
                  return Align(
                    alignment: where.value,
                    child: tracked.value
                        ? FFOpenOriginTracker(child: card)
                        : card,
                  );
                },
              ),
            ),
          ),
          if (isOpen)
            FFPage<void>(
              key: const ValueKey('detail'),
              child: const Scaffold(body: Text('Detail page')),
            ),
        ],
        onDidRemovePage: (_) => open.value = false,
      ),
    ),
  );
}

/// The open container's clip around the page showing [text].
Rect _containerRect(WidgetTester tester, String text) => tester.getRect(
  find.ancestor(of: find.text(text), matching: find.byType(ClipRRect)).first,
);

/// The container's own surface opacity (the dissolve): the ColoredBox right
/// inside its clip.
double _surfaceAlpha(WidgetTester tester, String text) {
  final clip = find
      .ancestor(of: find.text(text), matching: find.byType(ClipRRect))
      .first;
  return tester
      .widget<ColoredBox>(
        find.descendant(of: clip, matching: find.byType(ColoredBox)).first,
      )
      .color
      .a;
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

  testWidgets('closing lands on the card where it is now, and dissolves', (
    tester,
  ) async {
    final pages = _Pages();
    addTearDown(pages.dispose);
    await tester.pumpWidget(pages.app());
    await tester.tap(find.text('Open card'));
    await tester.pumpAndSettle();
    expect(find.text('Detail page'), findsOneWidget);

    // The list re-lays-out while the page is open: the card moves.
    pages.where.value = Alignment.bottomRight;
    Navigator.of(tester.element(find.text('Detail page'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230)); // of 260
    // The list is back on stage; find the card's place now.
    final card = tester.getRect(find.text('Open card'));
    final box = _containerRect(tester, 'Detail page');
    // It heads for the card's new place, not the old one…
    expect((box.center - card.center).distance, lessThan(45));
    // …and has mostly dissolved into it (no blank sheet left on the card).
    expect(_surfaceAlpha(tester, 'Detail page'), lessThan(0.4));
    await tester.pumpAndSettle();
    expect(find.text('Detail page'), findsNothing);
  });

  testWidgets('popping mid-flight continues from where the page is', (
    tester,
  ) async {
    final pages = _Pages();
    addTearDown(pages.dispose);
    await tester.pumpWidget(pages.app());
    await tester.tap(find.text('Open card'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final before = _containerRect(tester, 'Detail page');
    Navigator.of(tester.element(find.text('Detail page'))).pop();
    await tester.pump(const Duration(milliseconds: 1));
    final after = _containerRect(tester, 'Detail page');
    // No jump at the turn-around (a few px of normal motion at most).
    expect((after.left - before.left).abs(), lessThan(12));
    expect((after.top - before.top).abs(), lessThan(12));
    expect((after.right - before.right).abs(), lessThan(12));
    expect((after.bottom - before.bottom).abs(), lessThan(12));
    await tester.pumpAndSettle();
    expect(find.text('Detail page'), findsNothing);
  });

  testWidgets('the page underneath stays put while a container opens', (
    tester,
  ) async {
    final pages = _Pages()..where.value = Alignment.topLeft;
    addTearDown(pages.dispose);
    await tester.pumpWidget(pages.app());
    final home = tester.getTopLeft(find.text('Open card'));

    // As a container: the list does not move.
    await tester.tap(find.text('Open card'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.getTopLeft(find.text('Open card')), home);
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Detail page'))).pop();
    await tester.pumpAndSettle();

    // As a plain push (nothing tapped): the list slides a third of the way.
    pages.tracked.value = false;
    await tester.pump();
    pages.open.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getTopLeft(find.text('Open card')).dx, lessThan(home.dx - 5));
    await tester.pumpAndSettle();
  });

  group('edge swipe-back on a container page', () {
    Future<_Pages> openDetail(WidgetTester tester) async {
      final pages = _Pages();
      addTearDown(pages.dispose);
      await tester.pumpWidget(pages.app());
      await tester.tap(find.text('Open card'));
      await tester.pumpAndSettle();
      expect(find.text('Detail page'), findsOneWidget);
      return pages;
    }

    Future<TestGesture> drag(
      WidgetTester tester,
      Offset from, {
      required int steps,
      double step = 40,
    }) async {
      final gesture = await tester.startGesture(from);
      for (var i = 0; i < steps; i++) {
        await gesture.moveBy(Offset(step, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      return gesture;
    }

    testWidgets('dragging in from the edge shrinks it; letting go closes', (
      tester,
    ) async {
      await openDetail(tester);
      final full = _containerRect(tester, 'Detail page').width;
      final gesture = await drag(tester, const Offset(4, 300), steps: 8);
      // Under the finger: the container has shrunk, the page is still there.
      expect(_containerRect(tester, 'Detail page').width, lessThan(full - 40));
      expect(find.text('Detail page'), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Detail page'), findsNothing);
      // Back on the list, input works again (the gesture was released).
      expect(find.text('Open card'), findsOneWidget);
    });

    testWidgets('a short swipe springs back open', (tester) async {
      await openDetail(tester);
      final full = _containerRect(tester, 'Detail page');
      final gesture = await drag(
        tester,
        const Offset(4, 300),
        steps: 2,
        step: 20,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Detail page'), findsOneWidget);
      expect(_containerRect(tester, 'Detail page'), full);
      // …and the page is interactive again: a real swipe still works.
      final again = await drag(tester, const Offset(4, 300), steps: 8);
      await again.up();
      await tester.pumpAndSettle();
      expect(find.text('Detail page'), findsNothing);
    });

    testWidgets('a swipe that starts away from the edge does nothing', (
      tester,
    ) async {
      await openDetail(tester);
      final gesture = await drag(tester, const Offset(200, 300), steps: 8);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Detail page'), findsOneWidget);
    });
  });
}
