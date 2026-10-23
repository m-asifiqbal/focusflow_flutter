/// ============================================================
/// EXPORT OPTIONS — what Import & Export (screen 35) exports
/// ============================================================
///
/// What: the format tile, the INCLUDE checklist, the two switches and the
/// SAVE TO tile, as one immutable value the export service consumes.
/// Why: the screen state and the pure export code share one shape, so the
/// "Export N items" label and the file are computed from the same choice.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/l10n/tr.dart';

/// The FORMAT tiles.
enum ExportFormat {
  /// Full FocusFlow backup (encrypted whenever a backup PIN is set; the
  /// Export tab says "not encrypted" otherwise).
  ffbackup('.ffbackup', 'ffbackup'),

  /// Readable JSON for developers.
  json('JSON', 'json'),

  /// One CSV per module (zipped when more than one).
  csv('CSV', 'csv'),

  /// Notes as Markdown files + one PDF.
  pdfMd('PDF/MD', 'zip');

  const ExportFormat(this.label, this.extension);

  /// File-format name (not translated).
  final String label;
  final String extension;

  /// The line under the format tile. A getter so it follows the language.
  String get subtitle => switch (this) {
    ffbackup => tr('Full · encrypted'),
    json => tr('Developers'),
    csv => tr('Spreadsheets'),
    pdfMd => tr('Notes only'),
  };

  /// Vault items only ever leave the app inside an encrypted .ffbackup.
  bool get allowsVault => this == ffbackup;

  /// PDF/MD carries notes only.
  bool allows(ExportModule m) => switch (this) {
    ffbackup => true,
    json || csv => m != ExportModule.vault,
    pdfMd => m == ExportModule.notes,
  };
}

/// The INCLUDE checklist rows (snapshot table per module).
enum ExportModule {
  notes('notes', 'note'),
  tasks('tasks', 'task'),
  reminders('reminders', 'reminder'),
  habits('habits', 'habit'),
  medicines('medicines', 'medicine'),
  vault('vault_items', 'vault');

  const ExportModule(this.table, this.itemType);

  /// The module's name in the active language.
  String get label => switch (this) {
    notes => tr('Notes'),
    tasks => tr('Tasks'),
    reminders => tr('Reminders'),
    habits => tr('Habits'),
    medicines => tr('Medicines'),
    vault => tr('Vault'),
  };

  /// Snapshot / SQL table name.
  final String table;

  /// `item_tags.item_type` / ItemType key.
  final String itemType;
}

/// SAVE TO tiles.
enum ExportTarget { drive, device, share }

@immutable
class ExportOptions {
  const ExportOptions({
    this.format = ExportFormat.ffbackup,
    this.modules = const {
      ExportModule.notes,
      ExportModule.tasks,
      ExportModule.reminders,
      ExportModule.habits,
      ExportModule.medicines,
    },
    this.includeArchived = true,
    this.includeAttachments = true,
    this.includeSettings = true,
    this.target = ExportTarget.drive,
  });

  final ExportFormat format;
  final Set<ExportModule> modules;
  final bool includeArchived;
  final bool includeAttachments;

  /// Carry the app's settings in the file (.ffbackup only), so importing it
  /// on another phone — or after a reinstall — restores the configuration.
  final bool includeSettings;
  final ExportTarget target;

  /// The modules that will actually be written for [format].
  Set<ExportModule> get effectiveModules =>
      modules.where(format.allows).toSet();

  ExportOptions copyWith({
    ExportFormat? format,
    Set<ExportModule>? modules,
    bool? includeArchived,
    bool? includeAttachments,
    bool? includeSettings,
    ExportTarget? target,
  }) => ExportOptions(
    format: format ?? this.format,
    modules: modules ?? this.modules,
    includeArchived: includeArchived ?? this.includeArchived,
    includeAttachments: includeAttachments ?? this.includeAttachments,
    includeSettings: includeSettings ?? this.includeSettings,
    target: target ?? this.target,
  );

  @override
  bool operator ==(Object other) =>
      other is ExportOptions &&
      other.format == format &&
      setEquals(other.modules, modules) &&
      other.includeArchived == includeArchived &&
      other.includeAttachments == includeAttachments &&
      other.includeSettings == includeSettings &&
      other.target == target;

  @override
  int get hashCode => Object.hash(
    format,
    Object.hashAllUnordered(modules),
    includeArchived,
    includeAttachments,
    includeSettings,
    target,
  );
}

/// Items per module (active / archived) for the INCLUDE counts.
@immutable
class ExportCounts {
  const ExportCounts({this.active = const {}, this.archived = const {}});

  final Map<ExportModule, int> active;
  final Map<ExportModule, int> archived;

  int of(ExportModule m, {required bool includeArchived}) =>
      (active[m] ?? 0) + (includeArchived ? (archived[m] ?? 0) : 0);

  /// "Export N items" for [o].
  int total(ExportOptions o) => o.effectiveModules.fold(
    0,
    (sum, m) => sum + of(m, includeArchived: o.includeArchived),
  );
}
