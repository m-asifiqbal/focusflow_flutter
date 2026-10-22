/// ============================================================
/// HABIT WORDS — stored English words, shown in the active language
/// ============================================================
///
/// What: a habit's category ("Health") and unit ("glasses") are stored as
/// plain text: the category is one of a fixed English list, the unit is
/// free text the user typed or a template filled in. Colours, search and
/// the build ⇄ quit unit swap match them by their English spelling, and a
/// backup must read the same in every language — so the stored value never
/// changes with the language; only what is *shown* does.
/// Why [shown]: a word with an entry in the active pack (the registered
/// categories and template units) is translated; anything else — a unit the
/// user typed, a category from an import — is shown as written. It never
/// goes through `tr` itself, so a `{` typed by the user is not read as a
/// placeholder.
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';

abstract final class HabitWords {
  /// [stored] (a category or a unit) in the active language.
  static String shown(String stored) => L10n.has(stored) ? tr(stored) : stored;
}
