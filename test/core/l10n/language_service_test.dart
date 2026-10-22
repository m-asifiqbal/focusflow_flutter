/// Adding, selecting and removing languages: packs are read only when used,
/// only added languages can be selected, the saved language survives a restart
/// (and falls back to English when its pack is gone), and the translator
/// follows the switch.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/l10n/app_language.dart';
import 'package:focusflow/core/l10n/language_service.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);
  final Map<String, String> files;
  final loaded = <String>[];

  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    if (text == null) throw FlutterError('Unable to load asset: $key');
    loaded.add(key);
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Bundle bundle;
  late ProviderContainer container;
  late LanguageController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    bundle = _Bundle({
      'assets/l10n/de.json': jsonEncode({'Archive': 'Archiv'}),
      'assets/l10n/ar.json': jsonEncode({'Archive': 'الأرشيف'}),
    });
    final provider = Provider((ref) => LanguageController(ref, bundle: bundle));
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    controller = container.read(provider);
    L10n.reset();
  });

  tearDown(() {
    container.dispose();
    L10n.reset();
  });

  test('English is the default and reads no pack', () {
    expect(controller.available, [AppLanguage.en]);
    expect(L10n.language, AppLanguage.en);
    expect(bundle.loaded, isEmpty);
  });

  test('a language that was not added cannot be selected', () async {
    await controller.select(AppLanguage.de);
    expect(L10n.language, AppLanguage.en);
    expect(container.read(settingsProvider).languageCode, 'en');
    expect(bundle.loaded, isEmpty);
  });

  test(
    'add checks the pack, select switches the translator and the setting',
    () async {
      expect(await controller.add(AppLanguage.de), isTrue);
      expect(container.read(settingsProvider).enabledLanguages, ['de']);
      expect(controller.available, [AppLanguage.en, AppLanguage.de]);
      expect(L10n.language, AppLanguage.en, reason: 'adding does not switch');

      await controller.select(AppLanguage.de);
      expect(L10n.language, AppLanguage.de);
      expect(tr('Archive'), 'Archiv');
      expect(container.read(settingsProvider).languageCode, 'de');

      await controller.select(AppLanguage.en);
      expect(tr('Archive'), 'Archive');
    },
  );

  test('a missing or broken pack is not added', () async {
    expect(await controller.add(AppLanguage.zh), isFalse);
    expect(container.read(settingsProvider).enabledLanguages, isEmpty);

    bundle.files['assets/l10n/hi.json'] = '{ not json';
    expect(await controller.add(AppLanguage.hi), isFalse);
    expect(container.read(settingsProvider).enabledLanguages, isEmpty);
  });

  test('removing the language in use falls back to English', () async {
    await controller.add(AppLanguage.de);
    await controller.add(AppLanguage.ar);
    await controller.select(AppLanguage.de);

    await controller.remove(AppLanguage.de);
    expect(L10n.language, AppLanguage.en);
    expect(tr('Archive'), 'Archive');
    final s = container.read(settingsProvider);
    expect(s.languageCode, 'en');
    expect(s.enabledLanguages, ['ar']);
  });

  test('removing another language keeps the one in use', () async {
    await controller.add(AppLanguage.de);
    await controller.add(AppLanguage.ar);
    await controller.select(AppLanguage.ar);
    await controller.remove(AppLanguage.de);
    expect(L10n.language, AppLanguage.ar);
    expect(container.read(settingsProvider).enabledLanguages, ['ar']);
  });

  test(
    'the saved language is restored at start, English when it was removed',
    () async {
      await controller.add(AppLanguage.de);
      await controller.select(AppLanguage.de);
      final prefs = await SharedPreferences.getInstance();

      L10n.reset();
      await activateLanguage(
        storedLanguage(container.read(settingsProvider)),
        bundle: bundle,
      );
      expect(tr('Archive'), 'Archiv');

      // A setting that names a language that is no longer added.
      final s = container
          .read(settingsProvider)
          .copyWith(enabledLanguages: const []);
      expect(storedLanguage(s), AppLanguage.en);
      expect(
        prefs.getString(SettingsController.prefsKey),
        contains('"languageCode":"de"'),
      );
    },
  );

  test('an unreadable pack at start leaves the app in English', () async {
    final active = await activateLanguage(AppLanguage.zh, bundle: bundle);
    expect(active, AppLanguage.en);
    expect(L10n.language, AppLanguage.en);
  });
}
