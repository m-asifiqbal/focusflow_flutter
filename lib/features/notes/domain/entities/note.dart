/// ============================================================
/// NOTE — rich-text note with optional checklist, cover and lock
/// ============================================================
///
/// Plain immutable entity. [contentDelta] (Quill Delta JSON) is the source
/// of truth for the body; [plainText] is its extracted text, used for
/// previews and full-text search; [checklist] is a cached preview of the
/// checklist lines for cards. Locked notes never expose their body in
/// lists ([preview] is empty) — the editor decrypts/unlocks on open.
/// ============================================================
library;

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';

@immutable
class ChecklistItem {
  const ChecklistItem({required this.text, this.done = false});

  final String text;
  final bool done;

  ChecklistItem copyWith({String? text, bool? done}) =>
      ChecklistItem(text: text ?? this.text, done: done ?? this.done);

  Map<String, Object?> toJson() => {'text': text, 'done': done};

  static ChecklistItem? fromJson(Object? json) {
    if (json is! Map) return null;
    final text = json['text'];
    if (text is! String) return null;
    return ChecklistItem(text: text, done: json['done'] == true);
  }

  /// Decodes the `checklist_json` column (invalid input → empty list).
  static List<ChecklistItem> decodeList(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final list = jsonDecode(json);
      if (list is! List) return const [];
      return List.unmodifiable(list.map(fromJson).whereType<ChecklistItem>());
    } on FormatException {
      return const [];
    }
  }

  static String encodeList(List<ChecklistItem> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  @override
  bool operator ==(Object other) =>
      other is ChecklistItem && other.text == text && other.done == done;

  @override
  int get hashCode => Object.hash(text, done);

  @override
  String toString() => '[${done ? 'x' : ' '}] $text';
}

@immutable
class Note {
  const Note({
    required this.id,
    this.title = '',
    this.contentDelta = '[]',
    this.plainText = '',
    this.checklist = const [],
    this.coverImagePath,
    this.isLocked = false,
    this.wordCount = 0,
    this.reminderId,
    this.reminderAt,
    this.folderId,
    this.folderName,
    this.tags = const [],
    this.colorHex,
    this.isPinned = false,
    this.isFavorite = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.deletedAt,
  });

  final String id;
  final String title;

  /// Quill Delta JSON (`[{"insert":"…\n"}]`).
  final String contentDelta;

  /// Plain text of the body (search + previews).
  final String plainText;

  /// Cached checklist lines for card previews.
  final List<ChecklistItem> checklist;

  /// Relative path (app documents) of the cover image.
  final String? coverImagePath;

  /// Requires the note's own PIN to open; previews hidden.
  final bool isLocked;
  final int wordCount;

  /// Linked reminder ("🔔 Reminder Fri").
  final String? reminderId;

  /// Next trigger of the linked reminder (joined; null when none / gone).
  final DateTime? reminderAt;
  final String? folderId;
  final String? folderName;
  final List<Tag> tags;

  /// `RRGGBB` card colour; null = white.
  final String? colorHex;
  final bool isPinned;
  final bool isFavorite;
  final double sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;

  ItemRef get ref => ItemRef(ItemType.note, id);
  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;
  bool get isActive => archivedAt == null && deletedAt == null;

  /// Nothing worth keeping (used to discard a new note on back).
  bool get isEmpty =>
      title.trim().isEmpty &&
      plainText.trim().isEmpty &&
      checklist.isEmpty &&
      coverImagePath == null;

  /// [title], else the first line of the body, else "Untitled note".
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    if (!isLocked) {
      final first = plainText.trim().split('\n').first.trim();
      if (first.isNotEmpty) return first;
    }
    return 'Untitled note';
  }

  /// Card preview: the body with whitespace collapsed (max 240 chars);
  /// empty for locked notes.
  String get preview {
    if (isLocked) return '';
    final text = plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= 240 ? text : '${text.substring(0, 240).trimRight()}…';
  }

  int get checklistDone => checklist.where((c) => c.done).length;

  Note copyWith({
    String? title,
    String? contentDelta,
    String? plainText,
    List<ChecklistItem>? checklist,
    String? coverImagePath,
    bool clearCover = false,
    bool? isLocked,
    int? wordCount,
    String? reminderId,
    bool clearReminder = false,
    DateTime? reminderAt,
    String? folderId,
    String? folderName,
    bool clearFolder = false,
    List<Tag>? tags,
    String? colorHex,
    bool clearColor = false,
    bool? isPinned,
    bool? isFavorite,
    double? sortOrder,
    DateTime? updatedAt,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => Note(
    id: id,
    title: title ?? this.title,
    contentDelta: contentDelta ?? this.contentDelta,
    plainText: plainText ?? this.plainText,
    checklist: checklist ?? this.checklist,
    coverImagePath: clearCover ? null : (coverImagePath ?? this.coverImagePath),
    isLocked: isLocked ?? this.isLocked,
    wordCount: wordCount ?? this.wordCount,
    reminderId: clearReminder ? null : (reminderId ?? this.reminderId),
    reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
    folderId: clearFolder ? null : (folderId ?? this.folderId),
    folderName: clearFolder ? null : (folderName ?? this.folderName),
    tags: tags ?? this.tags,
    colorHex: clearColor ? null : (colorHex ?? this.colorHex),
    isPinned: isPinned ?? this.isPinned,
    isFavorite: isFavorite ?? this.isFavorite,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
  );

  static const _checkEq = ListEquality<ChecklistItem>();
  static const _tagsEq = ListEquality<Tag>();

  @override
  bool operator ==(Object other) =>
      other is Note &&
      other.id == id &&
      other.title == title &&
      other.contentDelta == contentDelta &&
      other.plainText == plainText &&
      _checkEq.equals(other.checklist, checklist) &&
      other.coverImagePath == coverImagePath &&
      other.isLocked == isLocked &&
      other.wordCount == wordCount &&
      other.reminderId == reminderId &&
      other.reminderAt == reminderAt &&
      other.folderId == folderId &&
      other.folderName == folderName &&
      _tagsEq.equals(other.tags, tags) &&
      other.colorHex == colorHex &&
      other.isPinned == isPinned &&
      other.isFavorite == isFavorite &&
      other.sortOrder == sortOrder &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.archivedAt == archivedAt &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    contentDelta,
    plainText,
    _checkEq.hash(checklist),
    coverImagePath,
    isLocked,
    wordCount,
    reminderId,
    reminderAt,
    folderId,
    folderName,
    _tagsEq.hash(tags),
    colorHex,
    isPinned,
    isFavorite,
    sortOrder,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
  ]);

  @override
  String toString() => 'Note($id, $displayTitle)';
}
