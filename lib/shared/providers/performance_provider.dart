/// ============================================================
/// PERFORMANCE PROVIDERS — are visual effects reduced right now?
/// ============================================================
///
/// [devicePerformanceProvider] is the start-up device check (overridden by
/// bootstrap; "capable" when not). [reducedEffectsProvider] combines it with
/// Settings › Appearance › Visual effects: Automatic follows the device,
/// Full and Reduced force it. app.dart hands the result to the design system
/// (core/widgets/ff_effects.dart).
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/performance/device_performance.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

final devicePerformanceProvider = Provider<DevicePerformance>(
  (ref) => const DevicePerformance(),
);

/// Whether the costly effects (tab-bar blur, card → page transition,
/// shimmer) are drawn in their cheap form.
final reducedEffectsProvider = Provider<bool>((ref) {
  final mode = ref.watch(settingsProvider.select((s) => s.performanceMode));
  return switch (mode) {
    PerformanceMode.full => false,
    PerformanceMode.reduced => true,
    PerformanceMode.auto => ref.watch(devicePerformanceProvider).lowEnd,
  };
});
