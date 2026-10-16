/// ============================================================
/// SETTINGS ENTRY — one searchable row of Settings or a sub-page
/// ============================================================
///
/// What: the unit of the Settings search index (screen 30 "Search
/// settings…"): a title, the page it lives on, extra keywords and where
/// tapping it goes.
/// Why: search must find rows on *every* sub-page, not only the visible
/// ones, and deep-link straight to them — a static, pure-Dart index keeps
/// that testable and independent of the widgets.
/// ============================================================
library;

/// Root-screen rows whose tap runs an in-place action (a picker sheet)
/// rather than opening a page.
enum SettingsRootAction {
  language,
  startScreen,
  weekStart,
  dateTimeFormat,
  hideInSwitcher,
  feedback,
  help,
  rate,
}

class SettingsEntry {
  const SettingsEntry({
    required this.title,
    required this.page,
    this.keywords = const [],
    this.route,
    this.action,
  }) : assert(route != null || action != null);

  final String title;

  /// Where the row lives ("Appearance", "Vault security"); shown as the
  /// result's subtitle.
  final String page;

  /// Synonyms the user might type ("dark", "font", "pin").
  final List<String> keywords;

  /// Deep link opened by the result (null for [action] rows).
  final String? route;

  /// In-place action on the root screen.
  final SettingsRootAction? action;

  /// Lower-cased haystack for matching.
  String get _haystack => [title, page, ...keywords].join(' ').toLowerCase();

  /// Match score for [tokens] (all must match); 0 = no match. Title
  /// starts with the whole query > title prefix > title word > title
  /// substring > page/keywords.
  int score(List<String> tokens) {
    if (tokens.isEmpty) return 0;
    final hay = _haystack;
    if (!tokens.every(hay.contains)) return 0;
    final t = title.toLowerCase();
    final first = tokens.first;
    if (t.startsWith(tokens.join(' '))) return 5;
    if (t.startsWith(first)) return 4;
    if (t.split(RegExp(r'[\s&·]+')).any((w) => w.startsWith(first))) return 3;
    if (t.contains(first)) return 2;
    return 1;
  }
}

/// Entries of [index] matching [query], best first (stable within a score).
List<SettingsEntry> searchSettings(List<SettingsEntry> index, String query) {
  final tokens = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return const [];
  final scored = <(int, int, SettingsEntry)>[];
  for (var i = 0; i < index.length; i++) {
    final s = index[i].score(tokens);
    if (s > 0) scored.add((s, i, index[i]));
  }
  scored.sort((a, b) {
    final byScore = b.$1.compareTo(a.$1);
    return byScore != 0 ? byScore : a.$2.compareTo(b.$2);
  });
  return [for (final e in scored) e.$3];
}
