/// Lock-screen access (Xiaomi "Show on lock screen" / background pop-up,
/// blocked channels): read through a port, fixed by opening the system page,
/// re-read afterwards; failures never throw into the UI.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/notifications/lock_screen_access.dart';

class _Fake implements LockScreenAccessSource {
  LockScreenAccess value = const LockScreenAccess(
    xiaomi: true,
    showOnLockScreen: false,
  );
  final opened = <String?>[];

  @override
  Future<LockScreenAccess> read() async => value;

  @override
  Future<void> openSettings({String? channelId}) async => opened.add(channelId);
}

class _Broken implements LockScreenAccessSource {
  @override
  Future<LockScreenAccess> read() => throw StateError('no native side');

  @override
  Future<void> openSettings({String? channelId}) =>
      throw StateError('no settings page');
}

void main() {
  ProviderContainer make(LockScreenAccessSource source) {
    final c = ProviderContainer(
      overrides: [lockScreenAccessSourceProvider.overrideWithValue(source)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('flags: known-off needs attention, unknown only in Settings', () {
    const off = LockScreenAccess(xiaomi: true, backgroundPopup: false);
    expect(off.makerSwitchOff, isTrue);
    expect(off.needsAttention, isTrue);

    const unknown = LockScreenAccess(xiaomi: true, showOnLockScreen: null);
    expect(unknown.makerSwitchOff, isFalse);
    expect(unknown.makerSwitchUnknown, isTrue);
    expect(unknown.needsAttention, isFalse);

    const blocked = LockScreenAccess(blockedChannels: ['alarms_v2']);
    expect(blocked.needsAttention, isTrue);
    expect(blocked.makerSwitchOff, isFalse);

    expect(LockScreenAccess.fine.needsAttention, isFalse);
    // The Xiaomi switches mean nothing on another phone.
    expect(
      const LockScreenAccess(showOnLockScreen: false).makerSwitchOff,
      isFalse,
    );
  });

  test('reports the state and re-reads it after the request', () async {
    final fake = _Fake();
    final c = make(fake);
    expect(
      (await c.read(lockScreenAccessProvider.future)).makerSwitchOff,
      true,
    );

    await c.read(lockScreenSettingsRequestProvider)(channelId: 'alarms_v2');
    expect(fake.opened, ['alarms_v2']);

    fake.value = LockScreenAccess.fine; // the user fixed it on the page
    expect(
      (await c.read(lockScreenAccessProvider.future)).needsAttention,
      isFalse,
    );
  });

  test('a missing native side counts as fine (no banner)', () async {
    final c = make(_Broken());
    expect(
      (await c.read(lockScreenAccessProvider.future)).needsAttention,
      isFalse,
    );
    await c.read(lockScreenSettingsRequestProvider)(); // must not throw
  });

  test('with no MainActivity behind the channel it is fine', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(
      (await c.read(lockScreenAccessProvider.future)).needsAttention,
      isFalse,
    );
  });
}
