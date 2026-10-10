/// Entry point for the Quick Add sheet (screen 04), opened by the centre FAB
/// on every tab. The quick_add feature replaces this body with the real sheet.
library;

import 'package:flutter/material.dart';

/// Opens the "What's next?" sheet. [date] pre-selects a day (Calendar
/// long-press); [text] pre-fills quick capture (empty-state hints).
Future<void> showQuickAdd(
  BuildContext context, {
  DateTime? date,
  String? text,
}) async {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Quick Add — coming soon')));
}
