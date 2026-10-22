/// ============================================================
/// FF SWIPE ACTIONS — swipe-to-reveal row actions (screen 10)
/// ============================================================
///
/// Swipe toward the start edge → reveals [FFSwipeActions.endActions]
/// (Archive slate + Delete rose) in a rounded panel 8 pt from the card;
/// swipe toward the end edge → reveals the optional [startAction]
/// (Complete / Pin). Release past half the panel to keep it open; a full
/// swipe (> 55% of the width) runs the start action (and, if enabled, the
/// outermost end action). Haptic ticks on each threshold (FFHaptics).
///
/// * One open row at a time per [FFSwipeGroup] (default: app-wide).
/// * Tapping outside (or on the row) closes it.
/// * RTL-aware: "start"/"end" follow the reading direction.
/// * Screen readers get every action as a custom semantics action.
/// ============================================================
library;

// A nullable preset label resolves to tr() when read (it must follow the
// language), and a private field cannot be a named initializing formal.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/ff_haptics.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/theme/fa_icons.dart';

enum _Tone { custom, archive, delete, complete, pin }

/// One revealed action.
@immutable
class FFSwipeAction {
  const FFSwipeAction({
    required this.icon,
    required String label,
    required this.onTap,
    required Color this.color,
  }) : _label = label,
       _tone = _Tone.custom;

  /// Slate "Archive".
  const FFSwipeAction.archive({
    required this.onTap,
    String? label,
    this.icon = FontAwesomeIcons.boxArchive,
  }) : color = null,
       _label = label,
       _tone = _Tone.archive;

  /// Rose "Delete".
  const FFSwipeAction.delete({
    required this.onTap,
    String? label,
    this.icon = FontAwesomeIcons.trashCan,
  }) : color = null,
       _label = label,
       _tone = _Tone.delete;

  /// Primary "Complete".
  const FFSwipeAction.complete({
    required this.onTap,
    String? label,
    this.icon = FontAwesomeIcons.check,
  }) : color = null,
       _label = label,
       _tone = _Tone.complete;

  /// Amber "Pin".
  const FFSwipeAction.pin({
    required this.onTap,
    String? label,
    this.icon = FontAwesomeIcons.thumbtack,
  }) : color = null,
       _label = label,
       _tone = _Tone.pin;

  final IconData icon;
  final String? _label;

  /// The given label, else the preset's own text in the active language.
  String get label =>
      _label ??
      switch (_tone) {
        _Tone.archive => tr('Archive'),
        _Tone.delete => tr('Delete'),
        _Tone.complete => tr('Complete'),
        _Tone.pin => tr('Pin'),
        _Tone.custom => '',
      };
  final VoidCallback onTap;
  final Color? color;
  final _Tone _tone;

  Color _resolve(FFColors ff) =>
      color ??
      switch (_tone) {
        _Tone.archive => ff.neutralSolid,
        _Tone.delete => ff.dangerSolid,
        _Tone.complete => ff.primaryGradient.colors.first,
        _Tone.pin => ModuleStyle.vault.solid,
        _Tone.custom => ff.primary,
      };
}

/// Keeps at most one [FFSwipeActions] row open.
class FFSwipeGroup {
  FFSwipeGroup();

  /// Default app-wide group.
  static final FFSwipeGroup global = FFSwipeGroup();

  _FFSwipeActionsState? _open;

  void _didOpen(_FFSwipeActionsState row) {
    if (identical(_open, row)) return;
    final previous = _open;
    _open = row;
    previous?._close();
  }

  void _didClose(_FFSwipeActionsState row) {
    if (identical(_open, row)) _open = null;
  }

  /// Closes whichever row is open.
  void closeAll() {
    final open = _open;
    _open = null;
    open?._close();
  }
}

class FFSwipeActions extends StatefulWidget {
  const FFSwipeActions({
    required this.child,
    this.endActions = const [],
    this.startAction,
    this.group,
    this.radius = AppRadii.card,
    this.actionWidth = 72,
    this.gap = AppSpacing.sm,
    this.fullSwipeStart = true,
    this.fullSwipeEnd = false,
    this.enabled = true,
    super.key,
  });

  final Widget child;

  /// Revealed at the end edge (right in LTR), outermost last.
  final List<FFSwipeAction> endActions;

  /// Revealed at the start edge (left in LTR).
  final FFSwipeAction? startAction;

  /// Defaults to [FFSwipeGroup.global].
  final FFSwipeGroup? group;

  /// Panel corner radius (match the card).
  final double radius;
  final double actionWidth;

  /// Space between the card and the panel.
  final double gap;

  /// Full swipe toward the end edge runs [startAction].
  final bool fullSwipeStart;

  /// Full swipe toward the start edge runs the outermost end action.
  final bool fullSwipeEnd;
  final bool enabled;

  @override
  State<FFSwipeActions> createState() => _FFSwipeActionsState();
}

class _FFSwipeActionsState extends State<FFSwipeActions>
    with SingleTickerProviderStateMixin {
  /// Positive = end actions revealed; negative = start action revealed.
  /// Created eagerly: a disabled row never touches it, and creating it
  /// lazily in dispose() would look up TickerMode on a deactivated element.
  late final AnimationController _ctrl;
  double _width = 0;
  bool _pastOpen = false;
  bool _pastFull = false;

  FFSwipeGroup get _group => widget.group ?? FFSwipeGroup.global;
  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  double get _endExtent => widget.endActions.isEmpty
      ? 0
      : widget.endActions.length * widget.actionWidth + widget.gap;
  double get _startExtent =>
      widget.startAction == null ? 0 : widget.actionWidth + widget.gap;
  double get _fullThreshold => _width * 0.55;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _group._didClose(this);
    _ctrl.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    _ctrl.stop();
    _pastOpen = _ctrl.value.abs() > 0;
    _pastFull = false;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final raw = details.primaryDelta ?? 0;
    var delta = _rtl ? raw : -raw;
    final x = _ctrl.value;
    final endMax = widget.fullSwipeEnd ? _width : _endExtent;
    final startMax = widget.startAction == null
        ? 0.0
        : (widget.fullSwipeStart ? _width : _startExtent);
    // Rubber-band past the panel when a full swipe isn't allowed.
    if ((x > _endExtent && !widget.fullSwipeEnd && delta > 0) ||
        (x < -_startExtent && !widget.fullSwipeStart && delta < 0)) {
      delta *= 0.3;
    }
    final next = (x + delta).clamp(-startMax - 24, endMax + 24);
    _ctrl.value = next;

    final open = next > _endExtent / 2 || -next > _startExtent / 2;
    if (open != _pastOpen) {
      _pastOpen = open;
      if (open) FFHaptics.selection(context);
    }
    final full =
        (next > _fullThreshold && widget.fullSwipeEnd) ||
        (-next > _fullThreshold && widget.fullSwipeStart);
    if (full != _pastFull) {
      _pastFull = full;
      if (full) FFHaptics.medium(context);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final raw = details.primaryVelocity ?? 0;
    final v = _rtl ? raw : -raw;
    final x = _ctrl.value;
    if (x > 0) {
      if (widget.fullSwipeEnd && x > _fullThreshold) {
        _run(widget.endActions.last);
        return;
      }
      final open = v > 400 || (v > -400 && x > _endExtent / 2);
      _animateTo(open ? _endExtent : 0);
    } else if (x < 0) {
      if (widget.fullSwipeStart && -x > _fullThreshold) {
        _run(widget.startAction!);
        return;
      }
      final open = v < -400 || (v < 400 && -x > _startExtent / 2);
      _animateTo(open ? -_startExtent : 0);
    }
  }

  void _animateTo(double target) {
    if (target == 0) {
      _group._didClose(this);
    } else {
      _group._didOpen(this);
    }
    if (!mounted) return;
    if (context.reduceMotion) {
      _ctrl.value = target;
    } else {
      _ctrl.animateTo(
        target,
        duration: AppMotion.normal,
        curve: AppMotion.curve,
      );
    }
  }

  void _close() {
    if (mounted && _ctrl.value != 0) _animateTo(0);
  }

  void _run(FFSwipeAction action) {
    _animateTo(0);
    action.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final actions = [?widget.startAction, ...widget.endActions];
    if (!widget.enabled || actions.isEmpty) return widget.child;
    final rtl = _rtl;
    return Semantics(
      customSemanticsActions: {
        for (final a in actions)
          CustomSemanticsAction(label: a.label): () => a.onTap(),
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          _width = constraints.maxWidth.isFinite ? constraints.maxWidth : 400;
          return TapRegion(
            onTapOutside: (_) => _close(),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: AnimatedBuilder(
                animation: _ctrl,
                child: widget.child,
                builder: (context, child) {
                  final x = _ctrl.value;
                  final open = x.abs() > 0.5;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: x > 0 && widget.endActions.isNotEmpty
                            ? _Panel(
                                actions: widget.endActions,
                                width: x - widget.gap,
                                alignment: AlignmentDirectional.centerEnd,
                                radius: widget.radius,
                                actionWidth: widget.actionWidth,
                                onRun: _run,
                              )
                            : const SizedBox.shrink(),
                      ),
                      Positioned.fill(
                        child: x < 0 && widget.startAction != null
                            ? _Panel(
                                actions: [widget.startAction!],
                                width: -x - widget.gap,
                                alignment: AlignmentDirectional.centerStart,
                                radius: widget.radius,
                                actionWidth: widget.actionWidth,
                                onRun: _run,
                              )
                            : const SizedBox.shrink(),
                      ),
                      Transform.translate(
                        offset: Offset(rtl ? x : -x, 0),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: open ? _close : null,
                          child: AbsorbPointer(absorbing: open, child: child),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.actions,
    required this.width,
    required this.alignment,
    required this.radius,
    required this.actionWidth,
    required this.onRun,
  });

  final List<FFSwipeAction> actions;
  final double width;
  final AlignmentDirectional alignment;
  final double radius;
  final double actionWidth;
  final ValueChanged<FFSwipeAction> onRun;

  @override
  Widget build(BuildContext context) {
    if (width <= 0) return const SizedBox.shrink();
    final ff = context.ff;
    final style = context.text.buttonSmall.copyWith(
      fontSize: 13,
      color: ff.onGradient,
    );
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final a in actions)
                Expanded(
                  child: Semantics(
                    button: true,
                    label: a.label,
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        FFHaptics.light(context);
                        onRun(a);
                      },
                      child: ColoredBox(
                        color: a._resolve(ff),
                        child: ClipRect(
                          child: OverflowBox(
                            minWidth: 0,
                            maxWidth: actionWidth,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(a.icon, size: 18, color: ff.onGradient),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs,
                                  ),
                                  child: Text(
                                    a.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: style,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
