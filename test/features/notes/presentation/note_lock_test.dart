/// Notes with their own PIN: the verifier service (never the PIN, a salt per
/// note, constant-time compare), the wrong-PIN back-off, and the flows in the
/// editor — the padlock in the top bar sets + confirms a PIN, a locked note
/// asks for exactly that PIN, a mismatch starts over, Change / Remove need
/// the PIN, and a note locked the old way keeps asking for the Vault PIN.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/crypto/pin_kdf.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/notes/domain/services/note_pin.dart';
import 'package:focusflow/features/notes/presentation/providers/note_lock_providers.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../notes_fixtures.dart';

/// Cheap Argon2 (64 KiB · 1 pass) on the test isolate.
const _cheap = NotePinService(
  kdf: Argon2PinKdf(useIsolate: false),
  params: KdfParams.testing,
);

void main() {
  group('NotePinService', () {
    test('a verifier checks only its own PIN and never contains it', () async {
      final v = await _cheap.createVerifier('4821');
      expect(v, startsWith('v1:'));
      expect(v, isNot(contains('4821')));
      expect(await _cheap.verify('4821', v), isTrue);
      expect(await _cheap.verify('4822', v), isFalse);
      expect(await _cheap.verify('482', v), isFalse);
      expect(await _cheap.verify('abcd', v), isFalse);
    });

    test(
      'every note gets its own salt: same PIN, different verifier',
      () async {
        final a = await _cheap.createVerifier('1234');
        final b = await _cheap.createVerifier('1234');
        expect(a, isNot(b));
        // …and one note's verifier says nothing about another's PIN.
        final other = await _cheap.createVerifier('9999');
        expect(await _cheap.verify('1234', other), isFalse);
      },
    );

    test('the cost travels with the verifier', () async {
      // A verifier made with other parameters still verifies with a service
      // configured differently (parameters are read from the string).
      final v = await _cheap.createVerifier('246810'.substring(0, 6));
      const heavier = NotePinService(
        kdf: Argon2PinKdf(useIsolate: false),
        params: KdfParams(memoryKiB: 128, iterations: 2),
      );
      expect(await heavier.verify('246810', v), isTrue);
    });

    test('malformed verifiers and PINs never match', () async {
      for (final bad in ['', 'v1', 'v2:64:1:AA==:AA==', 'v1:x:1:AA==:AA==']) {
        expect(await _cheap.verify('1234', bad), isFalse, reason: bad);
      }
      expect(() => _cheap.createVerifier('12'), throwsArgumentError);
      expect(() => _cheap.createVerifier('1234567'), throwsArgumentError);
      expect(NotePinService.isValidPin('0000'), isTrue);
      expect(NotePinService.isValidPin('12a4'), isFalse);
    });

    test('back-off: three free tries, then 30 s doubling, capped', () {
      expect(NotePinBackoff.delayFor(2), isNull);
      expect(NotePinBackoff.delayFor(3), const Duration(seconds: 30));
      expect(NotePinBackoff.delayFor(4), const Duration(minutes: 1));
      expect(NotePinBackoff.delayFor(5), const Duration(minutes: 2));
      expect(NotePinBackoff.delayFor(40), NotePinBackoff.max);
    });
  });

  group('in the editor', () {
    late Directory docs;

    setUp(() => docs = Directory.systemTemp.createTempSync('ff_lock'));
    tearDown(() {
      if (docs.existsSync()) docs.deleteSync(recursive: true);
    });

    Future<TestHarness> boot(WidgetTester tester) async {
      await loadAppFonts();
      final h = (await tester.runAsync(
        () => TestHarness.create(
          now: kNotesNow,
          overrides: [
            ...notesOverrides(docs),
            notePinServiceProvider.overrideWithValue(_cheap),
          ],
        ),
      ))!;
      addTearDown(() => tester.runAsync(h.dispose));
      return h;
    }

    Future<void> pin(WidgetTester tester, String digits) async {
      for (final d in digits.split('')) {
        await tester.tap(find.bySemanticsLabel(d).first);
        await tester.pump();
      }
    }

    Future<void> confirm(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Submit PIN').first);
      await settle(tester);
    }

    Future<(bool, String?)> state(
      WidgetTester tester,
      TestHarness h,
      String id,
    ) async {
      final repo = h.read(notesRepositoryProvider);
      final note = await tester.runAsync(() => repo.getNote(id));
      final verifier = await tester.runAsync(() => repo.lockVerifier(id));
      return (note!.isLocked, verifier);
    }

    testWidgets('the top-bar padlock locks the note with a PIN chosen twice', (
      tester,
    ) async {
      final h = await boot(tester);
      final id = (await tester.runAsync(() => seedMockupNote(h)))!;
      await pumpApp(tester, h, AppRoutes.note(id));

      await tester.tap(find.bySemanticsLabel('Lock note with a PIN'));
      await settle(tester);
      expect(find.text('Set a PIN for this note'), findsOneWidget);
      await pin(tester, '12');
      await captureScreen(tester, '08_note_pin_sheet');
      await tester.tap(find.bySemanticsLabel('Delete last digit').first);
      await tester.tap(find.bySemanticsLabel('Delete last digit').first);
      await tester.pump();

      // A PIN needs at least four digits before ✓ works.
      await pin(tester, '12');
      await confirm(tester);
      expect(find.text('Set a PIN for this note'), findsOneWidget);

      await pin(tester, '34');
      await confirm(tester);
      expect(find.text('Confirm PIN'), findsOneWidget);

      // A different second PIN starts over.
      await pin(tester, '1235');
      await confirm(tester);
      expect(find.text('Set a PIN for this note'), findsOneWidget);
      expect(find.textContaining("PINs don't match"), findsOneWidget);

      await pin(tester, '1234');
      await confirm(tester);
      await pin(tester, '1234');
      await confirm(tester);

      final (locked, verifier) = await state(tester, h, id);
      expect(locked, isTrue);
      expect(verifier, isNotNull);
      expect(verifier, isNot(contains('1234')));
      expect(find.text('Note locked with its own PIN'), findsOneWidget);
      // Locked from the editor: it stays open for this session.
      expect(find.text('Mobile App Design Trends 2024'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Note is locked. Change or remove the PIN'),
        findsOneWidget,
      );
    });

    testWidgets('a locked note opens only with its own PIN', (tester) async {
      final h = await boot(tester);
      final (a, b) = (await tester.runAsync(() async {
        final a = await seedMockupNote(h);
        final b = await h
            .read(notesRepositoryProvider)
            .createEmpty(title: 'Second note');
        final repo = h.read(notesRepositoryProvider);
        await repo.lockWithPin(a, await _cheap.createVerifier('1111'));
        await repo.lockWithPin(b, await _cheap.createVerifier('2222'));
        return (a, b);
      }))!;

      await pumpApp(tester, h, AppRoutes.note(a));
      await settle(tester);
      expect(find.text('Enter PIN'), findsOneWidget);
      expect(find.text('Mobile App Design Trends 2024'), findsNothing);

      // The other note's PIN does not open this one.
      await pin(tester, '2222');
      await confirm(tester);
      expect(find.text('Wrong PIN'), findsOneWidget);
      expect(find.text('Mobile App Design Trends 2024'), findsNothing);

      await pin(tester, '1111');
      await confirm(tester);
      expect(find.text('Mobile App Design Trends 2024'), findsOneWidget);

      // …and note b still asks for its own.
      h.read(routerProvider).go(AppRoutes.home);
      await settle(tester);
      unawaited(h.read(routerProvider).push<void>(AppRoutes.note(b)));
      await settle(tester);
      await settle(tester);
      expect(find.text('Enter PIN'), findsOneWidget);
      await pin(tester, '1111');
      await confirm(tester);
      expect(find.text('Wrong PIN'), findsOneWidget);
    });

    testWidgets('three wrong PINs lock the pad for a while', (tester) async {
      final h = await boot(tester);
      final id = (await tester.runAsync(() async {
        final id = await seedMockupNote(h);
        await h
            .read(notesRepositoryProvider)
            .lockWithPin(id, await _cheap.createVerifier('1111'));
        return id;
      }))!;
      await pumpApp(tester, h, AppRoutes.note(id));
      await settle(tester);
      for (var i = 0; i < 3; i++) {
        await pin(tester, '9999');
        await confirm(tester);
      }
      expect(find.textContaining('Try again in'), findsOneWidget);
      // Even the right PIN is refused while locked out.
      await pin(tester, '1111');
      expect(find.text('Mobile App Design Trends 2024'), findsNothing);
      expect(
        h.container
            .read(notePinAttemptsProvider.notifier)
            .remaining(id, h.clock.now()),
        greaterThan(Duration.zero),
      );
    });

    testWidgets('Change and Remove ask for the PIN first', (tester) async {
      final h = await boot(tester);
      final id = (await tester.runAsync(() async {
        final id = await seedMockupNote(h);
        await h
            .read(notesRepositoryProvider)
            .lockWithPin(id, await _cheap.createVerifier('1111'));
        return id;
      }))!;
      await pumpApp(tester, h, AppRoutes.note(id));
      await settle(tester);
      await pin(tester, '1111');
      await confirm(tester);

      await tester.tap(
        find.bySemanticsLabel('Note is locked. Change or remove the PIN'),
      );
      await settle(tester);
      await tester.tap(find.text('Remove note lock'));
      await settle(tester);
      expect(find.text('Enter PIN to remove the lock'), findsOneWidget);
      await pin(tester, '1111');
      await confirm(tester);

      final (locked, verifier) = await state(tester, h, id);
      expect(locked, isFalse);
      expect(verifier, isNull);
      expect(find.text('Note lock removed'), findsOneWidget);
      expect(find.bySemanticsLabel('Lock note with a PIN'), findsOneWidget);
    });

    testWidgets('a note locked the old way still asks for the Vault PIN', (
      tester,
    ) async {
      final h = await boot(tester);
      final id = (await tester.runAsync(
        () => seedMockupNote(h, locked: true),
      ))!;
      await pumpApp(tester, h, AppRoutes.note(id));
      expect(find.text('This note is locked'), findsOneWidget);
      final (locked, verifier) = await state(tester, h, id);
      expect((locked, verifier), (true, null));
      await tester.pump(VaultSessionController.loadTimeout);
    });
  });
}
