/// Screen 32 — Settings › Appearance: the mockup state in light + dark;
/// theme, accent, text size, layout rows and switches write the live
/// settings; alternate icons say "coming soon"; no overflow at 360 pt /
/// text scale 1.3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_typography.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';

/// design/32_settings_appearance.png is 1170×3495 (390×1165 pt).
const _mockupTall = Size(390, 1165);

void main() {
  late TestHarness h;

  Future<void> setUp(WidgetTester tester) async {
    await loadAppFonts();
    h = (await tester.runAsync(
      () => TestHarness.create(now: DateTime(2026, 6, 12, 9, 41)),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
  }

  AppSettings settings() => h.read(settingsProvider);

  Future<void> tap(WidgetTester tester, Finder f) async {
    // The list builds lazily: scroll rows below the fold into existence.
    if (f.evaluate().isEmpty) {
      await tester.dragUntilVisible(
        f,
        find.byType(ListView).first,
        const Offset(0, -200),
      );
    }
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester);
  }

  testWidgets('mockup state (light)', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settingsAppearance, size: _mockupTall);
    for (final t in [
      'Appearance',
      'THEME',
      'Light',
      'Dark',
      'System',
      'ACCENT COLOUR',
      'TEXT SIZE',
      "Preview: The quick brown fox plans tomorrow's tasks.",
      'APP ICON',
      'Default',
      'Mint',
      'Night',
      'Mono',
      'Notes default view',
      'Grid',
      'Comfortable',
      'Reduce motion',
      'Use system font',
    ]) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '32_settings_appearance');
  });

  testWidgets('mockup state (dark)', (tester) async {
    await setUp(tester);
    await pumpApp(
      tester,
      h,
      AppRoutes.settingsAppearance,
      size: _mockupTall,
      dark: true,
    );
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '32_settings_appearance_dark');
  });

  testWidgets('theme, accent and text size apply live', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settingsAppearance);
    await tap(tester, find.bySemanticsLabel('Dark theme'));
    expect(settings().themeMode, ThemeMode.dark);

    await tap(tester, find.bySemanticsLabel('Blue accent'));
    expect(settings().accent, AccentColor.blue);
    final ctx = tester.element(find.text('Appearance').first);
    expect(Theme.of(ctx).brightness, Brightness.dark);

    final slider = find.byType(Slider);
    await tester.ensureVisible(slider);
    await tester.pump();
    final rect = tester.getRect(slider);
    await tester.tapAt(Offset(rect.right - 12, rect.center.dy));
    await settle(tester);
    expect(settings().textScale, 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('text size: dragging previews locally, saves once on release', (
    tester,
  ) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settingsAppearance);
    const previewText = "Preview: The quick brown fox plans tomorrow's tasks.";
    final slider = find.byType(Slider);
    await tester.ensureVisible(slider);
    await tester.pump();
    var writes = 0;
    final sub = h.container.listen(
      settingsProvider.select((s) => s.textScale),
      (_, _) => writes++,
    );
    addTearDown(sub.close);
    double previewScale() =>
        MediaQuery.textScalerOf(tester.element(find.text(previewText))).scale(10);
    expect(previewScale(), closeTo(10, 1e-9));

    final rect = tester.getRect(slider);
    final gesture = await tester.startGesture(rect.center);
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveTo(Offset(rect.right - 4, rect.center.dy));
    await tester.pump();
    // Mid-drag: nothing persisted, the app still at 1.0, preview enlarged.
    expect(writes, 0);
    expect(settings().textScale, 1.0);
    expect(previewScale(), greaterThan(10));
    expect(
      MediaQuery.textScalerOf(tester.element(find.text('Appearance').first))
          .scale(10),
      closeTo(10, 1e-9),
    );

    await gesture.up();
    await settle(tester);
    expect(writes, 1);
    expect(settings().textScale, 1.3);
    // The whole app now carries the new size; the preview no longer
    // needs its own override.
    expect(previewScale(), closeTo(13, 1e-9));
  });

  testWidgets('system font applies (no longer "coming soon")', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settingsAppearance);
    await tap(tester, find.text('Use system font'));
    expect(settings().useSystemFont, isTrue);
    final ctx = tester.element(find.text('Appearance').first);
    expect(Theme.of(ctx).extension<FFTextStyles>()!.body.fontFamily, isNull);
  });

  testWidgets('layout rows and switches write settings', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settingsAppearance);
    await tap(tester, find.text('Notes default view'));
    await tap(tester, find.text('List').last);
    expect(settings().notesView, NotesView.list);

    await tap(tester, find.text('List density'));
    await tap(tester, find.text('Compact').last);
    expect(settings().listDensity, ListDensity.compact);

    await tap(tester, find.text('Reduce motion'));
    expect(settings().reduceMotion, isTrue);
    await tap(tester, find.text('Use system font'));
    expect(settings().useSystemFont, isTrue);
  });

  testWidgets('alternate app icons are honest about availability', (
    tester,
  ) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settingsAppearance);
    await tap(tester, find.bySemanticsLabel('Night app icon, coming soon'));
    expect(find.text('Night icon is coming soon'), findsOneWidget);
    expect(settings().appIcon, 'default');
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    await setUp(tester);
    await pumpApp(
      tester,
      h,
      AppRoutes.settingsAppearance,
      size: const Size(360, 1400),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '32_settings_appearance_small');
  });
}
