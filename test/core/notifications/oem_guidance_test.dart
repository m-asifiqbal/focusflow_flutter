/// "On Xiaomi phones, allow auto-start": which makers get the hint, that it
/// is offered once in the editor (always in Settings), and that opening the
/// page is remembered.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/notifications/background_delivery.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_gateway.dart';

void main() {
  late FakeOemBackgroundGuide guide;
  late ProviderContainer container;

  Future<void> boot({String? brand, bool opens = true}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    guide = FakeOemBackgroundGuide(brand: brand, opens: opens);
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        oemBackgroundGuideProvider.overrideWithValue(guide),
      ],
    );
    addTearDown(container.dispose);
    await container.read(aggressiveBrandProvider.future);
  }

  test('known aggressive makers are listed, stock Android is not', () {
    for (final m in ['xiaomi', 'oppo', 'vivo', 'huawei', 'samsung', 'realme']) {
      expect(aggressiveBackgroundMakers, contains(m));
    }
    expect(aggressiveBackgroundMakers, isNot(contains('google')));
    expect(aggressiveBackgroundMakers, isNot(contains('motorola')));
  });

  test('nothing to suggest on stock Android / iOS', () async {
    await boot();
    expect(container.read(aggressiveBrandProvider).valueOrNull, isNull);
    expect(container.read(suggestAutostartProvider), isFalse);
  });

  test('suggested once on an aggressive maker, until it was opened', () async {
    await boot(brand: 'Xiaomi');
    expect(container.read(suggestAutostartProvider), isTrue);

    expect(await container.read(autostartRequestProvider)(), isTrue);
    expect(guide.opened, 1);
    expect(container.read(suggestAutostartProvider), isFalse);
    // Settings keeps offering it: the brand is still known.
    expect(container.read(aggressiveBrandProvider).valueOrNull, 'Xiaomi');
  });

  test('a phone with no known screen still counts as asked', () async {
    await boot(brand: 'Vivo', opens: false);
    expect(await container.read(autostartRequestProvider)(), isFalse);
    expect(container.read(suggestAutostartProvider), isFalse);
  });

  test('a failing guide never throws into the UI', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        oemBackgroundGuideProvider.overrideWithValue(_Broken()),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(aggressiveBrandProvider.future), isNull);
    expect(await container.read(autostartRequestProvider)(), isFalse);
  });
}

class _Broken implements OemBackgroundGuide {
  @override
  Future<String?> aggressiveBrand() => throw StateError('no device info');

  @override
  Future<bool> openSettings() => throw StateError('no activity');
}
