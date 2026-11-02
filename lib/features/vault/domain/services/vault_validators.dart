/// ============================================================
/// VAULT VALIDATORS — card numbers, IBANs, BICs and document dates
/// ============================================================
///
/// Pure Dart helpers behind the editor's soft checks ("this card number
/// doesn't look right"), the grouped display of long numbers and the expiry
/// badges. Every check is *advisory*: a vault must keep whatever the user
/// typed (old cards, odd national formats), so nothing here blocks a save.
/// Values never leave memory and nothing logs them.
/// ============================================================
library;

import 'package:focusflow/core/utils/date_utils.dart';

/// A recognised card network (proper nouns — never translated).
enum VaultCardBrand {
  visa('Visa'),
  mastercard('Mastercard'),
  amex('American Express'),
  discover('Discover'),
  diners('Diners Club'),
  jcb('JCB'),
  unionPay('UnionPay'),
  maestro('Maestro');

  const VaultCardBrand(this.label);

  final String label;
}

abstract final class VaultCardNumber {
  /// Digits only.
  static String digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  /// The network of [number] from its issuer prefix (null when unknown or
  /// too short to tell). Prefix ranges follow the public IIN allocations.
  static VaultCardBrand? brand(String number) {
    final d = digits(number);
    if (d.length < 2) return null;
    // The leading [n] digits as a number (-1 while the number is shorter).
    int p(int n) => d.length >= n ? int.parse(d.substring(0, n)) : -1;
    final p2 = p(2), p3 = p(3), p4 = p(4);
    if (d.startsWith('4')) return VaultCardBrand.visa;
    if (p2 == 34 || p2 == 37) return VaultCardBrand.amex;
    if ((p2 >= 51 && p2 <= 55) || (p4 >= 2221 && p4 <= 2720)) {
      return VaultCardBrand.mastercard;
    }
    if (p2 == 62) return VaultCardBrand.unionPay;
    if (p4 == 6011 || (p3 >= 644 && p3 <= 649) || p2 == 65) {
      return VaultCardBrand.discover;
    }
    if (p4 >= 3528 && p4 <= 3589) return VaultCardBrand.jcb;
    if (p2 == 36 || p2 == 38 || p2 == 39 || (p3 >= 300 && p3 <= 305)) {
      return VaultCardBrand.diners;
    }
    if (p2 == 50 || (p2 >= 56 && p2 <= 69)) return VaultCardBrand.maestro;
    return null;
  }

  /// Luhn checksum (ISO/IEC 7812). Needs 12–19 digits.
  static bool isValid(String number) {
    final d = digits(number);
    if (d.length < 12 || d.length > 19) return false;
    var sum = 0;
    var alternate = false;
    for (var i = d.length - 1; i >= 0; i--) {
      var n = d.codeUnitAt(i) - 0x30;
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  /// "4242 4242 4242 4242" — Amex 4-6-5, Diners 4-6-4, otherwise groups of 4.
  static String format(String number) {
    final d = digits(number);
    final gaps = switch (brand(number)) {
      VaultCardBrand.amex => const [4, 10],
      VaultCardBrand.diners when d.length == 14 => const [4, 10],
      _ => [for (var i = 4; i < d.length; i += 4) i],
    };
    final out = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (gaps.contains(i)) out.write(' ');
      out.write(d[i]);
    }
    return out.toString();
  }
}

abstract final class VaultIban {
  /// Upper-case, no spaces or dashes.
  static String normalise(String s) =>
      s.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

  /// ISO 13616 mod-97 check (15–34 chars, country code + 2 check digits).
  static bool isValid(String iban) {
    final s = normalise(iban);
    if (s.length < 15 || s.length > 34) return false;
    if (!RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]+$').hasMatch(s)) return false;
    final rearranged = s.substring(4) + s.substring(0, 4);
    var remainder = 0;
    for (final unit in rearranged.codeUnits) {
      // Letters A–Z are 10–35; digits stay as they are.
      final value = unit >= 0x41 ? unit - 0x41 + 10 : unit - 0x30;
      remainder = value > 9
          ? (remainder * 100 + value) % 97
          : (remainder * 10 + value) % 97;
    }
    return remainder == 1;
  }

  /// "GB82 WEST 1234 5698 7654 32".
  static String format(String iban) {
    final s = normalise(iban);
    return [
      for (var i = 0; i < s.length; i += 4)
        s.substring(i, (i + 4).clamp(0, s.length)),
    ].join(' ');
  }
}

abstract final class VaultBic {
  /// SWIFT/BIC: 4-letter bank, 2-letter country, 2 location, optional 3 branch.
  static bool isValid(String bic) => RegExp(
    r'^[A-Z]{4}[A-Z]{2}[A-Z0-9]{2}([A-Z0-9]{3})?$',
  ).hasMatch(bic.replaceAll(' ', '').toUpperCase());
}

/// "•••• 1234" — never more than the last four characters of [value].
String vaultMaskTail(String value) {
  final t = value.replaceAll(RegExp(r'\s'), '');
  if (t.isEmpty) return '';
  return '•••• ${t.length <= 4 ? t : t.substring(t.length - 4)}';
}

/// Where a document / card date stands relative to today.
enum VaultExpiryStatus { expired, soon, ok }

abstract final class VaultDates {
  /// Days before an expiry at which an item is flagged "soon".
  static const int soonDays = 60;

  /// `yyyy-MM-dd` of [d] (the form dates are stored in).
  static String key(DateTime d) => DateUtilsX.dayKey(d);

  /// The calendar day of a stored `yyyy-MM-dd` value, or null when [s] is
  /// not a real date (stored dates are floating days, like task due dates).
  static DateTime? tryParse(String s) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s.trim());
    if (m == null) return null;
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    final date = DateTime(y, mo, d);
    // DateTime rolls 2025-02-31 over to March: reject anything that moved.
    return date.year == y && date.month == mo && date.day == d ? date : null;
  }

  /// Whole days from [now] to the stored date [s] (negative = past); null
  /// when [s] is empty or not a date.
  static int? daysUntil(String s, DateTime now) {
    final date = tryParse(s);
    return date == null ? null : DateUtilsX.daysBetween(now, date);
  }

  static VaultExpiryStatus? status(String s, DateTime now) {
    final days = daysUntil(s, now);
    if (days == null) return null;
    if (days < 0) return VaultExpiryStatus.expired;
    return days <= soonDays ? VaultExpiryStatus.soon : VaultExpiryStatus.ok;
  }

  /// `MM/YY` card expiry → the last day of that month, or null.
  static DateTime? cardExpiryEnd(String mmYY) {
    final m = RegExp(r'^(\d{1,2})\s*/\s*(\d{2}|\d{4})$').firstMatch(mmYY.trim());
    if (m == null) return null;
    final month = int.parse(m[1]!);
    var year = int.parse(m[2]!);
    if (month < 1 || month > 12) return null;
    if (year < 100) year += 2000;
    return DateTime(year, month + 1, 0);
  }
}
