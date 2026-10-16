// Shared harness for the design-system widget tests: pumps a widget inside
// the real FocusFlow theme (light or dark) on a phone-sized surface with a
// configurable text scale (defaults to the worst case we support: 1.3 at
// 360 pt wide).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_theme.dart';

const Size kNarrowPhone = Size(360, 800);

/// Pumps [child] in a themed [MaterialApp]. When [scroll] is true the child
/// sits in a padded vertical scroll view inside a Scaffold (like a screen
/// body); otherwise it is the Scaffold body itself.
Future<void> pumpFF(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  double textScale = 1.3,
  Size size = kNarrowPhone,
  bool scroll = true,
  bool disableAnimations = false,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(AccentColor.emerald),
      darkTheme: AppTheme.dark(AccentColor.emerald),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: Directionality(textDirection: textDirection, child: app!),
      ),
      home: Scaffold(
        body: scroll
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: child,
              )
            : child,
      ),
    ),
  );
}
