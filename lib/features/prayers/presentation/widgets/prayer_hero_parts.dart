/// ============================================================
/// PRAYER HERO PARTS — the two small lines of the Prayer card's text
/// ============================================================
///
/// What: [PrayerJamaatLine] — the jamaat words with the people icon right
/// after the last one (it follows the text when it wraps, and flips with
/// the language); [PrayerIconLine] — an icon and its text (the place, the
/// alarm), the icon aligned with the first line.
/// Why: split from prayer_hero.dart to keep that file small.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';

/// The jamaat line: the words, then the people icon right after the last
/// one (it follows the text when it wraps, and flips with the language).
class PrayerJamaatLine extends StatelessWidget {
  const PrayerJamaatLine({
    required this.text,
    required this.color,
    required this.style,
    super.key,
  });

  final String text;
  final Color color;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: text),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
            child: Icon(FontAwesomeIcons.users, size: 14, color: color),
          ),
        ),
      ],
    ),
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
    style: style,
  );
}

/// An icon and its text, the icon aligned with the first line.
class PrayerIconLine extends StatelessWidget {
  const PrayerIconLine({
    required this.icon,
    required this.text,
    required this.color,
    required this.style,
    super.key,
  });

  final IconData icon;
  final String text;
  final Color color;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(top: 3),
        child: Icon(icon, size: 14, color: color),
      ),
      const SizedBox(width: AppSpacing.sm),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    ],
  );
}
