/// ============================================================
/// FF SWITCH — iOS-style 51×31 primary switch
/// ============================================================
///
/// A token-styled [CupertinoSwitch] (the mockups are iOS-native looking on
/// both platforms) with an accessible label.
/// ============================================================
library;

import 'package:flutter/cupertino.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';

class FFSwitch extends StatelessWidget {
  const FFSwitch({
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.activeColor,
    this.vault = false,
    super.key,
  });

  final bool value;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  /// Track colour when on (defaults to primary / vault accent).
  final Color? activeColor;
  final bool vault;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      label: semanticLabel,
      child: CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor:
            activeColor ?? (vault ? ff.vaultChipActive : ff.primary),
        inactiveTrackColor: vault
            ? ff.vaultSurface
            : ff.ink.withValues(alpha: ff.isDark ? 0.16 : 0.1),
        thumbColor: ff.onGradient,
      ),
    );
  }
}
