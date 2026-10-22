/// ============================================================
/// SETTINGS PAGE — the shared frame of every Settings sub-page
/// ============================================================
///
/// What: "‹ Settings | <Title>" nav header over a padded, scrolling list
/// of sections (grouped lists, hero cards, footnotes) — the layout of
/// mockups 31–33 — plus [SettingsFootnote] for the muted note under a
/// section.
/// Why: General, Home layout, Gestures, Sounds, App lock, Tags & folders,
/// Storage, About and the module defaults all share it, so spacing stays
/// identical to the designed sub-pages.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.title,
    required this.children,
    this.backLabel,
    this.trailing = const [],
    super.key,
  });

  final String title;

  /// Label of the back button; "Settings" when null.
  final String? backLabel;

  /// Optional nav-bar actions (e.g. "Reset").
  final List<Widget> trailing;

  /// Sections, top to bottom; a section gap is inserted between them.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return FFScaffold(
      body: Column(
        children: [
          FFNavHeader(
            leading: FFBackButton(label: backLabel ?? tr('Settings')),
            title: title,
            trailing: trailing,
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.grouped,
                AppSpacing.lg,
                AppSpacing.grouped,
                AppSpacing.xxl + bottom,
              ),
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.section),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Muted explanatory text under a section (mockup 33's recovery note).
class SettingsFootnote extends StatelessWidget {
  const SettingsFootnote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.md),
    child: Text(
      text,
      style: context.text.meta.copyWith(
        color: context.ff.inkMuted,
        height: 1.45,
      ),
    ),
  );
}
