/// ============================================================
/// VAULT TYPE STYLE — the one icon per vault item type
/// ============================================================
///
/// Used by the type chips, the type picker, the category tiles and the
/// default avatar of the schema types. (It was declared twice, in the editor
/// header and the list widgets; every screen now reads it from here.)
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';

IconData vaultTypeIcon(VaultItemType type) => switch (type) {
  VaultItemType.login => FontAwesomeIcons.key,
  VaultItemType.card => FontAwesomeIcons.solidCreditCard,
  VaultItemType.wifi => FontAwesomeIcons.wifi,
  VaultItemType.secureNote => FontAwesomeIcons.solidNoteSticky,
  VaultItemType.bankAccount => FontAwesomeIcons.buildingColumns,
  VaultItemType.cryptoWallet => FontAwesomeIcons.coins,
  VaultItemType.insurance => FontAwesomeIcons.shieldHeart,
  VaultItemType.identity => FontAwesomeIcons.addressCard,
  VaultItemType.passport => FontAwesomeIcons.passport,
  VaultItemType.driverLicense => FontAwesomeIcons.idCardClip,
  VaultItemType.nationalId => FontAwesomeIcons.solidIdCard,
  VaultItemType.medical => FontAwesomeIcons.heartPulse,
  VaultItemType.emailAccount => FontAwesomeIcons.envelope,
  VaultItemType.server => FontAwesomeIcons.server,
  VaultItemType.apiKey => FontAwesomeIcons.terminal,
  VaultItemType.softwareLicense => FontAwesomeIcons.certificate,
  VaultItemType.membership => FontAwesomeIcons.ticket,
  VaultItemType.vehicle => FontAwesomeIcons.carSide,
};
