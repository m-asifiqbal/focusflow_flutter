/// ============================================================
/// QUICK ADD SHEET — "What's next?" (screen 04)
/// ============================================================
///
/// What: title + subtitle, the natural-language capture field, the six
/// module tiles and a Cancel button, inside the shared [FFBottomSheet]
/// (34-radius, handle, blurred scrim, drag-to-dismiss, keyboard-safe).
/// The sheet pops with a [QuickAddResult]; `showQuickAdd` acts on it.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/quick_add/presentation/providers/quick_add_providers.dart';
import 'package:focusflow/features/quick_add/presentation/quick_add_flows.dart';
import 'package:focusflow/features/quick_add/presentation/widgets/quick_add_tiles.dart';
import 'package:focusflow/features/quick_add/presentation/widgets/quick_capture_field.dart';

class QuickAddSheet extends StatelessWidget {
  const QuickAddSheet({this.args = const QuickAddArgs(), super.key});

  final QuickAddArgs args;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    void close([QuickAddResult? result]) => Navigator.of(context).pop(result);
    return FFBottomSheet(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        AppSpacing.xxl,
        AppSpacing.screen,
        AppSpacing.xl,
      ),
      footer: FFSecondaryButton(
        label: 'Cancel',
        variant: FFSecondaryVariant.surface,
        // Mockup: darker than the subtitle's inkMuted.
        foreground: ff.ink.withValues(alpha: 0.7),
        onPressed: close,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              'What’s next?',
              textAlign: TextAlign.center,
              style: context.text.title,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Capture anything in two taps',
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          QuickCaptureField(
            args: args,
            onSubmit: (capture) => close(QuickAddCaptured(capture)),
          ),
          const SizedBox(height: AppSpacing.lg),
          QuickAddTileGrid(onTap: (module) => close(QuickAddModule(module))),
        ],
      ),
    );
  }
}
