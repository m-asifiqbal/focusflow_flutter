/// ============================================================
/// VAULT AVATAR — 44 pt brand tile or letter avatar (screens 17 / 18 / 19)
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/presentation/vault_brands.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';

class VaultAvatar extends StatelessWidget {
  const VaultAvatar({
    required this.title,
    required this.type,
    this.iconKey,
    this.colorHex,
    this.size = AppSizes.roundButton,
    this.radius = AppRadii.tileLg,
    super.key,
  });

  VaultAvatar.record(
    VaultItemRecord record, {
    double size = AppSizes.roundButton,
    double radius = AppRadii.tileLg,
    Key? key,
  }) : this(
         title: record.title,
         type: record.type,
         iconKey: record.iconKey,
         colorHex: record.colorHex,
         size: size,
         radius: radius,
         key: key,
       );

  final String title;
  final VaultItemType type;
  final String? iconKey;
  final String? colorHex;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final spec = VaultBrands.avatarFor(
      title: title,
      type: type,
      iconKey: iconKey,
      colorHex: colorHex,
      fallback: ff.vaultAvatarFallback,
      onFallback: ff.vaultInk,
    );
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: spec.background,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: spec.icon != null
            ? Icon(spec.icon, size: size * 0.46, color: spec.foreground)
            : Text(
                spec.letter ?? '?',
                textScaler: TextScaler.noScaling,
                style: context.text.stat.copyWith(
                  fontSize: size * 0.46,
                  fontWeight: FontWeight.w800,
                  color: spec.foreground,
                ),
              ),
      ),
    );
  }
}
