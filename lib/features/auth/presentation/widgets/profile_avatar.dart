/// ============================================================
/// PROFILE AVATAR — the user's own avatar, with their local photo
/// ============================================================
///
/// [FFAvatar] plus the local profile picture (`profilePhotoProvider`): the
/// photo when one was chosen, the initial / person glyph otherwise. Every
/// place that shows *the user* (Home header, Settings card, Account screen)
/// uses this, so a photo set once appears everywhere and updates live.
/// A circle by default; [rounded] (the Settings profile card) makes it a
/// rounded square whose corners scale with its size like the app's icon
/// tiles ([cornerRatio]).
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/widgets/ff_avatar.dart';
import 'package:focusflow/features/auth/presentation/providers/account_providers.dart';

class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({
    this.initial,
    this.size = 44,
    this.border = true,
    this.rounded = false,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  /// Corner radius ÷ size of a [rounded] avatar: the large icon tile's
  /// proportion, so it rounds like the tiles and cards around it.
  static const double cornerRatio = AppRadii.tileLg / AppSizes.iconTileLg;

  /// Shown when there is no photo.
  final String? initial;
  final double size;
  final bool border;

  /// A rounded square instead of a circle.
  final bool rounded;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // valueOrNull keeps the previous picture while a new one is read.
    final photo = ref.watch(profilePhotoProvider).valueOrNull;
    return FFAvatar(
      initial: initial,
      image: photo == null ? null : MemoryImage(photo),
      size: size,
      radius: rounded ? size * cornerRatio : null,
      border: border,
      onTap: onTap,
      semanticLabel: semanticLabel,
    );
  }
}
