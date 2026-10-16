/// ============================================================
/// VAULT BRANDS — offline brand catalogue for vault item avatars
/// ============================================================
///
/// Screen 18 shows a 44 pt brand tile per item: the brand glyph on its
/// brand colour (Google, GitHub on white; LinkedIn blue …) or a letter
/// avatar ("N" on Netflix red). Favicons are never fetched — the app is
/// offline-first — so known brands come from this catalogue (Font Awesome
/// brand glyphs + brand colours as data hex strings) and everything else
/// gets a letter avatar on the item's colour.
///
/// Resolution order: the item's `iconKey` → a brand whose name / keyword
/// matches the title → letter avatar on `colorHex` (or the vault default).
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';

/// One known brand. Colours are `RRGGBB` data, not theme colours.
@immutable
class VaultBrand {
  const VaultBrand(
    this.key,
    this.name, {
    required this.bgHex,
    this.fgHex = 'FFFFFF',
    this.icon,
    this.letter,
    this.keywords = const [],
  });

  final String key;
  final String name;
  final String bgHex;
  final String fgHex;

  /// Brand glyph; null = [letter] avatar.
  final IconData? icon;
  final String? letter;

  /// Extra lower-case title fragments that identify the brand.
  final List<String> keywords;
}

/// What a vault avatar draws.
@immutable
class VaultAvatarSpec {
  const VaultAvatarSpec({
    required this.background,
    required this.foreground,
    this.icon,
    this.letter,
  });

  final Color background;
  final Color foreground;
  final IconData? icon;
  final String? letter;
}

abstract final class VaultBrands {
  static const List<VaultBrand> all = [
    VaultBrand(
      'google',
      'Google',
      bgHex: 'FFFFFF',
      fgHex: '4285F4',
      icon: FontAwesomeIcons.google,
      keywords: ['gmail'],
    ),
    VaultBrand(
      'github',
      'GitHub',
      bgHex: 'FFFFFF',
      fgHex: '181717',
      icon: FontAwesomeIcons.github,
    ),
    VaultBrand(
      'gitlab',
      'GitLab',
      bgHex: 'FC6D26',
      icon: FontAwesomeIcons.gitlab,
    ),
    VaultBrand(
      'linkedin',
      'LinkedIn',
      bgHex: '0A66C2',
      icon: FontAwesomeIcons.linkedinIn,
    ),
    VaultBrand('netflix', 'Netflix', bgHex: 'E50914', letter: 'N'),
    VaultBrand('figma', 'Figma', bgHex: '1E1E1E', icon: FontAwesomeIcons.figma),
    VaultBrand(
      'bank',
      'Bank',
      bgHex: 'F59E0B',
      icon: FontAwesomeIcons.buildingColumns,
      keywords: ['bank', 'credit union'],
    ),
    VaultBrand(
      'facebook',
      'Facebook',
      bgHex: '1877F2',
      icon: FontAwesomeIcons.facebookF,
    ),
    VaultBrand('apple', 'Apple', bgHex: '111111', icon: FontAwesomeIcons.apple),
    VaultBrand(
      'microsoft',
      'Microsoft',
      bgHex: 'FFFFFF',
      fgHex: '00A4EF',
      icon: FontAwesomeIcons.microsoft,
      keywords: ['outlook', 'office'],
    ),
    VaultBrand(
      'amazon',
      'Amazon',
      bgHex: '232F3E',
      fgHex: 'FF9900',
      icon: FontAwesomeIcons.amazon,
    ),
    VaultBrand(
      'x',
      'X',
      bgHex: '000000',
      icon: FontAwesomeIcons.xTwitter,
      keywords: ['twitter'],
    ),
    VaultBrand(
      'instagram',
      'Instagram',
      bgHex: 'E1306C',
      icon: FontAwesomeIcons.instagram,
    ),
    VaultBrand(
      'dropbox',
      'Dropbox',
      bgHex: '0061FF',
      icon: FontAwesomeIcons.dropbox,
    ),
    VaultBrand('slack', 'Slack', bgHex: '4A154B', icon: FontAwesomeIcons.slack),
    VaultBrand(
      'spotify',
      'Spotify',
      bgHex: '1DB954',
      icon: FontAwesomeIcons.spotify,
    ),
    VaultBrand(
      'paypal',
      'PayPal',
      bgHex: '003087',
      icon: FontAwesomeIcons.paypal,
    ),
    VaultBrand(
      'reddit',
      'Reddit',
      bgHex: 'FF4500',
      icon: FontAwesomeIcons.reddit,
    ),
    VaultBrand(
      'youtube',
      'YouTube',
      bgHex: 'FF0000',
      icon: FontAwesomeIcons.youtube,
    ),
    VaultBrand(
      'whatsapp',
      'WhatsApp',
      bgHex: '25D366',
      icon: FontAwesomeIcons.whatsapp,
    ),
    VaultBrand(
      'discord',
      'Discord',
      bgHex: '5865F2',
      icon: FontAwesomeIcons.discord,
    ),
  ];

  static final Map<String, VaultBrand> _byKey = {for (final b in all) b.key: b};

  /// The brand for [iconKey], else the first brand named in [title].
  static VaultBrand? match(String? iconKey, String title) {
    if (iconKey != null && _byKey.containsKey(iconKey)) return _byKey[iconKey];
    final t = title.toLowerCase();
    if (t.isEmpty) return null;
    for (final b in all) {
      if (b.key == 'x') continue; // too short to guess from a title
      if (t.contains(b.name.toLowerCase())) return b;
      if (b.keywords.any(t.contains)) return b;
    }
    return null;
  }

  /// Avatar for an item. [fallback] is used when the item has neither a
  /// brand nor a colour; [onFallback] is the letter colour on it.
  static VaultAvatarSpec avatarFor({
    required String title,
    required VaultItemType type,
    required Color fallback,
    required Color onFallback,
    String? iconKey,
    String? colorHex,
  }) {
    final brand = match(iconKey, title);
    if (brand != null) {
      return VaultAvatarSpec(
        background: parseHex(colorHex) ?? parseHex(brand.bgHex)!,
        foreground: parseHex(brand.fgHex)!,
        icon: brand.icon,
        letter: brand.letter,
      );
    }
    final trimmed = title.trim();
    return VaultAvatarSpec(
      background: parseHex(colorHex) ?? fallback,
      foreground: onFallback,
      letter: trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
    );
  }
}
