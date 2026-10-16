/// FFBottomNav geometry and motion: the "+" is 1 dp smaller than the pill on
/// every side and centred on it; the highlight hugs its tab's content; the
/// four cells tile the pill (no dead zones); nothing overflows on narrow
/// phones / large text; the highlight glides to the newly selected tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_bottom_nav.dart';

const _labels = ['Home', 'Library', 'Insights', 'Settings'];

Future<void> _pump(
  WidgetTester tester, {
  int index = 0,
  Size size = const Size(402, 874),
  double textScale = 1,
  ValueChanged<int>? onTap,
  VoidCallback? onFab,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(AccentColor.emerald),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        extendBody: true,
        bottomNavigationBar: FFBottomNav(
          currentIndex: index,
          onTap: onTap ?? (_) {},
          onFab: onFab ?? () {},
        ),
      ),
    ),
  );
}

Rect _fab(WidgetTester tester) =>
    tester.getRect(find.bySemanticsLabel('Quick add'));

/// The frosted pill (the BackdropFilter fills exactly the capsule).
Rect _pill(WidgetTester tester) => tester.getRect(find.byType(BackdropFilter));

/// The sliding highlight: the only box with a fully rounded (pill) radius.
Finder get _highlightFinder => find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).borderRadius ==
          BorderRadius.circular(AppRadii.pill),
);

void main() {
  testWidgets('the + is 1 dp smaller than the pill all around, centred', (
    tester,
  ) async {
    await _pump(tester);
    final pill = _pill(tester);
    final fab = _fab(tester);
    expect(pill.height, FFBottomNav.height);
    expect(fab.height, FFBottomNav.height - 2);
    expect(fab.width, FFBottomNav.height - 2);
    expect(fab.top - pill.top, closeTo(1, 0.01));
    expect(pill.bottom - fab.bottom, closeTo(1, 0.01));
    expect(fab.center.dy, closeTo(pill.center.dy, 0.01));
    // Separate circle on the right, never inside the pill.
    expect(fab.left, greaterThanOrEqualTo(pill.right));
  });

  testWidgets('tab label is 12.5 pt', (tester) async {
    await _pump(tester);
    expect(tester.widget<Text>(find.text('Home')).style!.fontSize, 12.5);
  });

  testWidgets('the highlight hugs its content instead of filling the pill', (
    tester,
  ) async {
    await _pump(tester);
    final box = tester.getRect(_highlightFinder);
    final pill = _pill(tester);
    final label = tester.getRect(find.text('Home'));
    expect(box.height, 42);
    // icon 19 + gap 7 + the label + 2×14 padding (+1 sub-pixel safety) —
    // not the whole leftover width the highlight used to fill.
    // (±1.5: the rendered label can be 1 dp wider than its measurement.)
    expect(box.width, closeTo(19 + 7 + label.width + 28 + 1, 1.5));
    expect(box.left, greaterThanOrEqualTo(pill.left));
    expect(box.right, lessThanOrEqualTo(pill.right));
    // 14 dp of padding after the label, inside the highlight.
    expect(box.right - label.right, closeTo(14, 2));
    expect(box.height, lessThan(pill.height - 16));
  });

  testWidgets('cells tile the pill: no gaps, every cell taps its own tab', (
    tester,
  ) async {
    final taps = <int>[];
    await _pump(tester, onTap: taps.add);
    final pill = _pill(tester);
    final cells = [
      for (final l in _labels) tester.getRect(find.bySemanticsLabel(l)),
    ];
    for (var i = 0; i < 3; i++) {
      expect(cells[i].right, closeTo(cells[i + 1].left, 0.01));
    }
    final total = cells.fold<double>(0, (a, r) => a + r.width);
    // Pill minus its 8 dp padding each side (border is drawn inside).
    expect(total, closeTo(pill.width - 16, 0.01));
    for (final c in cells) {
      expect(c.width, greaterThanOrEqualTo(43.5));
      expect(c.height, greaterThanOrEqualTo(44));
    }
    for (var i = 0; i < 4; i++) {
      // Both edges of a cell belong to it (no dead zones between tabs).
      await tester.tapAt(Offset(cells[i].left + 1, cells[i].center.dy));
      await tester.tapAt(Offset(cells[i].right - 1, cells[i].center.dy));
    }
    expect(taps, [0, 0, 1, 1, 2, 2, 3, 3]);
  });

  for (final size in const [Size(320, 640), Size(360, 800), Size(430, 932)]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('no overflow at ${size.width.toInt()} pt, text $scale', (
        tester,
      ) async {
        for (var i = 0; i < 4; i++) {
          await _pump(tester, index: i, size: size, textScale: scale);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final pill = _pill(tester);
          final highlight = tester.getRect(_highlightFinder);
          expect(highlight.left, greaterThanOrEqualTo(pill.left - 0.01));
          expect(highlight.right, lessThanOrEqualTo(pill.right + 0.01));
          // The active label is fully inside its highlight.
          final label = tester.getRect(find.text(_labels[i]));
          expect(label.right, lessThanOrEqualTo(highlight.right + 0.5));
        }
      });
    }
  }

  testWidgets('selecting another tab glides the highlight there', (
    tester,
  ) async {
    await _pump(tester, index: 0);
    final start = tester.getRect(_highlightFinder);
    await _pump(tester, index: 3);
    await tester.pump(); // first frame of the animation
    await tester.pump(const Duration(milliseconds: 120));
    final mid = tester.getRect(_highlightFinder);
    expect(mid.left, greaterThan(start.left));
    await tester.pumpAndSettle();
    final end = tester.getRect(_highlightFinder);
    expect(end.left, greaterThan(mid.left));
    // Settled: the new tab's label is open inside the highlight; the old
    // tab's label is gone (icon-only).
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    final label = tester.getRect(find.text('Settings'));
    expect(label.left, greaterThan(end.left));
    expect(label.right, lessThan(end.right));
  });

  testWidgets('reduce motion jumps straight to the new tab', (tester) async {
    await _pump(tester, index: 0);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pump(tester, index: 2);
    await tester.pump();
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('the + reports taps', (tester) async {
    var fab = 0;
    await _pump(tester, onFab: () => fab++);
    await tester.tap(find.bySemanticsLabel('Quick add'));
    expect(fab, 1);
  });
}
