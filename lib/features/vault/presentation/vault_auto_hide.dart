/// ============================================================
/// VAULT AUTO-HIDE — revealed secrets hide themselves after 4 s
/// ============================================================
///
/// What: the set of revealed keys (a field name, a history row) where each
/// one carries its own timer; when it runs out the key is hidden again and
/// [onChanged] fires. [cycleOf] counts how often a key was shown, so the
/// countdown ring of the eye button restarts on every reveal.
/// Why: a password left on screen is the one thing the vault must not do;
/// the controller and the history sheet share this instead of two timers.
/// Pure Dart (a [Timer] per shown key, cancelled on [hide] / [dispose]).
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

class VaultAutoHide<K extends Object> {
  VaultAutoHide({this.duration = defaultDuration, required this.onChanged});

  /// How long a revealed secret stays on screen.
  static const Duration defaultDuration = Duration(seconds: 4);

  final Duration duration;

  /// Called after the shown set changed (by [show], [hide] or a timeout).
  final VoidCallback onChanged;

  final Map<K, Timer> _timers = {};
  final Map<K, int> _cycles = {};

  bool isShown(K key) => _timers.containsKey(key);

  /// The keys shown right now.
  Set<K> get shown => Set.unmodifiable(_timers.keys);

  /// How many times [key] has been shown (the ring's restart key).
  int cycleOf(K key) => _cycles[key] ?? 0;

  /// Shows [key] (again, restarting its countdown).
  void show(K key) {
    _timers[key]?.cancel();
    _cycles[key] = cycleOf(key) + 1;
    _timers[key] = Timer(duration, () => hide(key));
    onChanged();
  }

  void hide(K key) {
    final timer = _timers.remove(key);
    if (timer == null) return;
    timer.cancel();
    onChanged();
  }

  void toggle(K key) => isShown(key) ? hide(key) : show(key);

  void hideAll() {
    if (_timers.isEmpty) return;
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    onChanged();
  }

  /// Cancels every timer without notifying (the owner is going away).
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }
}
