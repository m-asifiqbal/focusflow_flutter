/// ============================================================
/// ARCHIVE NOTICE — the explanatory cards of Archive (23) and Trash (24)
/// ============================================================
///
/// What: Archive's mint info banner ("Archived items are hidden from
/// lists…") and Recently Deleted's rose card ("Auto-deletes after 30 days"
/// + body). Why: both mockups use a lighter body weight and (Trash) a
/// title line that FFInfoBanner doesn't have; colours come from tokens so
/// dark mode and the accent colour work for free.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';

enum ArchiveNoticeTone { info, danger }

class ArchiveNotice extends StatelessWidget {
  const ArchiveNotice({
    required this.icon,
    required this.body,
    this.title,
    this.tone = ArchiveNoticeTone.info,
    super.key,
  });

  final IconData icon;
  final String body;
  final String? title;
  final ArchiveNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final danger = tone == ArchiveNoticeTone.danger;
    final Color bg;
    final Color iconColor;
    final Color titleColor;
    final Color bodyColor;
    if (danger) {
      bg = ff.dangerSoft;
      iconColor = ff.danger;
      // A deeper rose than the icon (rose-700 in the mockup).
      titleColor = Color.lerp(ff.danger, ff.ink, ff.isDark ? 0.1 : 0.22)!;
      bodyColor = ff.danger.withValues(alpha: 0.85);
    } else {
      // Dark primarySoft is already translucent — use it as is.
      bg = ff.isDark ? ff.primarySoft : ff.primarySoft.withValues(alpha: 0.75);
      iconColor = ff.primary;
      titleColor = ff.primaryStrong;
      bodyColor = ff.primaryStrong.withValues(alpha: 0.85);
    }
    final bodyStyle = context.text.bodySmall.copyWith(
      fontSize: 14,
      height: 1.36,
      fontWeight: FontWeight.w400,
      color: bodyColor,
    );
    final titleText = title;
    return Semantics(
      container: true,
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          titleText == null ? AppSpacing.md : 17,
          AppSpacing.lg,
          titleText == null ? AppSpacing.md : 18,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(
            danger ? AppRadii.hero - 4 : AppRadii.card,
          ),
          border: danger
              ? Border.all(color: ff.danger.withValues(alpha: 0.14))
              : null,
        ),
        child: Row(
          crossAxisAlignment: titleText == null
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(
                top: titleText == null ? 0 : 1,
              ),
              child: Icon(
                icon,
                size: titleText == null ? 16 : 17,
                color: iconColor,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (titleText != null) ...[
                    Text(
                      titleText,
                      style: context.text.cardTitle.copyWith(
                        fontSize: 16.5,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Text(body, style: bodyStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
