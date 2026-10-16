/// ============================================================
/// ONBOARDING CONTROLLER — page index + "seen" flag (screen 01)
/// ============================================================
///
/// State = the visible page (0..[pageCount]-1). [finish] persists
/// `onboardingSeen` so the intro never shows again (the router's launch
/// redirect reads the same flag).
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class OnboardingController extends AutoDisposeNotifier<int> {
  static const int pageCount = 3;

  @override
  int build() => 0;

  void setPage(int page) => state = page.clamp(0, pageCount - 1);

  bool get isLast => state == pageCount - 1;

  /// Marks onboarding as seen (Skip, Continue, Restore).
  Future<void> finish() => ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(onboardingSeen: true));
}

final onboardingControllerProvider =
    NotifierProvider.autoDispose<OnboardingController, int>(
      OnboardingController.new,
    );
