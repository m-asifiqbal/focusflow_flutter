/// ============================================================
/// QUIET HOURS ROW — "Quiet hours  [10:00 PM] – [7:00 AM]" (screen 31)
/// ============================================================
///
/// What: the quiet-hours row of the BEHAVIOUR card. When on, two soft
/// primary pills show the window; each opens a wheel sheet that also offers
/// "Turn off quiet hours". When off, the row shows "Off" and tapping it
/// picks a start time (which turns quiet hours on).
/// Why: the mockup has no switch on this row. When the pills don't fit
/// beside the title (narrow screens, large text) they move under it, so
/// nothing overflows at 360 pt / text scale 1.3.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_digest_section.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_pickers.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_settings_controller.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_settings_style.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class QuietHoursRow extends ConsumerWidget {
  const QuietHoursRow({super.key});

  static String get _hint =>
      tr('Non-alarm notifications wait until quiet hours end');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(notificationSettingsControllerProvider);
    final use24h = s.use24HourTime;
    const tile = NotificationRowTile(
      FontAwesomeIcons.solidMoon,
      NotificationTints.night,
    );

    Future<void> pick({required bool start}) async {
      final choice = await showNotificationTimeSheet(
        context,
        title: start ? tr('Quiet hours start') : tr('Quiet hours end'),
        subtitle: _hint,
        minutes: start ? s.quietStartMinutes : s.quietEndMinutes,
        use24h: use24h,
        offLabel: s.quietHours ? tr('Turn off quiet hours') : null,
      );
      if (choice == null) return;
      final m = choice.value;
      if (m == null) return c.setQuietHours(false);
      return start
          ? c.setQuietWindow(startMinutes: m)
          : c.setQuietWindow(endMinutes: m);
    }

    if (!s.quietHours) {
      return FFListRow(
        leading: tile,
        title: tr('Quiet hours'),
        value: tr('Off'),
        onTap: () => pick(start: true),
      );
    }

    final from = NotificationLabels.time(s.quietStartMinutes, use24h: use24h);
    final to = NotificationLabels.time(s.quietEndMinutes, use24h: use24h);
    final pills = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TimePill(
          label: from,
          semanticLabel: tr('Quiet hours start, {from}', {'from': from}),
          onTap: () => pick(start: true),
        ),
        const _Dash(),
        _TimePill(
          label: to,
          semanticLabel: tr('Quiet hours end, {to}', {'to': to}),
          onTap: () => pick(start: false),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Text(
          tr('Quiet hours'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.rowTitle,
        );
        final inline =
            constraints.maxWidth - _chrome >=
            _pillsWidth(context, from, to) + _minTitleWidth(context);
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.rowMin),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.rowVertical,
            ),
            child: Row(
              crossAxisAlignment: inline
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                tile,
                const SizedBox(width: AppSpacing.rowLeadingGap),
                Expanded(
                  child: inline
                      ? Row(
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: AppSpacing.sm),
                            pills,
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            title,
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: pills,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Row padding + tile + gap + gap before the pills.
  static const double _chrome =
      AppSpacing.lg * 2 +
      AppSizes.iconTileSm +
      AppSpacing.rowLeadingGap +
      AppSpacing.sm;

  /// Room the two-line title needs beside the pills ("Quiet / hours"):
  /// its widest word (of the title in the active language).
  static double _minTitleWidth(BuildContext context) {
    var widest = 0.0;
    for (final word in tr('Quiet hours').split(' ')) {
      final p = TextPainter(
        text: TextSpan(text: word, style: context.text.rowTitle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      if (p.width > widest) widest = p.width;
      p.dispose();
    }
    return widest + AppSpacing.xxs;
  }

  static double _pillsWidth(BuildContext context, String from, String to) {
    final style = _TimePill.textStyle(context);
    final scaler = MediaQuery.textScalerOf(context);
    double w(String s) {
      final p = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = p.width;
      p.dispose();
      return width + _TimePill.hPad * 2;
    }

    return w(from) + w(to) + _Dash.width;
  }
}

/// Soft primary time pill; 44 pt tall tap target around a 32 pt pill.
class _TimePill extends StatelessWidget {
  const _TimePill({
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  static const double hPad = AppSpacing.md;

  static TextStyle textStyle(BuildContext context) => context.text.buttonSmall;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    // Light: half-strength primarySoft (the mockup's emerald-50); dark:
    // primarySoft is already a 15 % tint.
    final fill = ff.isDark
        ? ff.primarySoft
        : Color.alphaBlend(ff.primarySoft.withValues(alpha: 0.5), ff.surface);
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTap),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: hPad,
                  vertical: AppSpacing.pillVertical,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  style: textStyle(context).copyWith(color: ff.primaryStrong),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The thin "–" between the pills (8 pt line, 14 pt each side).
class _Dash extends StatelessWidget {
  const _Dash();

  static const double _gap = AppSpacing.md + AppSpacing.xxs;
  static const double _line = AppSpacing.sm;
  static const double width = _gap * 2 + _line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: _gap),
      child: SizedBox(
        width: _line,
        height: AppSizes.hairline,
        child: ColoredBox(color: context.ff.inkFaint),
      ),
    );
  }
}
