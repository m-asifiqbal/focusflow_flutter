/// ============================================================
/// FF PROGRESS DIALOG — a blocking "Working…" dialog with its own handle
/// ============================================================
///
/// What: [showFFProgressDialog] pushes the centred dialog with a spinner and
/// a line ("Restoring…"); back and the barrier can't close it. It returns an
/// [FFProgressHandle] whose [FFProgressHandle.close] removes exactly this
/// dialog — also when other routes were pushed above it meanwhile — and is
/// safe to call more than once.
/// Why: closing a progress dialog with a plain `Navigator.pop()` closes
/// whatever is on top. When anything else landed above it (a second flow,
/// a sheet), the wrong route went away and the un-dismissable dialog stayed
/// for good — the app looked frozen.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/widgets/ff_banners.dart';
import 'package:focusflow/core/widgets/ff_dialog.dart';

/// Closes the dialog [showFFProgressDialog] opened.
class FFProgressHandle {
  FFProgressHandle._(this._navigator, this._route);

  final NavigatorState _navigator;
  final Route<void> _route;
  bool _closed = false;

  /// Removes the dialog (no-op when it is already gone).
  void close() {
    if (_closed) return;
    _closed = true;
    if (!_navigator.mounted || !_route.isActive) return;
    if (_route.isCurrent) {
      _navigator.pop();
    } else {
      _navigator.removeRoute(_route);
    }
  }
}

/// Shows a blocking dialog with [message] until the handle is closed.
FFProgressHandle showFFProgressDialog(BuildContext context, String message) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = ffDialogRoute<void>(
    context,
    navigator: navigator,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: FFDialog(content: FFLoadingView(message: message)),
    ),
  );
  navigator.push(route);
  return FFProgressHandle._(navigator, route);
}
