/// ============================================================
/// REMINDER TITLE CARD — bell tile + title + note (top of screen 13)
/// ============================================================
///
/// What: an orange bell tile beside the title field (Lexend 19 w600) and a
/// one-line-growing "Add a note…" field.
/// Why: the fields own their controllers (seeded once from the loaded
/// reminder) and report every change to the editor controller, which stays
/// the single source of truth for Save / discard.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/reminders/presentation/reminder_tokens.dart';

class ReminderTitleCard extends StatefulWidget {
  const ReminderTitleCard({
    required this.title,
    required this.note,
    required this.onTitleChanged,
    required this.onNoteChanged,
    this.autofocus = false,
    super.key,
  });

  /// Initial values (read once).
  final String title;
  final String note;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onNoteChanged;

  /// Focus the title (new, untitled reminder).
  final bool autofocus;

  /// Bell tile size (mockup: 42 pt).
  static const double tileSize = 42;

  @override
  State<ReminderTitleCard> createState() => _ReminderTitleCardState();
}

class _ReminderTitleCardState extends State<ReminderTitleCard> {
  late final _title = TextEditingController(text: widget.title);
  late final _note = TextEditingController(text: widget.note);
  final _noteFocus = FocusNode();

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    const bare = InputDecoration(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      filled: false,
      isCollapsed: true,
      contentPadding: EdgeInsets.zero,
    );
    final titleStyle = context.text.reminderEditorTitle.copyWith(color: ff.ink);
    final noteStyle = context.text.reminderNote.copyWith(color: ff.inkMuted);
    return FFCard(
      // Mockup: 81 pt tall card, title optically centred on the tile.
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        15,
        AppSpacing.lg,
        19,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FFIconTile(
            icon: FontAwesomeIcons.solidBell,
            colors: ModuleStyle.reminders.colors,
            size: ReminderTitleCard.tileSize,
            radius: AppRadii.tile,
            iconSize: ReminderSizes.titleGlyph,
          ),
          const SizedBox(width: ReminderSizes.tileGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _title,
                  autofocus: widget.autofocus,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  onChanged: widget.onTitleChanged,
                  onSubmitted: (_) => _noteFocus.requestFocus(),
                  style: titleStyle,
                  decoration: bare.copyWith(
                    hintText: 'Reminder title',
                    hintStyle: titleStyle.copyWith(color: ff.inkFaint),
                  ),
                ),
                const SizedBox(height: ReminderSizes.titleNoteGap),
                TextField(
                  controller: _note,
                  focusNode: _noteFocus,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: widget.onNoteChanged,
                  style: noteStyle,
                  decoration: bare.copyWith(
                    hintText: 'Add a note…',
                    hintStyle: noteStyle.copyWith(color: ff.inkFaint),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
