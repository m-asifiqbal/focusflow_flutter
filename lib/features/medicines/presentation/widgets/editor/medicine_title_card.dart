/// ============================================================
/// MEDICINE TITLE CARD — icon, name and strength (editor top card)
/// ============================================================
///
/// The pink tile shows the chosen form's icon (it flips with a small
/// rotation + scale when the form changes); the name field gets focus on
/// a new medicine; the strength is free text ("500 mg", "5 ml").
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';
import 'package:focusflow/features/medicines/presentation/notifiers/medicine_editor_controller.dart';

class MedicineTitleCard extends ConsumerStatefulWidget {
  const MedicineTitleCard({
    required this.args,
    required this.initial,
    required this.autofocus,
    super.key,
  });

  final MedicineEditorArgs args;

  /// The draft the fields start from (read once).
  final Medicine initial;
  final bool autofocus;

  @override
  ConsumerState<MedicineTitleCard> createState() => _MedicineTitleCardState();
}

class _MedicineTitleCardState extends ConsumerState<MedicineTitleCard> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _strength = TextEditingController(text: widget.initial.strength);

  @override
  void dispose() {
    _name.dispose();
    _strength.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final form = ref.watch(
      medicineEditorControllerProvider(
        widget.args,
      ).select((s) => s.valueOrNull?.draft.form ?? MedicineForm.tablet),
    );
    final c = ref.read(medicineEditorControllerProvider(widget.args).notifier);
    final colors = MedicineStyle.colors;
    InputDecoration deco(String hint) => InputDecoration(
      hintText: hint,
      isDense: true,
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      hintStyle: TextStyle(color: ff.inkFaint),
    );
    return FFCard(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: context.motion(AppMotion.slow),
            transitionBuilder: (child, a) => RotationTransition(
              turns: Tween(begin: -0.08, end: 0.0).animate(a),
              child: ScaleTransition(scale: a, child: child),
            ),
            child: FFIconTile(
              key: ValueKey(form),
              icon: MedicineStyle.icon(form),
              colors: colors,
              size: MedicineSizes.titleTile,
              iconSize: MedicineSizes.titleGlyph,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _name,
                  autofocus: widget.autofocus,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: 80,
                  buildCounter: _noCounter,
                  style: text.title,
                  decoration: deco(tr('Medicine name')),
                  onChanged: c.setName,
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: _strength,
                  textInputAction: TextInputAction.done,
                  maxLength: 40,
                  buildCounter: _noCounter,
                  style: text.meta.copyWith(color: ff.inkMuted),
                  decoration: deco(tr('Strength, e.g. 500 mg')),
                  onChanged: c.setStrength,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget? _noCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => null;
}
