/// The local profile photo: it shows on Home (not only in the profile), and
/// the profile's photo pop-up has a "View photo" option that opens the whole
/// picture full screen.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/ff_avatar.dart';
import 'package:focusflow/features/auth/presentation/providers/account_providers.dart';
import 'package:focusflow/features/home/presentation/widgets/home_header.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../auth_test_support.dart';

final _now = DateTime(2026, 10, 13, 9, 41);

/// A real 1×1 PNG (so the image decodes in tests).
final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  Future<TestHarness> harness(WidgetTester tester, {bool photo = true}) async {
    final fakes = AuthFakes();
    final h = (await tester.runAsync(() => authHarness(fakes, now: _now)))!;
    addTearDown(() async {
      await tester.runAsync(h.dispose);
      if (fakes.dir.existsSync()) fakes.dir.deleteSync(recursive: true);
    });
    if (photo) {
      await tester.runAsync(() => fakes.files.write(profilePhotoPath, _photo));
    }
    return h;
  }

  testWidgets('the photo shows in the Home header', (tester) async {
    final h = await harness(tester);
    await pumpApp(tester, h, AppRoutes.home);
    await settle(tester); // the picture is read from disk
    final avatar = tester.widget<FFAvatar>(
      find.descendant(
        of: find.byType(HomeHeader),
        matching: find.byType(FFAvatar),
      ),
    );
    expect(avatar.image, isNotNull);
  });

  testWidgets('without a photo Home keeps the initial', (tester) async {
    final h = await harness(tester, photo: false);
    await pumpApp(tester, h, AppRoutes.home);
    final avatar = tester.widget<FFAvatar>(
      find.descendant(
        of: find.byType(HomeHeader),
        matching: find.byType(FFAvatar),
      ),
    );
    expect(avatar.image, isNull);
  });

  testWidgets('the photo pop-up offers "View photo" → full-screen preview', (
    tester,
  ) async {
    final h = await harness(tester);
    await pumpApp(tester, h, AppRoutes.settingsAccount);
    await settle(tester); // the picture is read from disk
    await tester.tap(find.byType(FFAvatar));
    await settle(tester);
    expect(find.text('View photo'), findsOneWidget);
    // It leads the list.
    expect(
      tester.getTopLeft(find.text('View photo')).dy,
      lessThan(tester.getTopLeft(find.text('Choose photo')).dy),
    );

    await tester.tap(find.text('View photo'));
    await settle(tester);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    // Double-tap zooms in, again zooms out.
    final viewer = find.byType(InteractiveViewer);
    final controller = tester
        .widget<InteractiveViewer>(viewer)
        .transformationController!;
    await tester.tap(viewer);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(viewer);
    await settle(tester);
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(2));
    await tester.tap(viewer);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(viewer);
    await settle(tester);
    expect(controller.value.getMaxScaleOnAxis(), closeTo(1, 0.01));

    // The close button leaves the viewer.
    await tester.tap(find.byIcon(FontAwesomeIcons.xmark));
    await settle(tester);
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('no photo, no "View photo"', (tester) async {
    final h = await harness(tester, photo: false);
    await pumpApp(tester, h, AppRoutes.settingsAccount);
    await tester.tap(find.byType(FFAvatar));
    await settle(tester);
    expect(find.text('Choose photo'), findsOneWidget);
    expect(find.text('View photo'), findsNothing);
  });
}
