/// ============================================================
/// FTS QUERY — turns user input into a safe FTS5 MATCH expression
/// ============================================================
///
/// User text must never reach FTS5 syntax unescaped: characters such as
/// `"`, `*`, `:`, `(`, `^`, `-`, `AND`/`OR`/`NOT`/`NEAR` all mean something
/// to the FTS5 query parser. Every term therefore becomes a quoted string
/// (inner quotes doubled) followed by `*` for prefix matching:
///
///   `design "trends` → `"design"* AND """trends"*`
///
/// The `unicode61` tokenizer then splits each quoted string exactly like it
/// split the indexed text, so punctuation inside a term is harmless. Terms
/// without any letter or digit are dropped (an empty phrase is a syntax
/// error in FTS5).
/// ============================================================
library;

abstract final class FtsQuery {
  static final RegExp _hasWordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

  /// Splits [input] on whitespace into searchable terms (original case),
  /// dropping terms that contain no letter or digit.
  static List<String> terms(String input) => input
      .split(RegExp(r'\s+'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty && _hasWordChar.hasMatch(t))
      .toList();

  /// `"t1"* AND "t2"*` (every term must match, prefix match on the last
  /// token of each term). Restrict to one FTS column with [column]
  /// (`title : "t1"* AND title : "t2"*`). Returns null when [terms] is
  /// empty — callers must then skip the FTS query entirely.
  static String? prefixMatch(List<String> terms, {String? column}) {
    if (terms.isEmpty) return null;
    final col = column == null ? '' : '$column : ';
    return terms.map((t) => '$col"${t.replaceAll('"', '""')}"*').join(' AND ');
  }

  /// Convenience: [terms] + [prefixMatch] in one call.
  static String? fromInput(String input, {String? column}) =>
      prefixMatch(terms(input), column: column);
}
