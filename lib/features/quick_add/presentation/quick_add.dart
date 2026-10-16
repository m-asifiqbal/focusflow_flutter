/// ============================================================
/// QUICK ADD — entry point for the "What's next?" sheet (screen 04)
/// ============================================================
///
/// Opened by the centre FAB on every tab, Calendar long-press (with a
/// [date]) and empty-state hints (with [text]). The sheet returns what the
/// user chose; [runQuickAddResult] then opens the editor on the caller's
/// page, so closing an editor returns to the previous tab.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/quick_add/presentation/providers/quick_add_providers.dart';
import 'package:focusflow/features/quick_add/presentation/quick_add_flows.dart';
import 'package:focusflow/features/quick_add/presentation/widgets/quick_add_sheet.dart';

/// Opens the "What's next?" sheet. [date] pre-selects a day (Calendar
/// long-press); [text] pre-fills quick capture (empty-state hints).
Future<void> showQuickAdd(
  BuildContext context, {
  DateTime? date,
  String? text,
}) async {
  final result = await showFFBottomSheet<QuickAddResult>(
    context,
    wrap: false,
    builder: (_) => QuickAddSheet(
      args: QuickAddArgs(text: text, date: date),
    ),
  );
  if (result == null || !context.mounted) return;
  await runQuickAddResult(context, result, date: date);
}
