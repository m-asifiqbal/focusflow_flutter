/// ============================================================
/// ARCHIVE HEADER — nav bar of Archive (23) and Recently Deleted (24)
/// ============================================================
///
/// What: "‹ Library · Title · Select" normally; "Cancel · Title · All"
/// (or "None" once everything is selected) in selection mode, as on
/// design/24. Why: both screens switch the same way.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/widgets/widgets.dart';

class ArchiveHeader extends StatelessWidget {
  const ArchiveHeader({
    required this.title,
    required this.selecting,
    required this.canSelect,
    required this.allSelected,
    required this.onSelect,
    required this.onCancel,
    required this.onToggleAll,
    super.key,
  });

  final String title;
  final bool selecting;

  /// False hides "Select" (nothing to select).
  final bool canSelect;
  final bool allSelected;
  final VoidCallback onSelect;
  final VoidCallback onCancel;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) => FFNavHeader(
    leading: selecting
        ? FFNavAction(label: 'Cancel', onPressed: onCancel)
        : const FFBackButton(label: 'Library'),
    title: title,
    trailing: [
      if (selecting)
        FFNavAction(label: allSelected ? 'None' : 'All', onPressed: onToggleAll)
      else if (canSelect)
        FFNavAction(label: 'Select', onPressed: onSelect),
    ],
  );
}
