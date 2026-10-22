/// ============================================================
/// DANGER CONFIRM DIALOG — "type DELETE" (+ vault PIN) confirmation
/// ============================================================
///
/// Used by Erase local data and Delete account & Drive data. The confirm
/// button enables once the user typed DELETE (case-sensitive) and — when a
/// vault exists — a PIN; the PIN is checked through [verifyPin] before the
/// dialog closes, so a wrong PIN shows inline and nothing is erased.
/// The PIN is never stored or logged.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/widgets/widgets.dart';

/// Returns true only when confirmed (and the PIN, if asked, was right).
Future<bool> showDangerConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required bool askPin,
  required Future<bool> Function(String pin) verifyPin,
  IconData icon = FontAwesomeIcons.triangleExclamation,
}) async {
  final ok = await showFFDialog<bool>(
    context,
    builder: (_) => _DangerDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      askPin: askPin,
      verifyPin: verifyPin,
      icon: icon,
    ),
  );
  return ok ?? false;
}

class _DangerDialog extends StatefulWidget {
  const _DangerDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.askPin,
    required this.verifyPin,
    required this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool askPin;
  final Future<bool> Function(String pin) verifyPin;
  final IconData icon;

  @override
  State<_DangerDialog> createState() => _DangerDialogState();
}

class _DangerDialogState extends State<_DangerDialog> {
  static const _word = 'DELETE';
  final _word$ = TextEditingController();
  final _pin = TextEditingController();
  bool _checking = false;
  String? _pinError;

  @override
  void initState() {
    super.initState();
    _word$.addListener(_rebuild);
    _pin.addListener(_rebuild);
  }

  void _rebuild() => setState(() => _pinError = null);

  @override
  void dispose() {
    _word$.dispose();
    _pin.dispose();
    super.dispose();
  }

  bool get _ready =>
      _word$.text.trim() == _word && (!widget.askPin || _pin.text.length >= 4);

  Future<void> _confirm() async {
    if (!widget.askPin) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _checking = true);
    final ok = await widget.verifyPin(_pin.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      _pin.clear();
      setState(() {
        _checking = false;
        _pinError = tr('Wrong vault PIN');
      });
    }
  }

  /// [sentence] (already translated, with the word filled in) split around
  /// the typed word so only that word is emphasised, wherever the language
  /// puts it.
  List<InlineSpan> _typeToConfirm(String sentence, TextStyle emphasis) {
    final at = sentence.indexOf(_word);
    if (at < 0) return [TextSpan(text: sentence)];
    return [
      TextSpan(text: sentence.substring(0, at)),
      TextSpan(text: _word, style: emphasis),
      TextSpan(text: sentence.substring(at + _word.length)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    return FFDialog(
      icon: widget.icon,
      iconColor: ff.dangerSolid,
      iconBackground: ff.dangerSoft,
      title: widget.title,
      message: widget.message,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: _typeToConfirm(
                tr('Type {word} to confirm', {'word': _word}),
                TextStyle(fontWeight: FontWeight.w800, color: ff.dangerStrong),
              ),
            ),
            style: text.meta,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _word$,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: _word),
          ),
          if (widget.askPin) ...[
            const SizedBox(height: AppSpacing.md),
            Text(tr('Vault PIN'), style: text.meta),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: InputDecoration(
                hintText: '••••',
                errorText: _pinError,
              ),
            ),
          ],
        ],
      ),
      actions: [
        FFDangerButton(
          label: widget.confirmLabel,
          loading: _checking,
          onPressed: _ready && !_checking ? _confirm : null,
        ),
        FFTextButton(
          label: tr('Cancel'),
          style: text.button.copyWith(fontSize: 17, color: ff.inkMuted),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
