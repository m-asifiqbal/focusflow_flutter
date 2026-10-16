/// speech_to_text adapter: a start() that is cancelled (or stopped) while
/// the plugin is still initialising never begins listening, and a session
/// cancelled during listen() start-up is torn down again.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/quick_add/data/datasource/plugin_capture_inputs.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// The plugin, scripted: [init] / [listening] complete when the test says.
class _FakeStt implements SpeechToText {
  Completer<bool> init = Completer<bool>();
  Completer<void>? listening;
  int listens = 0;
  void Function(SpeechRecognitionResult)? onResult;
  int cancels = 0;
  int stops = 0;

  @override
  dynamic noSuchMethod(Invocation i) {
    switch (i.memberName) {
      case #initialize:
        return init.future;
      case #listen:
        listens++;
        onResult =
            i.namedArguments[#onResult]
                as void Function(SpeechRecognitionResult)?;
        return listening?.future ?? Future<void>.value();
      case #cancel:
        cancels++;
        return Future<void>.value();
      case #stop:
        stops++;
        return Future<void>.value();
    }
    return super.noSuchMethod(i);
  }
}

void main() {
  late _FakeStt stt;
  late SpeechToTextCapture capture;

  setUp(() {
    stt = _FakeStt();
    capture = SpeechToTextCapture(stt);
  });

  Future<bool> start() => capture.start(onWords: (_) {}, onDone: () {});

  test('starts listening normally', () async {
    final f = start();
    stt.init.complete(true);
    expect(await f, isTrue);
    expect(stt.listens, 1);
  });

  test('cancel during initialise: never listens', () async {
    final f = start();
    await capture.cancel();
    stt.init.complete(true);
    expect(await f, isFalse);
    expect(stt.listens, 0);
  });

  test('stop during initialise aborts the start', () async {
    final f = start();
    await capture.stop();
    stt.init.complete(true);
    expect(await f, isFalse);
    expect(stt.listens, 0);
  });

  test(
    'cancel while listen() starts up: the late session is cancelled',
    () async {
      stt.listening = Completer<void>();
      final f = start();
      stt.init.complete(true);
      await pumpEventQueue();
      expect(stt.listens, 1);
      await capture.cancel();
      stt.listening!.complete();
      expect(await f, isFalse);
      expect(stt.cancels, 2);
    },
  );

  test(
    'a running session stops normally (final words still delivered)',
    () async {
      final words = <String>[];
      stt.init.complete(true);
      expect(await capture.start(onWords: words.add, onDone: () {}), isTrue);
      await capture.stop();
      expect(stt.stops, 1);
      // The engine delivers the final result after stop().
      stt.onResult!(
        SpeechRecognitionResult([
          SpeechRecognitionWords('call mom', null, 1),
        ], 1),
      );
      expect(words, ['call mom']);
    },
  );
}
