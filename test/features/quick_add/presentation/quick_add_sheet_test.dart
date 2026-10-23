/// Screen 04 — Quick Add sheet: opens from the FAB over Home (light + dark
/// captures), natural-language capture → prefilled editor, module tiles,
/// dictation, Quick Scan OCR → note, Cancel, no overflow at 360 pt / 1.3.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/platform/text_scanner.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/quick_add/domain/services/capture_inputs.dart';
import 'package:focusflow/features/quick_add/presentation/providers/quick_add_providers.dart';
import 'package:focusflow/features/quick_add/presentation/widgets/quick_add_sheet.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../../home/home_seed.dart';
import '../../reminders/isolated_notifications.dart';

class _FakeSpeech implements SpeechCapture {
  void Function(String)? words;
  void Function()? done;
  int stops = 0;

  @override
  Future<bool> start({
    required void Function(String words) onWords,
    required void Function() onDone,
  }) async {
    words = onWords;
    done = onDone;
    return true;
  }

  @override
  Future<void> stop() async {
    stops++;
    done?.call();
  }

  @override
  Future<void> cancel() async {}
}

class _FakeImages implements ScanImageSource {
  final discarded = <String>[];
  ScanSource? source;

  /// Thrown by [pick] when set (plugin missing, permission denied …).
  Object? pickError;

  @override
  Future<String?> pick(ScanSource source) async {
    this.source = source;
    if (pickError case final e?) throw e;
    return '/tmp/scan.jpg';
  }

  @override
  Future<void> discard(String path) async => discarded.add(path);
}

class _FakeScanner extends TextScanner {
  const _FakeScanner(this.text, {this.error});
  final String text;
  final Object? error;

  @override
  Future<String> recognizeText(String imagePath) async {
    if (error case final e?) throw e;
    return text;
  }
}

void main() {
  late TestHarness h;
  late _FakeSpeech speech;
  late _FakeImages images;

  Future<void> boot(
    WidgetTester tester, {
    String ocr = 'Milk\nEggs',
    Object? ocrError,
  }) async {
    await loadAppFonts();
    speech = _FakeSpeech();
    images = _FakeImages();
    h = (await tester.runAsync(
      () => TestHarness.create(
        now: homeNow,
        overrides: [
          ...isolatedNotifications(),
          speechCaptureProvider.overrideWithValue(speech),
          scanImageSourceProvider.overrideWithValue(images),
          textScannerProvider.overrideWithValue(
            _FakeScanner(ocr, error: ocrError),
          ),
        ],
      ),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await tester.runAsync(() => seedHomeMockup(h));
  }

  Future<void> open(
    WidgetTester tester, {
    bool dark = false,
    Size size = kMockupSize,
    double textScale = 1,
  }) async {
    await pumpApp(
      tester,
      h,
      AppRoutes.home,
      dark: dark,
      size: size,
      textScale: textScale,
    );
    await tester.tap(find.bySemanticsLabel('Quick add'));
    await settle(tester);
    expect(find.byType(QuickAddSheet), findsOneWidget);
  }

  String location() => h.read(routerProvider).state.uri.toString();

  testWidgets('renders the mockup (light)', (tester) async {
    await boot(tester);
    await open(tester);
    await captureScreen(tester, '04_quick_add');
    expect(find.text('What’s next?'), findsOneWidget);
    expect(find.text('Capture anything in two taps'), findsOneWidget);
    expect(find.text('Try “Pay rent tomorrow 9am”'), findsOneWidget);
    for (final t in ['Note', 'Task', 'Reminder', 'Habit', 'Password', 'Scan']) {
      expect(find.text(t), findsOneWidget);
    }
    // Inside the sheet: Home behind it builds every section (its notes
    // carry folder tags like IDEAS too).
    final sheet = find.byType(QuickAddSheet);
    for (final c in ['IDEAS', 'TO-DOS', 'ALERTS', 'ROUTINE', 'SECURE', 'OCR']) {
      expect(
        find.descendant(of: sheet, matching: find.text(c)),
        findsOneWidget,
      );
    }
    expect(find.bySemanticsLabel('Dictate'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('renders in dark mode', (tester) async {
    await boot(tester);
    await open(tester, dark: true);
    await captureScreen(tester, '04_quick_add_dark');
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture shows a preview and opens the prefilled editor', (
    tester,
  ) async {
    await boot(tester);
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Pay rent tomorrow 9am');
    await settle(tester);
    expect(
      find.bySemanticsLabel('Will create: Reminder · Tomorrow 09:00 AM'),
      findsOneWidget,
    );
    await captureScreen(tester, '04_quick_add_typing');

    await tester.tap(find.bySemanticsLabel('Create reminder'));
    await settle(tester);
    expect(find.byType(QuickAddSheet), findsNothing);
    final uri = Uri.parse(location());
    expect(uri.path, AppRoutes.newReminderPath);
    expect(uri.queryParameters['title'], 'Pay rent');
    expect(
      DateTime.parse(uri.queryParameters['at']!),
      DateTime(2023, 6, 14, 9),
    );
  });

  testWidgets('a dated phrase without time opens the task editor', (
    tester,
  ) async {
    await boot(tester);
    await open(tester);
    await tester.enterText(
      find.byType(TextField),
      'Book flights friday #trip !high',
    );
    await settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    final uri = Uri.parse(location());
    expect(uri.path, AppRoutes.newTaskPath);
    expect(uri.queryParameters, {
      'title': 'Book flights',
      'date': '2023-06-16',
      'priority': '3',
      'tag': 'trip',
    });
  });

  testWidgets('tiles open their editors; Cancel closes', (tester) async {
    await boot(tester);
    await open(tester);
    await tester.tap(find.bySemanticsLabel('New task'));
    await settle(tester);
    expect(location(), AppRoutes.newTaskPath);

    await open(tester);
    await tester.tap(find.bySemanticsLabel('New habit'));
    await settle(tester);
    expect(location(), AppRoutes.newHabitPath);

    await open(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.byType(QuickAddSheet), findsNothing);
    expect(location(), AppRoutes.home);
  });

  testWidgets('dictation fills the field and pulses the mic', (tester) async {
    await boot(tester);
    await open(tester);
    await tester.tap(find.bySemanticsLabel('Dictate'));
    await tester.pump();
    expect(find.bySemanticsLabel('Stop dictation'), findsOneWidget);
    expect(find.text('Listening…'), findsOneWidget);
    speech.words!('Call mom at 5pm');
    await tester.pump();
    expect(find.text('Call mom at 5pm'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Stop dictation'));
    await settle(tester);
    expect(speech.stops, 1);
    expect(find.bySemanticsLabel('Dictate'), findsOneWidget);
    expect(find.bySemanticsLabel('Create reminder'), findsOneWidget);
  });

  testWidgets('Quick Scan: photo → OCR → new note, photo discarded', (
    tester,
  ) async {
    await boot(tester);
    await open(tester);
    await tester.tap(find.bySemanticsLabel('Scan text into a note'));
    await settle(tester);
    await tester.tap(find.text('Take photo'));
    await settle(tester);
    expect(images.source, ScanSource.camera);
    expect(images.discarded, ['/tmp/scan.jpg']);
    final uri = Uri.parse(location());
    expect(uri.path, AppRoutes.newNote);
    expect(uri.queryParameters['text'], 'Milk\nEggs');
  });

  testWidgets('Quick Scan with no text shows a toast', (tester) async {
    await boot(tester, ocr: '');
    await open(tester);
    await tester.tap(find.bySemanticsLabel('Scan text into a note'));
    await settle(tester);
    await tester.tap(find.text('Choose from library'));
    await settle(tester);
    expect(images.source, ScanSource.gallery);
    expect(find.text('No text found in that photo'), findsOneWidget);
    expect(location(), AppRoutes.home);
  });

  testWidgets('only the tag the editor saves is previewed and passed', (
    tester,
  ) async {
    await boot(tester);
    await open(tester);
    await tester.enterText(
      find.byType(TextField),
      'Pay bills tomorrow #home #money',
    );
    await settle(tester);
    expect(
      find.bySemanticsLabel('Will create: Task · Tomorrow · #home'),
      findsOneWidget,
    );
    expect(find.text('#money'), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    final uri = Uri.parse(location());
    expect(uri.path, AppRoutes.newTaskPath);
    expect(uri.queryParameters['tag'], 'home');
  });

  testWidgets('Quick Scan: a missing camera plugin shows a toast', (
    tester,
  ) async {
    await boot(tester);
    images.pickError = MissingPluginException('image_picker');
    await open(tester);
    await tester.tap(find.bySemanticsLabel('Scan text into a note'));
    await settle(tester);
    await tester.tap(find.text('Take photo'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text("Couldn't open the camera"), findsOneWidget);
    expect(location(), AppRoutes.home);
  });

  testWidgets('Quick Scan: an unexpected OCR error shows a toast', (
    tester,
  ) async {
    await boot(tester, ocrError: StateError('vision crashed'));
    await open(tester);
    await tester.tap(find.bySemanticsLabel('Scan text into a note'));
    await settle(tester);
    await tester.tap(find.text('Choose from library'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text("Couldn't read that photo"), findsOneWidget);
    expect(images.discarded, ['/tmp/scan.jpg']);
    expect(location(), AppRoutes.home);
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    await boot(tester);
    await open(tester, size: const Size(360, 800), textScale: 1.3);
    await tester.enterText(
      find.byType(TextField),
      'Review budget every monday 9am #finance !high',
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '04_quick_add_360_x13');
  });
}
