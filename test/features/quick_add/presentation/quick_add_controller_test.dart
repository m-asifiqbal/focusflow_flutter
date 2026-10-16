/// Quick Add controller dictation lifecycle: closing the sheet while the
/// mic is still starting cancels the late session and ignores its
/// callbacks; a second tap during start-up stops it.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/quick_add/domain/services/capture_inputs.dart';
import 'package:focusflow/features/quick_add/presentation/providers/quick_add_providers.dart';

/// Mic whose start() resolves when the test completes [started].
class _SlowSpeech implements SpeechCapture {
  final started = Completer<bool>();
  void Function(String)? words;
  void Function()? done;
  int cancels = 0;
  int stops = 0;

  @override
  Future<bool> start({
    required void Function(String words) onWords,
    required void Function() onDone,
  }) {
    words = onWords;
    done = onDone;
    return started.future;
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> cancel() async => cancels++;
}

void main() {
  const args = QuickAddArgs();
  late _SlowSpeech speech;
  late ProviderContainer container;

  setUp(() {
    speech = _SlowSpeech();
    container = ProviderContainer(
      overrides: [speechCaptureProvider.overrideWithValue(speech)],
    );
    addTearDown(container.dispose);
  });

  test(
    'sheet closed while the mic starts: late session is cancelled',
    () async {
      final sub = container.listen(quickAddControllerProvider(args), (_, _) {});
      final result = container
          .read(quickAddControllerProvider(args).notifier)
          .toggleListening();
      expect(
        container.read(quickAddControllerProvider(args)).listening,
        isTrue,
      );

      sub.close(); // the sheet closes
      await container.pump(); // autoDispose runs
      expect(speech.cancels, 1);

      speech.started.complete(true); // permission granted, engine running
      expect(await result, isFalse);
      expect(speech.cancels, 2);

      // Late callbacks from the plugin are ignored (no disposed-state error).
      speech.words!('too late');
      speech.done!();
    },
  );

  test('tapping the mic again during start-up stops it', () async {
    final sub = container.listen(quickAddControllerProvider(args), (_, _) {});
    addTearDown(sub.close);
    final notifier = container.read(quickAddControllerProvider(args).notifier);
    final first = notifier.toggleListening();
    await notifier.toggleListening();
    expect(speech.stops, 1);
    expect(container.read(quickAddControllerProvider(args)).listening, isFalse);
    speech.started.complete(false); // the aborted start reports false
    expect(await first, isFalse);
    expect(container.read(quickAddControllerProvider(args)).listening, isFalse);
  });

  test('dictated words append to the existing text', () async {
    final sub = container.listen(quickAddControllerProvider(args), (_, _) {});
    addTearDown(sub.close);
    final notifier = container.read(quickAddControllerProvider(args).notifier)
      ..setText('Buy milk ');
    final f = notifier.toggleListening();
    speech.started.complete(true);
    expect(await f, isTrue);
    speech.words!('tomorrow 9am');
    expect(
      container.read(quickAddControllerProvider(args)).text,
      'Buy milk tomorrow 9am',
    );
  });
}
