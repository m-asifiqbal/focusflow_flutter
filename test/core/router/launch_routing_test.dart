/// Launch routing: the first screen follows onboarding + Settings ›
/// Start screen, and the redirect keeps first-launch users in onboarding.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';

void main() {
  group('startLocation', () {
    test('onboarding until it has been seen, whatever the start screen', () {
      for (final screen in StartScreen.values) {
        expect(
          startLocation(const AppSettings().copyWith(startScreen: screen)),
          AppRoutes.onboarding,
        );
      }
    });

    test('then the chosen start screen', () {
      final seen = const AppSettings().copyWith(onboardingSeen: true);
      expect(startLocation(seen), AppRoutes.home);
      expect(
        startLocation(seen.copyWith(startScreen: StartScreen.library)),
        AppRoutes.library,
      );
      expect(
        startLocation(seen.copyWith(startScreen: StartScreen.insights)),
        AppRoutes.insights,
      );
    });
  });

  group('launchRedirect', () {
    test('first launch: any app route goes to onboarding', () {
      for (final loc in [
        AppRoutes.home,
        AppRoutes.library,
        AppRoutes.settings,
        AppRoutes.insights,
      ]) {
        expect(
          launchRedirect(location: loc, onboardingSeen: false),
          AppRoutes.onboarding,
          reason: loc,
        );
      }
    });

    test('first launch: onboarding and sign-in are allowed', () {
      expect(
        launchRedirect(location: AppRoutes.onboarding, onboardingSeen: false),
        isNull,
      );
      expect(
        launchRedirect(location: AppRoutes.signIn, onboardingSeen: false),
        isNull,
      );
    });

    test('after onboarding nothing is redirected', () {
      for (final loc in [
        AppRoutes.home,
        AppRoutes.onboarding,
        AppRoutes.signIn,
        AppRoutes.settings,
      ]) {
        expect(launchRedirect(location: loc, onboardingSeen: true), isNull);
      }
    });
  });
}
