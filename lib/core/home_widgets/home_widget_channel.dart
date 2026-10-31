/// ============================================================
/// HOME WIDGET CHANNEL — the Dart side of the Android widget bridge
/// ============================================================
///
/// Channel `focusflow/home_widgets` (android/.../widget/HomeWidgetBridge.kt):
///   push(json)        stores the snapshot natively and redraws every widget
///   requestPin(kind)  asks the launcher to add a widget (Android 8+); false
///                     when the launcher cannot / the user declined
///   counts()          how many widgets of each kind are on the home screen
/// Android only; everywhere else (iOS, tests, desktop) every call is a no-op
/// — the app never depends on the answer.
/// No plugin: a few lines of channel code beat a dependency (rule: only the
/// network packages the app already has).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HomeWidgetChannel {
  const HomeWidgetChannel([this._channel = const MethodChannel(channelName)]);

  static const String channelName = 'focusflow/home_widgets';

  final MethodChannel _channel;

  /// Whether this platform has widgets we can feed.
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Hands [json] (a widget snapshot) to the widgets. True when delivered.
  Future<bool> push(String json) async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('push', json) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Shows the launcher's "add widget" prompt for [kind].
  Future<bool> requestPin(String kind) async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPin', kind) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Widgets on the home screen per kind (empty when unknown).
  Future<Map<String, int>> counts() async {
    if (!supported) return const {};
    try {
      final raw = await _channel.invokeMapMethod<String, int>('counts');
      return raw ?? const {};
    } on MissingPluginException {
      return const {};
    } on PlatformException {
      return const {};
    }
  }
}
