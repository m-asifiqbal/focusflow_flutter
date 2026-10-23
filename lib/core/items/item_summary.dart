/// ============================================================
/// ITEM SUMMARY — one row of a mixed, cross-module list
/// ============================================================
///
/// Archive (23), Recently Deleted (24), Pinned / Favourites / by-tag lists
/// (Library) and the item actions sheet show items of every module with the
/// same row widget; this is the module-agnostic data behind such a row.
/// It never contains secrets: vault items expose only their plaintext
/// title and type label, locked notes no body text.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';

@immutable
class ItemSummary {
  const ItemSummary({
    required this.ref,
    required this.title,
    this.meta = '',
    this.colorHex,
    this.isPinned = false,
    this.isFavorite = false,
    this.folderId,
    this.folderName,
    this.isLocked = false,
    this.isCompleted = false,
    this.scheduledAt,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.deletedAt,
  });

  final ItemRef ref;

  /// Note / task / reminder / vault title, habit name (may be empty for an
  /// untitled note — use [displayTitle]).
  final String title;

  /// Short secondary text: note preview (empty when locked), task notes,
  /// reminder note, habit category, vault type label ("Login").
  final String meta;
  final String? colorHex;
  final bool isPinned;
  final bool isFavorite;
  final String? folderId;
  final String? folderName;

  /// Locked note (its own PIN) or vault item (the vault PIN) — opening asks
  /// for it.
  final bool isLocked;

  /// Task completed / one-time reminder done.
  final bool isCompleted;

  /// Task due (date + time) or reminder trigger; null for other modules.
  final DateTime? scheduledAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;

  ItemType get type => ref.type;
  String get id => ref.id;
  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;
  bool get isActive => archivedAt == null && deletedAt == null;

  /// [title], or a module fallback ("Untitled note") when empty.
  String get displayTitle => title.trim().isEmpty
      ? switch (type) {
          ItemType.note => tr('Untitled note'),
          ItemType.task => tr('Untitled task'),
          ItemType.reminder => tr('Untitled reminder'),
          ItemType.habit => tr('Untitled habit'),
          ItemType.medicine => tr('Untitled medicine'),
          ItemType.vault => tr('Untitled password'),
        }
      : title;

  /// Whole days left before the 30-day purge removes this trashed item
  /// (rounded up; 0 when due). Null when the item is not in the trash.
  int? daysUntilPurge(
    DateTime now, {
    Duration retention = const Duration(days: 30),
  }) {
    final deleted = deletedAt;
    if (deleted == null) return null;
    final left = deleted.add(retention).difference(now);
    if (left <= Duration.zero) return 0;
    return (left.inMinutes / Duration.minutesPerDay).ceil();
  }

  ItemSummary copyWith({
    String? title,
    String? meta,
    bool? isPinned,
    bool? isFavorite,
    String? folderName,
  }) => ItemSummary(
    ref: ref,
    title: title ?? this.title,
    meta: meta ?? this.meta,
    colorHex: colorHex,
    isPinned: isPinned ?? this.isPinned,
    isFavorite: isFavorite ?? this.isFavorite,
    folderId: folderId,
    folderName: folderName ?? this.folderName,
    isLocked: isLocked,
    isCompleted: isCompleted,
    scheduledAt: scheduledAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
    deletedAt: deletedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is ItemSummary &&
      other.ref == ref &&
      other.title == title &&
      other.meta == meta &&
      other.colorHex == colorHex &&
      other.isPinned == isPinned &&
      other.isFavorite == isFavorite &&
      other.folderId == folderId &&
      other.folderName == folderName &&
      other.isLocked == isLocked &&
      other.isCompleted == isCompleted &&
      other.scheduledAt == scheduledAt &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.archivedAt == archivedAt &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(
    ref,
    title,
    meta,
    colorHex,
    isPinned,
    isFavorite,
    folderId,
    folderName,
    isLocked,
    isCompleted,
    scheduledAt,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
  );

  @override
  String toString() => 'ItemSummary($ref, $title)';
}
