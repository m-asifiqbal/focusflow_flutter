/// ============================================================
/// QUICK CAPTURE FIELD — "Try “Pay rent tomorrow 9am”" + mic + preview
/// ============================================================
///
/// What: the 52 pt capture input of screen 04 (wand icon · text · mic), a
/// round submit button once there is text, a pulsing mic while dictating,
/// and the parsed-preview chip row ("Reminder · Tomorrow 09:00 AM · #home")
/// shown before the editor opens.
/// Why: state lives in [quickAddControllerProvider]; this widget only
/// mirrors it into a TextEditingController (dictation writes the text).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/quick_add/domain/entities/quick_capture.dart';
import 'package:focusflow/features/quick_add/presentation/providers/quick_add_providers.dart';
import 'package:focusflow/features/quick_add/presentation/widgets/quick_capture_preview_row.dart';

class QuickCaptureField extends ConsumerStatefulWidget {
  const QuickCaptureField({
    required this.args,
    required this.onSubmit,
    super.key,
  });

  final QuickAddArgs args;

  /// Called with the parsed capture when the user submits.
  final ValueChanged<QuickCapture> onSubmit;

  @override
  ConsumerState<QuickCaptureField> createState() => _QuickCaptureFieldState();
}

class _QuickCaptureFieldState extends ConsumerState<QuickCaptureField> {
  late final TextEditingController _controller;
  final _focus = FocusNode();
  bool _micUnavailable = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(quickAddControllerProvider(widget.args)).text,
    );
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final capture = ref.read(quickCapturePreviewProvider(widget.args));
    if (capture != null) widget.onSubmit(capture);
  }

  Future<void> _toggleMic() async {
    final notifier = ref.read(quickAddControllerProvider(widget.args).notifier);
    final ok = await notifier.toggleListening();
    if (mounted) setState(() => _micUnavailable = !ok);
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final provider = quickAddControllerProvider(widget.args);
    // Dictation writes the text: mirror it into the field.
    ref.listen(provider.select((s) => s.text), (_, text) {
      if (_controller.text != text) {
        _controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    });
    final listening = ref.watch(provider.select((s) => s.listening));
    final capture = ref.watch(quickCapturePreviewProvider(widget.args));
    final focused = _focus.hasFocus || listening;
    final textStyle = context.text.bodySmall.copyWith(
      height: 1.3,
      color: ff.ink,
    );

    final field = AnimatedContainer(
      duration: context.motion(AppMotion.fast),
      curve: AppMotion.curve,
      constraints: const BoxConstraints(minHeight: AppSizes.search),
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        end: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: ff.surface,
        borderRadius: BorderRadius.circular(AppRadii.row),
        border: Border.all(
          color: focused ? ff.primary : ff.chipBorder,
          width: AppSizes.hairline,
        ),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              FontAwesomeIcons.wandMagicSparkles,
              size: AppSizes.heroGlyph,
              color: ff.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              onChanged: ref.read(provider.notifier).setText,
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              style: textStyle,
              cursorColor: ff.primary,
              maxLines: 1,
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: listening
                    ? tr('Listening…')
                    : tr('Try “Pay rent tomorrow 9am”'),
                hintMaxLines: 1,
                hintStyle: textStyle.copyWith(color: ff.inkFaint),
              ),
            ),
          ),
          _MicButton(listening: listening, onTap: _toggleMic),
          if (capture != null)
            _SubmitButton(kind: capture.kind, onTap: _submit),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        field,
        if (_micUnavailable && !listening)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: AppSpacing.sm,
              start: AppSpacing.xs,
            ),
            child: Text(
              tr(
                'Speech recognition isn’t available. Check microphone permission in Settings.',
              ),
              style: context.text.meta.copyWith(color: ff.danger),
            ),
          ),
        AnimatedSize(
          duration: context.motion(AppMotion.normal),
          curve: AppMotion.curve,
          alignment: AlignmentDirectional.topStart,
          child: capture == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
                  child: QuickCapturePreviewRow(capture: capture),
                ),
        ),
      ],
    );
  }
}

/// Mic toggle; a soft halo pulses while listening (static under reduce
/// motion).
class _MicButton extends StatefulWidget {
  const _MicButton({required this.listening, required this.onTap});

  final bool listening;
  final VoidCallback onTap;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppMotion.slow * 3,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.listening && !context.reduceMotion) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = widget.listening ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      button: true,
      toggled: widget.listening,
      label: widget.listening ? tr('Stop dictation') : tr('Dictate'),
      excludeSemantics: true,
      child: FFPressable(
        onTap: widget.onTap,
        child: SizedBox.square(
          dimension: AppSizes.minTap,
          child: Center(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => Container(
                width: AppSizes.iconTileSm + 4 * _pulse.value,
                height: AppSizes.iconTileSm + 4 * _pulse.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.listening
                      ? ff.danger.withValues(alpha: 0.12 + 0.1 * _pulse.value)
                      : null,
                ),
                child: child,
              ),
              child: Icon(
                FontAwesomeIcons.microphone,
                size: AppSizes.heroGlyph,
                color: widget.listening ? ff.danger : ff.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.kind, required this.onTap});

  final QuickCaptureKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      button: true,
      label: tr('Create {toLowerCase}', {
        'toLowerCase': kind.label.toLowerCase(),
      }),
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: SizedBox.square(
          dimension: AppSizes.minTap,
          child: Center(
            child: Container(
              width: AppSizes.iconTileSm,
              height: AppSizes.iconTileSm,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ff.primary,
              ),
              child: Icon(
                FontAwesomeIcons.arrowUp,
                size: AppSizes.tileGlyph,
                color: ff.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
