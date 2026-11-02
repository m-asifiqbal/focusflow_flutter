/// ============================================================
/// VAULT ICONS — the glyph library for vault item avatars
/// ============================================================
///
/// Besides the brand tiles (vault_brands.dart) and the letter avatar, an
/// item can wear a plain glyph — a bank, a passport, a server — on a colour
/// of the user's choice. Glyphs are Font Awesome icons that are already
/// bundled, so the library costs no assets and works offline.
///
/// An item stores `iconKey = 'g:<key>'` (brand keys stay un-prefixed, so
/// every older item keeps resolving). Keys are permanent storage ids: add
/// new glyphs freely, never rename one. Search matches the key and its
/// English keywords (the same limit as the rest of in-app search).
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/fa_icons.dart';

/// One selectable glyph.
@immutable
class VaultGlyph {
  const VaultGlyph(this.key, this.icon, [this.keywords = const []]);

  /// Storage id without the `g:` prefix.
  final String key;
  final IconData icon;

  /// Extra lower-case search words.
  final List<String> keywords;

  /// The value stored in `VaultItemRecord.iconKey`.
  String get iconKey => '${VaultIcons.prefix}$key';

  bool matches(String needle) =>
      key.contains(needle) || keywords.any((k) => k.contains(needle));
}

/// A titled row-group of glyphs in the picker.
@immutable
class VaultGlyphGroup {
  const VaultGlyphGroup(this.title, this.glyphs);

  final String title;
  final List<VaultGlyph> glyphs;
}

abstract final class VaultIcons {
  /// `iconKey` prefix that marks a glyph (brands have none).
  static const String prefix = 'g:';

  static bool isGlyphKey(String? iconKey) =>
      iconKey != null && iconKey.startsWith(prefix);

  /// The glyph an `iconKey` names, or null (brand key, unknown glyph, null).
  static IconData? iconFor(String? iconKey) {
    if (!isGlyphKey(iconKey)) return null;
    return _byKey[iconKey!.substring(prefix.length)]?.icon;
  }

  /// Every glyph, in picker order (const data, built once).
  static const List<VaultGlyph> all = [
    // Finance
    VaultGlyph('bank', FontAwesomeIcons.buildingColumns, ['savings', 'branch']),
    VaultGlyph('card', FontAwesomeIcons.solidCreditCard, ['credit', 'debit']),
    VaultGlyph('wallet', FontAwesomeIcons.wallet, ['money', 'purse']),
    VaultGlyph('coins', FontAwesomeIcons.coins, ['crypto', 'change']),
    VaultGlyph('cash', FontAwesomeIcons.moneyBill, ['money', 'bill']),
    VaultGlyph('piggy', FontAwesomeIcons.piggyBank, ['savings']),
    VaultGlyph('chart', FontAwesomeIcons.chartLine, ['invest', 'stocks']),
    VaultGlyph('receipt', FontAwesomeIcons.receipt, ['bill', 'invoice']),
    VaultGlyph('sack', FontAwesomeIcons.sackDollar, ['money', 'loan']),
    VaultGlyph('payments', FontAwesomeIcons.handHoldingDollar, ['salary']),
    VaultGlyph('bitcoin', FontAwesomeIcons.bitcoinSign, ['crypto']),
    VaultGlyph('scale', FontAwesomeIcons.scaleBalanced, ['legal', 'tax']),
    // Security
    VaultGlyph('lock', FontAwesomeIcons.lock, ['private']),
    VaultGlyph('unlock', FontAwesomeIcons.unlockKeyhole, ['open']),
    VaultGlyph('key', FontAwesomeIcons.key, ['password', 'login']),
    VaultGlyph('shield', FontAwesomeIcons.shieldHalved, ['protect', 'safe']),
    VaultGlyph('user-shield', FontAwesomeIcons.userShield, ['account']),
    VaultGlyph('fingerprint', FontAwesomeIcons.fingerprint, ['biometric']),
    VaultGlyph('vault', FontAwesomeIcons.vault, ['safe', 'strongbox']),
    VaultGlyph('file-shield', FontAwesomeIcons.fileShield, ['secure']),
    VaultGlyph('certificate', FontAwesomeIcons.certificate, ['seal', 'ssl']),
    VaultGlyph('eye', FontAwesomeIcons.eye, ['private']),
    VaultGlyph('mask', FontAwesomeIcons.mask, ['anonymous']),
    VaultGlyph('bug', FontAwesomeIcons.bug, ['security']),
    // Documents
    VaultGlyph('passport', FontAwesomeIcons.passport, ['travel', 'visa']),
    VaultGlyph('id-card', FontAwesomeIcons.solidIdCard, ['identity']),
    VaultGlyph('id-badge', FontAwesomeIcons.idBadge, ['employee']),
    VaultGlyph('address-card', FontAwesomeIcons.addressCard, ['contact']),
    VaultGlyph('file', FontAwesomeIcons.fileLines, ['document']),
    VaultGlyph('contract', FontAwesomeIcons.fileContract, ['agreement']),
    VaultGlyph('folder', FontAwesomeIcons.folder, ['files']),
    VaultGlyph('book', FontAwesomeIcons.book, ['notebook']),
    VaultGlyph('news', FontAwesomeIcons.newspaper, ['subscription']),
    VaultGlyph('clipboard', FontAwesomeIcons.clipboard, ['list']),
    VaultGlyph('stamp', FontAwesomeIcons.stamp, ['official']),
    VaultGlyph('gavel', FontAwesomeIcons.gavel, ['court', 'law']),
    // Travel & transport
    VaultGlyph('plane', FontAwesomeIcons.plane, ['flight', 'airline']),
    VaultGlyph('car', FontAwesomeIcons.carSide, ['vehicle', 'auto']),
    VaultGlyph('bus', FontAwesomeIcons.bus, ['transit']),
    VaultGlyph('train', FontAwesomeIcons.train, ['rail', 'metro']),
    VaultGlyph('ship', FontAwesomeIcons.ship, ['cruise', 'ferry']),
    VaultGlyph('bicycle', FontAwesomeIcons.bicycle, ['bike']),
    VaultGlyph('motorcycle', FontAwesomeIcons.motorcycle, ['bike']),
    VaultGlyph('truck', FontAwesomeIcons.truck, ['delivery', 'shipping']),
    VaultGlyph('fuel', FontAwesomeIcons.gasPump, ['petrol', 'gas']),
    VaultGlyph('map', FontAwesomeIcons.mapLocationDot, ['place', 'gps']),
    VaultGlyph('suitcase', FontAwesomeIcons.suitcaseRolling, ['luggage']),
    VaultGlyph('hotel', FontAwesomeIcons.hotel, ['stay', 'booking']),
    // Home & utilities
    VaultGlyph('home', FontAwesomeIcons.house, ['house']),
    VaultGlyph('bed', FontAwesomeIcons.bed, ['sleep']),
    VaultGlyph('couch', FontAwesomeIcons.couch, ['furniture']),
    VaultGlyph('bath', FontAwesomeIcons.bath, ['bathroom']),
    VaultGlyph('bulb', FontAwesomeIcons.lightbulb, ['electric', 'light']),
    VaultGlyph('wifi', FontAwesomeIcons.wifi, ['internet', 'router']),
    VaultGlyph('tv', FontAwesomeIcons.tv, ['television', 'cable']),
    VaultGlyph('plug', FontAwesomeIcons.plug, ['power']),
    VaultGlyph('fire', FontAwesomeIcons.fire, ['gas', 'heating']),
    VaultGlyph('water', FontAwesomeIcons.droplet, ['utility']),
    VaultGlyph('bolt', FontAwesomeIcons.bolt, ['electricity']),
    VaultGlyph('building', FontAwesomeIcons.building, ['office', 'apartment']),
    // Work & tech
    VaultGlyph('briefcase', FontAwesomeIcons.briefcase, ['work', 'job']),
    VaultGlyph('laptop', FontAwesomeIcons.laptop, ['computer']),
    VaultGlyph('mobile', FontAwesomeIcons.mobileScreen, ['phone', 'sim']),
    VaultGlyph('tablet', FontAwesomeIcons.tablet, ['ipad']),
    VaultGlyph('server', FontAwesomeIcons.server, ['host', 'vps']),
    VaultGlyph('database', FontAwesomeIcons.database, ['sql', 'data']),
    VaultGlyph('cloud', FontAwesomeIcons.cloud, ['storage', 'aws']),
    VaultGlyph('code', FontAwesomeIcons.code, ['developer', 'api']),
    VaultGlyph('terminal', FontAwesomeIcons.terminal, ['ssh', 'shell']),
    VaultGlyph('chip', FontAwesomeIcons.microchip, ['hardware']),
    VaultGlyph('globe', FontAwesomeIcons.globe, ['website', 'domain']),
    VaultGlyph('envelope', FontAwesomeIcons.envelope, ['email', 'mail']),
    // Fun & media
    VaultGlyph('gamepad', FontAwesomeIcons.gamepad, ['games', 'console']),
    VaultGlyph('music', FontAwesomeIcons.music, ['streaming', 'audio']),
    VaultGlyph('film', FontAwesomeIcons.film, ['movies', 'video']),
    VaultGlyph('camera', FontAwesomeIcons.camera, ['photo']),
    VaultGlyph('headphones', FontAwesomeIcons.headphones, ['podcast']),
    VaultGlyph('palette', FontAwesomeIcons.palette, ['art', 'design']),
    VaultGlyph('star', FontAwesomeIcons.star, ['favourite', 'rating']),
    VaultGlyph('heart', FontAwesomeIcons.solidHeart, ['love', 'dating']),
    VaultGlyph('gift', FontAwesomeIcons.gift, ['present', 'voucher']),
    VaultGlyph('cake', FontAwesomeIcons.cakeCandles, ['birthday']),
    VaultGlyph('trophy', FontAwesomeIcons.trophy, ['award', 'win']),
    VaultGlyph('ticket', FontAwesomeIcons.ticket, ['event', 'pass']),
    // Shopping & food
    VaultGlyph('cart', FontAwesomeIcons.cartShopping, ['shop', 'store']),
    VaultGlyph('bag', FontAwesomeIcons.bagShopping, ['fashion']),
    VaultGlyph('store', FontAwesomeIcons.store, ['shop', 'market']),
    VaultGlyph('basket', FontAwesomeIcons.basketShopping, ['grocery']),
    VaultGlyph('food', FontAwesomeIcons.utensils, ['restaurant', 'dining']),
    VaultGlyph('coffee', FontAwesomeIcons.mugHot, ['cafe']),
    VaultGlyph('pizza', FontAwesomeIcons.pizzaSlice, ['delivery']),
    VaultGlyph('shirt', FontAwesomeIcons.shirt, ['clothes']),
    VaultGlyph('gem', FontAwesomeIcons.gem, ['jewellery', 'luxury']),
    VaultGlyph('crown', FontAwesomeIcons.crown, ['premium', 'vip']),
    VaultGlyph('award', FontAwesomeIcons.award, ['loyalty', 'rewards']),
    VaultGlyph('tag', FontAwesomeIcons.tag, ['coupon', 'discount']),
    // Health & life
    VaultGlyph('heartbeat', FontAwesomeIcons.heartPulse, ['health', 'fitness']),
    VaultGlyph('stethoscope', FontAwesomeIcons.stethoscope, ['doctor']),
    VaultGlyph('medkit', FontAwesomeIcons.kitMedical, ['first aid']),
    VaultGlyph('pills', FontAwesomeIcons.pills, ['medicine', 'pharmacy']),
    VaultGlyph('syringe', FontAwesomeIcons.syringe, ['vaccine']),
    VaultGlyph('tooth', FontAwesomeIcons.tooth, ['dentist']),
    VaultGlyph('school', FontAwesomeIcons.graduationCap, ['education', 'uni']),
    VaultGlyph('gym', FontAwesomeIcons.dumbbell, ['fitness', 'workout']),
    VaultGlyph('paw', FontAwesomeIcons.paw, ['pet', 'vet']),
    VaultGlyph('baby', FontAwesomeIcons.baby, ['family', 'kids']),
    VaultGlyph('leaf', FontAwesomeIcons.leaf, ['nature', 'eco']),
    VaultGlyph('mosque', FontAwesomeIcons.mosque, ['prayer', 'faith']),
  ];

  static final Map<String, VaultGlyph> _byKey = {for (final g in all) g.key: g};

  /// The picker's groups (titles follow the active language). Each group is
  /// a slice of [all]: twelve glyphs per group, in the order above.
  static List<VaultGlyphGroup> get groups {
    final titles = [
      tr('Finance'),
      tr('Security'),
      tr('Documents'),
      tr('Travel & transport'),
      tr('Home & utilities'),
      tr('Work & tech'),
      tr('Fun & media'),
      tr('Shopping & food'),
      tr('Health & life'),
    ];
    const per = 12;
    return [
      for (var i = 0; i < titles.length; i++)
        VaultGlyphGroup(titles[i], all.sublist(i * per, (i + 1) * per)),
    ];
  }

  /// Glyphs whose key or keywords contain [query] (case-insensitive).
  static List<VaultGlyph> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return all;
    return [
      for (final g in all)
        if (g.matches(needle)) g,
    ];
  }
}
