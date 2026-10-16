/// ============================================================
/// QUICK ADD PROVIDERS — parser, capture inputs and the sheet controller
/// ============================================================
///
/// What: [quickCaptureParserProvider] (honours the week-start setting),
/// the mic / scan adapters, and [quickAddControllerProvider] — the sheet's
/// draft text + dictation state — with [quickCapturePreviewProvider]
/// deriving the parsed preview from it.
/// Why: keeps parsing and plugin calls out of the widgets; tests override
/// [speechCaptureProvider] / [scanImageSourceProvider].
/// ============================================================
library;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/features/quick_add/data/datasource/plugin_capture_inputs.dart';
import 'package:focusflow/features/quick_add/domain/entities/quick_capture.dart';
import 'package:focusflow/features/quick_add/domain/services/capture_inputs.dart';
import 'package:focusflow/features/quick_add/domain/services/quick_capture_parser.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

final quickCaptureParserProvider = Provider<QuickCaptureParser>(
  (ref) => QuickCaptureParser(
    weekStartsOn: ref.watch(settingsProvider.select((s) => s.weekStartsOn)),
  ),
);

final speechCaptureProvider = Provider<SpeechCapture>(
  (ref) => SpeechToTextCapture(),
);

final scanImageSourceProvider = Provider<ScanImageSource>(
  (ref) => ImagePickerScanSource(),
);

/// How the sheet was opened: pre-filled text and / or a pre-selected day.
@immutable
class QuickAddArgs {
  const QuickAddArgs({this.text, this.date});

  final String? text;
  final DateTime? date;

  @override
  bool operator ==(Object other) =>
      other is QuickAddArgs && other.text == text && other.date == date;

  @override
  int get hashCode => Object.hash(text, date);
}

@immutable
class QuickAddState {
  const QuickAddState({this.text = '', this.listening = false});

  /// The capture field's text.
  final String text;

  /// Dictation in progress (pulsing mic).
  final bool listening;

  QuickAddState copyWith({String? text, bool? listening}) => QuickAddState(
    text: text ?? this.text,
    listening: listening ?? this.listening,
  );
}

/// Draft text and dictation for one open sheet.
///
/// Closing the sheet disposes this controller. Starting the mic awaits the
/// plugin (permission prompt, engine start-up), so the sheet can close
/// mid-start: the controller then cancels the session as soon as it is
/// running and ignores every late callback — the mic never keeps
/// listening behind a closed sheet.
class QuickAddController
    extends AutoDisposeFamilyNotifier<QuickAddState, QuickAddArgs> {
  String _base = '';
  bool _disposed = false;
  late SpeechCapture _speech;

  @override
  QuickAddState build(QuickAddArgs arg) {
    _disposed = false;
    _speech = ref.read(speechCaptureProvider);
    ref.onDispose(() {
      _disposed = true;
      // Covers a session that is running *and* one still starting.
      if (state.listening) _speech.cancel();
    });
    return QuickAddState(text: arg.text ?? '');
  }

  void setText(String text) {
    if (_disposed) return;
    if (text != state.text) state = state.copyWith(text: text);
  }

  /// Starts dictation (appending to the current text) or stops it.
  /// Returns false when the mic could not start (or the sheet closed
  /// while it was starting).
  Future<bool> toggleListening() async {
    final speech = _speech;
    if (state.listening) {
      await speech.stop();
      if (!_disposed) state = state.copyWith(listening: false);
      return true;
    }
    _base = state.text.trimRight();
    state = state.copyWith(listening: true);
    final ok = await speech.start(
      onWords: (words) {
        final w = words.trim();
        setText(_base.isEmpty || w.isEmpty ? '$_base$w' : '$_base $w');
      },
      onDone: () {
        if (!_disposed) state = state.copyWith(listening: false);
      },
    );
    if (_disposed) {
      // Closed while starting: the dispose-time cancel may have run before
      // the session existed, so stop the one that just started.
      if (ok) await speech.cancel();
      return false;
    }
    if (!ok) state = state.copyWith(listening: false);
    return ok;
  }
}

final quickAddControllerProvider = NotifierProvider.autoDispose
    .family<QuickAddController, QuickAddState, QuickAddArgs>(
      QuickAddController.new,
    );

/// The parsed draft, or null while the field is blank.
final quickCapturePreviewProvider = Provider.autoDispose
    .family<QuickCapture?, QuickAddArgs>((ref, args) {
      final text = ref.watch(
        quickAddControllerProvider(args).select((s) => s.text),
      );
      if (text.trim().isEmpty) return null;
      return ref
          .watch(quickCaptureParserProvider)
          .parse(text, ref.watch(clockProvider).now(), defaultDay: args.date);
    });
