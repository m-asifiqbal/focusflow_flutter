/// ============================================================
/// VAULT EXPIRY — wording and tone of an expiry date
/// ============================================================
///
/// The editor, the detail card and the list badge all say the same thing
/// about a document date ("Expired", "Expires in 12 days"), so the wording
/// and the tone live here. Dates are stored as `yyyy-MM-dd` (floating days;
/// see VaultDates) and compared against the injected clock — never against
/// `DateTime.now()` in widgets.
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/vault/domain/services/vault_validators.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';

/// "Expired" · "Expires today" · "Expires in 12 days" for the stored
/// [date]; null when it is not a date or more than a year away (a far-off
/// date needs no nagging).
String? vaultExpiryNote(String date, DateTime now) {
  final days = VaultDates.daysUntil(date, now);
  if (days == null) return null;
  if (days < 0) return tr('Expired');
  if (days == 0) return tr('Expires today');
  if (days > 365) return null;
  return tr('{count, plural, one {Expires in # day} other {Expires in # days}}', {
    'count': days,
  });
}

/// The badge tone of [date]'s status; null when there is nothing to flag
/// (not a date, or comfortably in the future).
VaultTone? vaultExpiryTone(FFColors ff, String date, DateTime now) =>
    switch (VaultDates.status(date, now)) {
      VaultExpiryStatus.expired => ff.vaultExpired,
      VaultExpiryStatus.soon => ff.vaultExpiring,
      _ => null,
    };

/// A stored `yyyy-MM-dd` date in the active locale ("5 Mar 2027"); the raw
/// text when it is not a date.
String vaultDateLabel(String date) {
  final d = VaultDates.tryParse(date);
  return d == null ? date : DateFormats.of('d MMM y').format(d);
}
