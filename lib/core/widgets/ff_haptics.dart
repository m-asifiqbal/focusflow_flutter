/// ============================================================
/// FF HAPTICS — app-wide "haptics on/off" for the design system
/// ============================================================
///
/// What: an inherited [FFHaptics] scope carrying Settings › Sounds &
/// haptics › Haptics, plus `FFHaptics.light/selection/medium(context)`
/// helpers that fire only when it is enabled.
/// Why: core widgets (FFCheckCircle, FFSwipeActions…) must not depend on
/// Riverpod or the settings model. app.dart provides the scope from the
/// live settings; without a scope (widget tests, previews) haptics stay
/// enabled, matching the default setting.
///
/// ```dart
/// FFHaptics.light(context); // instead of HapticFeedback.lightImpact()
/// ```
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class FFHaptics extends InheritedWidget {
  const FFHaptics({required this.enabled, required super.child, super.key});

  /// False when the user turned haptics off.
  final bool enabled;

  /// Whether haptics may fire under [context] (true without a scope).
  /// Read at event time, so it doesn't register a rebuild dependency.
  static bool enabledOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FFHaptics>()?.enabled ?? true;

  /// Light tap (completing a checkbox, running a swipe action).
  static void light(BuildContext context) =>
      _fire(context, HapticFeedback.lightImpact);

  /// Selection tick (crossing a threshold, unchecking).
  static void selection(BuildContext context) =>
      _fire(context, HapticFeedback.selectionClick);

  /// Medium thump (full-swipe armed).
  static void medium(BuildContext context) =>
      _fire(context, HapticFeedback.mediumImpact);

  static void _fire(BuildContext context, Future<void> Function() feedback) {
    if (enabledOf(context)) unawaited(feedback());
  }

  @override
  bool updateShouldNotify(FFHaptics oldWidget) => enabled != oldWidget.enabled;
}
