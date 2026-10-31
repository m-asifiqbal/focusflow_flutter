/// ============================================================
/// SHARE INTAKE — text and links shared into the app from other apps
/// ============================================================
///
/// What: the tiny platform channel `focusflow/share`. Android's share sheet
/// reaches `ShareTargetActivity`, which forwards the shared text (and the
/// subject, e.g. a page title) to MainActivity; MainActivity parks it until
/// [ShareIntake.initial] asks and pushes later ones as `onShare`.
/// Why: a channel instead of a sharing plugin — no new dependency, and the
/// same shape as the launcher shortcuts (core/platform/launcher_shortcuts.dart).
/// iOS has no share extension yet: there the channel is missing and nothing
/// arrives.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One share: what the other app put in EXTRA_TEXT / EXTRA_SUBJECT.
@immutable
class SharedText {
  const SharedText({required this.text, this.subject = ''});

  final String text;
  final String subject;

  static SharedText? fromChannel(Object? raw) {
    if (raw is! Map) return null;
    final text = raw['text'];
    final subject = raw['subject'];
    final s = SharedText(
      text: text is String ? text : '',
      subject: subject is String ? subject : '',
    );
    return s.text.trim().isEmpty && s.subject.trim().isEmpty ? null : s;
  }
}

class ShareIntake {
  const ShareIntake([this._channel = const MethodChannel(channelName)]);

  static const String channelName = 'focusflow/share';

  final MethodChannel _channel;

  /// Shares that arrived before Dart was listening (the one that started the
  /// app, usually); returned once.
  Future<List<SharedText>> initial() async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('getInitial');
      return [
        for (final r in raw ?? const <Object?>[]) ?SharedText.fromChannel(r),
      ];
    } on MissingPluginException {
      return const []; // iOS, tests, desktop
    } on PlatformException {
      return const [];
    }
  }

  /// Calls [onShare] for every share that arrives while the app runs.
  void listen(void Function(SharedText share) onShare) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onShare') return;
      final s = SharedText.fromChannel(call.arguments);
      if (s != null) onShare(s);
    });
  }

  void stopListening() => _channel.setMethodCallHandler(null);
}

final shareIntakeProvider = Provider<ShareIntake>((ref) => const ShareIntake());
