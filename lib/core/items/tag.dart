/// ============================================================
/// TAG — a cross-module label (`#work`, `#design`)
/// ============================================================
///
/// Tags are shared by every module through the `item_tags` join table.
/// Names are stored normalised (no leading '#', lower case, spaces → '-'),
/// see [Tag.normalize]. [usageCount] is only filled by
/// `TagsRepository.watchTags()` (active items carrying the tag); inside an
/// item (Note.tags, TaskItem.tags …) it is 0.
/// ============================================================
library;

import 'package:flutter/foundation.dart';

@immutable
class Tag {
  const Tag({
    required this.id,
    required this.name,
    this.colorHex,
    this.usageCount = 0,
  });

  final String id;

  /// Normalised name without '#', e.g. `work`.
  final String name;

  /// `RRGGBB`; null = default tag colour.
  final String? colorHex;

  /// Number of active (not archived / deleted) items carrying this tag.
  final int usageCount;

  /// Display label with the hash: `#work`.
  String get label => '#$name';

  Tag copyWith({
    String? name,
    String? colorHex,
    bool clearColor = false,
    int? usageCount,
  }) => Tag(
    id: id,
    name: name ?? this.name,
    colorHex: clearColor ? null : (colorHex ?? this.colorHex),
    usageCount: usageCount ?? this.usageCount,
  );

  /// Normalises user input into a stored tag name: trims, strips leading
  /// '#', lower-cases and turns inner whitespace into '-'. Returns '' for
  /// input that has nothing left.
  static String normalize(String input) {
    var s = input.trim();
    while (s.startsWith('#')) {
      s = s.substring(1);
    }
    return s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
  }

  @override
  bool operator ==(Object other) =>
      other is Tag &&
      other.id == id &&
      other.name == name &&
      other.colorHex == colorHex &&
      other.usageCount == usageCount;

  @override
  int get hashCode => Object.hash(id, name, colorHex, usageCount);

  @override
  String toString() => 'Tag($label, $usageCount)';
}
