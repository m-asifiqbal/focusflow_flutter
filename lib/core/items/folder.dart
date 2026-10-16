/// ============================================================
/// FOLDER — note folders, task lists and vault folders
/// ============================================================
///
/// One table (`folders`) scoped by [module]: Notes use them as folders
/// (Ideas, Work…), Tasks as lists (Work, Personal), the Vault as folders
/// (Work, Personal, Finance). Deleting a folder never deletes its items —
/// they simply lose their `folderId` (see FoldersRepository.delete).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_type.dart';

@immutable
class Folder {
  const Folder({
    required this.id,
    required this.module,
    required this.name,
    this.colorHex,
    this.iconKey,
    this.sortOrder = 0,
    this.itemCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  /// Which module the folder belongs to.
  final ItemType module;
  final String name;

  /// `RRGGBB`; null = module default.
  final String? colorHex;
  final String? iconKey;

  /// Manual order of the folder chips (lower first).
  final double sortOrder;

  /// Active (not archived / deleted) items in this folder. Filled by
  /// `FoldersRepository.watchFolders`.
  final int itemCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Folder copyWith({
    String? name,
    String? colorHex,
    bool clearColor = false,
    String? iconKey,
    double? sortOrder,
    int? itemCount,
  }) => Folder(
    id: id,
    module: module,
    name: name ?? this.name,
    colorHex: clearColor ? null : (colorHex ?? this.colorHex),
    iconKey: iconKey ?? this.iconKey,
    sortOrder: sortOrder ?? this.sortOrder,
    itemCount: itemCount ?? this.itemCount,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Folder &&
      other.id == id &&
      other.module == module &&
      other.name == name &&
      other.colorHex == colorHex &&
      other.iconKey == iconKey &&
      other.sortOrder == sortOrder &&
      other.itemCount == itemCount &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    module,
    name,
    colorHex,
    iconKey,
    sortOrder,
    itemCount,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'Folder(${module.key}/$name, $itemCount)';
}
