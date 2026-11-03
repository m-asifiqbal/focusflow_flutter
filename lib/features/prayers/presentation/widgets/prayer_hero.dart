/// ============================================================
/// PRAYER HERO — the next prayer, on top of the Prayer page
/// ============================================================
///
/// What: PrayerToday.card — the prayer whose waqt is still open and that
/// is not marked yet ("NOW", "Ends in 1h 12m", a bar of the window gone),
/// else the next prayer to begin — today's, or tomorrow's first once today
/// has none left ("NEXT · TOMORROW", "in 5h 10m"). The left half is the
/// text: the name, its window, the jamaat (with a people icon after it),
/// the bar, the place (with its icon) and "Alarm" when set. The right half
/// is a living sky with the four-part curve, the sun or moon in front of it
/// and the time left in this part ([PrayerSunArc]); the two halves melt
/// into each other. No Mark button here: the open prayer is marked in the
/// day list below, like on Home. Tap → the prayer's log sheet. No prayer
/// ahead at all: a calm "No prayers coming up" card.
/// Why: one steady focal point that answers "what's next?" (user's
/// request) — what is open now lives in the timeline. Accent gradient,
/// like Home's Today's Focus card, so the two heroes read as one family.
/// Kept alive while the page is open: scrolling away and back must not
/// rebuild the sky (and replay its intro). When a waqt ends the text
/// cross-fades to the next one (the page hands in the new slot at that
/// second — see prayer_clock_ticker.dart).
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_hero_parts.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_sun_arc.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_frame.dart';

class PrayerHeroCard extends StatefulWidget {
  const PrayerHeroCard({
    required this.slot,
    required this.now,
    required this.use24h,
    required this.onOpen,
    required this.sunFor,
    this.located = true,
    this.southern = false,
    super.key,
  });

  /// The open unmarked prayer, else the next one (null = none ahead).
  final PrayerSlot? slot;
  final DateTime now;
  final bool use24h;
  final VoidCallback onOpen;

  /// Sun times of a day for the sky (null without a location).
  final SolarDay? Function(DateTime day) sunFor;

  /// A location is saved (the curve shows sunrise / sunset times).
  final bool located;

  /// The saved place is south of the equator (the moon's lit side flips).
  final bool southern;

  @override
  State<PrayerHeroCard> createState() => _PrayerHeroCardState();
}

class _PrayerHeroCardState extends State<PrayerHeroCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// The text column's width on a card whose content is [inner] wide.
  static double _textWidth(double inner) =>
      (inner + 2 * AppSpacing.xl) * PrayerStyle.heroTextShare - AppSpacing.xl;

  /// "3:42 PM – 5:21 PM" may break at the dash only, never inside a time.
  static String _unbreakable(String window) =>
      window.split(' – ').map((t) => t.replaceAll(' ', ' ')).join(' – ');

  /// Fades and lifts the new text in; the old one fades out above it.
  static Widget _swap(Widget child, Animation<double> a) => FadeTransition(
    opacity: a,
    child: SlideTransition(
      position: Tween(begin: const Offset(0, .12), end: Offset.zero).animate(a),
      child: child,
    ),
  );

  static Widget _stackTop(Widget? current, List<Widget> previous) => Stack(
    alignment: AlignmentDirectional.topStart,
    children: [...previous, ?current],
  );

  /// The card shell: the sky behind, [body] on top, never shorter than
  /// [PrayerStyle.heroMinHeight] so the scene keeps its shape.
  Widget _shell(
    BuildContext context,
    Widget arc,
    Widget body, {
    String? label,
  }) {
    final ff = context.ff;
    return FFCard(
      gradient: ff.primaryGradient,
      border: false,
      padding: EdgeInsets.zero,
      onTap: widget.slot == null ? null : widget.onOpen,
      semanticLabel: label,
      child: Stack(
        children: [
          Positioned.fill(child: arc),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: PrayerStyle.heroMinHeight,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: body,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ff = context.ff;
    final text = context.text;
    final s = widget.slot;
    final on = ff.onGradient;
    final soft = on.withValues(alpha: 0.78);
    final stops = ff.primaryGradient.colors;
    final arc = PrayerSunArc(
      sunFor: widget.sunFor,
      use24h: widget.use24h,
      ground: stops[stops.length ~/ 2],
      located: widget.located,
      southern: widget.southern,
    );
    const shadows = [
      Shadow(
        color: PrayerStyle.skyTextShadow,
        blurRadius: 4,
        offset: Offset(0, 1),
      ),
    ];
    if (s == null) {
      return _shell(
        context,
        arc,
        LayoutBuilder(
          builder: (context, c) => SizedBox(
            width: _textWidth(c.maxWidth),
            child: Text(
              tr('No prayers coming up'),
              style: text.cardTitle.copyWith(color: on, fontSize: 18),
            ),
          ),
        ),
      );
    }
    final w = s.window;
    final state = s.stateAt(widget.now);
    final open =
        state == PrayerSlotState.open || state == PrayerSlotState.endingSoon;
    final tomorrow = !DateUtilsX.isSameDay(s.day, widget.now);
    final eyebrow = open
        ? tr('Now')
        : [tr('Next'), if (tomorrow) tr('Tomorrow')].join(' · ');
    final end = w.end;
    final String timing;
    final bool soon;
    if (open) {
      timing = end == null
          ? ''
          : PrayerFormat.endsIn(end.difference(widget.now));
      soon = state == PrayerSlotState.endingSoon;
    } else {
      final ahead = w.start.difference(widget.now);
      timing = PrayerFormat.inTime(ahead);
      soon = ahead <= PrayerSchedule.endingSoon;
    }
    final length = w.length;
    final passed = length == null || length.inSeconds <= 0
        ? 0.0
        : (widget.now.difference(w.start).inSeconds / length.inSeconds).clamp(
            0.0,
            1.0,
          );
    // The card's text, 1.5 pt under the page defaults (user's request).
    const shrink = PrayerStyle.heroShrink;
    final jamaat = PrayerFormat.jamaat(s, widget.now, use24h: widget.use24h);
    final place = s.prayer.place.trim();
    final alarm = s.prayer.priority == PrayerPriority.high;
    final fade = context.motion(const Duration(milliseconds: 320));
    return _shell(
      context,
      arc,
      label: tr('{when}: {name}, {window}. {timing}', {
        'when': eyebrow,
        'name': s.prayer.displayName,
        'window': PrayerFormat.window(w, use24h: widget.use24h),
        'timing': timing,
      }),
      LayoutBuilder(
        builder: (context, c) {
          final textWidth = _textWidth(c.maxWidth);
          // The bar stops short of the curve's foot: with a place / alarm
          // line under it the bar rises to the horizon, where it used to run
          // into the sun's half circle.
          final cardWidth = c.maxWidth + 2 * AppSpacing.xl;
          final barWidth = math.max(
            0.0,
            math.min(
              textWidth,
              SkyLayout.of(cardWidth).nearEdge -
                  AppSpacing.xl -
                  PrayerStyle.heroBarGap,
            ),
          );
          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      AnimatedSwitcher(
                        duration: fade,
                        transitionBuilder: _swap,
                        layoutBuilder: _stackTop,
                        child: Text(
                          eyebrow.toUpperCase(),
                          key: ValueKey(eyebrow),
                          style: text.meta.copyWith(
                            color: soft,
                            fontSize: (text.meta.fontSize ?? 13) - shrink,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          timing,
                          maxLines: 2,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: text.meta.copyWith(
                            color: soon ? on : soft,
                            fontWeight: soon
                                ? FontWeight.w700
                                : FontWeight.w500,
                            shadows: shadows,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SizedBox(
                      width: textWidth,
                      child: AnimatedSwitcher(
                        duration: fade,
                        transitionBuilder: _swap,
                        layoutBuilder: _stackTop,
                        child: Column(
                          key: ValueKey(s.id),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.prayer.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.largeTitle.copyWith(
                                color: on,
                                fontSize: PrayerStyle.heroName - shrink,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _unbreakable(
                                PrayerFormat.window(w, use24h: widget.use24h),
                              ),
                              style: text.body.copyWith(
                                color: soft,
                                fontSize: (text.body.fontSize ?? 16) - shrink,
                              ),
                            ),
                            if (jamaat != null) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              // Beside the sky: room for a third line.
                              PrayerJamaatLine(
                                text: jamaat,
                                color: on,
                                style: text.body.copyWith(
                                  color: on,
                                  fontSize: (text.body.fontSize ?? 16) - shrink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  if (open && end != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SizedBox(
                        width: barWidth,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: passed),
                            duration: context.motion(
                              const Duration(milliseconds: 600),
                            ),
                            curve: Curves.easeOutCubic,
                            builder: (context, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 6,
                              color: on,
                              backgroundColor: on.withValues(alpha: 0.22),
                              semanticsLabel: tr('Time passed in this window'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (place.isNotEmpty || alarm) ...[
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.lg,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (place.isNotEmpty)
                          PrayerIconLine(
                            icon: PrayerStyle.placeIcon(
                              place,
                              s.prayer.tradition,
                            ),
                            text: place,
                            color: soft,
                            style: text.bodySmall.copyWith(color: soft),
                          ),
                        if (alarm)
                          PrayerIconLine(
                            icon: FontAwesomeIcons.solidBell,
                            text: tr('Alarm'),
                            color: soft,
                            style: text.bodySmall.copyWith(color: soft),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
