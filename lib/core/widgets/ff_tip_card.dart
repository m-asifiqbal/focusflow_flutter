/// ============================================================
/// FF TIP CARD — "tip of the day" with an "Another tip" button
/// ============================================================
///
/// What: a soft module-tinted card: icon tile, title, one tip from [tips]
/// and an optional footnote. The tip shown is picked from [day] (a new
/// one every day, the same one all day); "Another tip" steps through the
/// rest with a cross-fade and starts over on the next day.
/// Why: Medicine insights (health tips) and the Prayer page (prayer tips)
/// share it; the catalogues stay in their features — this only rotates.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/ff_buttons.dart';
import 'package:focusflow/core/widgets/ff_card.dart';
import 'package:focusflow/core/widgets/ff_icon_tile.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';

class FFTipCard extends StatefulWidget {
  const FFTipCard({
    required this.title,
    required this.tips,
    required this.day,
    required this.icon,
    required this.colors,
    this.footnote,
    super.key,
  });

  final String title;

  /// The catalogue to rotate through (already in the active language).
  final List<String> tips;

  /// Today (local); picks the tip of the day.
  final DateTime day;
  final IconData icon;
  final ModuleColors colors;

  /// Small print under the tip (e.g. "not medical advice").
  final String? footnote;

  /// The tip of [day] out of [count]: consecutive days never repeat until
  /// the whole catalogue has been shown.
  static int indexFor(DateTime day, int count) {
    if (count <= 0) return 0;
    final n = DateUtilsX.daysBetween(DateTime(2000), day);
    return n % count;
  }

  @override
  State<FFTipCard> createState() => _FFTipCardState();
}

class _FFTipCardState extends State<FFTipCard> {
  /// How many times "Another tip" was tapped today.
  int _skip = 0;

  @override
  void didUpdateWidget(FFTipCard old) {
    super.didUpdateWidget(old);
    if (!DateUtilsX.isSameDay(old.day, widget.day)) _skip = 0;
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final b = ff.brightness;
    final tips = widget.tips;
    if (tips.isEmpty) return const SizedBox.shrink();
    final i =
        (FFTipCard.indexFor(widget.day, tips.length) + _skip) % tips.length;
    final ink = widget.colors.inkFor(b);
    return FFCard(
      color: widget.colors.softFor(b),
      border: false,
      shadow: false,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FFIconTile(
                icon: widget.icon,
                colors: widget.colors,
                size: AppSizes.iconTileSm,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: context.text.cardTitle.copyWith(color: ink),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AnimatedSwitcher(
                      duration: context.motion(AppMotion.normal),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: AlignmentDirectional.topStart,
                        children: [...previous, ?current],
                      ),
                      child: Semantics(
                        key: ValueKey(i),
                        liveRegion: _skip > 0,
                        child: Text(
                          tips[i],
                          style: context.text.body.copyWith(color: ff.ink),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: widget.footnote == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: AppSizes.iconTileSm + AppSpacing.md,
                        ),
                        child: Text(
                          widget.footnote!,
                          style: context.text.caption,
                        ),
                      ),
              ),
              if (tips.length > 1)
                FFTextButton(
                  label: tr('Another tip'),
                  icon: FontAwesomeIcons.arrowsRotate,
                  color: ink,
                  onPressed: () => setState(() => _skip++),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
