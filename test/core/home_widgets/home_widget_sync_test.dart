/// The widget sync: nothing runs while no widget is on the home screen; once
/// one is, a snapshot is built and pushed (and an unchanged one is not
/// pushed again). Plus the settings page that adds widgets and holds the
/// privacy switches.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/home_widgets/home_widget_channel.dart';
import 'package:focusflow/core/home_widgets/home_widget_sync.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../helpers/screen_harness.dart';
import '../../helpers/test_container.dart';

const _channel = MethodChannel(HomeWidgetChannel.channelName);
final _now = DateTime(2026, 10, 31, 9, 30);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  Map<String, int> placed = {};

  setUp(() {
    calls.clear();
    placed = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'counts' => placed,
            'push' => true,
            'requestPin' => true,
            _ => null,
          };
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('sync', () {
    late TestHarness h;
    setUp(() async => h = await TestHarness.create(now: _now));
    tearDown(() => h.dispose());

    test('with no widget placed it asks once and does nothing else', () async {
      final sync = h.read(homeWidgetSyncProvider);
      await sync.start();
      await sync.refresh(); // direct call still works…
      sync.schedule(); // …but scheduling only re-checks for widgets
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(calls.where((c) => c.method == 'counts'), isNotEmpty);
      // Only refresh() above pushed; no stream or timer was started.
      expect(calls.where((c) => c.method == 'push'), hasLength(1));
    });

    test(
      'with a widget placed it pushes a snapshot, once per change',
      () async {
        placed = {'tasks': 1};
        final sync = h.read(homeWidgetSyncProvider);
        await sync.start();
        await Future<void>.delayed(
          HomeWidgetSync.debounce + const Duration(milliseconds: 600),
        );
        final pushes = calls.where((c) => c.method == 'push').toList();
        expect(pushes, isNotEmpty);
        final snapshot = jsonDecode(pushes.first.arguments as String) as Map;
        expect(snapshot['v'], 1);
        expect(snapshot['day'], '2026-10-31');

        // Nothing changed: refreshing again pushes nothing new.
        final before = pushes.length;
        await sync.refresh();
        expect(calls.where((c) => c.method == 'push'), hasLength(before));
      },
    );
  });

  group('settings page', () {
    late TestHarness h;
    setUp(() async => h = await TestHarness.create(now: _now));
    tearDown(() => h.dispose());

    testWidgets('lists the six widgets, saves privacy switches, pins', (
      tester,
    ) async {
      await loadAppFonts();
      placed = {'tasks': 2};
      await pumpApp(tester, h, AppRoutes.settingsHomeWidgets);
      expect(find.text('Home screen widgets'), findsWidgets);
      for (final name in [
        'All together',
        'Tasks',
        'Habits',
        'Medicine',
        'Reminders',
        'Notes',
      ]) {
        expect(find.text(name), findsWidgets, reason: name);
      }
      expect(find.textContaining('2 on your home screen'), findsOneWidget);

      // Privacy switches write settings.
      expect(h.read(settingsProvider).widgetsShowNoteText, isTrue);
      await tester.tap(find.text('Show note text'));
      await settle(tester);
      expect(h.read(settingsProvider).widgetsShowNoteText, isFalse);
      expect(find.text('Titles only'), findsOneWidget);
      await tester.tap(find.text('Show completed tasks'));
      await settle(tester);
      expect(h.read(settingsProvider).widgetsShowCompleted, isFalse);

      // "Add" asks the launcher to pin that widget.
      await tester.tap(find.text('Add').first);
      await settle(tester);
      final pin = calls.firstWhere((c) => c.method == 'requestPin');
      expect(pin.arguments, 'today');
      expect(tester.takeException(), isNull);
      // A widget is placed in this test, so the app started the sync: stop
      // its timers before the test ends.
      h.read(homeWidgetSyncProvider).dispose();
    });
  });
}
