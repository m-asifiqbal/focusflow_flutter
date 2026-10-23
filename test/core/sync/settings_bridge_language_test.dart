/// Restoring settings that change the language loads that language's pack
/// first (like Settings › Language): the app must not switch locale / text
/// direction while every text stays in the old pack.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/l10n/app_language.dart';
import 'package:focusflow/core/l10n/l10n.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/settings/backup_settings.dart';
import 'package:focusflow/core/sync/settings_bridge.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../helpers/test_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(L10n.reset);

  test('a restored language is activated, not only stored', () async {
    final h = await TestHarness.create(now: DateTime(2026, 10, 23, 9));
    addTearDown(h.dispose);
    expect(L10n.language, AppLanguage.en);

    final backup = BackupSettings.of(
      const AppSettings(languageCode: 'de', enabledLanguages: ['de']),
    );
    await h.read(settingsBackupBridgeProvider).apply(backup, replace: true);

    expect(h.read(settingsProvider).languageCode, 'de');
    expect(L10n.language, AppLanguage.de);
  });

  test('a backup in the same language changes nothing', () async {
    final h = await TestHarness.create(now: DateTime(2026, 10, 23, 9));
    addTearDown(h.dispose);
    await h
        .read(settingsBackupBridgeProvider)
        .apply(BackupSettings.of(const AppSettings()), replace: true);
    expect(L10n.language, AppLanguage.en);
  });
}
