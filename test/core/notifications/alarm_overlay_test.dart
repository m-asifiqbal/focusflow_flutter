/// "Display over other apps" for the alarm screen: read through a port, asked
/// by opening the system page, re-read afterwards; failures never throw into
/// the UI.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/notifications/alarm_overlay.dart';

class _FakeOverlay implements AlarmOverlay {
  bool allowed = false;
  int requests = 0;

  @override
  Future<bool> isAllowed() async => allowed;

  @override
  Future<void> request() async => requests++;
}

class _Broken implements AlarmOverlay {
  @override
  Future<bool> isAllowed() => throw StateError('no native side');

  @override
  Future<void> request() => throw StateError('no settings page');
}

void main() {
  ProviderContainer make(AlarmOverlay overlay) {
    final c = ProviderContainer(
      overrides: [alarmOverlayProvider.overrideWithValue(overlay)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('reports the permission and re-reads it after the request', () async {
    final fake = _FakeOverlay();
    final c = make(fake);
    expect(await c.read(alarmOverAppsAllowedProvider.future), isFalse);

    await c.read(alarmOverAppsRequestProvider)();
    expect(fake.requests, 1);

    fake.allowed = true; // the user flipped it on the system page
    expect(await c.read(alarmOverAppsAllowedProvider.future), isTrue);
  });

  test('a missing native side counts as allowed (no banner)', () async {
    final c = make(_Broken());
    expect(await c.read(alarmOverAppsAllowedProvider.future), isTrue);
    await c.read(alarmOverAppsRequestProvider)(); // must not throw
  });

  test('off Android there is nothing to ask', () async {
    // flutter_test reports Android, but with no MainActivity behind the
    // channel the platform implementation falls back to "allowed".
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await c.read(alarmOverAppsAllowedProvider.future), isTrue);
  });
}
