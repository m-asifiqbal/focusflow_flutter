/// ============================================================
/// MEDICINE STYLE — colours, icons and sizes of the medicine screens
/// ============================================================
///
/// Medicine is pink ([ModuleStyle.medicines]); the icon follows the form
/// (tablet, capsule, bottle, dropper, syringe, inhaler). Sizes that are not
/// a design-system token live in [MedicineSizes] so feature widgets never
/// hard-code numbers.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';

abstract final class MedicineStyle {
  static ModuleColors get colors => ModuleStyle.medicines.colors;

  static IconData icon(MedicineForm f) => switch (f) {
    MedicineForm.tablet => FontAwesomeIcons.tablets,
    MedicineForm.capsule => FontAwesomeIcons.capsules,
    MedicineForm.liquid => FontAwesomeIcons.prescriptionBottle,
    MedicineForm.drops => FontAwesomeIcons.eyeDropper,
    MedicineForm.injection => FontAwesomeIcons.syringe,
    MedicineForm.inhaler => FontAwesomeIcons.lungs,
    MedicineForm.other => FontAwesomeIcons.kitMedical,
  };

  /// Refill / low stock (amber, like the vault's warnings).
  static ModuleColors get stock => ModuleStyle.vault.colors;
}

abstract final class MedicineSizes {
  /// Hero ring on the list ("Today's doses") and the detail screen.
  static const double heroRing = 76;
  static const double heroStroke = 8;
  static const double detailRing = 168;
  static const double detailStroke = 14;

  /// Title tile of the editor.
  static const double titleTile = 64;
  static const double titleGlyph = 28;

  /// Week grid dots (detail).
  static const double weekDot = 12;
  static const double weekDotGap = 6;

  /// Stepper buttons (dose amount, refill) and its value's width.
  static const double stepper = 34;
  static const double stepperLabel = 120;
  static const double stepperLabelCompact = 76;

  /// Loading placeholders of the list.
  static const double skeletonHero = 120;
  static const double skeletonRow = 72;

  /// Progress bar of the hero card.
  static const double progressBar = 8;

  /// Insights › Medicine charts.
  static const double insightDonutMax = 150;
  static const double barMinWidth = 3;
  static const double barMaxWidth = 22;
  static const double vennHeight = 230;

  /// Scale of a dose's check when it pops in.
  static const double checkPop = 1.25;
}
