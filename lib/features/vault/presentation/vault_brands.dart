/// ============================================================
/// VAULT BRANDS — offline brand catalogue for vault item avatars
/// ============================================================
///
/// Screen 18 shows a 44 pt tile per item: a brand glyph on its brand colour
/// (Google, GitHub on white; LinkedIn blue …), a letter avatar ("N" on
/// Netflix red, "H" on HSBC red), a plain glyph from vault_icons.dart, or
/// the type's own icon. Favicons are never fetched — the app is offline-first
/// — so known brands come from this catalogue (Font Awesome brand glyphs or
/// a letter, plus brand colours as data hex strings).
///
/// Resolution order: the item's `iconKey` (glyph or brand) → a brand whose
/// name / keyword appears in the title as a whole word (specific brands
/// first, the generic "Bank" last) → the type's icon for schema types, or a
/// letter avatar on `colorHex` (or the vault default) for the original four.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_schema.dart';
import 'package:focusflow/features/vault/presentation/vault_icons.dart';
import 'package:focusflow/features/vault/presentation/vault_type_style.dart';

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
    this.generic = false,
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

  /// A category word ("Bank") rather than a company: only used when no
  /// specific brand matches the title.
  final bool generic;
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
    // ── Everyday web ──
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
      keywords: ['outlook', 'office', 'azure'],
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
    VaultBrand(
      'telegram',
      'Telegram',
      bgHex: '26A5E4',
      icon: FontAwesomeIcons.telegram,
    ),
    VaultBrand(
      'tiktok',
      'TikTok',
      bgHex: '010101',
      icon: FontAwesomeIcons.tiktok,
    ),
    VaultBrand(
      'snapchat',
      'Snapchat',
      bgHex: 'FFFC00',
      fgHex: '111111',
      icon: FontAwesomeIcons.snapchat,
    ),
    VaultBrand(
      'pinterest',
      'Pinterest',
      bgHex: 'E60023',
      icon: FontAwesomeIcons.pinterest,
    ),
    VaultBrand(
      'twitch',
      'Twitch',
      bgHex: '9146FF',
      icon: FontAwesomeIcons.twitch,
    ),
    VaultBrand(
      'skype',
      'Skype',
      bgHex: '00AFF0',
      icon: FontAwesomeIcons.skype,
    ),
    VaultBrand('zoom', 'Zoom', bgHex: '0B5CFF', icon: FontAwesomeIcons.video),
    VaultBrand(
      'yahoo',
      'Yahoo',
      bgHex: '6001D2',
      icon: FontAwesomeIcons.yahoo,
    ),
    VaultBrand(
      'steam',
      'Steam',
      bgHex: '171A21',
      icon: FontAwesomeIcons.steam,
    ),
    VaultBrand(
      'playstation',
      'PlayStation',
      bgHex: '003791',
      icon: FontAwesomeIcons.playstation,
    ),
    VaultBrand(
      'xbox',
      'Xbox',
      bgHex: '107C10',
      icon: FontAwesomeIcons.xbox,
    ),
    VaultBrand('nintendo', 'Nintendo', bgHex: 'E60012', letter: 'N'),
    VaultBrand(
      'soundcloud',
      'SoundCloud',
      bgHex: 'FF5500',
      icon: FontAwesomeIcons.soundcloud,
    ),
    VaultBrand(
      'vimeo',
      'Vimeo',
      bgHex: '1AB7EA',
      icon: FontAwesomeIcons.vimeoV,
    ),
    VaultBrand(
      'patreon',
      'Patreon',
      bgHex: 'FF424D',
      icon: FontAwesomeIcons.patreon,
    ),
    VaultBrand('ebay', 'eBay', bgHex: 'FFFFFF', fgHex: 'E53238', icon: FontAwesomeIcons.ebay),
    VaultBrand('etsy', 'Etsy', bgHex: 'F1641E', icon: FontAwesomeIcons.etsy),
    VaultBrand(
      'airbnb',
      'Airbnb',
      bgHex: 'FF5A5F',
      icon: FontAwesomeIcons.airbnb,
    ),
    VaultBrand('uber', 'Uber', bgHex: '000000', icon: FontAwesomeIcons.uber),
    VaultBrand(
      'shopify',
      'Shopify',
      bgHex: '96BF48',
      icon: FontAwesomeIcons.shopify,
    ),
    VaultBrand(
      'wordpress',
      'WordPress',
      bgHex: '21759B',
      icon: FontAwesomeIcons.wordpress,
    ),
    // ── Developer & cloud ──
    VaultBrand(
      'aws',
      'AWS',
      bgHex: '232F3E',
      fgHex: 'FF9900',
      icon: FontAwesomeIcons.aws,
      keywords: ['amazon web services'],
    ),
    VaultBrand(
      'digitalocean',
      'DigitalOcean',
      bgHex: '0080FF',
      icon: FontAwesomeIcons.digitalOcean,
    ),
    VaultBrand(
      'cloudflare',
      'Cloudflare',
      bgHex: 'F38020',
      icon: FontAwesomeIcons.cloudflare,
    ),
    VaultBrand(
      'docker',
      'Docker',
      bgHex: '2496ED',
      icon: FontAwesomeIcons.docker,
    ),
    VaultBrand('npm', 'npm', bgHex: 'CB3837', icon: FontAwesomeIcons.npm),
    VaultBrand(
      'bitbucket',
      'Bitbucket',
      bgHex: '0052CC',
      icon: FontAwesomeIcons.bitbucket,
    ),
    VaultBrand(
      'jira',
      'Jira',
      bgHex: '0052CC',
      icon: FontAwesomeIcons.jira,
      keywords: ['atlassian', 'confluence'],
    ),
    VaultBrand(
      'trello',
      'Trello',
      bgHex: '0052CC',
      icon: FontAwesomeIcons.trello,
    ),
    VaultBrand(
      'stackoverflow',
      'Stack Overflow',
      bgHex: 'F48024',
      icon: FontAwesomeIcons.stackOverflow,
    ),
    VaultBrand(
      'chrome',
      'Chrome',
      bgHex: 'FFFFFF',
      fgHex: '4285F4',
      icon: FontAwesomeIcons.chrome,
    ),
    VaultBrand(
      'firefox',
      'Firefox',
      bgHex: 'FF7139',
      icon: FontAwesomeIcons.firefoxBrowser,
    ),
    VaultBrand(
      'android',
      'Android',
      bgHex: '3DDC84',
      fgHex: '073042',
      icon: FontAwesomeIcons.android,
    ),
    VaultBrand(
      'ubuntu',
      'Ubuntu',
      bgHex: 'E95420',
      icon: FontAwesomeIcons.ubuntu,
      keywords: ['linux'],
    ),
    // ── Payments & crypto ──
    VaultBrand(
      'stripe',
      'Stripe',
      bgHex: '635BFF',
      icon: FontAwesomeIcons.stripeS,
    ),
    VaultBrand(
      'visa',
      'Visa',
      bgHex: '1A1F71',
      icon: FontAwesomeIcons.ccVisa,
    ),
    VaultBrand(
      'mastercard',
      'Mastercard',
      bgHex: '1B1B1F',
      fgHex: 'EB001B',
      icon: FontAwesomeIcons.ccMastercard,
    ),
    VaultBrand(
      'amex',
      'American Express',
      bgHex: '2E77BC',
      icon: FontAwesomeIcons.ccAmex,
      keywords: ['amex'],
    ),
    VaultBrand(
      'bitcoin',
      'Bitcoin',
      bgHex: 'F7931A',
      icon: FontAwesomeIcons.bitcoin,
      keywords: ['btc'],
    ),
    VaultBrand(
      'ethereum',
      'Ethereum',
      bgHex: '3C3C3D',
      icon: FontAwesomeIcons.ethereum,
      keywords: ['eth'],
    ),
    VaultBrand(
      'binance',
      'Binance',
      bgHex: 'F3BA2F',
      fgHex: '1E2026',
      letter: 'B',
    ),
    VaultBrand('coinbase', 'Coinbase', bgHex: '0052FF', letter: 'C'),
    VaultBrand('kraken', 'Kraken', bgHex: '5741D9', letter: 'K'),
    VaultBrand(
      'revolut',
      'Revolut',
      bgHex: '0075EB',
      letter: 'R',
    ),
    VaultBrand(
      'wise',
      'Wise',
      bgHex: '9FE870',
      fgHex: '163300',
      letter: 'W',
      keywords: ['transferwise'],
    ),
    VaultBrand('monzo', 'Monzo', bgHex: 'FF4F40', letter: 'M'),
    VaultBrand('n26', 'N26', bgHex: '36A18B', letter: 'N'),
    VaultBrand(
      'klarna',
      'Klarna',
      bgHex: 'FFB3C7',
      fgHex: '17120F',
      letter: 'K',
    ),
    // ── Banks ──
    VaultBrand('hsbc', 'HSBC', bgHex: 'DB0011', letter: 'H'),
    VaultBrand(
      'chase',
      'Chase',
      bgHex: '117ACA',
      letter: 'C',
      keywords: ['jpmorgan'],
    ),
    VaultBrand(
      'bofa',
      'Bank of America',
      bgHex: 'E31837',
      letter: 'B',
      keywords: ['bofa'],
    ),
    VaultBrand(
      'wellsfargo',
      'Wells Fargo',
      bgHex: 'D71E28',
      letter: 'W',
    ),
    VaultBrand(
      'citi',
      'Citi',
      bgHex: '056DAE',
      letter: 'C',
      keywords: ['citibank'],
    ),
    VaultBrand('barclays', 'Barclays', bgHex: '00AEEF', letter: 'B'),
    VaultBrand('santander', 'Santander', bgHex: 'EC0000', letter: 'S'),
    VaultBrand(
      'capitalone',
      'Capital One',
      bgHex: '004977',
      letter: 'C',
    ),
    VaultBrand('ally', 'Ally', bgHex: '650360', letter: 'A'),
    VaultBrand('schwab', 'Schwab', bgHex: '00A0DF', letter: 'S'),
    VaultBrand('ing', 'ING', bgHex: 'FF6200', letter: 'I'),
    VaultBrand('bbva', 'BBVA', bgHex: '004481', letter: 'B'),
    VaultBrand(
      'deutschebank',
      'Deutsche Bank',
      bgHex: '0018A8',
      letter: 'D',
    ),
    VaultBrand(
      'standardchartered',
      'Standard Chartered',
      bgHex: '0473EA',
      letter: 'S',
    ),
    VaultBrand(
      'emiratesnbd',
      'Emirates NBD',
      bgHex: 'C8102E',
      letter: 'E',
    ),
    VaultBrand('bkash', 'bKash', bgHex: 'E2136E', letter: 'b'),
    VaultBrand('nagad', 'Nagad', bgHex: 'F6921E', letter: 'N'),
    VaultBrand('brac', 'BRAC Bank', bgHex: '0A6EBD', letter: 'B'),
    VaultBrand(
      'dbbl',
      'Dutch-Bangla Bank',
      bgHex: '0F8B43',
      letter: 'D',
      keywords: ['dbbl'],
    ),
    VaultBrand(
      'sbi',
      'State Bank of India',
      bgHex: '22409A',
      letter: 'S',
      keywords: ['sbi'],
    ),
    VaultBrand('hdfc', 'HDFC', bgHex: '004C8F', letter: 'H'),
    VaultBrand('icici', 'ICICI', bgHex: 'F37E20', letter: 'I'),
    VaultBrand('paytm', 'Paytm', bgHex: '00B9F1', letter: 'P'),
    VaultBrand('phonepe', 'PhonePe', bgHex: '5F259F', letter: 'P'),
    VaultBrand('hbl', 'HBL', bgHex: '00844D', letter: 'H'),
    VaultBrand('meezan', 'Meezan Bank', bgHex: '6D2077', letter: 'M'),
    VaultBrand('jazzcash', 'JazzCash', bgHex: 'ED1C24', letter: 'J'),
    VaultBrand('easypaisa', 'Easypaisa', bgHex: '3EB649', letter: 'E'),
    // Category word, last: any title with "bank" in it, when no specific
    // brand above matched.
    VaultBrand(
      'bank',
      'Bank',
      bgHex: 'F59E0B',
      icon: FontAwesomeIcons.buildingColumns,
      keywords: ['credit union'],
      generic: true,
    ),
  ];

  static final Map<String, VaultBrand> _byKey = {for (final b in all) b.key: b};

  /// One whole-word pattern per brand (name + keywords), built once. A
  /// whole-word match keeps "Wise" out of "likewise" and "ING" out of
  /// "Shopping" — the substring test this replaced could not.
  static final List<(VaultBrand, RegExp)> _patterns = [
    for (final b in all)
      // "X" alone is too short to guess from a title: only its keywords
      // ("twitter") identify it.
      if (b.key != 'x' || b.keywords.isNotEmpty)
        (
          b,
          _wordPattern(b.key == 'x' ? b.keywords : [b.name, ...b.keywords]),
        ),
  ];

  static RegExp _wordPattern(List<String> words) => RegExp(
    '(?<![\\p{L}\\p{N}])(${words.map(RegExp.escape).join('|')})(?![\\p{L}\\p{N}])',
    caseSensitive: false,
    unicode: true,
  );

  /// Titles resolved so far (each keystroke in the editor resolves a new
  /// prefix; bounded so it cannot grow without end).
  static final Map<String, VaultBrand?> _titleMemo = {};

  static VaultBrand? _fromTitle(String title) {
    final t = title.trim();
    if (t.isEmpty) return null;
    if (_titleMemo.containsKey(t)) return _titleMemo[t];
    VaultBrand? found;
    for (final generic in const [false, true]) {
      for (final (b, p) in _patterns) {
        if (b.generic == generic && p.hasMatch(t)) {
          found = b;
          break;
        }
      }
      if (found != null) break;
    }
    if (_titleMemo.length >= 256) _titleMemo.clear();
    return _titleMemo[t] = found;
  }

  /// The brand for [iconKey], else the first brand named in [title].
  static VaultBrand? match(String? iconKey, String title) {
    if (iconKey != null && _byKey.containsKey(iconKey)) return _byKey[iconKey];
    // A glyph choice is explicit: do not second-guess it from the title.
    if (VaultIcons.isGlyphKey(iconKey)) return null;
    return _fromTitle(title);
  }

  /// Brands whose name or keywords contain [query] (picker search).
  static List<VaultBrand> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return all;
    return [
      for (final b in all)
        if (b.name.toLowerCase().contains(needle) ||
            b.keywords.any((k) => k.contains(needle)))
          b,
    ];
  }

  /// Avatar for an item. [fallback] is used when the item has neither an
  /// icon nor a colour; [onFallback] is the glyph / letter colour on it;
  /// [typeColor] tints a schema type's own icon.
  static VaultAvatarSpec avatarFor({
    required String title,
    required VaultItemType type,
    required Color fallback,
    required Color onFallback,
    required Color typeColor,
    String? iconKey,
    String? colorHex,
  }) {
    final chosen = parseHex(colorHex);
    final glyph = VaultIcons.iconFor(iconKey);
    if (glyph != null) {
      return VaultAvatarSpec(
        background: chosen ?? fallback,
        foreground: onFallback,
        icon: glyph,
      );
    }
    final brand = match(iconKey, title);
    if (brand != null) {
      return VaultAvatarSpec(
        background: chosen ?? parseHex(brand.bgHex)!,
        foreground: parseHex(brand.fgHex)!,
        icon: brand.icon,
        letter: brand.letter,
      );
    }
    // The newer types have no natural letter ("P" for a passport says
    // nothing): show the type's own icon, tinted with its category colour.
    if (type.isSchemaType && iconKey == null && chosen == null) {
      return VaultAvatarSpec(
        background: typeColor.withValues(alpha: 0.18),
        foreground: typeColor,
        icon: vaultTypeIcon(type),
      );
    }
    final trimmed = title.trim();
    return VaultAvatarSpec(
      background: chosen ?? fallback,
      foreground: onFallback,
      letter: trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
    );
  }
}
