/// ============================================================
/// FF BANNERS · LOADING — inline status surfaces
/// ============================================================
///
/// * [FFInfoBanner]  — soft tinted note with icon (Archive "hidden from
///   lists…", 23); [FFInfoBanner.danger] is the rose Trash variant (24).
/// * [FFErrorBanner] — rose banner with a Retry action (list load errors).
/// * [FFLoadingView] — centred spinner + optional caption.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_buttons.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/theme/fa_icons.dart';

enum _BannerTone { info, danger }

class FFInfoBanner extends StatelessWidget {
  const FFInfoBanner({
    required this.icon,
    required this.text,
    this.colors,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : _tone = _BannerTone.info;

  /// Rose variant ("Items here are deleted forever after 30 days").
  const FFInfoBanner.danger({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : colors = null,
       _tone = _BannerTone.danger;

  final IconData icon;
  final String text;

  /// Custom tint (module trio); defaults to the primary family.
  final ModuleColors? colors;
  final String? actionLabel;
  final VoidCallback? onAction;
  final _BannerTone _tone;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final (Color bg, Color iconColor, Color fg) = switch (_tone) {
      _BannerTone.danger => (ff.dangerSoft, ff.dangerSolid, ff.dangerStrong),
      _BannerTone.info when colors != null => (
        colors!.softFor(ff.brightness),
        colors!.solid,
        colors!.inkFor(ff.brightness),
      ),
      _BannerTone.info => (
        ff.primarySoft.withValues(alpha: ff.isDark ? 1 : 0.75),
        ff.primary,
        ff.primaryStrong,
      ),
    };
    return _BannerFrame(
      bg: bg,
      icon: icon,
      iconColor: iconColor,
      text: text,
      textColor: fg,
      action: actionLabel == null
          ? null
          : FFTextButton(
              label: actionLabel!,
              onPressed: onAction,
              color: iconColor,
            ),
    );
  }
}

class FFErrorBanner extends StatelessWidget {
  const FFErrorBanner({
    required this.message,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.icon = FontAwesomeIcons.triangleExclamation,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      liveRegion: true,
      child: _BannerFrame(
        bg: ff.dangerSoft,
        icon: icon,
        iconColor: ff.dangerSolid,
        text: message,
        textColor: ff.dangerStrong,
        action: onRetry == null
            ? null
            : FFTextButton(
                label: retryLabel,
                icon: FontAwesomeIcons.rotateRight,
                onPressed: onRetry,
                color: ff.dangerStrong,
              ),
      ),
    );
  }
}

class _BannerFrame extends StatelessWidget {
  const _BannerFrame({
    required this.bg,
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.textColor,
    this.action,
  });

  final Color bg;
  final IconData icon;
  final Color iconColor;
  final String text;
  final Color textColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        action == null ? AppSpacing.lg : AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: action,
            ),
          ],
        ],
      ),
    );
  }
}

class FFLoadingView extends StatelessWidget {
  const FFLoadingView({this.message, this.color, super.key});

  final String? message;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Center(
      child: Semantics(
        label: message ?? 'Loading',
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 30,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                color: color ?? ff.primary,
                backgroundColor: (color ?? ff.primary).withValues(alpha: 0.12),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: context.text.meta,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
