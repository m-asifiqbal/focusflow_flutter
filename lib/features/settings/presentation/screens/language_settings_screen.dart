/// ============================================================
/// LANGUAGE SETTINGS — Settings › General › Language (`/settings/language`)
/// ============================================================
///
/// What: the languages FocusFlow speaks. English is always there; the others
/// (Bangla, Arabic, Chinese, Hindi, German, Spanish) are bundled packs that
/// stay unused until the user adds one here. Tapping a language switches the
/// whole app to it at once (adding it first when needed); "Remove" takes an
/// added language off the list again (the one in use falls back to English).
/// Why: the app is offline-first and a pack is a few dozen kilobytes of text,
/// so "adding" is instant and needs no network — see core/l10n/
/// language_service.dart. Names are shown in the language's own script so a
/// user who cannot read the current language can still find theirs.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/app_language.dart';
import 'package:focusflow/core/l10n/language_service.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/settings/presentation/settings_style.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_sections.dart';
import 'package:focusflow/features/settings/presentation/widgets/settings_page.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class LanguageSettingsScreen extends ConsumerStatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  ConsumerState<LanguageSettingsScreen> createState() =>
      _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState
    extends ConsumerState<LanguageSettingsScreen> {
  /// The language being added right now (its row says "Adding…").
  AppLanguage? _busy;

  Future<void> _choose(AppLanguage language, {required bool added}) async {
    if (_busy != null) return;
    final controller = ref.read(languageControllerProvider);
    if (!added) {
      setState(() => _busy = language);
      final ok = await controller.add(language);
      if (!mounted) return;
      setState(() => _busy = null);
      if (!ok) {
        showFFToast(
          context,
          tr("Couldn't add {language}", {'language': language.englishName}),
        );
        return;
      }
    }
    await controller.select(language);
  }

  Future<void> _remove(AppLanguage language) async {
    await ref.read(languageControllerProvider).remove(language);
    if (!mounted) return;
    showFFToast(
      context,
      tr('{language} removed', {'language': language.englishName}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final s = ref.watch(settingsProvider);
    final active = storedLanguage(s);
    return SettingsPage(
      title: tr('Language'),
      children: [
        FFGroupedList(
          footer: tr(
            'Add a language to use FocusFlow in it. It is stored on this phone and works offline. Translations are new: anything not translated yet shows in English.',
          ),
          children: [
            for (final language in AppLanguage.values)
              _row(
                context,
                ff,
                language,
                active,
                s.enabledLanguages.contains(language.code),
              ),
          ],
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    FFColors ff,
    AppLanguage language,
    AppLanguage active,
    bool added,
  ) {
    final isEnglish = language == AppLanguage.en;
    final selected = language == active;
    final available = isEnglish || added;
    final busy = _busy == language;
    final Widget? trailing;
    if (busy) {
      trailing = Text(tr('Adding…'), style: context.text.caption);
    } else if (selected) {
      trailing = Semantics(
        label: tr('Selected'),
        child: ExcludeSemantics(
          child: Icon(FontAwesomeIcons.check, size: 16, color: ff.primary),
        ),
      );
    } else if (available) {
      trailing = isEnglish
          ? null
          : FFTextButton(
              label: tr('Remove'),
              color: ff.danger,
              semanticLabel: tr('Remove {language}', {
                'language': language.englishName,
              }),
              onPressed: () => _remove(language),
            );
    } else {
      trailing = FFTextButton(
        label: tr('Add'),
        semanticLabel: tr('Add {language}', {'language': language.englishName}),
        onPressed: () => _choose(language, added: false),
      );
    }
    return FFListRow(
      leading: settingsTile(FontAwesomeIcons.language, SettingsTints.sky),
      title: language.nativeName,
      subtitle: isEnglish
          ? tr('Default · always available')
          : language.englishName,
      trailing: trailing,
      chevron: false,
      semanticLabel: selected
          ? tr('{language}, selected', {'language': language.englishName})
          : language.englishName,
      onTap: busy || selected
          ? null
          : () => _choose(language, added: available),
    );
  }
}
