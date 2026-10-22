/// ============================================================
/// SEARCH RESULT ROW — one hit in the "TOP RESULTS" card (screen 06)
/// ============================================================
///
/// Soft module tile · title with matched terms highlighted · meta line
/// ("Notes · Ideas · 2h ago", "Tasks · Today 11:30 AM", "Vault · unlock to
/// view", "Habits · 12-day streak") · faint open-in icon. A body-only match
/// shows its snippet as a third line so the user sees why it matched —
/// never for vault items or locked notes (they carry no snippet).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/domain/services/habit_words.dart';
import 'package:focusflow/features/search/domain/entities/search_hit.dart';
import 'package:focusflow/features/search/presentation/providers/search_providers.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Meta line of [hit] (module first). Pure — unit tested.
String searchHitMeta(
  SearchHit hit, {
  required DateTime now,
  bool use24h = false,
  bool vaultUnlocked = false,
  int? habitStreak,
}) {
  String time(DateTime t) =>
      DateFormats.of(use24h ? 'HH:mm' : 'h:mm a').format(t);
  String day(DateTime d) {
    final diff = DateUtilsX.daysBetween(now, d);
    if (diff == 0) return tr('Today');
    if (diff == 1) return tr('Tomorrow');
    if (diff == -1) return tr('Yesterday');
    if (diff > 1 && diff < 7) return DateFormats.of('EEE').format(d);
    return DateFormats.of(d.year == now.year ? 'MMM d' : 'MMM d, y').format(d);
  }

  final parts = <String>[hit.type.plural];
  switch (hit.type) {
    case ItemType.note:
      if (hit.folderName != null) parts.add(hit.folderName!);
      parts.add(
        hit.isLocked ? tr('Locked') : DateUtilsX.ago(hit.updatedAt, now),
      );
    case ItemType.task:
      if (hit.isCompleted) {
        parts.add(tr('Done'));
      } else if (hit.dueDay != null) {
        final d = hit.dueDay!;
        parts.add(
          hit.dueMinutes == null
              ? day(d)
              : '${day(d)} ${time(DateUtilsX.atMinutes(d, hit.dueMinutes!))}',
        );
      } else {
        parts.add(DateUtilsX.ago(hit.updatedAt, now));
      }
    case ItemType.reminder:
      final t = hit.triggerAt;
      parts.add(
        t == null ? DateUtilsX.ago(hit.updatedAt, now) : '${day(t)} ${time(t)}',
      );
    case ItemType.habit:
      if (habitStreak != null && habitStreak > 0) {
        parts.add(tr('{n}-day streak', {'n': habitStreak}));
      } else if (hit.detail.isNotEmpty) {
        // The habit category is stored in English.
        parts.add(HabitWords.shown(hit.detail));
      }
    case ItemType.vault:
      parts.add(vaultUnlocked ? hit.detail : tr('unlock to view'));
  }
  if (hit.isArchived) parts.add(tr('Archived'));
  return parts.where((p) => p.isNotEmpty).join(' · ');
}

class SearchResultRow extends ConsumerWidget {
  const SearchResultRow({
    required this.hit,
    required this.query,
    required this.onTap,
    super.key,
  });

  final SearchHit hit;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final text = context.text;
    final style = hit.type.style;
    final streak = hit.type == ItemType.habit
        ? ref.watch(searchHabitStreakProvider(hit.ref.id)).valueOrNull
        : null;
    final meta = searchHitMeta(
      hit,
      now: ref.watch(clockProvider).now(),
      use24h: ref.watch(settingsProvider.select((s) => s.use24HourTime)),
      vaultUnlocked:
          hit.type == ItemType.vault &&
          ref.watch(vaultStatusProvider) == VaultStatus.unlocked,
      habitStreak: streak,
    );
    final title = hit.title.trim().isEmpty ? tr('Untitled') : hit.title;
    final titleMatches = FFHighlightedText.segments(
      title,
      query,
    ).any((s) => s.$2);
    final showSnippet = !titleMatches && hit.snippet.isNotEmpty;

    return Semantics(
      button: true,
      label: '$title, $meta',
      hint: tr('Open'),
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: _Tokens.rowPadV,
          ),
          child: Row(
            children: [
              FFIconTile.soft(
                icon: style.icon,
                colors: style.colors,
                size: _Tokens.tile,
                iconSize: _Tokens.glyph,
              ),
              const SizedBox(width: AppSpacing.rowLeadingGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FFHighlightedText(
                      title,
                      query: query,
                      maxLines: 1,
                      style: text.cardTitle.copyWith(
                        fontSize: _Tokens.titleSize,
                        color: ff.ink,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.meta.copyWith(
                        fontSize: _Tokens.metaSize,
                        fontWeight: FontWeight.w500,
                        color: ff.inkFaint,
                      ),
                    ),
                    if (showSnippet) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      FFHighlightedText(
                        hit.snippet,
                        query: query,
                        maxLines: 2,
                        style: text.bodySmall.copyWith(
                          fontSize: _Tokens.metaSize,
                          height: 1.35,
                          color: ff.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ExcludeSemantics(
                child: Icon(
                  FontAwesomeIcons.arrowUpRightFromSquare,
                  size: _Tokens.openIcon,
                  color: ff.inkFaint.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row measurements taken from design/06 (390-pt frame).
abstract final class _Tokens {
  static const double tile = 40;
  static const double glyph = 17;
  static const double titleSize = 15;
  static const double metaSize = 12.5;
  static const double rowPadV = 15;
  static const double openIcon = 15;
}
