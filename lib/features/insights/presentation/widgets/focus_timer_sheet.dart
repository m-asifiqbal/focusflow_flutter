/// ============================================================
/// FOCUS TIMER SHEET — pick a length, count down, record the session
/// ============================================================
///
/// What: [showFocusTimer] opens a bottom sheet with 25 / 45 / 60 min or a
/// custom length (5–180, step 5), a countdown ring (FFProgressRing) and
/// Start / Pause / Resume / Stop. A session that reaches its length, or is
/// stopped after ≥ 1 min, is saved as a focus session (Insights › Focus
/// hours). Closing the sheet mid-session stops and saves it too.
/// Why: the state lives in focusTimerProvider, so rebuilds never reset the
/// timer; this widget only owns the 1-second repaint timer (cancelled with
/// it). The ring animates each second unless reduce motion is on.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/domain/services/focus_timer.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';
import 'package:focusflow/features/insights/presentation/providers/focus_timer_controller.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

/// Opens the focus timer, optionally for a task (its id is stored with
/// the session). Completes when the sheet closes.
Future<void> showFocusTimer(
  BuildContext context, {
  String? taskId,
  String? taskTitle,
}) => showFFBottomSheet<void>(
  context,
  builder: (_) =>
      FocusTimerSheet(target: (taskId: taskId, taskTitle: taskTitle)),
);

class FocusTimerSheet extends ConsumerStatefulWidget {
  const FocusTimerSheet({required this.target, super.key});

  final FocusTarget target;

  @override
  ConsumerState<FocusTimerSheet> createState() => _FocusTimerSheetState();
}

class _FocusTimerSheetState extends ConsumerState<FocusTimerSheet> {
  Timer? _ticker;
  bool _custom = false;

  FocusTimerController get _controller =>
      ref.read(focusTimerProvider(widget.target).notifier);

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Runs the 1-second repaint while a session is running.
  void _syncTicker(FocusTimerState s) {
    final running = s.phase == FocusPhase.running;
    if (running && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        unawaited(_controller.tick());
      });
    } else if (!running && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  static String _clock(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(focusTimerProvider(widget.target));
    _syncTicker(s);
    final now = ref.watch(clockProvider).now();
    final ff = context.ff;
    final remaining = s.remainingAt(now);
    final title = widget.target.taskTitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            tr('Focus session'),
            textAlign: TextAlign.center,
            style: context.text.sectionTitle,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          title == null || title.trim().isEmpty
              ? tr('One thing at a time.')
              : title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Center(
          child: FFProgressRing(
            progress: s.progressAt(now),
            size: InsightsDimens.timerRing,
            stroke: InsightsDimens.timerStroke,
            duration: context.motion(AppMotion.slow),
            semanticLabel: tr('{v} remaining of {plannedMinutes} minutes', {
              'v': _clock(remaining),
              'plannedMinutes': s.plannedMinutes,
            }),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _clock(remaining),
                    style: context.text.heroNumber.copyWith(
                      fontSize: InsightsDimens.timerDigits,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Text(switch (s.phase) {
                  FocusPhase.setup => tr('{plannedMinutes} min', {
                    'plannedMinutes': s.plannedMinutes,
                  }),
                  FocusPhase.running => tr('Focusing'),
                  FocusPhase.paused => tr('Paused'),
                  FocusPhase.finished => tr('Complete'),
                }, style: context.text.meta),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        ...switch (s.phase) {
          FocusPhase.setup => _setup(context, s),
          FocusPhase.running => [
            _pair(
              FFSecondaryButton(
                label: tr('Pause'),
                icon: FontAwesomeIcons.pause,
                onPressed: _controller.pause,
              ),
              FFSoftDangerButton(
                label: tr('Stop'),
                icon: FontAwesomeIcons.stop,
                onPressed: _stop,
              ),
            ),
          ],
          FocusPhase.paused => [
            _pair(
              FFSecondaryButton(
                label: tr('Resume'),
                icon: FontAwesomeIcons.play,
                onPressed: _controller.resume,
              ),
              FFSoftDangerButton(
                label: tr('Stop'),
                icon: FontAwesomeIcons.stop,
                onPressed: _stop,
              ),
            ),
          ],
          FocusPhase.finished => [
            Text(
              s.savedMinutes == null
                  ? tr('Under a minute, so nothing was saved.')
                  : tr('Saved {savedMinutes} min of focus. Nice work!', {
                      'savedMinutes': s.savedMinutes,
                    }),
              textAlign: TextAlign.center,
              style: context.text.rowTitle.copyWith(color: ff.ink),
            ),
            const SizedBox(height: AppSpacing.lg),
            _pair(
              FFSecondaryButton(
                label: tr('Again'),
                icon: FontAwesomeIcons.arrowRotateRight,
                onPressed: _controller.reset,
              ),
              FFPrimaryButton(
                label: tr('Done'),
                height: AppSizes.secondaryButton,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        },
      ],
    );
  }

  Future<void> _stop() async {
    await _controller.stop();
  }

  Widget _pair(Widget a, Widget b) => Row(
    children: [
      Expanded(child: a),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: b),
    ],
  );

  List<Widget> _setup(BuildContext context, FocusTimerState s) {
    final isPreset = !_custom && FocusTimer.presets.contains(s.plannedMinutes);
    return [
      Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final m in FocusTimer.presets)
            FFChip(
              label: tr('{m} min', {'m': m}),
              selected: isPreset && s.plannedMinutes == m,
              onTap: () {
                setState(() => _custom = false);
                _controller.setMinutes(m);
              },
            ),
          FFChip(
            label: tr('Custom'),
            selected: !isPreset,
            onTap: () => setState(() => _custom = true),
          ),
        ],
      ),
      if (!isPreset) ...[
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FFRoundIconButton(
              icon: FontAwesomeIcons.minus,
              semanticLabel: tr('Five minutes less'),
              onPressed: s.plannedMinutes <= FocusTimer.minMinutes
                  ? null
                  : () => _controller.setMinutes(
                      s.plannedMinutes - FocusTimer.customStep,
                    ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Text(
              tr('{plannedMinutes} min', {'plannedMinutes': s.plannedMinutes}),
              style: context.text.stat,
            ),
            const SizedBox(width: AppSpacing.lg),
            FFRoundIconButton(
              icon: FontAwesomeIcons.plus,
              semanticLabel: tr('Five minutes more'),
              onPressed: s.plannedMinutes >= FocusTimer.maxMinutes
                  ? null
                  : () => _controller.setMinutes(
                      s.plannedMinutes + FocusTimer.customStep,
                    ),
            ),
          ],
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
      FFPrimaryButton(
        label: tr('Start focus'),
        icon: FontAwesomeIcons.play,
        onPressed: _controller.start,
      ),
    ];
  }
}
