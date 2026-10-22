// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $NotesTable extends Notes with TableInfo<$NotesTable, NoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<double> sortOrder = GeneratedColumn<double>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncVersionMeta = const VerificationMeta(
    'syncVersion',
  );
  @override
  late final GeneratedColumn<int> syncVersion = GeneratedColumn<int>(
    'sync_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _contentDeltaMeta = const VerificationMeta(
    'contentDelta',
  );
  @override
  late final GeneratedColumn<String> contentDelta = GeneratedColumn<String>(
    'content_delta',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _plainTextMeta = const VerificationMeta(
    'plainText',
  );
  @override
  late final GeneratedColumn<String> plainText = GeneratedColumn<String>(
    'plain_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _checklistJsonMeta = const VerificationMeta(
    'checklistJson',
  );
  @override
  late final GeneratedColumn<String> checklistJson = GeneratedColumn<String>(
    'checklist_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _coverImagePathMeta = const VerificationMeta(
    'coverImagePath',
  );
  @override
  late final GeneratedColumn<String> coverImagePath = GeneratedColumn<String>(
    'cover_image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isLockedMeta = const VerificationMeta(
    'isLocked',
  );
  @override
  late final GeneratedColumn<bool> isLocked = GeneratedColumn<bool>(
    'is_locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lockVerifierMeta = const VerificationMeta(
    'lockVerifier',
  );
  @override
  late final GeneratedColumn<String> lockVerifier = GeneratedColumn<String>(
    'lock_verifier',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wordCountMeta = const VerificationMeta(
    'wordCount',
  );
  @override
  late final GeneratedColumn<int> wordCount = GeneratedColumn<int>(
    'word_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _reminderIdMeta = const VerificationMeta(
    'reminderId',
  );
  @override
  late final GeneratedColumn<String> reminderId = GeneratedColumn<String>(
    'reminder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
    isPinned,
    isFavorite,
    colorHex,
    folderId,
    sortOrder,
    syncVersion,
    lastSyncedAt,
    deviceId,
    title,
    contentDelta,
    plainText,
    checklistJson,
    coverImagePath,
    isLocked,
    lockVerifier,
    wordCount,
    reminderId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('sync_version')) {
      context.handle(
        _syncVersionMeta,
        syncVersion.isAcceptableOrUnknown(
          data['sync_version']!,
          _syncVersionMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('content_delta')) {
      context.handle(
        _contentDeltaMeta,
        contentDelta.isAcceptableOrUnknown(
          data['content_delta']!,
          _contentDeltaMeta,
        ),
      );
    }
    if (data.containsKey('plain_text')) {
      context.handle(
        _plainTextMeta,
        plainText.isAcceptableOrUnknown(data['plain_text']!, _plainTextMeta),
      );
    }
    if (data.containsKey('checklist_json')) {
      context.handle(
        _checklistJsonMeta,
        checklistJson.isAcceptableOrUnknown(
          data['checklist_json']!,
          _checklistJsonMeta,
        ),
      );
    }
    if (data.containsKey('cover_image_path')) {
      context.handle(
        _coverImagePathMeta,
        coverImagePath.isAcceptableOrUnknown(
          data['cover_image_path']!,
          _coverImagePathMeta,
        ),
      );
    }
    if (data.containsKey('is_locked')) {
      context.handle(
        _isLockedMeta,
        isLocked.isAcceptableOrUnknown(data['is_locked']!, _isLockedMeta),
      );
    }
    if (data.containsKey('lock_verifier')) {
      context.handle(
        _lockVerifierMeta,
        lockVerifier.isAcceptableOrUnknown(
          data['lock_verifier']!,
          _lockVerifierMeta,
        ),
      );
    }
    if (data.containsKey('word_count')) {
      context.handle(
        _wordCountMeta,
        wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta),
      );
    }
    if (data.containsKey('reminder_id')) {
      context.handle(
        _reminderIdMeta,
        reminderId.isAcceptableOrUnknown(data['reminder_id']!, _reminderIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      ),
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sort_order'],
      )!,
      syncVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_version'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      contentDelta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_delta'],
      )!,
      plainText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plain_text'],
      )!,
      checklistJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checklist_json'],
      )!,
      coverImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_image_path'],
      ),
      isLocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_locked'],
      )!,
      lockVerifier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lock_verifier'],
      ),
      wordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}word_count'],
      )!,
      reminderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_id'],
      ),
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class NoteRow extends DataClass implements Insertable<NoteRow> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final bool isPinned;
  final bool isFavorite;

  /// `RRGGBB`; null = module default / white card.
  final String? colorHex;

  /// Folder (notes/vault) or list (tasks). See [Folders].
  final String? folderId;

  /// Manual sort position (lower first). Fractional so a drag only rewrites
  /// the moved row.
  final double sortOrder;
  final int syncVersion;
  final DateTime? lastSyncedAt;

  /// Device that last wrote the row (core/storage/device_id).
  final String deviceId;
  final String title;

  /// Quill Delta JSON (`[{"insert":"…"}]`). Source of truth for the body.
  final String contentDelta;

  /// Plain text extracted from the delta — previews + full-text search.
  final String plainText;

  /// Cached checklist preview: JSON `[{"text":"…","done":true}]`.
  final String checklistJson;

  /// Relative path (under app documents) of the cover image, if any.
  final String? coverImagePath;

  /// Locked notes need their own PIN to open; previews are hidden.
  final bool isLocked;

  /// Argon2id verifier of the note's own PIN (`v1:m:t:salt:hash`, see
  /// NotePinService) — never the PIN. Null on a locked note = a legacy lock
  /// made with the vault PIN, which still opens with it.
  final String? lockVerifier;
  final int wordCount;

  /// Linked reminder ("Reminder Fri" in the editor meta line).
  final String? reminderId;
  const NoteRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.deletedAt,
    required this.isPinned,
    required this.isFavorite,
    this.colorHex,
    this.folderId,
    required this.sortOrder,
    required this.syncVersion,
    this.lastSyncedAt,
    required this.deviceId,
    required this.title,
    required this.contentDelta,
    required this.plainText,
    required this.checklistJson,
    this.coverImagePath,
    required this.isLocked,
    this.lockVerifier,
    required this.wordCount,
    this.reminderId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_favorite'] = Variable<bool>(isFavorite);
    if (!nullToAbsent || colorHex != null) {
      map['color_hex'] = Variable<String>(colorHex);
    }
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['sort_order'] = Variable<double>(sortOrder);
    map['sync_version'] = Variable<int>(syncVersion);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['title'] = Variable<String>(title);
    map['content_delta'] = Variable<String>(contentDelta);
    map['plain_text'] = Variable<String>(plainText);
    map['checklist_json'] = Variable<String>(checklistJson);
    if (!nullToAbsent || coverImagePath != null) {
      map['cover_image_path'] = Variable<String>(coverImagePath);
    }
    map['is_locked'] = Variable<bool>(isLocked);
    if (!nullToAbsent || lockVerifier != null) {
      map['lock_verifier'] = Variable<String>(lockVerifier);
    }
    map['word_count'] = Variable<int>(wordCount);
    if (!nullToAbsent || reminderId != null) {
      map['reminder_id'] = Variable<String>(reminderId);
    }
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      isPinned: Value(isPinned),
      isFavorite: Value(isFavorite),
      colorHex: colorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(colorHex),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      sortOrder: Value(sortOrder),
      syncVersion: Value(syncVersion),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      deviceId: Value(deviceId),
      title: Value(title),
      contentDelta: Value(contentDelta),
      plainText: Value(plainText),
      checklistJson: Value(checklistJson),
      coverImagePath: coverImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverImagePath),
      isLocked: Value(isLocked),
      lockVerifier: lockVerifier == null && nullToAbsent
          ? const Value.absent()
          : Value(lockVerifier),
      wordCount: Value(wordCount),
      reminderId: reminderId == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderId),
    );
  }

  factory NoteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      colorHex: serializer.fromJson<String?>(json['colorHex']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      sortOrder: serializer.fromJson<double>(json['sortOrder']),
      syncVersion: serializer.fromJson<int>(json['syncVersion']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      title: serializer.fromJson<String>(json['title']),
      contentDelta: serializer.fromJson<String>(json['contentDelta']),
      plainText: serializer.fromJson<String>(json['plainText']),
      checklistJson: serializer.fromJson<String>(json['checklistJson']),
      coverImagePath: serializer.fromJson<String?>(json['coverImagePath']),
      isLocked: serializer.fromJson<bool>(json['isLocked']),
      lockVerifier: serializer.fromJson<String?>(json['lockVerifier']),
      wordCount: serializer.fromJson<int>(json['wordCount']),
      reminderId: serializer.fromJson<String?>(json['reminderId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'colorHex': serializer.toJson<String?>(colorHex),
      'folderId': serializer.toJson<String?>(folderId),
      'sortOrder': serializer.toJson<double>(sortOrder),
      'syncVersion': serializer.toJson<int>(syncVersion),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'title': serializer.toJson<String>(title),
      'contentDelta': serializer.toJson<String>(contentDelta),
      'plainText': serializer.toJson<String>(plainText),
      'checklistJson': serializer.toJson<String>(checklistJson),
      'coverImagePath': serializer.toJson<String?>(coverImagePath),
      'isLocked': serializer.toJson<bool>(isLocked),
      'lockVerifier': serializer.toJson<String?>(lockVerifier),
      'wordCount': serializer.toJson<int>(wordCount),
      'reminderId': serializer.toJson<String?>(reminderId),
    };
  }

  NoteRow copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> archivedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? isPinned,
    bool? isFavorite,
    Value<String?> colorHex = const Value.absent(),
    Value<String?> folderId = const Value.absent(),
    double? sortOrder,
    int? syncVersion,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    String? deviceId,
    String? title,
    String? contentDelta,
    String? plainText,
    String? checklistJson,
    Value<String?> coverImagePath = const Value.absent(),
    bool? isLocked,
    Value<String?> lockVerifier = const Value.absent(),
    int? wordCount,
    Value<String?> reminderId = const Value.absent(),
  }) => NoteRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    isPinned: isPinned ?? this.isPinned,
    isFavorite: isFavorite ?? this.isFavorite,
    colorHex: colorHex.present ? colorHex.value : this.colorHex,
    folderId: folderId.present ? folderId.value : this.folderId,
    sortOrder: sortOrder ?? this.sortOrder,
    syncVersion: syncVersion ?? this.syncVersion,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    deviceId: deviceId ?? this.deviceId,
    title: title ?? this.title,
    contentDelta: contentDelta ?? this.contentDelta,
    plainText: plainText ?? this.plainText,
    checklistJson: checklistJson ?? this.checklistJson,
    coverImagePath: coverImagePath.present
        ? coverImagePath.value
        : this.coverImagePath,
    isLocked: isLocked ?? this.isLocked,
    lockVerifier: lockVerifier.present ? lockVerifier.value : this.lockVerifier,
    wordCount: wordCount ?? this.wordCount,
    reminderId: reminderId.present ? reminderId.value : this.reminderId,
  );
  NoteRow copyWithCompanion(NotesCompanion data) {
    return NoteRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      syncVersion: data.syncVersion.present
          ? data.syncVersion.value
          : this.syncVersion,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      title: data.title.present ? data.title.value : this.title,
      contentDelta: data.contentDelta.present
          ? data.contentDelta.value
          : this.contentDelta,
      plainText: data.plainText.present ? data.plainText.value : this.plainText,
      checklistJson: data.checklistJson.present
          ? data.checklistJson.value
          : this.checklistJson,
      coverImagePath: data.coverImagePath.present
          ? data.coverImagePath.value
          : this.coverImagePath,
      isLocked: data.isLocked.present ? data.isLocked.value : this.isLocked,
      lockVerifier: data.lockVerifier.present
          ? data.lockVerifier.value
          : this.lockVerifier,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      reminderId: data.reminderId.present
          ? data.reminderId.value
          : this.reminderId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('colorHex: $colorHex, ')
          ..write('folderId: $folderId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('title: $title, ')
          ..write('contentDelta: $contentDelta, ')
          ..write('plainText: $plainText, ')
          ..write('checklistJson: $checklistJson, ')
          ..write('coverImagePath: $coverImagePath, ')
          ..write('isLocked: $isLocked, ')
          ..write('lockVerifier: $lockVerifier, ')
          ..write('wordCount: $wordCount, ')
          ..write('reminderId: $reminderId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
    isPinned,
    isFavorite,
    colorHex,
    folderId,
    sortOrder,
    syncVersion,
    lastSyncedAt,
    deviceId,
    title,
    contentDelta,
    plainText,
    checklistJson,
    coverImagePath,
    isLocked,
    lockVerifier,
    wordCount,
    reminderId,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.archivedAt == this.archivedAt &&
          other.deletedAt == this.deletedAt &&
          other.isPinned == this.isPinned &&
          other.isFavorite == this.isFavorite &&
          other.colorHex == this.colorHex &&
          other.folderId == this.folderId &&
          other.sortOrder == this.sortOrder &&
          other.syncVersion == this.syncVersion &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.deviceId == this.deviceId &&
          other.title == this.title &&
          other.contentDelta == this.contentDelta &&
          other.plainText == this.plainText &&
          other.checklistJson == this.checklistJson &&
          other.coverImagePath == this.coverImagePath &&
          other.isLocked == this.isLocked &&
          other.lockVerifier == this.lockVerifier &&
          other.wordCount == this.wordCount &&
          other.reminderId == this.reminderId);
}

class NotesCompanion extends UpdateCompanion<NoteRow> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> archivedAt;
  final Value<DateTime?> deletedAt;
  final Value<bool> isPinned;
  final Value<bool> isFavorite;
  final Value<String?> colorHex;
  final Value<String?> folderId;
  final Value<double> sortOrder;
  final Value<int> syncVersion;
  final Value<DateTime?> lastSyncedAt;
  final Value<String> deviceId;
  final Value<String> title;
  final Value<String> contentDelta;
  final Value<String> plainText;
  final Value<String> checklistJson;
  final Value<String?> coverImagePath;
  final Value<bool> isLocked;
  final Value<String?> lockVerifier;
  final Value<int> wordCount;
  final Value<String?> reminderId;
  final Value<int> rowid;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.folderId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.title = const Value.absent(),
    this.contentDelta = const Value.absent(),
    this.plainText = const Value.absent(),
    this.checklistJson = const Value.absent(),
    this.coverImagePath = const Value.absent(),
    this.isLocked = const Value.absent(),
    this.lockVerifier = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.reminderId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.folderId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.title = const Value.absent(),
    this.contentDelta = const Value.absent(),
    this.plainText = const Value.absent(),
    this.checklistJson = const Value.absent(),
    this.coverImagePath = const Value.absent(),
    this.isLocked = const Value.absent(),
    this.lockVerifier = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.reminderId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<NoteRow> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? deletedAt,
    Expression<bool>? isPinned,
    Expression<bool>? isFavorite,
    Expression<String>? colorHex,
    Expression<String>? folderId,
    Expression<double>? sortOrder,
    Expression<int>? syncVersion,
    Expression<DateTime>? lastSyncedAt,
    Expression<String>? deviceId,
    Expression<String>? title,
    Expression<String>? contentDelta,
    Expression<String>? plainText,
    Expression<String>? checklistJson,
    Expression<String>? coverImagePath,
    Expression<bool>? isLocked,
    Expression<String>? lockVerifier,
    Expression<int>? wordCount,
    Expression<String>? reminderId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (colorHex != null) 'color_hex': colorHex,
      if (folderId != null) 'folder_id': folderId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (syncVersion != null) 'sync_version': syncVersion,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (title != null) 'title': title,
      if (contentDelta != null) 'content_delta': contentDelta,
      if (plainText != null) 'plain_text': plainText,
      if (checklistJson != null) 'checklist_json': checklistJson,
      if (coverImagePath != null) 'cover_image_path': coverImagePath,
      if (isLocked != null) 'is_locked': isLocked,
      if (lockVerifier != null) 'lock_verifier': lockVerifier,
      if (wordCount != null) 'word_count': wordCount,
      if (reminderId != null) 'reminder_id': reminderId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? archivedAt,
    Value<DateTime?>? deletedAt,
    Value<bool>? isPinned,
    Value<bool>? isFavorite,
    Value<String?>? colorHex,
    Value<String?>? folderId,
    Value<double>? sortOrder,
    Value<int>? syncVersion,
    Value<DateTime?>? lastSyncedAt,
    Value<String>? deviceId,
    Value<String>? title,
    Value<String>? contentDelta,
    Value<String>? plainText,
    Value<String>? checklistJson,
    Value<String?>? coverImagePath,
    Value<bool>? isLocked,
    Value<String?>? lockVerifier,
    Value<int>? wordCount,
    Value<String?>? reminderId,
    Value<int>? rowid,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      colorHex: colorHex ?? this.colorHex,
      folderId: folderId ?? this.folderId,
      sortOrder: sortOrder ?? this.sortOrder,
      syncVersion: syncVersion ?? this.syncVersion,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      deviceId: deviceId ?? this.deviceId,
      title: title ?? this.title,
      contentDelta: contentDelta ?? this.contentDelta,
      plainText: plainText ?? this.plainText,
      checklistJson: checklistJson ?? this.checklistJson,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      isLocked: isLocked ?? this.isLocked,
      lockVerifier: lockVerifier ?? this.lockVerifier,
      wordCount: wordCount ?? this.wordCount,
      reminderId: reminderId ?? this.reminderId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<double>(sortOrder.value);
    }
    if (syncVersion.present) {
      map['sync_version'] = Variable<int>(syncVersion.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (contentDelta.present) {
      map['content_delta'] = Variable<String>(contentDelta.value);
    }
    if (plainText.present) {
      map['plain_text'] = Variable<String>(plainText.value);
    }
    if (checklistJson.present) {
      map['checklist_json'] = Variable<String>(checklistJson.value);
    }
    if (coverImagePath.present) {
      map['cover_image_path'] = Variable<String>(coverImagePath.value);
    }
    if (isLocked.present) {
      map['is_locked'] = Variable<bool>(isLocked.value);
    }
    if (lockVerifier.present) {
      map['lock_verifier'] = Variable<String>(lockVerifier.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<int>(wordCount.value);
    }
    if (reminderId.present) {
      map['reminder_id'] = Variable<String>(reminderId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('colorHex: $colorHex, ')
          ..write('folderId: $folderId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('title: $title, ')
          ..write('contentDelta: $contentDelta, ')
          ..write('plainText: $plainText, ')
          ..write('checklistJson: $checklistJson, ')
          ..write('coverImagePath: $coverImagePath, ')
          ..write('isLocked: $isLocked, ')
          ..write('lockVerifier: $lockVerifier, ')
          ..write('wordCount: $wordCount, ')
          ..write('reminderId: $reminderId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, TaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<double> sortOrder = GeneratedColumn<double>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncVersionMeta = const VerificationMeta(
    'syncVersion',
  );
  @override
  late final GeneratedColumn<int> syncVersion = GeneratedColumn<int>(
    'sync_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueTimeMinutesMeta = const VerificationMeta(
    'dueTimeMinutes',
  );
  @override
  late final GeneratedColumn<int> dueTimeMinutes = GeneratedColumn<int>(
    'due_time_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _repeatRuleMeta = const VerificationMeta(
    'repeatRule',
  );
  @override
  late final GeneratedColumn<String> repeatRule = GeneratedColumn<String>(
    'repeat_rule',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remindOffsetMinutesMeta =
      const VerificationMeta('remindOffsetMinutes');
  @override
  late final GeneratedColumn<int> remindOffsetMinutes = GeneratedColumn<int>(
    'remind_offset_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderIdMeta = const VerificationMeta(
    'reminderId',
  );
  @override
  late final GeneratedColumn<String> reminderId = GeneratedColumn<String>(
    'reminder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedNoteIdMeta = const VerificationMeta(
    'linkedNoteId',
  );
  @override
  late final GeneratedColumn<String> linkedNoteId = GeneratedColumn<String>(
    'linked_note_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _boardStatusMeta = const VerificationMeta(
    'boardStatus',
  );
  @override
  late final GeneratedColumn<int> boardStatus = GeneratedColumn<int>(
    'board_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
    isPinned,
    isFavorite,
    colorHex,
    folderId,
    sortOrder,
    syncVersion,
    lastSyncedAt,
    deviceId,
    title,
    notes,
    dueDate,
    dueTimeMinutes,
    priority,
    repeatRule,
    remindOffsetMinutes,
    reminderId,
    linkedNoteId,
    completedAt,
    boardStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('sync_version')) {
      context.handle(
        _syncVersionMeta,
        syncVersion.isAcceptableOrUnknown(
          data['sync_version']!,
          _syncVersionMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('due_time_minutes')) {
      context.handle(
        _dueTimeMinutesMeta,
        dueTimeMinutes.isAcceptableOrUnknown(
          data['due_time_minutes']!,
          _dueTimeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('repeat_rule')) {
      context.handle(
        _repeatRuleMeta,
        repeatRule.isAcceptableOrUnknown(data['repeat_rule']!, _repeatRuleMeta),
      );
    }
    if (data.containsKey('remind_offset_minutes')) {
      context.handle(
        _remindOffsetMinutesMeta,
        remindOffsetMinutes.isAcceptableOrUnknown(
          data['remind_offset_minutes']!,
          _remindOffsetMinutesMeta,
        ),
      );
    }
    if (data.containsKey('reminder_id')) {
      context.handle(
        _reminderIdMeta,
        reminderId.isAcceptableOrUnknown(data['reminder_id']!, _reminderIdMeta),
      );
    }
    if (data.containsKey('linked_note_id')) {
      context.handle(
        _linkedNoteIdMeta,
        linkedNoteId.isAcceptableOrUnknown(
          data['linked_note_id']!,
          _linkedNoteIdMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('board_status')) {
      context.handle(
        _boardStatusMeta,
        boardStatus.isAcceptableOrUnknown(
          data['board_status']!,
          _boardStatusMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      ),
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sort_order'],
      )!,
      syncVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_version'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      dueTimeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_time_minutes'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      repeatRule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_rule'],
      ),
      remindOffsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remind_offset_minutes'],
      ),
      reminderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_id'],
      ),
      linkedNoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_note_id'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      boardStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}board_status'],
      )!,
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class TaskRow extends DataClass implements Insertable<TaskRow> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final bool isPinned;
  final bool isFavorite;

  /// `RRGGBB`; null = module default / white card.
  final String? colorHex;

  /// Folder (notes/vault) or list (tasks). See [Folders].
  final String? folderId;

  /// Manual sort position (lower first). Fractional so a drag only rewrites
  /// the moved row.
  final double sortOrder;
  final int syncVersion;
  final DateTime? lastSyncedAt;

  /// Device that last wrote the row (core/storage/device_id).
  final String deviceId;
  final String title;
  final String notes;

  /// Local calendar day the task is due (stored at local midnight).
  final DateTime? dueDate;

  /// Minutes after midnight (09:00 → 540); null = all day.
  final int? dueTimeMinutes;

  /// 0 none · 1 low · 2 medium · 3 high.
  final int priority;

  /// RFC 5545 RRULE (e.g. `FREQ=WEEKLY;BYDAY=TU`); null = no repeat.
  final String? repeatRule;

  /// "Remind me 15 min before" — creates/updates [reminderId].
  final int? remindOffsetMinutes;
  final String? reminderId;
  final String? linkedNoteId;
  final DateTime? completedAt;

  /// Board view column: 0 to do · 1 doing · 2 done (v1.1).
  final int boardStatus;
  const TaskRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.deletedAt,
    required this.isPinned,
    required this.isFavorite,
    this.colorHex,
    this.folderId,
    required this.sortOrder,
    required this.syncVersion,
    this.lastSyncedAt,
    required this.deviceId,
    required this.title,
    required this.notes,
    this.dueDate,
    this.dueTimeMinutes,
    required this.priority,
    this.repeatRule,
    this.remindOffsetMinutes,
    this.reminderId,
    this.linkedNoteId,
    this.completedAt,
    required this.boardStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_favorite'] = Variable<bool>(isFavorite);
    if (!nullToAbsent || colorHex != null) {
      map['color_hex'] = Variable<String>(colorHex);
    }
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['sort_order'] = Variable<double>(sortOrder);
    map['sync_version'] = Variable<int>(syncVersion);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['title'] = Variable<String>(title);
    map['notes'] = Variable<String>(notes);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    if (!nullToAbsent || dueTimeMinutes != null) {
      map['due_time_minutes'] = Variable<int>(dueTimeMinutes);
    }
    map['priority'] = Variable<int>(priority);
    if (!nullToAbsent || repeatRule != null) {
      map['repeat_rule'] = Variable<String>(repeatRule);
    }
    if (!nullToAbsent || remindOffsetMinutes != null) {
      map['remind_offset_minutes'] = Variable<int>(remindOffsetMinutes);
    }
    if (!nullToAbsent || reminderId != null) {
      map['reminder_id'] = Variable<String>(reminderId);
    }
    if (!nullToAbsent || linkedNoteId != null) {
      map['linked_note_id'] = Variable<String>(linkedNoteId);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['board_status'] = Variable<int>(boardStatus);
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      isPinned: Value(isPinned),
      isFavorite: Value(isFavorite),
      colorHex: colorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(colorHex),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      sortOrder: Value(sortOrder),
      syncVersion: Value(syncVersion),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      deviceId: Value(deviceId),
      title: Value(title),
      notes: Value(notes),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      dueTimeMinutes: dueTimeMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(dueTimeMinutes),
      priority: Value(priority),
      repeatRule: repeatRule == null && nullToAbsent
          ? const Value.absent()
          : Value(repeatRule),
      remindOffsetMinutes: remindOffsetMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(remindOffsetMinutes),
      reminderId: reminderId == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderId),
      linkedNoteId: linkedNoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedNoteId),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      boardStatus: Value(boardStatus),
    );
  }

  factory TaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      colorHex: serializer.fromJson<String?>(json['colorHex']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      sortOrder: serializer.fromJson<double>(json['sortOrder']),
      syncVersion: serializer.fromJson<int>(json['syncVersion']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String>(json['notes']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      dueTimeMinutes: serializer.fromJson<int?>(json['dueTimeMinutes']),
      priority: serializer.fromJson<int>(json['priority']),
      repeatRule: serializer.fromJson<String?>(json['repeatRule']),
      remindOffsetMinutes: serializer.fromJson<int?>(
        json['remindOffsetMinutes'],
      ),
      reminderId: serializer.fromJson<String?>(json['reminderId']),
      linkedNoteId: serializer.fromJson<String?>(json['linkedNoteId']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      boardStatus: serializer.fromJson<int>(json['boardStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'colorHex': serializer.toJson<String?>(colorHex),
      'folderId': serializer.toJson<String?>(folderId),
      'sortOrder': serializer.toJson<double>(sortOrder),
      'syncVersion': serializer.toJson<int>(syncVersion),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String>(notes),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'dueTimeMinutes': serializer.toJson<int?>(dueTimeMinutes),
      'priority': serializer.toJson<int>(priority),
      'repeatRule': serializer.toJson<String?>(repeatRule),
      'remindOffsetMinutes': serializer.toJson<int?>(remindOffsetMinutes),
      'reminderId': serializer.toJson<String?>(reminderId),
      'linkedNoteId': serializer.toJson<String?>(linkedNoteId),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'boardStatus': serializer.toJson<int>(boardStatus),
    };
  }

  TaskRow copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> archivedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? isPinned,
    bool? isFavorite,
    Value<String?> colorHex = const Value.absent(),
    Value<String?> folderId = const Value.absent(),
    double? sortOrder,
    int? syncVersion,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    String? deviceId,
    String? title,
    String? notes,
    Value<DateTime?> dueDate = const Value.absent(),
    Value<int?> dueTimeMinutes = const Value.absent(),
    int? priority,
    Value<String?> repeatRule = const Value.absent(),
    Value<int?> remindOffsetMinutes = const Value.absent(),
    Value<String?> reminderId = const Value.absent(),
    Value<String?> linkedNoteId = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    int? boardStatus,
  }) => TaskRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    isPinned: isPinned ?? this.isPinned,
    isFavorite: isFavorite ?? this.isFavorite,
    colorHex: colorHex.present ? colorHex.value : this.colorHex,
    folderId: folderId.present ? folderId.value : this.folderId,
    sortOrder: sortOrder ?? this.sortOrder,
    syncVersion: syncVersion ?? this.syncVersion,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    deviceId: deviceId ?? this.deviceId,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    dueTimeMinutes: dueTimeMinutes.present
        ? dueTimeMinutes.value
        : this.dueTimeMinutes,
    priority: priority ?? this.priority,
    repeatRule: repeatRule.present ? repeatRule.value : this.repeatRule,
    remindOffsetMinutes: remindOffsetMinutes.present
        ? remindOffsetMinutes.value
        : this.remindOffsetMinutes,
    reminderId: reminderId.present ? reminderId.value : this.reminderId,
    linkedNoteId: linkedNoteId.present ? linkedNoteId.value : this.linkedNoteId,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    boardStatus: boardStatus ?? this.boardStatus,
  );
  TaskRow copyWithCompanion(TasksCompanion data) {
    return TaskRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      syncVersion: data.syncVersion.present
          ? data.syncVersion.value
          : this.syncVersion,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      dueTimeMinutes: data.dueTimeMinutes.present
          ? data.dueTimeMinutes.value
          : this.dueTimeMinutes,
      priority: data.priority.present ? data.priority.value : this.priority,
      repeatRule: data.repeatRule.present
          ? data.repeatRule.value
          : this.repeatRule,
      remindOffsetMinutes: data.remindOffsetMinutes.present
          ? data.remindOffsetMinutes.value
          : this.remindOffsetMinutes,
      reminderId: data.reminderId.present
          ? data.reminderId.value
          : this.reminderId,
      linkedNoteId: data.linkedNoteId.present
          ? data.linkedNoteId.value
          : this.linkedNoteId,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      boardStatus: data.boardStatus.present
          ? data.boardStatus.value
          : this.boardStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('colorHex: $colorHex, ')
          ..write('folderId: $folderId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('dueDate: $dueDate, ')
          ..write('dueTimeMinutes: $dueTimeMinutes, ')
          ..write('priority: $priority, ')
          ..write('repeatRule: $repeatRule, ')
          ..write('remindOffsetMinutes: $remindOffsetMinutes, ')
          ..write('reminderId: $reminderId, ')
          ..write('linkedNoteId: $linkedNoteId, ')
          ..write('completedAt: $completedAt, ')
          ..write('boardStatus: $boardStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
    isPinned,
    isFavorite,
    colorHex,
    folderId,
    sortOrder,
    syncVersion,
    lastSyncedAt,
    deviceId,
    title,
    notes,
    dueDate,
    dueTimeMinutes,
    priority,
    repeatRule,
    remindOffsetMinutes,
    reminderId,
    linkedNoteId,
    completedAt,
    boardStatus,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.archivedAt == this.archivedAt &&
          other.deletedAt == this.deletedAt &&
          other.isPinned == this.isPinned &&
          other.isFavorite == this.isFavorite &&
          other.colorHex == this.colorHex &&
          other.folderId == this.folderId &&
          other.sortOrder == this.sortOrder &&
          other.syncVersion == this.syncVersion &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.deviceId == this.deviceId &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.dueDate == this.dueDate &&
          other.dueTimeMinutes == this.dueTimeMinutes &&
          other.priority == this.priority &&
          other.repeatRule == this.repeatRule &&
          other.remindOffsetMinutes == this.remindOffsetMinutes &&
          other.reminderId == this.reminderId &&
          other.linkedNoteId == this.linkedNoteId &&
          other.completedAt == this.completedAt &&
          other.boardStatus == this.boardStatus);
}

class TasksCompanion extends UpdateCompanion<TaskRow> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> archivedAt;
  final Value<DateTime?> deletedAt;
  final Value<bool> isPinned;
  final Value<bool> isFavorite;
  final Value<String?> colorHex;
  final Value<String?> folderId;
  final Value<double> sortOrder;
  final Value<int> syncVersion;
  final Value<DateTime?> lastSyncedAt;
  final Value<String> deviceId;
  final Value<String> title;
  final Value<String> notes;
  final Value<DateTime?> dueDate;
  final Value<int?> dueTimeMinutes;
  final Value<int> priority;
  final Value<String?> repeatRule;
  final Value<int?> remindOffsetMinutes;
  final Value<String?> reminderId;
  final Value<String?> linkedNoteId;
  final Value<DateTime?> completedAt;
  final Value<int> boardStatus;
  final Value<int> rowid;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.folderId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.dueTimeMinutes = const Value.absent(),
    this.priority = const Value.absent(),
    this.repeatRule = const Value.absent(),
    this.remindOffsetMinutes = const Value.absent(),
    this.reminderId = const Value.absent(),
    this.linkedNoteId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.boardStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.folderId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.dueTimeMinutes = const Value.absent(),
    this.priority = const Value.absent(),
    this.repeatRule = const Value.absent(),
    this.remindOffsetMinutes = const Value.absent(),
    this.reminderId = const Value.absent(),
    this.linkedNoteId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.boardStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TaskRow> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? deletedAt,
    Expression<bool>? isPinned,
    Expression<bool>? isFavorite,
    Expression<String>? colorHex,
    Expression<String>? folderId,
    Expression<double>? sortOrder,
    Expression<int>? syncVersion,
    Expression<DateTime>? lastSyncedAt,
    Expression<String>? deviceId,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<DateTime>? dueDate,
    Expression<int>? dueTimeMinutes,
    Expression<int>? priority,
    Expression<String>? repeatRule,
    Expression<int>? remindOffsetMinutes,
    Expression<String>? reminderId,
    Expression<String>? linkedNoteId,
    Expression<DateTime>? completedAt,
    Expression<int>? boardStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (colorHex != null) 'color_hex': colorHex,
      if (folderId != null) 'folder_id': folderId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (syncVersion != null) 'sync_version': syncVersion,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (dueDate != null) 'due_date': dueDate,
      if (dueTimeMinutes != null) 'due_time_minutes': dueTimeMinutes,
      if (priority != null) 'priority': priority,
      if (repeatRule != null) 'repeat_rule': repeatRule,
      if (remindOffsetMinutes != null)
        'remind_offset_minutes': remindOffsetMinutes,
      if (reminderId != null) 'reminder_id': reminderId,
      if (linkedNoteId != null) 'linked_note_id': linkedNoteId,
      if (completedAt != null) 'completed_at': completedAt,
      if (boardStatus != null) 'board_status': boardStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? archivedAt,
    Value<DateTime?>? deletedAt,
    Value<bool>? isPinned,
    Value<bool>? isFavorite,
    Value<String?>? colorHex,
    Value<String?>? folderId,
    Value<double>? sortOrder,
    Value<int>? syncVersion,
    Value<DateTime?>? lastSyncedAt,
    Value<String>? deviceId,
    Value<String>? title,
    Value<String>? notes,
    Value<DateTime?>? dueDate,
    Value<int?>? dueTimeMinutes,
    Value<int>? priority,
    Value<String?>? repeatRule,
    Value<int?>? remindOffsetMinutes,
    Value<String?>? reminderId,
    Value<String?>? linkedNoteId,
    Value<DateTime?>? completedAt,
    Value<int>? boardStatus,
    Value<int>? rowid,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      colorHex: colorHex ?? this.colorHex,
      folderId: folderId ?? this.folderId,
      sortOrder: sortOrder ?? this.sortOrder,
      syncVersion: syncVersion ?? this.syncVersion,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      deviceId: deviceId ?? this.deviceId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueDate: dueDate ?? this.dueDate,
      dueTimeMinutes: dueTimeMinutes ?? this.dueTimeMinutes,
      priority: priority ?? this.priority,
      repeatRule: repeatRule ?? this.repeatRule,
      remindOffsetMinutes: remindOffsetMinutes ?? this.remindOffsetMinutes,
      reminderId: reminderId ?? this.reminderId,
      linkedNoteId: linkedNoteId ?? this.linkedNoteId,
      completedAt: completedAt ?? this.completedAt,
      boardStatus: boardStatus ?? this.boardStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<double>(sortOrder.value);
    }
    if (syncVersion.present) {
      map['sync_version'] = Variable<int>(syncVersion.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (dueTimeMinutes.present) {
      map['due_time_minutes'] = Variable<int>(dueTimeMinutes.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (repeatRule.present) {
      map['repeat_rule'] = Variable<String>(repeatRule.value);
    }
    if (remindOffsetMinutes.present) {
      map['remind_offset_minutes'] = Variable<int>(remindOffsetMinutes.value);
    }
    if (reminderId.present) {
      map['reminder_id'] = Variable<String>(reminderId.value);
    }
    if (linkedNoteId.present) {
      map['linked_note_id'] = Variable<String>(linkedNoteId.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (boardStatus.present) {
      map['board_status'] = Variable<int>(boardStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('colorHex: $colorHex, ')
          ..write('folderId: $folderId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('dueDate: $dueDate, ')
          ..write('dueTimeMinutes: $dueTimeMinutes, ')
          ..write('priority: $priority, ')
          ..write('repeatRule: $repeatRule, ')
          ..write('remindOffsetMinutes: $remindOffsetMinutes, ')
          ..write('reminderId: $reminderId, ')
          ..write('linkedNoteId: $linkedNoteId, ')
          ..write('completedAt: $completedAt, ')
          ..write('boardStatus: $boardStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubtasksTable extends Subtasks
    with TableInfo<$SubtasksTable, SubtaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubtasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<double> sortOrder = GeneratedColumn<double>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    title,
    done,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subtasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubtaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SubtaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubtaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SubtasksTable createAlias(String alias) {
    return $SubtasksTable(attachedDatabase, alias);
  }
}

class SubtaskRow extends DataClass implements Insertable<SubtaskRow> {
  final String id;
  final String taskId;
  final String title;
  final bool done;
  final double sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SubtaskRow({
    required this.id,
    required this.taskId,
    required this.title,
    required this.done,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['title'] = Variable<String>(title);
    map['done'] = Variable<bool>(done);
    map['sort_order'] = Variable<double>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SubtasksCompanion toCompanion(bool nullToAbsent) {
    return SubtasksCompanion(
      id: Value(id),
      taskId: Value(taskId),
      title: Value(title),
      done: Value(done),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SubtaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubtaskRow(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      title: serializer.fromJson<String>(json['title']),
      done: serializer.fromJson<bool>(json['done']),
      sortOrder: serializer.fromJson<double>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'title': serializer.toJson<String>(title),
      'done': serializer.toJson<bool>(done),
      'sortOrder': serializer.toJson<double>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SubtaskRow copyWith({
    String? id,
    String? taskId,
    String? title,
    bool? done,
    double? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SubtaskRow(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    title: title ?? this.title,
    done: done ?? this.done,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SubtaskRow copyWithCompanion(SubtasksCompanion data) {
    return SubtaskRow(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      title: data.title.present ? data.title.value : this.title,
      done: data.done.present ? data.done.value : this.done,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubtaskRow(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('title: $title, ')
          ..write('done: $done, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, taskId, title, done, sortOrder, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubtaskRow &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.title == this.title &&
          other.done == this.done &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SubtasksCompanion extends UpdateCompanion<SubtaskRow> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<String> title;
  final Value<bool> done;
  final Value<double> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SubtasksCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.title = const Value.absent(),
    this.done = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubtasksCompanion.insert({
    required String id,
    required String taskId,
    this.title = const Value.absent(),
    this.done = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SubtaskRow> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? title,
    Expression<bool>? done,
    Expression<double>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (title != null) 'title': title,
      if (done != null) 'done': done,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubtasksCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<String>? title,
    Value<bool>? done,
    Value<double>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SubtasksCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      done: done ?? this.done,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<double>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubtasksCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('title: $title, ')
          ..write('done: $done, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, ReminderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<double> sortOrder = GeneratedColumn<double>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncVersionMeta = const VerificationMeta(
    'syncVersion',
  );
  @override
  late final GeneratedColumn<int> syncVersion = GeneratedColumn<int>(
    'sync_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _triggerAtMeta = const VerificationMeta(
    'triggerAt',
  );
  @override
  late final GeneratedColumn<DateTime> triggerAt = GeneratedColumn<DateTime>(
    'trigger_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repeatRuleMeta = const VerificationMeta(
    'repeatRule',
  );
  @override
  late final GeneratedColumn<String> repeatRule = GeneratedColumn<String>(
    'repeat_rule',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _alertStyleMeta = const VerificationMeta(
    'alertStyle',
  );
  @override
  late final GeneratedColumn<int> alertStyle = GeneratedColumn<int>(
    'alert_style',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _soundMeta = const VerificationMeta('sound');
  @override
  late final GeneratedColumn<String> sound = GeneratedColumn<String>(
    'sound',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('chime'),
  );
  static const VerificationMeta _snoozeMinutesMeta = const VerificationMeta(
    'snoozeMinutes',
  );
  @override
  late final GeneratedColumn<int> snoozeMinutes = GeneratedColumn<int>(
    'snooze_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  static const VerificationMeta _snoozedUntilMeta = const VerificationMeta(
    'snoozedUntil',
  );
  @override
  late final GeneratedColumn<DateTime> snoozedUntil = GeneratedColumn<DateTime>(
    'snoozed_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationJsonMeta = const VerificationMeta(
    'locationJson',
  );
  @override
  late final GeneratedColumn<String> locationJson = GeneratedColumn<String>(
    'location_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedItemIdMeta = const VerificationMeta(
    'linkedItemId',
  );
  @override
  late final GeneratedColumn<String> linkedItemId = GeneratedColumn<String>(
    'linked_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedItemTypeMeta = const VerificationMeta(
    'linkedItemType',
  );
  @override
  late final GeneratedColumn<String> linkedItemType = GeneratedColumn<String>(
    'linked_item_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lastFiredAtMeta = const VerificationMeta(
    'lastFiredAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastFiredAt = GeneratedColumn<DateTime>(
    'last_fired_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notificationIdMeta = const VerificationMeta(
    'notificationId',
  );
  @override
  late final GeneratedColumn<int> notificationId = GeneratedColumn<int>(
    'notification_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
    isPinned,
    isFavorite,
    colorHex,
    folderId,
    sortOrder,
    syncVersion,
    lastSyncedAt,
    deviceId,
    title,
    note,
    triggerAt,
    repeatRule,
    alertStyle,
    sound,
    snoozeMinutes,
    snoozedUntil,
    locationJson,
    linkedItemId,
    linkedItemType,
    isEnabled,
    lastFiredAt,
    completedAt,
    notificationId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('sync_version')) {
      context.handle(
        _syncVersionMeta,
        syncVersion.isAcceptableOrUnknown(
          data['sync_version']!,
          _syncVersionMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('trigger_at')) {
      context.handle(
        _triggerAtMeta,
        triggerAt.isAcceptableOrUnknown(data['trigger_at']!, _triggerAtMeta),
      );
    } else if (isInserting) {
      context.missing(_triggerAtMeta);
    }
    if (data.containsKey('repeat_rule')) {
      context.handle(
        _repeatRuleMeta,
        repeatRule.isAcceptableOrUnknown(data['repeat_rule']!, _repeatRuleMeta),
      );
    }
    if (data.containsKey('alert_style')) {
      context.handle(
        _alertStyleMeta,
        alertStyle.isAcceptableOrUnknown(data['alert_style']!, _alertStyleMeta),
      );
    }
    if (data.containsKey('sound')) {
      context.handle(
        _soundMeta,
        sound.isAcceptableOrUnknown(data['sound']!, _soundMeta),
      );
    }
    if (data.containsKey('snooze_minutes')) {
      context.handle(
        _snoozeMinutesMeta,
        snoozeMinutes.isAcceptableOrUnknown(
          data['snooze_minutes']!,
          _snoozeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('snoozed_until')) {
      context.handle(
        _snoozedUntilMeta,
        snoozedUntil.isAcceptableOrUnknown(
          data['snoozed_until']!,
          _snoozedUntilMeta,
        ),
      );
    }
    if (data.containsKey('location_json')) {
      context.handle(
        _locationJsonMeta,
        locationJson.isAcceptableOrUnknown(
          data['location_json']!,
          _locationJsonMeta,
        ),
      );
    }
    if (data.containsKey('linked_item_id')) {
      context.handle(
        _linkedItemIdMeta,
        linkedItemId.isAcceptableOrUnknown(
          data['linked_item_id']!,
          _linkedItemIdMeta,
        ),
      );
    }
    if (data.containsKey('linked_item_type')) {
      context.handle(
        _linkedItemTypeMeta,
        linkedItemType.isAcceptableOrUnknown(
          data['linked_item_type']!,
          _linkedItemTypeMeta,
        ),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('last_fired_at')) {
      context.handle(
        _lastFiredAtMeta,
        lastFiredAt.isAcceptableOrUnknown(
          data['last_fired_at']!,
          _lastFiredAtMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('notification_id')) {
      context.handle(
        _notificationIdMeta,
        notificationId.isAcceptableOrUnknown(
          data['notification_id']!,
          _notificationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_notificationIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReminderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      ),
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sort_order'],
      )!,
      syncVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_version'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      triggerAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}trigger_at'],
      )!,
      repeatRule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_rule'],
      ),
      alertStyle: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}alert_style'],
      )!,
      sound: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sound'],
      )!,
      snoozeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snooze_minutes'],
      )!,
      snoozedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}snoozed_until'],
      ),
      locationJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_json'],
      ),
      linkedItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_item_id'],
      ),
      linkedItemType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_item_type'],
      ),
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      lastFiredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_fired_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      notificationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_id'],
      )!,
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }
}

class ReminderRow extends DataClass implements Insertable<ReminderRow> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final bool isPinned;
  final bool isFavorite;

  /// `RRGGBB`; null = module default / white card.
  final String? colorHex;

  /// Folder (notes/vault) or list (tasks). See [Folders].
  final String? folderId;

  /// Manual sort position (lower first). Fractional so a drag only rewrites
  /// the moved row.
  final double sortOrder;
  final int syncVersion;
  final DateTime? lastSyncedAt;

  /// Device that last wrote the row (core/storage/device_id).
  final String deviceId;
  final String title;
  final String note;

  /// Next time the reminder fires (local wall time stored as an instant).
  final DateTime triggerAt;

  /// RRULE; null = once.
  final String? repeatRule;

  /// 0 notification · 1 alarm (full-screen intent / time-sensitive).
  final int alertStyle;
  final String sound;
  final int snoozeMinutes;
  final DateTime? snoozedUntil;

  /// JSON `{"lat":…,"lng":…,"radius":…,"onEnter":true,"label":"Office"}`
  /// (geofencing is v1.1 behind a flag; the column exists for sync).
  final String? locationJson;

  /// What the reminder belongs to (task / note …), if anything.
  final String? linkedItemId;
  final String? linkedItemType;
  final bool isEnabled;
  final DateTime? lastFiredAt;
  final DateTime? completedAt;

  /// Stable 31-bit id for flutter_local_notifications.
  final int notificationId;
  const ReminderRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.deletedAt,
    required this.isPinned,
    required this.isFavorite,
    this.colorHex,
    this.folderId,
    required this.sortOrder,
    required this.syncVersion,
    this.lastSyncedAt,
    required this.deviceId,
    required this.title,
    required this.note,
    required this.triggerAt,
    this.repeatRule,
    required this.alertStyle,
    required this.sound,
    required this.snoozeMinutes,
    this.snoozedUntil,
    this.locationJson,
    this.linkedItemId,
    this.linkedItemType,
    required this.isEnabled,
    this.lastFiredAt,
    this.completedAt,
    required this.notificationId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_favorite'] = Variable<bool>(isFavorite);
    if (!nullToAbsent || colorHex != null) {
      map['color_hex'] = Variable<String>(colorHex);
    }
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['sort_order'] = Variable<double>(sortOrder);
    map['sync_version'] = Variable<int>(syncVersion);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['title'] = Variable<String>(title);
    map['note'] = Variable<String>(note);
    map['trigger_at'] = Variable<DateTime>(triggerAt);
    if (!nullToAbsent || repeatRule != null) {
      map['repeat_rule'] = Variable<String>(repeatRule);
    }
    map['alert_style'] = Variable<int>(alertStyle);
    map['sound'] = Variable<String>(sound);
    map['snooze_minutes'] = Variable<int>(snoozeMinutes);
    if (!nullToAbsent || snoozedUntil != null) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil);
    }
    if (!nullToAbsent || locationJson != null) {
      map['location_json'] = Variable<String>(locationJson);
    }
    if (!nullToAbsent || linkedItemId != null) {
      map['linked_item_id'] = Variable<String>(linkedItemId);
    }
    if (!nullToAbsent || linkedItemType != null) {
      map['linked_item_type'] = Variable<String>(linkedItemType);
    }
    map['is_enabled'] = Variable<bool>(isEnabled);
    if (!nullToAbsent || lastFiredAt != null) {
      map['last_fired_at'] = Variable<DateTime>(lastFiredAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['notification_id'] = Variable<int>(notificationId);
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      isPinned: Value(isPinned),
      isFavorite: Value(isFavorite),
      colorHex: colorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(colorHex),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      sortOrder: Value(sortOrder),
      syncVersion: Value(syncVersion),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      deviceId: Value(deviceId),
      title: Value(title),
      note: Value(note),
      triggerAt: Value(triggerAt),
      repeatRule: repeatRule == null && nullToAbsent
          ? const Value.absent()
          : Value(repeatRule),
      alertStyle: Value(alertStyle),
      sound: Value(sound),
      snoozeMinutes: Value(snoozeMinutes),
      snoozedUntil: snoozedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozedUntil),
      locationJson: locationJson == null && nullToAbsent
          ? const Value.absent()
          : Value(locationJson),
      linkedItemId: linkedItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedItemId),
      linkedItemType: linkedItemType == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedItemType),
      isEnabled: Value(isEnabled),
      lastFiredAt: lastFiredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastFiredAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      notificationId: Value(notificationId),
    );
  }

  factory ReminderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      colorHex: serializer.fromJson<String?>(json['colorHex']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      sortOrder: serializer.fromJson<double>(json['sortOrder']),
      syncVersion: serializer.fromJson<int>(json['syncVersion']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      title: serializer.fromJson<String>(json['title']),
      note: serializer.fromJson<String>(json['note']),
      triggerAt: serializer.fromJson<DateTime>(json['triggerAt']),
      repeatRule: serializer.fromJson<String?>(json['repeatRule']),
      alertStyle: serializer.fromJson<int>(json['alertStyle']),
      sound: serializer.fromJson<String>(json['sound']),
      snoozeMinutes: serializer.fromJson<int>(json['snoozeMinutes']),
      snoozedUntil: serializer.fromJson<DateTime?>(json['snoozedUntil']),
      locationJson: serializer.fromJson<String?>(json['locationJson']),
      linkedItemId: serializer.fromJson<String?>(json['linkedItemId']),
      linkedItemType: serializer.fromJson<String?>(json['linkedItemType']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      lastFiredAt: serializer.fromJson<DateTime?>(json['lastFiredAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      notificationId: serializer.fromJson<int>(json['notificationId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'colorHex': serializer.toJson<String?>(colorHex),
      'folderId': serializer.toJson<String?>(folderId),
      'sortOrder': serializer.toJson<double>(sortOrder),
      'syncVersion': serializer.toJson<int>(syncVersion),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'title': serializer.toJson<String>(title),
      'note': serializer.toJson<String>(note),
      'triggerAt': serializer.toJson<DateTime>(triggerAt),
      'repeatRule': serializer.toJson<String?>(repeatRule),
      'alertStyle': serializer.toJson<int>(alertStyle),
      'sound': serializer.toJson<String>(sound),
      'snoozeMinutes': serializer.toJson<int>(snoozeMinutes),
      'snoozedUntil': serializer.toJson<DateTime?>(snoozedUntil),
      'locationJson': serializer.toJson<String?>(locationJson),
      'linkedItemId': serializer.toJson<String?>(linkedItemId),
      'linkedItemType': serializer.toJson<String?>(linkedItemType),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'lastFiredAt': serializer.toJson<DateTime?>(lastFiredAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'notificationId': serializer.toJson<int>(notificationId),
    };
  }

  ReminderRow copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> archivedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? isPinned,
    bool? isFavorite,
    Value<String?> colorHex = const Value.absent(),
    Value<String?> folderId = const Value.absent(),
    double? sortOrder,
    int? syncVersion,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    String? deviceId,
    String? title,
    String? note,
    DateTime? triggerAt,
    Value<String?> repeatRule = const Value.absent(),
    int? alertStyle,
    String? sound,
    int? snoozeMinutes,
    Value<DateTime?> snoozedUntil = const Value.absent(),
    Value<String?> locationJson = const Value.absent(),
    Value<String?> linkedItemId = const Value.absent(),
    Value<String?> linkedItemType = const Value.absent(),
    bool? isEnabled,
    Value<DateTime?> lastFiredAt = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    int? notificationId,
  }) => ReminderRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    isPinned: isPinned ?? this.isPinned,
    isFavorite: isFavorite ?? this.isFavorite,
    colorHex: colorHex.present ? colorHex.value : this.colorHex,
    folderId: folderId.present ? folderId.value : this.folderId,
    sortOrder: sortOrder ?? this.sortOrder,
    syncVersion: syncVersion ?? this.syncVersion,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    deviceId: deviceId ?? this.deviceId,
    title: title ?? this.title,
    note: note ?? this.note,
    triggerAt: triggerAt ?? this.triggerAt,
    repeatRule: repeatRule.present ? repeatRule.value : this.repeatRule,
    alertStyle: alertStyle ?? this.alertStyle,
    sound: sound ?? this.sound,
    snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
    snoozedUntil: snoozedUntil.present ? snoozedUntil.value : this.snoozedUntil,
    locationJson: locationJson.present ? locationJson.value : this.locationJson,
    linkedItemId: linkedItemId.present ? linkedItemId.value : this.linkedItemId,
    linkedItemType: linkedItemType.present
        ? linkedItemType.value
        : this.linkedItemType,
    isEnabled: isEnabled ?? this.isEnabled,
    lastFiredAt: lastFiredAt.present ? lastFiredAt.value : this.lastFiredAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    notificationId: notificationId ?? this.notificationId,
  );
  ReminderRow copyWithCompanion(RemindersCompanion data) {
    return ReminderRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      syncVersion: data.syncVersion.present
          ? data.syncVersion.value
          : this.syncVersion,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      title: data.title.present ? data.title.value : this.title,
      note: data.note.present ? data.note.value : this.note,
      triggerAt: data.triggerAt.present ? data.triggerAt.value : this.triggerAt,
      repeatRule: data.repeatRule.present
          ? data.repeatRule.value
          : this.repeatRule,
      alertStyle: data.alertStyle.present
          ? data.alertStyle.value
          : this.alertStyle,
      sound: data.sound.present ? data.sound.value : this.sound,
      snoozeMinutes: data.snoozeMinutes.present
          ? data.snoozeMinutes.value
          : this.snoozeMinutes,
      snoozedUntil: data.snoozedUntil.present
          ? data.snoozedUntil.value
          : this.snoozedUntil,
      locationJson: data.locationJson.present
          ? data.locationJson.value
          : this.locationJson,
      linkedItemId: data.linkedItemId.present
          ? data.linkedItemId.value
          : this.linkedItemId,
      linkedItemType: data.linkedItemType.present
          ? data.linkedItemType.value
          : this.linkedItemType,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      lastFiredAt: data.lastFiredAt.present
          ? data.lastFiredAt.value
          : this.lastFiredAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      notificationId: data.notificationId.present
          ? data.notificationId.value
          : this.notificationId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('colorHex: $colorHex, ')
          ..write('folderId: $folderId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('triggerAt: $triggerAt, ')
          ..write('repeatRule: $repeatRule, ')
          ..write('alertStyle: $alertStyle, ')
          ..write('sound: $sound, ')
          ..write('snoozeMinutes: $snoozeMinutes, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('locationJson: $locationJson, ')
          ..write('linkedItemId: $linkedItemId, ')
          ..write('linkedItemType: $linkedItemType, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('lastFiredAt: $lastFiredAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('notificationId: $notificationId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
    isPinned,
    isFavorite,
    colorHex,
    folderId,
    sortOrder,
    syncVersion,
    lastSyncedAt,
    deviceId,
    title,
    note,
    triggerAt,
    repeatRule,
    alertStyle,
    sound,
    snoozeMinutes,
    snoozedUntil,
    locationJson,
    linkedItemId,
    linkedItemType,
    isEnabled,
    lastFiredAt,
    completedAt,
    notificationId,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.archivedAt == this.archivedAt &&
          other.deletedAt == this.deletedAt &&
          other.isPinned == this.isPinned &&
          other.isFavorite == this.isFavorite &&
          other.colorHex == this.colorHex &&
          other.folderId == this.folderId &&
          other.sortOrder == this.sortOrder &&
          other.syncVersion == this.syncVersion &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.deviceId == this.deviceId &&
          other.title == this.title &&
          other.note == this.note &&
          other.triggerAt == this.triggerAt &&
          other.repeatRule == this.repeatRule &&
          other.alertStyle == this.alertStyle &&
          other.sound == this.sound &&
          other.snoozeMinutes == this.snoozeMinutes &&
          other.snoozedUntil == this.snoozedUntil &&
          other.locationJson == this.locationJson &&
          other.linkedItemId == this.linkedItemId &&
          other.linkedItemType == this.linkedItemType &&
          other.isEnabled == this.isEnabled &&
          other.lastFiredAt == this.lastFiredAt &&
          other.completedAt == this.completedAt &&
          other.notificationId == this.notificationId);
}

class RemindersCompanion extends UpdateCompanion<ReminderRow> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> archivedAt;
  final Value<DateTime?> deletedAt;
  final Value<bool> isPinned;
  final Value<bool> isFavorite;
  final Value<String?> colorHex;
  final Value<String?> folderId;
  final Value<double> sortOrder;
  final Value<int> syncVersion;
  final Value<DateTime?> lastSyncedAt;
  final Value<String> deviceId;
  final Value<String> title;
  final Value<String> note;
  final Value<DateTime> triggerAt;
  final Value<String?> repeatRule;
  final Value<int> alertStyle;
  final Value<String> sound;
  final Value<int> snoozeMinutes;
  final Value<DateTime?> snoozedUntil;
  final Value<String?> locationJson;
  final Value<String?> linkedItemId;
  final Value<String?> linkedItemType;
  final Value<bool> isEnabled;
  final Value<DateTime?> lastFiredAt;
  final Value<DateTime?> completedAt;
  final Value<int> notificationId;
  final Value<int> rowid;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.folderId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.title = const Value.absent(),
    this.note = const Value.absent(),
    this.triggerAt = const Value.absent(),
    this.repeatRule = const Value.absent(),
    this.alertStyle = const Value.absent(),
    this.sound = const Value.absent(),
    this.snoozeMinutes = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.locationJson = const Value.absent(),
    this.linkedItemId = const Value.absent(),
    this.linkedItemType = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.lastFiredAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.notificationId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemindersCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.folderId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.title = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime triggerAt,
    this.repeatRule = const Value.absent(),
    this.alertStyle = const Value.absent(),
    this.sound = const Value.absent(),
    this.snoozeMinutes = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.locationJson = const Value.absent(),
    this.linkedItemId = const Value.absent(),
    this.linkedItemType = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.lastFiredAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    required int notificationId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       triggerAt = Value(triggerAt),
       notificationId = Value(notificationId);
  static Insertable<ReminderRow> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? deletedAt,
    Expression<bool>? isPinned,
    Expression<bool>? isFavorite,
    Expression<String>? colorHex,
    Expression<String>? folderId,
    Expression<double>? sortOrder,
    Expression<int>? syncVersion,
    Expression<DateTime>? lastSyncedAt,
    Expression<String>? deviceId,
    Expression<String>? title,
    Expression<String>? note,
    Expression<DateTime>? triggerAt,
    Expression<String>? repeatRule,
    Expression<int>? alertStyle,
    Expression<String>? sound,
    Expression<int>? snoozeMinutes,
    Expression<DateTime>? snoozedUntil,
    Expression<String>? locationJson,
    Expression<String>? linkedItemId,
    Expression<String>? linkedItemType,
    Expression<bool>? isEnabled,
    Expression<DateTime>? lastFiredAt,
    Expression<DateTime>? completedAt,
    Expression<int>? notificationId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (colorHex != null) 'color_hex': colorHex,
      if (folderId != null) 'folder_id': folderId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (syncVersion != null) 'sync_version': syncVersion,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (title != null) 'title': title,
      if (note != null) 'note': note,
      if (triggerAt != null) 'trigger_at': triggerAt,
      if (repeatRule != null) 'repeat_rule': repeatRule,
      if (alertStyle != null) 'alert_style': alertStyle,
      if (sound != null) 'sound': sound,
      if (snoozeMinutes != null) 'snooze_minutes': snoozeMinutes,
      if (snoozedUntil != null) 'snoozed_until': snoozedUntil,
      if (locationJson != null) 'location_json': locationJson,
      if (linkedItemId != null) 'linked_item_id': linkedItemId,
      if (linkedItemType != null) 'linked_item_type': linkedItemType,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (lastFiredAt != null) 'last_fired_at': lastFiredAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (notificationId != null) 'notification_id': notificationId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemindersCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? archivedAt,
    Value<DateTime?>? deletedAt,
    Value<bool>? isPinned,
    Value<bool>? isFavorite,
    Value<String?>? colorHex,
    Value<String?>? folderId,
    Value<double>? sortOrder,
    Value<int>? syncVersion,
    Value<DateTime?>? lastSyncedAt,
    Value<String>? deviceId,
    Value<String>? title,
    Value<String>? note,
    Value<DateTime>? triggerAt,
    Value<String?>? repeatRule,
    Value<int>? alertStyle,
    Value<String>? sound,
    Value<int>? snoozeMinutes,
    Value<DateTime?>? snoozedUntil,
    Value<String?>? locationJson,
    Value<String?>? linkedItemId,
    Value<String?>? linkedItemType,
    Value<bool>? isEnabled,
    Value<DateTime?>? lastFiredAt,
    Value<DateTime?>? completedAt,
    Value<int>? notificationId,
    Value<int>? rowid,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      colorHex: colorHex ?? this.colorHex,
      folderId: folderId ?? this.folderId,
      sortOrder: sortOrder ?? this.sortOrder,
      syncVersion: syncVersion ?? this.syncVersion,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      deviceId: deviceId ?? this.deviceId,
      title: title ?? this.title,
      note: note ?? this.note,
      triggerAt: triggerAt ?? this.triggerAt,
      repeatRule: repeatRule ?? this.repeatRule,
      alertStyle: alertStyle ?? this.alertStyle,
      sound: sound ?? this.sound,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      locationJson: locationJson ?? this.locationJson,
      linkedItemId: linkedItemId ?? this.linkedItemId,
      linkedItemType: linkedItemType ?? this.linkedItemType,
      isEnabled: isEnabled ?? this.isEnabled,
      lastFiredAt: lastFiredAt ?? this.lastFiredAt,
      completedAt: completedAt ?? this.completedAt,
      notificationId: notificationId ?? this.notificationId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<double>(sortOrder.value);
    }
    if (syncVersion.present) {
      map['sync_version'] = Variable<int>(syncVersion.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (triggerAt.present) {
      map['trigger_at'] = Variable<DateTime>(triggerAt.value);
    }
    if (repeatRule.present) {
      map['repeat_rule'] = Variable<String>(repeatRule.value);
    }
    if (alertStyle.present) {
      map['alert_style'] = Variable<int>(alertStyle.value);
    }
    if (sound.present) {
      map['sound'] = Variable<String>(sound.value);
    }
    if (snoozeMinutes.present) {
      map['snooze_minutes'] = Variable<int>(snoozeMinutes.value);
    }
    if (snoozedUntil.present) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil.value);
    }
    if (locationJson.present) {
      map['location_json'] = Variable<String>(locationJson.value);
    }
    if (linkedItemId.present) {
      map['linked_item_id'] = Variable<String>(linkedItemId.value);
    }
    if (linkedItemType.present) {
      map['linked_item_type'] = Variable<String>(linkedItemType.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (lastFiredAt.present) {
      map['last_fired_at'] = Variable<DateTime>(lastFiredAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (notificationId.present) {
      map['notification_id'] = Variable<int>(notificationId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('colorHex: $colorHex, ')
          ..write('folderId: $folderId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('triggerAt: $triggerAt, ')
          ..write('repeatRule: $repeatRule, ')
          ..write('alertStyle: $alertStyle, ')
          ..write('sound: $sound, ')
          ..write('snoozeMinutes: $snoozeMinutes, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('locationJson: $locationJson, ')
          ..write('linkedItemId: $linkedItemId, ')
          ..write('linkedItemType: $linkedItemType, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('lastFiredAt: $lastFiredAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('notificationId: $notificationId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HabitsTable extends Habits with TableInfo<$HabitsTable, HabitRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<double> sortOrder = GeneratedColumn<double>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncVersionMeta = const VerificationMeta(
    'syncVersion',
  );
  @override
  late final GeneratedColumn<int> syncVersion = GeneratedColumn<int>(
    'sync_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _iconKeyMeta = const VerificationMeta(
    'iconKey',
  );
  @override
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
    'icon_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('star'),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Health'),
  );
  static const VerificationMeta _habitTypeMeta = const VerificationMeta(
    'habitType',
  );
  @override
  late final GeneratedColumn<int> habitType = GeneratedColumn<int>(
    'habit_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _targetCountMeta = const VerificationMeta(
    'targetCount',
  );
  @override
  late final GeneratedColumn<int> targetCount = GeneratedColumn<int>(
    'target_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('times'),
  );
  static const VerificationMeta _frequencyTypeMeta = const VerificationMeta(
    'frequencyType',
  );
  @override
  late final GeneratedColumn<int> frequencyType = GeneratedColumn<int>(
    'frequency_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _weekdaysMaskMeta = const VerificationMeta(
    'weekdaysMask',
  );
  @override
  late final GeneratedColumn<int> weekdaysMask = GeneratedColumn<int>(
    'weekdays_mask',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(127),
  );
  static const VerificationMeta _timesPerWeekMeta = const VerificationMeta(
    'timesPerWeek',
  );
  @override
  late final GeneratedColumn<int> timesPerWeek = GeneratedColumn<int>(
    'times_per_week',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _everyNDaysMeta = const VerificationMeta(
    'everyNDays',
  );
  @override
  late final GeneratedColumn<int> everyNDays = GeneratedColumn<int>(
    'every_n_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _partOfDayMeta = const VerificationMeta(
    'partOfDay',
  );
  @override
  late final GeneratedColumn<int> partOfDay = GeneratedColumn<int>(
    'part_of_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _reminderEnabledMeta = const VerificationMeta(
    'reminderEnabled',
  );
  @override
  late final GeneratedColumn<bool> reminderEnabled = GeneratedColumn<bool>(
    'reminder_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reminder_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _reminderTimesJsonMeta = const VerificationMeta(
    'reminderTimesJson',
  );
  @override
  late final GeneratedColumn<String> reminderTimesJson =
      GeneratedColumn<String>(
        'reminder_times_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPausedMeta = const VerificationMeta(
    'isPaused',
  );
  @override
  late final GeneratedColumn<bool> isPaused = GeneratedColumn<bool>(
    'is_paused',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_paused" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
    isPinned,
    isFavorite,
    colorHex,
    folderId,
    sortOrder,
    syncVersion,
    lastSyncedAt,
    deviceId,
    name,
    iconKey,
    category,
    habitType,
    targetCount,
    unit,
    frequencyType,
    weekdaysMask,
    timesPerWeek,
    everyNDays,
    partOfDay,
    reminderEnabled,
    reminderTimesJson,
    startDate,
    isPaused,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habits';
  @override
  VerificationContext validateIntegrity(
    Insertable<HabitRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('sync_version')) {
      context.handle(
        _syncVersionMeta,
        syncVersion.isAcceptableOrUnknown(
          data['sync_version']!,
          _syncVersionMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('icon_key')) {
      context.handle(
        _iconKeyMeta,
        iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('habit_type')) {
      context.handle(
        _habitTypeMeta,
        habitType.isAcceptableOrUnknown(data['habit_type']!, _habitTypeMeta),
      );
    }
    if (data.containsKey('target_count')) {
      context.handle(
        _targetCountMeta,
        targetCount.isAcceptableOrUnknown(
          data['target_count']!,
          _targetCountMeta,
        ),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('frequency_type')) {
      context.handle(
        _frequencyTypeMeta,
        frequencyType.isAcceptableOrUnknown(
          data['frequency_type']!,
          _frequencyTypeMeta,
        ),
      );
    }
    if (data.containsKey('weekdays_mask')) {
      context.handle(
        _weekdaysMaskMeta,
        weekdaysMask.isAcceptableOrUnknown(
          data['weekdays_mask']!,
          _weekdaysMaskMeta,
        ),
      );
    }
    if (data.containsKey('times_per_week')) {
      context.handle(
        _timesPerWeekMeta,
        timesPerWeek.isAcceptableOrUnknown(
          data['times_per_week']!,
          _timesPerWeekMeta,
        ),
      );
    }
    if (data.containsKey('every_n_days')) {
      context.handle(
        _everyNDaysMeta,
        everyNDays.isAcceptableOrUnknown(
          data['every_n_days']!,
          _everyNDaysMeta,
        ),
      );
    }
    if (data.containsKey('part_of_day')) {
      context.handle(
        _partOfDayMeta,
        partOfDay.isAcceptableOrUnknown(data['part_of_day']!, _partOfDayMeta),
      );
    }
    if (data.containsKey('reminder_enabled')) {
      context.handle(
        _reminderEnabledMeta,
        reminderEnabled.isAcceptableOrUnknown(
          data['reminder_enabled']!,
          _reminderEnabledMeta,
        ),
      );
    }
    if (data.containsKey('reminder_times_json')) {
      context.handle(
        _reminderTimesJsonMeta,
        reminderTimesJson.isAcceptableOrUnknown(
          data['reminder_times_json']!,
          _reminderTimesJsonMeta,
        ),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('is_paused')) {
      context.handle(
        _isPausedMeta,
        isPaused.isAcceptableOrUnknown(data['is_paused']!, _isPausedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HabitRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      ),
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sort_order'],
      )!,
      syncVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_version'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      iconKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_key'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      habitType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}habit_type'],
      )!,
      targetCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_count'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      frequencyType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}frequency_type'],
      )!,
      weekdaysMask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekdays_mask'],
      )!,
      timesPerWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}times_per_week'],
      )!,
      everyNDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}every_n_days'],
      )!,
      partOfDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}part_of_day'],
      )!,
      reminderEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reminder_enabled'],
      )!,
      reminderTimesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_times_json'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      isPaused: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_paused'],
      )!,
    );
  }

  @override
  $HabitsTable createAlias(String alias) {
    return $HabitsTable(attachedDatabase, alias);
  }
}

class HabitRow extends DataClass implements Insertable<HabitRow> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final bool isPinned;
  final bool isFavorite;

  /// `RRGGBB`; null = module default / white card.
  final String? colorHex;

  /// Folder (notes/vault) or list (tasks). See [Folders].
  final String? folderId;

  /// Manual sort position (lower first). Fractional so a drag only rewrites
  /// the moved row.
  final double sortOrder;
  final int syncVersion;
  final DateTime? lastSyncedAt;

  /// Device that last wrote the row (core/storage/device_id).
  final String deviceId;
  final String name;

  /// Key into the habit icon catalogue (features/habits).
  final String iconKey;
  final String category;

  /// 0 build · 1 quit.
  final int habitType;

  /// Daily target (8 glasses). 1 = a simple yes/no habit.
  final int targetCount;
  final String unit;

  /// 0 every day · 1 specific days ([weekdaysMask]) · 2 x per week · 3 every N days.
  final int frequencyType;

  /// Bit 0 = Monday … bit 6 = Sunday (127 = every day).
  final int weekdaysMask;
  final int timesPerWeek;
  final int everyNDays;

  /// 0 anytime · 1 morning · 2 afternoon · 3 evening (list filter chips).
  final int partOfDay;
  final bool reminderEnabled;

  /// JSON list of `HH:mm` strings.
  final String reminderTimesJson;

  /// First day the habit counts (yyyy-MM-dd).
  final String startDate;
  final bool isPaused;
  const HabitRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.deletedAt,
    required this.isPinned,
    required this.isFavorite,
    this.colorHex,
    this.folderId,
    required this.sortOrder,
    required this.syncVersion,
    this.lastSyncedAt,
    required this.deviceId,
    required this.name,
    required this.iconKey,
    required this.category,
    required this.habitType,
    required this.targetCount,
    required this.unit,
    required this.frequencyType,
    required this.weekdaysMask,
    required this.timesPerWeek,
    required this.everyNDays,
    required this.partOfDay,
    required this.reminderEnabled,
    required this.reminderTimesJson,
    required this.startDate,
    required this.isPaused,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_favorite'] = Variable<bool>(isFavorite);
    if (!nullToAbsent || colorHex != null) {
      map['color_hex'] = Variable<String>(colorHex);
    }
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['sort_order'] = Variable<double>(sortOrder);
    map['sync_version'] = Variable<int>(syncVersion);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['name'] = Variable<String>(name);
    map['icon_key'] = Variable<String>(iconKey);
    map['category'] = Variable<String>(category);
    map['habit_type'] = Variable<int>(habitType);
    map['target_count'] = Variable<int>(targetCount);
    map['unit'] = Variable<String>(unit);
    map['frequency_type'] = Variable<int>(frequencyType);
    map['weekdays_mask'] = Variable<int>(weekdaysMask);
    map['times_per_week'] = Variable<int>(timesPerWeek);
    map['every_n_days'] = Variable<int>(everyNDays);
    map['part_of_day'] = Variable<int>(partOfDay);
    map['reminder_enabled'] = Variable<bool>(reminderEnabled);
    map['reminder_times_json'] = Variable<String>(reminderTimesJson);
    map['start_date'] = Variable<String>(startDate);
    map['is_paused'] = Variable<bool>(isPaused);
    return map;
  }

  HabitsCompanion toCompanion(bool nullToAbsent) {
    return HabitsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      isPinned: Value(isPinned),
      isFavorite: Value(isFavorite),
      colorHex: colorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(colorHex),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      sortOrder: Value(sortOrder),
      syncVersion: Value(syncVersion),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      deviceId: Value(deviceId),
      name: Value(name),
      iconKey: Value(iconKey),
      category: Value(category),
      habitType: Value(habitType),
      targetCount: Value(targetCount),
      unit: Value(unit),
      frequencyType: Value(frequencyType),
      weekdaysMask: Value(weekdaysMask),
      timesPerWeek: Value(timesPerWeek),
      everyNDays: Value(everyNDays),
      partOfDay: Value(partOfDay),
      reminderEnabled: Value(reminderEnabled),
      reminderTimesJson: Value(reminderTimesJson),
      startDate: Value(startDate),
      isPaused: Value(isPaused),
    );
  }

  factory HabitRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      colorHex: serializer.fromJson<String?>(json['colorHex']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      sortOrder: serializer.fromJson<double>(json['sortOrder']),
      syncVersion: serializer.fromJson<int>(json['syncVersion']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      name: serializer.fromJson<String>(json['name']),
      iconKey: serializer.fromJson<String>(json['iconKey']),
      category: serializer.fromJson<String>(json['category']),
      habitType: serializer.fromJson<int>(json['habitType']),
      targetCount: serializer.fromJson<int>(json['targetCount']),
      unit: serializer.fromJson<String>(json['unit']),
      frequencyType: serializer.fromJson<int>(json['frequencyType']),
      weekdaysMask: serializer.fromJson<int>(json['weekdaysMask']),
      timesPerWeek: serializer.fromJson<int>(json['timesPerWeek']),
      everyNDays: serializer.fromJson<int>(json['everyNDays']),
      partOfDay: serializer.fromJson<int>(json['partOfDay']),
      reminderEnabled: serializer.fromJson<bool>(json['reminderEnabled']),
      reminderTimesJson: serializer.fromJson<String>(json['reminderTimesJson']),
      startDate: serializer.fromJson<String>(json['startDate']),
      isPaused: serializer.fromJson<bool>(json['isPaused']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'colorHex': serializer.toJson<String?>(colorHex),
      'folderId': serializer.toJson<String?>(folderId),
      'sortOrder': serializer.toJson<double>(sortOrder),
      'syncVersion': serializer.toJson<int>(syncVersion),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'name': serializer.toJson<String>(name),
      'iconKey': serializer.toJson<String>(iconKey),
      'category': serializer.toJson<String>(category),
      'habitType': serializer.toJson<int>(habitType),
      'targetCount': serializer.toJson<int>(targetCount),
      'unit': serializer.toJson<String>(unit),
      'frequencyType': serializer.toJson<int>(frequencyType),
      'weekdaysMask': serializer.toJson<int>(weekdaysMask),
      'timesPerWeek': serializer.toJson<int>(timesPerWeek),
      'everyNDays': serializer.toJson<int>(everyNDays),
      'partOfDay': serializer.toJson<int>(partOfDay),
      'reminderEnabled': serializer.toJson<bool>(reminderEnabled),
      'reminderTimesJson': serializer.toJson<String>(reminderTimesJson),
      'startDate': serializer.toJson<String>(startDate),
      'isPaused': serializer.toJson<bool>(isPaused),
    };
  }

  HabitRow copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> archivedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? isPinned,
    bool? isFavorite,
    Value<String?> colorHex = const Value.absent(),
    Value<String?> folderId = const Value.absent(),
    double? sortOrder,
    int? syncVersion,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    String? deviceId,
    String? name,
    String? iconKey,
    String? category,
    int? habitType,
    int? targetCount,
    String? unit,
    int? frequencyType,
    int? weekdaysMask,
    int? timesPerWeek,
    int? everyNDays,
    int? partOfDay,
    bool? reminderEnabled,
    String? reminderTimesJson,
    String? startDate,
    bool? isPaused,
  }) => HabitRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    isPinned: isPinned ?? this.isPinned,
    isFavorite: isFavorite ?? this.isFavorite,
    colorHex: colorHex.present ? colorHex.value : this.colorHex,
    folderId: folderId.present ? folderId.value : this.folderId,
    sortOrder: sortOrder ?? this.sortOrder,
    syncVersion: syncVersion ?? this.syncVersion,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    deviceId: deviceId ?? this.deviceId,
    name: name ?? this.name,
    iconKey: iconKey ?? this.iconKey,
    category: category ?? this.category,
    habitType: habitType ?? this.habitType,
    targetCount: targetCount ?? this.targetCount,
    unit: unit ?? this.unit,
    frequencyType: frequencyType ?? this.frequencyType,
    weekdaysMask: weekdaysMask ?? this.weekdaysMask,
    timesPerWeek: timesPerWeek ?? this.timesPerWeek,
    everyNDays: everyNDays ?? this.everyNDays,
    partOfDay: partOfDay ?? this.partOfDay,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderTimesJson: reminderTimesJson ?? this.reminderTimesJson,
    startDate: startDate ?? this.startDate,
    isPaused: isPaused ?? this.isPaused,
  );
  HabitRow copyWithCompanion(HabitsCompanion data) {
    return HabitRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      syncVersion: data.syncVersion.present
          ? data.syncVersion.value
          : this.syncVersion,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      name: data.name.present ? data.name.value : this.name,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      category: data.category.present ? data.category.value : this.category,
      habitType: data.habitType.present ? data.habitType.value : this.habitType,
      targetCount: data.targetCount.present
          ? data.targetCount.value
          : this.targetCount,
      unit: data.unit.present ? data.unit.value : this.unit,
      frequencyType: data.frequencyType.present
          ? data.frequencyType.value
          : this.frequencyType,
      weekdaysMask: data.weekdaysMask.present
          ? data.weekdaysMask.value
          : this.weekdaysMask,
      timesPerWeek: data.timesPerWeek.present
          ? data.timesPerWeek.value
          : this.timesPerWeek,
      everyNDays: data.everyNDays.present
          ? data.everyNDays.value
          : this.everyNDays,
      partOfDay: data.partOfDay.present ? data.partOfDay.value : this.partOfDay,
      reminderEnabled: data.reminderEnabled.present
          ? data.reminderEnabled.value
          : this.reminderEnabled,
      reminderTimesJson: data.reminderTimesJson.present
          ? data.reminderTimesJson.value
          : this.reminderTimesJson,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      isPaused: data.isPaused.present ? data.isPaused.value : this.isPaused,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('colorHex: $colorHex, ')
          ..write('folderId: $folderId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('name: $name, ')
          ..write('iconKey: $iconKey, ')
          ..write('category: $category, ')
          ..write('habitType: $habitType, ')
          ..write('targetCount: $targetCount, ')
          ..write('unit: $unit, ')
          ..write('frequencyType: $frequencyType, ')
          ..write('weekdaysMask: $weekdaysMask, ')
          ..write('timesPerWeek: $timesPerWeek, ')
          ..write('everyNDays: $everyNDays, ')
          ..write('partOfDay: $partOfDay, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderTimesJson: $reminderTimesJson, ')
          ..write('startDate: $startDate, ')
          ..write('isPaused: $isPaused')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
    isPinned,
    isFavorite,
    colorHex,
    folderId,
    sortOrder,
    syncVersion,
    lastSyncedAt,
    deviceId,
    name,
    iconKey,
    category,
    habitType,
    targetCount,
    unit,
    frequencyType,
    weekdaysMask,
    timesPerWeek,
    everyNDays,
    partOfDay,
    reminderEnabled,
    reminderTimesJson,
    startDate,
    isPaused,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.archivedAt == this.archivedAt &&
          other.deletedAt == this.deletedAt &&
          other.isPinned == this.isPinned &&
          other.isFavorite == this.isFavorite &&
          other.colorHex == this.colorHex &&
          other.folderId == this.folderId &&
          other.sortOrder == this.sortOrder &&
          other.syncVersion == this.syncVersion &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.deviceId == this.deviceId &&
          other.name == this.name &&
          other.iconKey == this.iconKey &&
          other.category == this.category &&
          other.habitType == this.habitType &&
          other.targetCount == this.targetCount &&
          other.unit == this.unit &&
          other.frequencyType == this.frequencyType &&
          other.weekdaysMask == this.weekdaysMask &&
          other.timesPerWeek == this.timesPerWeek &&
          other.everyNDays == this.everyNDays &&
          other.partOfDay == this.partOfDay &&
          other.reminderEnabled == this.reminderEnabled &&
          other.reminderTimesJson == this.reminderTimesJson &&
          other.startDate == this.startDate &&
          other.isPaused == this.isPaused);
}

class HabitsCompanion extends UpdateCompanion<HabitRow> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> archivedAt;
  final Value<DateTime?> deletedAt;
  final Value<bool> isPinned;
  final Value<bool> isFavorite;
  final Value<String?> colorHex;
  final Value<String?> folderId;
  final Value<double> sortOrder;
  final Value<int> syncVersion;
  final Value<DateTime?> lastSyncedAt;
  final Value<String> deviceId;
  final Value<String> name;
  final Value<String> iconKey;
  final Value<String> category;
  final Value<int> habitType;
  final Value<int> targetCount;
  final Value<String> unit;
  final Value<int> frequencyType;
  final Value<int> weekdaysMask;
  final Value<int> timesPerWeek;
  final Value<int> everyNDays;
  final Value<int> partOfDay;
  final Value<bool> reminderEnabled;
  final Value<String> reminderTimesJson;
  final Value<String> startDate;
  final Value<bool> isPaused;
  final Value<int> rowid;
  const HabitsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.folderId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.name = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.category = const Value.absent(),
    this.habitType = const Value.absent(),
    this.targetCount = const Value.absent(),
    this.unit = const Value.absent(),
    this.frequencyType = const Value.absent(),
    this.weekdaysMask = const Value.absent(),
    this.timesPerWeek = const Value.absent(),
    this.everyNDays = const Value.absent(),
    this.partOfDay = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderTimesJson = const Value.absent(),
    this.startDate = const Value.absent(),
    this.isPaused = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitsCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.folderId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.name = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.category = const Value.absent(),
    this.habitType = const Value.absent(),
    this.targetCount = const Value.absent(),
    this.unit = const Value.absent(),
    this.frequencyType = const Value.absent(),
    this.weekdaysMask = const Value.absent(),
    this.timesPerWeek = const Value.absent(),
    this.everyNDays = const Value.absent(),
    this.partOfDay = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderTimesJson = const Value.absent(),
    required String startDate,
    this.isPaused = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       startDate = Value(startDate);
  static Insertable<HabitRow> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? deletedAt,
    Expression<bool>? isPinned,
    Expression<bool>? isFavorite,
    Expression<String>? colorHex,
    Expression<String>? folderId,
    Expression<double>? sortOrder,
    Expression<int>? syncVersion,
    Expression<DateTime>? lastSyncedAt,
    Expression<String>? deviceId,
    Expression<String>? name,
    Expression<String>? iconKey,
    Expression<String>? category,
    Expression<int>? habitType,
    Expression<int>? targetCount,
    Expression<String>? unit,
    Expression<int>? frequencyType,
    Expression<int>? weekdaysMask,
    Expression<int>? timesPerWeek,
    Expression<int>? everyNDays,
    Expression<int>? partOfDay,
    Expression<bool>? reminderEnabled,
    Expression<String>? reminderTimesJson,
    Expression<String>? startDate,
    Expression<bool>? isPaused,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (colorHex != null) 'color_hex': colorHex,
      if (folderId != null) 'folder_id': folderId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (syncVersion != null) 'sync_version': syncVersion,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (name != null) 'name': name,
      if (iconKey != null) 'icon_key': iconKey,
      if (category != null) 'category': category,
      if (habitType != null) 'habit_type': habitType,
      if (targetCount != null) 'target_count': targetCount,
      if (unit != null) 'unit': unit,
      if (frequencyType != null) 'frequency_type': frequencyType,
      if (weekdaysMask != null) 'weekdays_mask': weekdaysMask,
      if (timesPerWeek != null) 'times_per_week': timesPerWeek,
      if (everyNDays != null) 'every_n_days': everyNDays,
      if (partOfDay != null) 'part_of_day': partOfDay,
      if (reminderEnabled != null) 'reminder_enabled': reminderEnabled,
      if (reminderTimesJson != null) 'reminder_times_json': reminderTimesJson,
      if (startDate != null) 'start_date': startDate,
      if (isPaused != null) 'is_paused': isPaused,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? archivedAt,
    Value<DateTime?>? deletedAt,
    Value<bool>? isPinned,
    Value<bool>? isFavorite,
    Value<String?>? colorHex,
    Value<String?>? folderId,
    Value<double>? sortOrder,
    Value<int>? syncVersion,
    Value<DateTime?>? lastSyncedAt,
    Value<String>? deviceId,
    Value<String>? name,
    Value<String>? iconKey,
    Value<String>? category,
    Value<int>? habitType,
    Value<int>? targetCount,
    Value<String>? unit,
    Value<int>? frequencyType,
    Value<int>? weekdaysMask,
    Value<int>? timesPerWeek,
    Value<int>? everyNDays,
    Value<int>? partOfDay,
    Value<bool>? reminderEnabled,
    Value<String>? reminderTimesJson,
    Value<String>? startDate,
    Value<bool>? isPaused,
    Value<int>? rowid,
  }) {
    return HabitsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      colorHex: colorHex ?? this.colorHex,
      folderId: folderId ?? this.folderId,
      sortOrder: sortOrder ?? this.sortOrder,
      syncVersion: syncVersion ?? this.syncVersion,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      category: category ?? this.category,
      habitType: habitType ?? this.habitType,
      targetCount: targetCount ?? this.targetCount,
      unit: unit ?? this.unit,
      frequencyType: frequencyType ?? this.frequencyType,
      weekdaysMask: weekdaysMask ?? this.weekdaysMask,
      timesPerWeek: timesPerWeek ?? this.timesPerWeek,
      everyNDays: everyNDays ?? this.everyNDays,
      partOfDay: partOfDay ?? this.partOfDay,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTimesJson: reminderTimesJson ?? this.reminderTimesJson,
      startDate: startDate ?? this.startDate,
      isPaused: isPaused ?? this.isPaused,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<double>(sortOrder.value);
    }
    if (syncVersion.present) {
      map['sync_version'] = Variable<int>(syncVersion.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (iconKey.present) {
      map['icon_key'] = Variable<String>(iconKey.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (habitType.present) {
      map['habit_type'] = Variable<int>(habitType.value);
    }
    if (targetCount.present) {
      map['target_count'] = Variable<int>(targetCount.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (frequencyType.present) {
      map['frequency_type'] = Variable<int>(frequencyType.value);
    }
    if (weekdaysMask.present) {
      map['weekdays_mask'] = Variable<int>(weekdaysMask.value);
    }
    if (timesPerWeek.present) {
      map['times_per_week'] = Variable<int>(timesPerWeek.value);
    }
    if (everyNDays.present) {
      map['every_n_days'] = Variable<int>(everyNDays.value);
    }
    if (partOfDay.present) {
      map['part_of_day'] = Variable<int>(partOfDay.value);
    }
    if (reminderEnabled.present) {
      map['reminder_enabled'] = Variable<bool>(reminderEnabled.value);
    }
    if (reminderTimesJson.present) {
      map['reminder_times_json'] = Variable<String>(reminderTimesJson.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (isPaused.present) {
      map['is_paused'] = Variable<bool>(isPaused.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('colorHex: $colorHex, ')
          ..write('folderId: $folderId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('name: $name, ')
          ..write('iconKey: $iconKey, ')
          ..write('category: $category, ')
          ..write('habitType: $habitType, ')
          ..write('targetCount: $targetCount, ')
          ..write('unit: $unit, ')
          ..write('frequencyType: $frequencyType, ')
          ..write('weekdaysMask: $weekdaysMask, ')
          ..write('timesPerWeek: $timesPerWeek, ')
          ..write('everyNDays: $everyNDays, ')
          ..write('partOfDay: $partOfDay, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderTimesJson: $reminderTimesJson, ')
          ..write('startDate: $startDate, ')
          ..write('isPaused: $isPaused, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HabitLogsTable extends HabitLogs
    with TableInfo<$HabitLogsTable, HabitLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _habitIdMeta = const VerificationMeta(
    'habitId',
  );
  @override
  late final GeneratedColumn<String> habitId = GeneratedColumn<String>(
    'habit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _skippedMeta = const VerificationMeta(
    'skipped',
  );
  @override
  late final GeneratedColumn<bool> skipped = GeneratedColumn<bool>(
    'skipped',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("skipped" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    habitId,
    date,
    count,
    skipped,
    note,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<HabitLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('habit_id')) {
      context.handle(
        _habitIdMeta,
        habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_habitIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    }
    if (data.containsKey('skipped')) {
      context.handle(
        _skippedMeta,
        skipped.isAcceptableOrUnknown(data['skipped']!, _skippedMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {habitId, date},
  ];
  @override
  HabitLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      habitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}habit_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
      skipped: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}skipped'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $HabitLogsTable createAlias(String alias) {
    return $HabitLogsTable(attachedDatabase, alias);
  }
}

class HabitLogRow extends DataClass implements Insertable<HabitLogRow> {
  final String id;
  final String habitId;

  /// Local day, yyyy-MM-dd.
  final String date;
  final int count;
  final bool skipped;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  const HabitLogRow({
    required this.id,
    required this.habitId,
    required this.date,
    required this.count,
    required this.skipped,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['habit_id'] = Variable<String>(habitId);
    map['date'] = Variable<String>(date);
    map['count'] = Variable<int>(count);
    map['skipped'] = Variable<bool>(skipped);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  HabitLogsCompanion toCompanion(bool nullToAbsent) {
    return HabitLogsCompanion(
      id: Value(id),
      habitId: Value(habitId),
      date: Value(date),
      count: Value(count),
      skipped: Value(skipped),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory HabitLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitLogRow(
      id: serializer.fromJson<String>(json['id']),
      habitId: serializer.fromJson<String>(json['habitId']),
      date: serializer.fromJson<String>(json['date']),
      count: serializer.fromJson<int>(json['count']),
      skipped: serializer.fromJson<bool>(json['skipped']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'habitId': serializer.toJson<String>(habitId),
      'date': serializer.toJson<String>(date),
      'count': serializer.toJson<int>(count),
      'skipped': serializer.toJson<bool>(skipped),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  HabitLogRow copyWith({
    String? id,
    String? habitId,
    String? date,
    int? count,
    bool? skipped,
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => HabitLogRow(
    id: id ?? this.id,
    habitId: habitId ?? this.habitId,
    date: date ?? this.date,
    count: count ?? this.count,
    skipped: skipped ?? this.skipped,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  HabitLogRow copyWithCompanion(HabitLogsCompanion data) {
    return HabitLogRow(
      id: data.id.present ? data.id.value : this.id,
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      date: data.date.present ? data.date.value : this.date,
      count: data.count.present ? data.count.value : this.count,
      skipped: data.skipped.present ? data.skipped.value : this.skipped,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitLogRow(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('date: $date, ')
          ..write('count: $count, ')
          ..write('skipped: $skipped, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    habitId,
    date,
    count,
    skipped,
    note,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitLogRow &&
          other.id == this.id &&
          other.habitId == this.habitId &&
          other.date == this.date &&
          other.count == this.count &&
          other.skipped == this.skipped &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class HabitLogsCompanion extends UpdateCompanion<HabitLogRow> {
  final Value<String> id;
  final Value<String> habitId;
  final Value<String> date;
  final Value<int> count;
  final Value<bool> skipped;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const HabitLogsCompanion({
    this.id = const Value.absent(),
    this.habitId = const Value.absent(),
    this.date = const Value.absent(),
    this.count = const Value.absent(),
    this.skipped = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitLogsCompanion.insert({
    required String id,
    required String habitId,
    required String date,
    this.count = const Value.absent(),
    this.skipped = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       habitId = Value(habitId),
       date = Value(date),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<HabitLogRow> custom({
    Expression<String>? id,
    Expression<String>? habitId,
    Expression<String>? date,
    Expression<int>? count,
    Expression<bool>? skipped,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (habitId != null) 'habit_id': habitId,
      if (date != null) 'date': date,
      if (count != null) 'count': count,
      if (skipped != null) 'skipped': skipped,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitLogsCompanion copyWith({
    Value<String>? id,
    Value<String>? habitId,
    Value<String>? date,
    Value<int>? count,
    Value<bool>? skipped,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return HabitLogsCompanion(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      date: date ?? this.date,
      count: count ?? this.count,
      skipped: skipped ?? this.skipped,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (habitId.present) {
      map['habit_id'] = Variable<String>(habitId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (skipped.present) {
      map['skipped'] = Variable<bool>(skipped.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitLogsCompanion(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('date: $date, ')
          ..write('count: $count, ')
          ..write('skipped: $skipped, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VaultItemsTable extends VaultItems
    with TableInfo<$VaultItemsTable, VaultItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<double> sortOrder = GeneratedColumn<double>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncVersionMeta = const VerificationMeta(
    'syncVersion',
  );
  @override
  late final GeneratedColumn<int> syncVersion = GeneratedColumn<int>(
    'sync_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _itemTypeMeta = const VerificationMeta(
    'itemType',
  );
  @override
  late final GeneratedColumn<int> itemType = GeneratedColumn<int>(
    'item_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _iconKeyMeta = const VerificationMeta(
    'iconKey',
  );
  @override
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
    'icon_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encryptedPayloadMeta = const VerificationMeta(
    'encryptedPayload',
  );
  @override
  late final GeneratedColumn<Uint8List> encryptedPayload =
      GeneratedColumn<Uint8List>(
        'encrypted_payload',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _passwordStrengthMeta = const VerificationMeta(
    'passwordStrength',
  );
  @override
  late final GeneratedColumn<int> passwordStrength = GeneratedColumn<int>(
    'password_strength',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _passwordUpdatedAtMeta = const VerificationMeta(
    'passwordUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> passwordUpdatedAt =
      GeneratedColumn<DateTime>(
        'password_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _passwordFingerprintMeta =
      const VerificationMeta('passwordFingerprint');
  @override
  late final GeneratedColumn<String> passwordFingerprint =
      GeneratedColumn<String>(
        'password_fingerprint',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _breachCountMeta = const VerificationMeta(
    'breachCount',
  );
  @override
  late final GeneratedColumn<int> breachCount = GeneratedColumn<int>(
    'breach_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _breachCheckedAtMeta = const VerificationMeta(
    'breachCheckedAt',
  );
  @override
  late final GeneratedColumn<DateTime> breachCheckedAt =
      GeneratedColumn<DateTime>(
        'breach_checked_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _hasTotpMeta = const VerificationMeta(
    'hasTotp',
  );
  @override
  late final GeneratedColumn<bool> hasTotp = GeneratedColumn<bool>(
    'has_totp',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_totp" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _expiryDaysMeta = const VerificationMeta(
    'expiryDays',
  );
  @override
  late final GeneratedColumn<int> expiryDays = GeneratedColumn<int>(
    'expiry_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
    isPinned,
    isFavorite,
    colorHex,
    folderId,
    sortOrder,
    syncVersion,
    lastSyncedAt,
    deviceId,
    itemType,
    title,
    iconKey,
    encryptedPayload,
    passwordStrength,
    passwordUpdatedAt,
    passwordFingerprint,
    breachCount,
    breachCheckedAt,
    hasTotp,
    expiryDays,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('sync_version')) {
      context.handle(
        _syncVersionMeta,
        syncVersion.isAcceptableOrUnknown(
          data['sync_version']!,
          _syncVersionMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('item_type')) {
      context.handle(
        _itemTypeMeta,
        itemType.isAcceptableOrUnknown(data['item_type']!, _itemTypeMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('icon_key')) {
      context.handle(
        _iconKeyMeta,
        iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta),
      );
    }
    if (data.containsKey('encrypted_payload')) {
      context.handle(
        _encryptedPayloadMeta,
        encryptedPayload.isAcceptableOrUnknown(
          data['encrypted_payload']!,
          _encryptedPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedPayloadMeta);
    }
    if (data.containsKey('password_strength')) {
      context.handle(
        _passwordStrengthMeta,
        passwordStrength.isAcceptableOrUnknown(
          data['password_strength']!,
          _passwordStrengthMeta,
        ),
      );
    }
    if (data.containsKey('password_updated_at')) {
      context.handle(
        _passwordUpdatedAtMeta,
        passwordUpdatedAt.isAcceptableOrUnknown(
          data['password_updated_at']!,
          _passwordUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('password_fingerprint')) {
      context.handle(
        _passwordFingerprintMeta,
        passwordFingerprint.isAcceptableOrUnknown(
          data['password_fingerprint']!,
          _passwordFingerprintMeta,
        ),
      );
    }
    if (data.containsKey('breach_count')) {
      context.handle(
        _breachCountMeta,
        breachCount.isAcceptableOrUnknown(
          data['breach_count']!,
          _breachCountMeta,
        ),
      );
    }
    if (data.containsKey('breach_checked_at')) {
      context.handle(
        _breachCheckedAtMeta,
        breachCheckedAt.isAcceptableOrUnknown(
          data['breach_checked_at']!,
          _breachCheckedAtMeta,
        ),
      );
    }
    if (data.containsKey('has_totp')) {
      context.handle(
        _hasTotpMeta,
        hasTotp.isAcceptableOrUnknown(data['has_totp']!, _hasTotpMeta),
      );
    }
    if (data.containsKey('expiry_days')) {
      context.handle(
        _expiryDaysMeta,
        expiryDays.isAcceptableOrUnknown(data['expiry_days']!, _expiryDaysMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      ),
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sort_order'],
      )!,
      syncVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_version'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      itemType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      iconKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_key'],
      ),
      encryptedPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}encrypted_payload'],
      )!,
      passwordStrength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}password_strength'],
      ),
      passwordUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}password_updated_at'],
      ),
      passwordFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password_fingerprint'],
      ),
      breachCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}breach_count'],
      ),
      breachCheckedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}breach_checked_at'],
      ),
      hasTotp: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_totp'],
      )!,
      expiryDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expiry_days'],
      ),
    );
  }

  @override
  $VaultItemsTable createAlias(String alias) {
    return $VaultItemsTable(attachedDatabase, alias);
  }
}

class VaultItemRow extends DataClass implements Insertable<VaultItemRow> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final bool isPinned;
  final bool isFavorite;

  /// `RRGGBB`; null = module default / white card.
  final String? colorHex;

  /// Folder (notes/vault) or list (tasks). See [Folders].
  final String? folderId;

  /// Manual sort position (lower first). Fractional so a drag only rewrites
  /// the moved row.
  final double sortOrder;
  final int syncVersion;
  final DateTime? lastSyncedAt;

  /// Device that last wrote the row (core/storage/device_id).
  final String deviceId;

  /// 0 login · 1 card · 2 wifi · 3 secure note.
  final int itemType;

  /// Plaintext title — the ONLY searchable field.
  final String title;

  /// Brand / icon key (letter avatar fallback).
  final String? iconKey;

  /// AES-256-GCM: nonce(12) ‖ ciphertext ‖ mac(16) of the JSON payload
  /// {username, password, url, totpSecret, notes, card…, wifi…, customFields}.
  final Uint8List encryptedPayload;

  /// Cached 0–4 strength of the current password (no secret leaks).
  final int? passwordStrength;
  final DateTime? passwordUpdatedAt;

  /// HMAC-SHA256(password) under a key derived from the vault DEK —
  /// detects reuse without decrypting every item.
  final String? passwordFingerprint;

  /// Have-I-Been-Pwned result cache (opt-in): null = never checked.
  final int? breachCount;
  final DateTime? breachCheckedAt;
  final bool hasTotp;

  /// "Password expiry reminder" in days; null = off.
  final int? expiryDays;
  const VaultItemRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.deletedAt,
    required this.isPinned,
    required this.isFavorite,
    this.colorHex,
    this.folderId,
    required this.sortOrder,
    required this.syncVersion,
    this.lastSyncedAt,
    required this.deviceId,
    required this.itemType,
    required this.title,
    this.iconKey,
    required this.encryptedPayload,
    this.passwordStrength,
    this.passwordUpdatedAt,
    this.passwordFingerprint,
    this.breachCount,
    this.breachCheckedAt,
    required this.hasTotp,
    this.expiryDays,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_favorite'] = Variable<bool>(isFavorite);
    if (!nullToAbsent || colorHex != null) {
      map['color_hex'] = Variable<String>(colorHex);
    }
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['sort_order'] = Variable<double>(sortOrder);
    map['sync_version'] = Variable<int>(syncVersion);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['item_type'] = Variable<int>(itemType);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || iconKey != null) {
      map['icon_key'] = Variable<String>(iconKey);
    }
    map['encrypted_payload'] = Variable<Uint8List>(encryptedPayload);
    if (!nullToAbsent || passwordStrength != null) {
      map['password_strength'] = Variable<int>(passwordStrength);
    }
    if (!nullToAbsent || passwordUpdatedAt != null) {
      map['password_updated_at'] = Variable<DateTime>(passwordUpdatedAt);
    }
    if (!nullToAbsent || passwordFingerprint != null) {
      map['password_fingerprint'] = Variable<String>(passwordFingerprint);
    }
    if (!nullToAbsent || breachCount != null) {
      map['breach_count'] = Variable<int>(breachCount);
    }
    if (!nullToAbsent || breachCheckedAt != null) {
      map['breach_checked_at'] = Variable<DateTime>(breachCheckedAt);
    }
    map['has_totp'] = Variable<bool>(hasTotp);
    if (!nullToAbsent || expiryDays != null) {
      map['expiry_days'] = Variable<int>(expiryDays);
    }
    return map;
  }

  VaultItemsCompanion toCompanion(bool nullToAbsent) {
    return VaultItemsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      isPinned: Value(isPinned),
      isFavorite: Value(isFavorite),
      colorHex: colorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(colorHex),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      sortOrder: Value(sortOrder),
      syncVersion: Value(syncVersion),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      deviceId: Value(deviceId),
      itemType: Value(itemType),
      title: Value(title),
      iconKey: iconKey == null && nullToAbsent
          ? const Value.absent()
          : Value(iconKey),
      encryptedPayload: Value(encryptedPayload),
      passwordStrength: passwordStrength == null && nullToAbsent
          ? const Value.absent()
          : Value(passwordStrength),
      passwordUpdatedAt: passwordUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(passwordUpdatedAt),
      passwordFingerprint: passwordFingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(passwordFingerprint),
      breachCount: breachCount == null && nullToAbsent
          ? const Value.absent()
          : Value(breachCount),
      breachCheckedAt: breachCheckedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(breachCheckedAt),
      hasTotp: Value(hasTotp),
      expiryDays: expiryDays == null && nullToAbsent
          ? const Value.absent()
          : Value(expiryDays),
    );
  }

  factory VaultItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultItemRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      colorHex: serializer.fromJson<String?>(json['colorHex']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      sortOrder: serializer.fromJson<double>(json['sortOrder']),
      syncVersion: serializer.fromJson<int>(json['syncVersion']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      itemType: serializer.fromJson<int>(json['itemType']),
      title: serializer.fromJson<String>(json['title']),
      iconKey: serializer.fromJson<String?>(json['iconKey']),
      encryptedPayload: serializer.fromJson<Uint8List>(
        json['encryptedPayload'],
      ),
      passwordStrength: serializer.fromJson<int?>(json['passwordStrength']),
      passwordUpdatedAt: serializer.fromJson<DateTime?>(
        json['passwordUpdatedAt'],
      ),
      passwordFingerprint: serializer.fromJson<String?>(
        json['passwordFingerprint'],
      ),
      breachCount: serializer.fromJson<int?>(json['breachCount']),
      breachCheckedAt: serializer.fromJson<DateTime?>(json['breachCheckedAt']),
      hasTotp: serializer.fromJson<bool>(json['hasTotp']),
      expiryDays: serializer.fromJson<int?>(json['expiryDays']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'colorHex': serializer.toJson<String?>(colorHex),
      'folderId': serializer.toJson<String?>(folderId),
      'sortOrder': serializer.toJson<double>(sortOrder),
      'syncVersion': serializer.toJson<int>(syncVersion),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'itemType': serializer.toJson<int>(itemType),
      'title': serializer.toJson<String>(title),
      'iconKey': serializer.toJson<String?>(iconKey),
      'encryptedPayload': serializer.toJson<Uint8List>(encryptedPayload),
      'passwordStrength': serializer.toJson<int?>(passwordStrength),
      'passwordUpdatedAt': serializer.toJson<DateTime?>(passwordUpdatedAt),
      'passwordFingerprint': serializer.toJson<String?>(passwordFingerprint),
      'breachCount': serializer.toJson<int?>(breachCount),
      'breachCheckedAt': serializer.toJson<DateTime?>(breachCheckedAt),
      'hasTotp': serializer.toJson<bool>(hasTotp),
      'expiryDays': serializer.toJson<int?>(expiryDays),
    };
  }

  VaultItemRow copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> archivedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? isPinned,
    bool? isFavorite,
    Value<String?> colorHex = const Value.absent(),
    Value<String?> folderId = const Value.absent(),
    double? sortOrder,
    int? syncVersion,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    String? deviceId,
    int? itemType,
    String? title,
    Value<String?> iconKey = const Value.absent(),
    Uint8List? encryptedPayload,
    Value<int?> passwordStrength = const Value.absent(),
    Value<DateTime?> passwordUpdatedAt = const Value.absent(),
    Value<String?> passwordFingerprint = const Value.absent(),
    Value<int?> breachCount = const Value.absent(),
    Value<DateTime?> breachCheckedAt = const Value.absent(),
    bool? hasTotp,
    Value<int?> expiryDays = const Value.absent(),
  }) => VaultItemRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    isPinned: isPinned ?? this.isPinned,
    isFavorite: isFavorite ?? this.isFavorite,
    colorHex: colorHex.present ? colorHex.value : this.colorHex,
    folderId: folderId.present ? folderId.value : this.folderId,
    sortOrder: sortOrder ?? this.sortOrder,
    syncVersion: syncVersion ?? this.syncVersion,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    deviceId: deviceId ?? this.deviceId,
    itemType: itemType ?? this.itemType,
    title: title ?? this.title,
    iconKey: iconKey.present ? iconKey.value : this.iconKey,
    encryptedPayload: encryptedPayload ?? this.encryptedPayload,
    passwordStrength: passwordStrength.present
        ? passwordStrength.value
        : this.passwordStrength,
    passwordUpdatedAt: passwordUpdatedAt.present
        ? passwordUpdatedAt.value
        : this.passwordUpdatedAt,
    passwordFingerprint: passwordFingerprint.present
        ? passwordFingerprint.value
        : this.passwordFingerprint,
    breachCount: breachCount.present ? breachCount.value : this.breachCount,
    breachCheckedAt: breachCheckedAt.present
        ? breachCheckedAt.value
        : this.breachCheckedAt,
    hasTotp: hasTotp ?? this.hasTotp,
    expiryDays: expiryDays.present ? expiryDays.value : this.expiryDays,
  );
  VaultItemRow copyWithCompanion(VaultItemsCompanion data) {
    return VaultItemRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      syncVersion: data.syncVersion.present
          ? data.syncVersion.value
          : this.syncVersion,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      title: data.title.present ? data.title.value : this.title,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      encryptedPayload: data.encryptedPayload.present
          ? data.encryptedPayload.value
          : this.encryptedPayload,
      passwordStrength: data.passwordStrength.present
          ? data.passwordStrength.value
          : this.passwordStrength,
      passwordUpdatedAt: data.passwordUpdatedAt.present
          ? data.passwordUpdatedAt.value
          : this.passwordUpdatedAt,
      passwordFingerprint: data.passwordFingerprint.present
          ? data.passwordFingerprint.value
          : this.passwordFingerprint,
      breachCount: data.breachCount.present
          ? data.breachCount.value
          : this.breachCount,
      breachCheckedAt: data.breachCheckedAt.present
          ? data.breachCheckedAt.value
          : this.breachCheckedAt,
      hasTotp: data.hasTotp.present ? data.hasTotp.value : this.hasTotp,
      expiryDays: data.expiryDays.present
          ? data.expiryDays.value
          : this.expiryDays,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultItemRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('colorHex: $colorHex, ')
          ..write('folderId: $folderId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('itemType: $itemType, ')
          ..write('title: $title, ')
          ..write('iconKey: $iconKey, ')
          ..write('encryptedPayload: $encryptedPayload, ')
          ..write('passwordStrength: $passwordStrength, ')
          ..write('passwordUpdatedAt: $passwordUpdatedAt, ')
          ..write('passwordFingerprint: $passwordFingerprint, ')
          ..write('breachCount: $breachCount, ')
          ..write('breachCheckedAt: $breachCheckedAt, ')
          ..write('hasTotp: $hasTotp, ')
          ..write('expiryDays: $expiryDays')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
    isPinned,
    isFavorite,
    colorHex,
    folderId,
    sortOrder,
    syncVersion,
    lastSyncedAt,
    deviceId,
    itemType,
    title,
    iconKey,
    $driftBlobEquality.hash(encryptedPayload),
    passwordStrength,
    passwordUpdatedAt,
    passwordFingerprint,
    breachCount,
    breachCheckedAt,
    hasTotp,
    expiryDays,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultItemRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.archivedAt == this.archivedAt &&
          other.deletedAt == this.deletedAt &&
          other.isPinned == this.isPinned &&
          other.isFavorite == this.isFavorite &&
          other.colorHex == this.colorHex &&
          other.folderId == this.folderId &&
          other.sortOrder == this.sortOrder &&
          other.syncVersion == this.syncVersion &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.deviceId == this.deviceId &&
          other.itemType == this.itemType &&
          other.title == this.title &&
          other.iconKey == this.iconKey &&
          $driftBlobEquality.equals(
            other.encryptedPayload,
            this.encryptedPayload,
          ) &&
          other.passwordStrength == this.passwordStrength &&
          other.passwordUpdatedAt == this.passwordUpdatedAt &&
          other.passwordFingerprint == this.passwordFingerprint &&
          other.breachCount == this.breachCount &&
          other.breachCheckedAt == this.breachCheckedAt &&
          other.hasTotp == this.hasTotp &&
          other.expiryDays == this.expiryDays);
}

class VaultItemsCompanion extends UpdateCompanion<VaultItemRow> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> archivedAt;
  final Value<DateTime?> deletedAt;
  final Value<bool> isPinned;
  final Value<bool> isFavorite;
  final Value<String?> colorHex;
  final Value<String?> folderId;
  final Value<double> sortOrder;
  final Value<int> syncVersion;
  final Value<DateTime?> lastSyncedAt;
  final Value<String> deviceId;
  final Value<int> itemType;
  final Value<String> title;
  final Value<String?> iconKey;
  final Value<Uint8List> encryptedPayload;
  final Value<int?> passwordStrength;
  final Value<DateTime?> passwordUpdatedAt;
  final Value<String?> passwordFingerprint;
  final Value<int?> breachCount;
  final Value<DateTime?> breachCheckedAt;
  final Value<bool> hasTotp;
  final Value<int?> expiryDays;
  final Value<int> rowid;
  const VaultItemsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.folderId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.itemType = const Value.absent(),
    this.title = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.encryptedPayload = const Value.absent(),
    this.passwordStrength = const Value.absent(),
    this.passwordUpdatedAt = const Value.absent(),
    this.passwordFingerprint = const Value.absent(),
    this.breachCount = const Value.absent(),
    this.breachCheckedAt = const Value.absent(),
    this.hasTotp = const Value.absent(),
    this.expiryDays = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaultItemsCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.folderId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.itemType = const Value.absent(),
    this.title = const Value.absent(),
    this.iconKey = const Value.absent(),
    required Uint8List encryptedPayload,
    this.passwordStrength = const Value.absent(),
    this.passwordUpdatedAt = const Value.absent(),
    this.passwordFingerprint = const Value.absent(),
    this.breachCount = const Value.absent(),
    this.breachCheckedAt = const Value.absent(),
    this.hasTotp = const Value.absent(),
    this.expiryDays = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       encryptedPayload = Value(encryptedPayload);
  static Insertable<VaultItemRow> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? deletedAt,
    Expression<bool>? isPinned,
    Expression<bool>? isFavorite,
    Expression<String>? colorHex,
    Expression<String>? folderId,
    Expression<double>? sortOrder,
    Expression<int>? syncVersion,
    Expression<DateTime>? lastSyncedAt,
    Expression<String>? deviceId,
    Expression<int>? itemType,
    Expression<String>? title,
    Expression<String>? iconKey,
    Expression<Uint8List>? encryptedPayload,
    Expression<int>? passwordStrength,
    Expression<DateTime>? passwordUpdatedAt,
    Expression<String>? passwordFingerprint,
    Expression<int>? breachCount,
    Expression<DateTime>? breachCheckedAt,
    Expression<bool>? hasTotp,
    Expression<int>? expiryDays,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (colorHex != null) 'color_hex': colorHex,
      if (folderId != null) 'folder_id': folderId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (syncVersion != null) 'sync_version': syncVersion,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (itemType != null) 'item_type': itemType,
      if (title != null) 'title': title,
      if (iconKey != null) 'icon_key': iconKey,
      if (encryptedPayload != null) 'encrypted_payload': encryptedPayload,
      if (passwordStrength != null) 'password_strength': passwordStrength,
      if (passwordUpdatedAt != null) 'password_updated_at': passwordUpdatedAt,
      if (passwordFingerprint != null)
        'password_fingerprint': passwordFingerprint,
      if (breachCount != null) 'breach_count': breachCount,
      if (breachCheckedAt != null) 'breach_checked_at': breachCheckedAt,
      if (hasTotp != null) 'has_totp': hasTotp,
      if (expiryDays != null) 'expiry_days': expiryDays,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaultItemsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? archivedAt,
    Value<DateTime?>? deletedAt,
    Value<bool>? isPinned,
    Value<bool>? isFavorite,
    Value<String?>? colorHex,
    Value<String?>? folderId,
    Value<double>? sortOrder,
    Value<int>? syncVersion,
    Value<DateTime?>? lastSyncedAt,
    Value<String>? deviceId,
    Value<int>? itemType,
    Value<String>? title,
    Value<String?>? iconKey,
    Value<Uint8List>? encryptedPayload,
    Value<int?>? passwordStrength,
    Value<DateTime?>? passwordUpdatedAt,
    Value<String?>? passwordFingerprint,
    Value<int?>? breachCount,
    Value<DateTime?>? breachCheckedAt,
    Value<bool>? hasTotp,
    Value<int?>? expiryDays,
    Value<int>? rowid,
  }) {
    return VaultItemsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      colorHex: colorHex ?? this.colorHex,
      folderId: folderId ?? this.folderId,
      sortOrder: sortOrder ?? this.sortOrder,
      syncVersion: syncVersion ?? this.syncVersion,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      deviceId: deviceId ?? this.deviceId,
      itemType: itemType ?? this.itemType,
      title: title ?? this.title,
      iconKey: iconKey ?? this.iconKey,
      encryptedPayload: encryptedPayload ?? this.encryptedPayload,
      passwordStrength: passwordStrength ?? this.passwordStrength,
      passwordUpdatedAt: passwordUpdatedAt ?? this.passwordUpdatedAt,
      passwordFingerprint: passwordFingerprint ?? this.passwordFingerprint,
      breachCount: breachCount ?? this.breachCount,
      breachCheckedAt: breachCheckedAt ?? this.breachCheckedAt,
      hasTotp: hasTotp ?? this.hasTotp,
      expiryDays: expiryDays ?? this.expiryDays,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<double>(sortOrder.value);
    }
    if (syncVersion.present) {
      map['sync_version'] = Variable<int>(syncVersion.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<int>(itemType.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (iconKey.present) {
      map['icon_key'] = Variable<String>(iconKey.value);
    }
    if (encryptedPayload.present) {
      map['encrypted_payload'] = Variable<Uint8List>(encryptedPayload.value);
    }
    if (passwordStrength.present) {
      map['password_strength'] = Variable<int>(passwordStrength.value);
    }
    if (passwordUpdatedAt.present) {
      map['password_updated_at'] = Variable<DateTime>(passwordUpdatedAt.value);
    }
    if (passwordFingerprint.present) {
      map['password_fingerprint'] = Variable<String>(passwordFingerprint.value);
    }
    if (breachCount.present) {
      map['breach_count'] = Variable<int>(breachCount.value);
    }
    if (breachCheckedAt.present) {
      map['breach_checked_at'] = Variable<DateTime>(breachCheckedAt.value);
    }
    if (hasTotp.present) {
      map['has_totp'] = Variable<bool>(hasTotp.value);
    }
    if (expiryDays.present) {
      map['expiry_days'] = Variable<int>(expiryDays.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultItemsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('colorHex: $colorHex, ')
          ..write('folderId: $folderId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('itemType: $itemType, ')
          ..write('title: $title, ')
          ..write('iconKey: $iconKey, ')
          ..write('encryptedPayload: $encryptedPayload, ')
          ..write('passwordStrength: $passwordStrength, ')
          ..write('passwordUpdatedAt: $passwordUpdatedAt, ')
          ..write('passwordFingerprint: $passwordFingerprint, ')
          ..write('breachCount: $breachCount, ')
          ..write('breachCheckedAt: $breachCheckedAt, ')
          ..write('hasTotp: $hasTotp, ')
          ..write('expiryDays: $expiryDays, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VaultHistoryTable extends VaultHistory
    with TableInfo<$VaultHistoryTable, VaultHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedPasswordMeta = const VerificationMeta(
    'encryptedPassword',
  );
  @override
  late final GeneratedColumn<Uint8List> encryptedPassword =
      GeneratedColumn<Uint8List>(
        'encrypted_password',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _changedAtMeta = const VerificationMeta(
    'changedAt',
  );
  @override
  late final GeneratedColumn<DateTime> changedAt = GeneratedColumn<DateTime>(
    'changed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    encryptedPassword,
    changedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('encrypted_password')) {
      context.handle(
        _encryptedPasswordMeta,
        encryptedPassword.isAcceptableOrUnknown(
          data['encrypted_password']!,
          _encryptedPasswordMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedPasswordMeta);
    }
    if (data.containsKey('changed_at')) {
      context.handle(
        _changedAtMeta,
        changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_changedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultHistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      encryptedPassword: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}encrypted_password'],
      )!,
      changedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}changed_at'],
      )!,
    );
  }

  @override
  $VaultHistoryTable createAlias(String alias) {
    return $VaultHistoryTable(attachedDatabase, alias);
  }
}

class VaultHistoryRow extends DataClass implements Insertable<VaultHistoryRow> {
  final String id;
  final String itemId;

  /// Previous password, encrypted with the vault DEK.
  final Uint8List encryptedPassword;
  final DateTime changedAt;
  const VaultHistoryRow({
    required this.id,
    required this.itemId,
    required this.encryptedPassword,
    required this.changedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['encrypted_password'] = Variable<Uint8List>(encryptedPassword);
    map['changed_at'] = Variable<DateTime>(changedAt);
    return map;
  }

  VaultHistoryCompanion toCompanion(bool nullToAbsent) {
    return VaultHistoryCompanion(
      id: Value(id),
      itemId: Value(itemId),
      encryptedPassword: Value(encryptedPassword),
      changedAt: Value(changedAt),
    );
  }

  factory VaultHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultHistoryRow(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      encryptedPassword: serializer.fromJson<Uint8List>(
        json['encryptedPassword'],
      ),
      changedAt: serializer.fromJson<DateTime>(json['changedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'encryptedPassword': serializer.toJson<Uint8List>(encryptedPassword),
      'changedAt': serializer.toJson<DateTime>(changedAt),
    };
  }

  VaultHistoryRow copyWith({
    String? id,
    String? itemId,
    Uint8List? encryptedPassword,
    DateTime? changedAt,
  }) => VaultHistoryRow(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    encryptedPassword: encryptedPassword ?? this.encryptedPassword,
    changedAt: changedAt ?? this.changedAt,
  );
  VaultHistoryRow copyWithCompanion(VaultHistoryCompanion data) {
    return VaultHistoryRow(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      encryptedPassword: data.encryptedPassword.present
          ? data.encryptedPassword.value
          : this.encryptedPassword,
      changedAt: data.changedAt.present ? data.changedAt.value : this.changedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultHistoryRow(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('encryptedPassword: $encryptedPassword, ')
          ..write('changedAt: $changedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    itemId,
    $driftBlobEquality.hash(encryptedPassword),
    changedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultHistoryRow &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          $driftBlobEquality.equals(
            other.encryptedPassword,
            this.encryptedPassword,
          ) &&
          other.changedAt == this.changedAt);
}

class VaultHistoryCompanion extends UpdateCompanion<VaultHistoryRow> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<Uint8List> encryptedPassword;
  final Value<DateTime> changedAt;
  final Value<int> rowid;
  const VaultHistoryCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.encryptedPassword = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaultHistoryCompanion.insert({
    required String id,
    required String itemId,
    required Uint8List encryptedPassword,
    required DateTime changedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       encryptedPassword = Value(encryptedPassword),
       changedAt = Value(changedAt);
  static Insertable<VaultHistoryRow> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<Uint8List>? encryptedPassword,
    Expression<DateTime>? changedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (encryptedPassword != null) 'encrypted_password': encryptedPassword,
      if (changedAt != null) 'changed_at': changedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaultHistoryCompanion copyWith({
    Value<String>? id,
    Value<String>? itemId,
    Value<Uint8List>? encryptedPassword,
    Value<DateTime>? changedAt,
    Value<int>? rowid,
  }) {
    return VaultHistoryCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      encryptedPassword: encryptedPassword ?? this.encryptedPassword,
      changedAt: changedAt ?? this.changedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (encryptedPassword.present) {
      map['encrypted_password'] = Variable<Uint8List>(encryptedPassword.value);
    }
    if (changedAt.present) {
      map['changed_at'] = Variable<DateTime>(changedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultHistoryCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('encryptedPassword: $encryptedPassword, ')
          ..write('changedAt: $changedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GeneratorHistoryTable extends GeneratorHistory
    with TableInfo<$GeneratorHistoryTable, GeneratorHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GeneratorHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedValueMeta = const VerificationMeta(
    'encryptedValue',
  );
  @override
  late final GeneratedColumn<Uint8List> encryptedValue =
      GeneratedColumn<Uint8List>(
        'encrypted_value',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('password'),
  );
  static const VerificationMeta _entropyBitsMeta = const VerificationMeta(
    'entropyBits',
  );
  @override
  late final GeneratedColumn<int> entropyBits = GeneratedColumn<int>(
    'entropy_bits',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    encryptedValue,
    mode,
    entropyBits,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'generator_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<GeneratorHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('encrypted_value')) {
      context.handle(
        _encryptedValueMeta,
        encryptedValue.isAcceptableOrUnknown(
          data['encrypted_value']!,
          _encryptedValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedValueMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('entropy_bits')) {
      context.handle(
        _entropyBitsMeta,
        entropyBits.isAcceptableOrUnknown(
          data['entropy_bits']!,
          _entropyBitsMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GeneratorHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GeneratorHistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      encryptedValue: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}encrypted_value'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      entropyBits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entropy_bits'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $GeneratorHistoryTable createAlias(String alias) {
    return $GeneratorHistoryTable(attachedDatabase, alias);
  }
}

class GeneratorHistoryRow extends DataClass
    implements Insertable<GeneratorHistoryRow> {
  final String id;
  final Uint8List encryptedValue;
  final String mode;
  final int entropyBits;
  final DateTime createdAt;
  const GeneratorHistoryRow({
    required this.id,
    required this.encryptedValue,
    required this.mode,
    required this.entropyBits,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['encrypted_value'] = Variable<Uint8List>(encryptedValue);
    map['mode'] = Variable<String>(mode);
    map['entropy_bits'] = Variable<int>(entropyBits);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  GeneratorHistoryCompanion toCompanion(bool nullToAbsent) {
    return GeneratorHistoryCompanion(
      id: Value(id),
      encryptedValue: Value(encryptedValue),
      mode: Value(mode),
      entropyBits: Value(entropyBits),
      createdAt: Value(createdAt),
    );
  }

  factory GeneratorHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GeneratorHistoryRow(
      id: serializer.fromJson<String>(json['id']),
      encryptedValue: serializer.fromJson<Uint8List>(json['encryptedValue']),
      mode: serializer.fromJson<String>(json['mode']),
      entropyBits: serializer.fromJson<int>(json['entropyBits']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'encryptedValue': serializer.toJson<Uint8List>(encryptedValue),
      'mode': serializer.toJson<String>(mode),
      'entropyBits': serializer.toJson<int>(entropyBits),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  GeneratorHistoryRow copyWith({
    String? id,
    Uint8List? encryptedValue,
    String? mode,
    int? entropyBits,
    DateTime? createdAt,
  }) => GeneratorHistoryRow(
    id: id ?? this.id,
    encryptedValue: encryptedValue ?? this.encryptedValue,
    mode: mode ?? this.mode,
    entropyBits: entropyBits ?? this.entropyBits,
    createdAt: createdAt ?? this.createdAt,
  );
  GeneratorHistoryRow copyWithCompanion(GeneratorHistoryCompanion data) {
    return GeneratorHistoryRow(
      id: data.id.present ? data.id.value : this.id,
      encryptedValue: data.encryptedValue.present
          ? data.encryptedValue.value
          : this.encryptedValue,
      mode: data.mode.present ? data.mode.value : this.mode,
      entropyBits: data.entropyBits.present
          ? data.entropyBits.value
          : this.entropyBits,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GeneratorHistoryRow(')
          ..write('id: $id, ')
          ..write('encryptedValue: $encryptedValue, ')
          ..write('mode: $mode, ')
          ..write('entropyBits: $entropyBits, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    $driftBlobEquality.hash(encryptedValue),
    mode,
    entropyBits,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GeneratorHistoryRow &&
          other.id == this.id &&
          $driftBlobEquality.equals(
            other.encryptedValue,
            this.encryptedValue,
          ) &&
          other.mode == this.mode &&
          other.entropyBits == this.entropyBits &&
          other.createdAt == this.createdAt);
}

class GeneratorHistoryCompanion extends UpdateCompanion<GeneratorHistoryRow> {
  final Value<String> id;
  final Value<Uint8List> encryptedValue;
  final Value<String> mode;
  final Value<int> entropyBits;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const GeneratorHistoryCompanion({
    this.id = const Value.absent(),
    this.encryptedValue = const Value.absent(),
    this.mode = const Value.absent(),
    this.entropyBits = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GeneratorHistoryCompanion.insert({
    required String id,
    required Uint8List encryptedValue,
    this.mode = const Value.absent(),
    this.entropyBits = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       encryptedValue = Value(encryptedValue),
       createdAt = Value(createdAt);
  static Insertable<GeneratorHistoryRow> custom({
    Expression<String>? id,
    Expression<Uint8List>? encryptedValue,
    Expression<String>? mode,
    Expression<int>? entropyBits,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (encryptedValue != null) 'encrypted_value': encryptedValue,
      if (mode != null) 'mode': mode,
      if (entropyBits != null) 'entropy_bits': entropyBits,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GeneratorHistoryCompanion copyWith({
    Value<String>? id,
    Value<Uint8List>? encryptedValue,
    Value<String>? mode,
    Value<int>? entropyBits,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return GeneratorHistoryCompanion(
      id: id ?? this.id,
      encryptedValue: encryptedValue ?? this.encryptedValue,
      mode: mode ?? this.mode,
      entropyBits: entropyBits ?? this.entropyBits,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (encryptedValue.present) {
      map['encrypted_value'] = Variable<Uint8List>(encryptedValue.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (entropyBits.present) {
      map['entropy_bits'] = Variable<int>(entropyBits.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GeneratorHistoryCompanion(')
          ..write('id: $id, ')
          ..write('encryptedValue: $encryptedValue, ')
          ..write('mode: $mode, ')
          ..write('entropyBits: $entropyBits, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FoldersTable extends Folders with TableInfo<$FoldersTable, FolderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _moduleMeta = const VerificationMeta('module');
  @override
  late final GeneratedColumn<String> module = GeneratedColumn<String>(
    'module',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconKeyMeta = const VerificationMeta(
    'iconKey',
  );
  @override
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
    'icon_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<double> sortOrder = GeneratedColumn<double>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    module,
    name,
    colorHex,
    iconKey,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<FolderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('module')) {
      context.handle(
        _moduleMeta,
        module.isAcceptableOrUnknown(data['module']!, _moduleMeta),
      );
    } else if (isInserting) {
      context.missing(_moduleMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('icon_key')) {
      context.handle(
        _iconKeyMeta,
        iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FolderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FolderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      module: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}module'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      ),
      iconKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_key'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }
}

class FolderRow extends DataClass implements Insertable<FolderRow> {
  final String id;
  final String module;
  final String name;
  final String? colorHex;
  final String? iconKey;
  final double sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const FolderRow({
    required this.id,
    required this.module,
    required this.name,
    this.colorHex,
    this.iconKey,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['module'] = Variable<String>(module);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || colorHex != null) {
      map['color_hex'] = Variable<String>(colorHex);
    }
    if (!nullToAbsent || iconKey != null) {
      map['icon_key'] = Variable<String>(iconKey);
    }
    map['sort_order'] = Variable<double>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      module: Value(module),
      name: Value(name),
      colorHex: colorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(colorHex),
      iconKey: iconKey == null && nullToAbsent
          ? const Value.absent()
          : Value(iconKey),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory FolderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FolderRow(
      id: serializer.fromJson<String>(json['id']),
      module: serializer.fromJson<String>(json['module']),
      name: serializer.fromJson<String>(json['name']),
      colorHex: serializer.fromJson<String?>(json['colorHex']),
      iconKey: serializer.fromJson<String?>(json['iconKey']),
      sortOrder: serializer.fromJson<double>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'module': serializer.toJson<String>(module),
      'name': serializer.toJson<String>(name),
      'colorHex': serializer.toJson<String?>(colorHex),
      'iconKey': serializer.toJson<String?>(iconKey),
      'sortOrder': serializer.toJson<double>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  FolderRow copyWith({
    String? id,
    String? module,
    String? name,
    Value<String?> colorHex = const Value.absent(),
    Value<String?> iconKey = const Value.absent(),
    double? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => FolderRow(
    id: id ?? this.id,
    module: module ?? this.module,
    name: name ?? this.name,
    colorHex: colorHex.present ? colorHex.value : this.colorHex,
    iconKey: iconKey.present ? iconKey.value : this.iconKey,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  FolderRow copyWithCompanion(FoldersCompanion data) {
    return FolderRow(
      id: data.id.present ? data.id.value : this.id,
      module: data.module.present ? data.module.value : this.module,
      name: data.name.present ? data.name.value : this.name,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FolderRow(')
          ..write('id: $id, ')
          ..write('module: $module, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex, ')
          ..write('iconKey: $iconKey, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    module,
    name,
    colorHex,
    iconKey,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FolderRow &&
          other.id == this.id &&
          other.module == this.module &&
          other.name == this.name &&
          other.colorHex == this.colorHex &&
          other.iconKey == this.iconKey &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class FoldersCompanion extends UpdateCompanion<FolderRow> {
  final Value<String> id;
  final Value<String> module;
  final Value<String> name;
  final Value<String?> colorHex;
  final Value<String?> iconKey;
  final Value<double> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.module = const Value.absent(),
    this.name = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoldersCompanion.insert({
    required String id,
    required String module,
    required String name,
    this.colorHex = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       module = Value(module),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<FolderRow> custom({
    Expression<String>? id,
    Expression<String>? module,
    Expression<String>? name,
    Expression<String>? colorHex,
    Expression<String>? iconKey,
    Expression<double>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (module != null) 'module': module,
      if (name != null) 'name': name,
      if (colorHex != null) 'color_hex': colorHex,
      if (iconKey != null) 'icon_key': iconKey,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoldersCompanion copyWith({
    Value<String>? id,
    Value<String>? module,
    Value<String>? name,
    Value<String?>? colorHex,
    Value<String?>? iconKey,
    Value<double>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      module: module ?? this.module,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      iconKey: iconKey ?? this.iconKey,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (module.present) {
      map['module'] = Variable<String>(module.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (iconKey.present) {
      map['icon_key'] = Variable<String>(iconKey.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<double>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('module: $module, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex, ')
          ..write('iconKey: $iconKey, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, TagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    colorHex,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class TagRow extends DataClass implements Insertable<TagRow> {
  final String id;

  /// Without the leading '#', lower case, unique.
  final String name;
  final String? colorHex;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TagRow({
    required this.id,
    required this.name,
    this.colorHex,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || colorHex != null) {
      map['color_hex'] = Variable<String>(colorHex);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      colorHex: colorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(colorHex),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorHex: serializer.fromJson<String?>(json['colorHex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'colorHex': serializer.toJson<String?>(colorHex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TagRow copyWith({
    String? id,
    String? name,
    Value<String?> colorHex = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TagRow(
    id: id ?? this.id,
    name: name ?? this.name,
    colorHex: colorHex.present ? colorHex.value : this.colorHex,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TagRow copyWithCompanion(TagsCompanion data) {
    return TagRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colorHex, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorHex == this.colorHex &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TagsCompanion extends UpdateCompanion<TagRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> colorHex;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String name,
    this.colorHex = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TagRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? colorHex,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorHex != null) 'color_hex': colorHex,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? colorHex,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemTagsTable extends ItemTags
    with TableInfo<$ItemTagsTable, ItemTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemTypeMeta = const VerificationMeta(
    'itemType',
  );
  @override
  late final GeneratedColumn<String> itemType = GeneratedColumn<String>(
    'item_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [itemId, itemType, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('item_type')) {
      context.handle(
        _itemTypeMeta,
        itemType.isAcceptableOrUnknown(data['item_type']!, _itemTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_itemTypeMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId, tagId};
  @override
  ItemTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemTagRow(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      itemType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_type'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $ItemTagsTable createAlias(String alias) {
    return $ItemTagsTable(attachedDatabase, alias);
  }
}

class ItemTagRow extends DataClass implements Insertable<ItemTagRow> {
  final String itemId;

  /// `ItemType.key`.
  final String itemType;
  final String tagId;
  const ItemTagRow({
    required this.itemId,
    required this.itemType,
    required this.tagId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['item_type'] = Variable<String>(itemType);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  ItemTagsCompanion toCompanion(bool nullToAbsent) {
    return ItemTagsCompanion(
      itemId: Value(itemId),
      itemType: Value(itemType),
      tagId: Value(tagId),
    );
  }

  factory ItemTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemTagRow(
      itemId: serializer.fromJson<String>(json['itemId']),
      itemType: serializer.fromJson<String>(json['itemType']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'itemType': serializer.toJson<String>(itemType),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  ItemTagRow copyWith({String? itemId, String? itemType, String? tagId}) =>
      ItemTagRow(
        itemId: itemId ?? this.itemId,
        itemType: itemType ?? this.itemType,
        tagId: tagId ?? this.tagId,
      );
  ItemTagRow copyWithCompanion(ItemTagsCompanion data) {
    return ItemTagRow(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemTagRow(')
          ..write('itemId: $itemId, ')
          ..write('itemType: $itemType, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, itemType, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemTagRow &&
          other.itemId == this.itemId &&
          other.itemType == this.itemType &&
          other.tagId == this.tagId);
}

class ItemTagsCompanion extends UpdateCompanion<ItemTagRow> {
  final Value<String> itemId;
  final Value<String> itemType;
  final Value<String> tagId;
  final Value<int> rowid;
  const ItemTagsCompanion({
    this.itemId = const Value.absent(),
    this.itemType = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemTagsCompanion.insert({
    required String itemId,
    required String itemType,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       itemType = Value(itemType),
       tagId = Value(tagId);
  static Insertable<ItemTagRow> custom({
    Expression<String>? itemId,
    Expression<String>? itemType,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (itemType != null) 'item_type': itemType,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemTagsCompanion copyWith({
    Value<String>? itemId,
    Value<String>? itemType,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return ItemTagsCompanion(
      itemId: itemId ?? this.itemId,
      itemType: itemType ?? this.itemType,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<String>(itemType.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemTagsCompanion(')
          ..write('itemId: $itemId, ')
          ..write('itemType: $itemType, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, AttachmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemTypeMeta = const VerificationMeta(
    'itemType',
  );
  @override
  late final GeneratedColumn<String> itemType = GeneratedColumn<String>(
    'item_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    itemType,
    fileName,
    mimeType,
    sizeBytes,
    localPath,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttachmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('item_type')) {
      context.handle(
        _itemTypeMeta,
        itemType.isAcceptableOrUnknown(data['item_type']!, _itemTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_itemTypeMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttachmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttachmentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      itemType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_type'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class AttachmentRow extends DataClass implements Insertable<AttachmentRow> {
  final String id;
  final String itemId;
  final String itemType;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  /// Relative to the app documents directory (`attachments/<id>.<ext>`).
  final String localPath;
  final DateTime createdAt;
  const AttachmentRow({
    required this.id,
    required this.itemId,
    required this.itemType,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.localPath,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['item_type'] = Variable<String>(itemType);
    map['file_name'] = Variable<String>(fileName);
    map['mime_type'] = Variable<String>(mimeType);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['local_path'] = Variable<String>(localPath);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      itemId: Value(itemId),
      itemType: Value(itemType),
      fileName: Value(fileName),
      mimeType: Value(mimeType),
      sizeBytes: Value(sizeBytes),
      localPath: Value(localPath),
      createdAt: Value(createdAt),
    );
  }

  factory AttachmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttachmentRow(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      itemType: serializer.fromJson<String>(json['itemType']),
      fileName: serializer.fromJson<String>(json['fileName']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      localPath: serializer.fromJson<String>(json['localPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'itemType': serializer.toJson<String>(itemType),
      'fileName': serializer.toJson<String>(fileName),
      'mimeType': serializer.toJson<String>(mimeType),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'localPath': serializer.toJson<String>(localPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AttachmentRow copyWith({
    String? id,
    String? itemId,
    String? itemType,
    String? fileName,
    String? mimeType,
    int? sizeBytes,
    String? localPath,
    DateTime? createdAt,
  }) => AttachmentRow(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    itemType: itemType ?? this.itemType,
    fileName: fileName ?? this.fileName,
    mimeType: mimeType ?? this.mimeType,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    localPath: localPath ?? this.localPath,
    createdAt: createdAt ?? this.createdAt,
  );
  AttachmentRow copyWithCompanion(AttachmentsCompanion data) {
    return AttachmentRow(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentRow(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('itemType: $itemType, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('localPath: $localPath, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    itemId,
    itemType,
    fileName,
    mimeType,
    sizeBytes,
    localPath,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttachmentRow &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.itemType == this.itemType &&
          other.fileName == this.fileName &&
          other.mimeType == this.mimeType &&
          other.sizeBytes == this.sizeBytes &&
          other.localPath == this.localPath &&
          other.createdAt == this.createdAt);
}

class AttachmentsCompanion extends UpdateCompanion<AttachmentRow> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<String> itemType;
  final Value<String> fileName;
  final Value<String> mimeType;
  final Value<int> sizeBytes;
  final Value<String> localPath;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.itemType = const Value.absent(),
    this.fileName = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.localPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    required String id,
    required String itemId,
    required String itemType,
    required String fileName,
    this.mimeType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    required String localPath,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       itemType = Value(itemType),
       fileName = Value(fileName),
       localPath = Value(localPath),
       createdAt = Value(createdAt);
  static Insertable<AttachmentRow> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<String>? itemType,
    Expression<String>? fileName,
    Expression<String>? mimeType,
    Expression<int>? sizeBytes,
    Expression<String>? localPath,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (itemType != null) 'item_type': itemType,
      if (fileName != null) 'file_name': fileName,
      if (mimeType != null) 'mime_type': mimeType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (localPath != null) 'local_path': localPath,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? itemId,
    Value<String>? itemType,
    Value<String>? fileName,
    Value<String>? mimeType,
    Value<int>? sizeBytes,
    Value<String>? localPath,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      itemType: itemType ?? this.itemType,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      localPath: localPath ?? this.localPath,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<String>(itemType.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('itemType: $itemType, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('localPath: $localPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InboxEntriesTable extends InboxEntries
    with TableInfo<$InboxEntriesTable, InboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InboxEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemTypeMeta = const VerificationMeta(
    'itemType',
  );
  @override
  late final GeneratedColumn<String> itemType = GeneratedColumn<String>(
    'item_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actionsJsonMeta = const VerificationMeta(
    'actionsJson',
  );
  @override
  late final GeneratedColumn<String> actionsJson = GeneratedColumn<String>(
    'actions_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<DateTime> readAt = GeneratedColumn<DateTime>(
    'read_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dismissedAtMeta = const VerificationMeta(
    'dismissedAt',
  );
  @override
  late final GeneratedColumn<DateTime> dismissedAt = GeneratedColumn<DateTime>(
    'dismissed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    title,
    body,
    itemId,
    itemType,
    actionsJson,
    createdAt,
    readAt,
    dismissedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inbox_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<InboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    }
    if (data.containsKey('item_type')) {
      context.handle(
        _itemTypeMeta,
        itemType.isAcceptableOrUnknown(data['item_type']!, _itemTypeMeta),
      );
    }
    if (data.containsKey('actions_json')) {
      context.handle(
        _actionsJsonMeta,
        actionsJson.isAcceptableOrUnknown(
          data['actions_json']!,
          _actionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    }
    if (data.containsKey('dismissed_at')) {
      context.handle(
        _dismissedAtMeta,
        dismissedAt.isAcceptableOrUnknown(
          data['dismissed_at']!,
          _dismissedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InboxRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      ),
      itemType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_type'],
      ),
      actionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actions_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}read_at'],
      ),
      dismissedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}dismissed_at'],
      ),
    );
  }

  @override
  $InboxEntriesTable createAlias(String alias) {
    return $InboxEntriesTable(attachedDatabase, alias);
  }
}

class InboxRow extends DataClass implements Insertable<InboxRow> {
  final String id;

  /// reminder · task · habit · security · sync · system.
  final String kind;
  final String title;
  final String body;
  final String? itemId;
  final String? itemType;

  /// JSON list of action keys offered inline (done, snooze, reschedule, view…).
  final String actionsJson;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? dismissedAt;
  const InboxRow({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.itemId,
    this.itemType,
    required this.actionsJson,
    required this.createdAt,
    this.readAt,
    this.dismissedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<String>(itemId);
    }
    if (!nullToAbsent || itemType != null) {
      map['item_type'] = Variable<String>(itemType);
    }
    map['actions_json'] = Variable<String>(actionsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<DateTime>(readAt);
    }
    if (!nullToAbsent || dismissedAt != null) {
      map['dismissed_at'] = Variable<DateTime>(dismissedAt);
    }
    return map;
  }

  InboxEntriesCompanion toCompanion(bool nullToAbsent) {
    return InboxEntriesCompanion(
      id: Value(id),
      kind: Value(kind),
      title: Value(title),
      body: Value(body),
      itemId: itemId == null && nullToAbsent
          ? const Value.absent()
          : Value(itemId),
      itemType: itemType == null && nullToAbsent
          ? const Value.absent()
          : Value(itemType),
      actionsJson: Value(actionsJson),
      createdAt: Value(createdAt),
      readAt: readAt == null && nullToAbsent
          ? const Value.absent()
          : Value(readAt),
      dismissedAt: dismissedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dismissedAt),
    );
  }

  factory InboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InboxRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      itemId: serializer.fromJson<String?>(json['itemId']),
      itemType: serializer.fromJson<String?>(json['itemType']),
      actionsJson: serializer.fromJson<String>(json['actionsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      readAt: serializer.fromJson<DateTime?>(json['readAt']),
      dismissedAt: serializer.fromJson<DateTime?>(json['dismissedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'itemId': serializer.toJson<String?>(itemId),
      'itemType': serializer.toJson<String?>(itemType),
      'actionsJson': serializer.toJson<String>(actionsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'readAt': serializer.toJson<DateTime?>(readAt),
      'dismissedAt': serializer.toJson<DateTime?>(dismissedAt),
    };
  }

  InboxRow copyWith({
    String? id,
    String? kind,
    String? title,
    String? body,
    Value<String?> itemId = const Value.absent(),
    Value<String?> itemType = const Value.absent(),
    String? actionsJson,
    DateTime? createdAt,
    Value<DateTime?> readAt = const Value.absent(),
    Value<DateTime?> dismissedAt = const Value.absent(),
  }) => InboxRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    body: body ?? this.body,
    itemId: itemId.present ? itemId.value : this.itemId,
    itemType: itemType.present ? itemType.value : this.itemType,
    actionsJson: actionsJson ?? this.actionsJson,
    createdAt: createdAt ?? this.createdAt,
    readAt: readAt.present ? readAt.value : this.readAt,
    dismissedAt: dismissedAt.present ? dismissedAt.value : this.dismissedAt,
  );
  InboxRow copyWithCompanion(InboxEntriesCompanion data) {
    return InboxRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      actionsJson: data.actionsJson.present
          ? data.actionsJson.value
          : this.actionsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      dismissedAt: data.dismissedAt.present
          ? data.dismissedAt.value
          : this.dismissedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InboxRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('itemId: $itemId, ')
          ..write('itemType: $itemType, ')
          ..write('actionsJson: $actionsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('readAt: $readAt, ')
          ..write('dismissedAt: $dismissedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    title,
    body,
    itemId,
    itemType,
    actionsJson,
    createdAt,
    readAt,
    dismissedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InboxRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.body == this.body &&
          other.itemId == this.itemId &&
          other.itemType == this.itemType &&
          other.actionsJson == this.actionsJson &&
          other.createdAt == this.createdAt &&
          other.readAt == this.readAt &&
          other.dismissedAt == this.dismissedAt);
}

class InboxEntriesCompanion extends UpdateCompanion<InboxRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> title;
  final Value<String> body;
  final Value<String?> itemId;
  final Value<String?> itemType;
  final Value<String> actionsJson;
  final Value<DateTime> createdAt;
  final Value<DateTime?> readAt;
  final Value<DateTime?> dismissedAt;
  final Value<int> rowid;
  const InboxEntriesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.itemId = const Value.absent(),
    this.itemType = const Value.absent(),
    this.actionsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.readAt = const Value.absent(),
    this.dismissedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InboxEntriesCompanion.insert({
    required String id,
    required String kind,
    required String title,
    this.body = const Value.absent(),
    this.itemId = const Value.absent(),
    this.itemType = const Value.absent(),
    this.actionsJson = const Value.absent(),
    required DateTime createdAt,
    this.readAt = const Value.absent(),
    this.dismissedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       title = Value(title),
       createdAt = Value(createdAt);
  static Insertable<InboxRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? itemId,
    Expression<String>? itemType,
    Expression<String>? actionsJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? readAt,
    Expression<DateTime>? dismissedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (itemId != null) 'item_id': itemId,
      if (itemType != null) 'item_type': itemType,
      if (actionsJson != null) 'actions_json': actionsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (readAt != null) 'read_at': readAt,
      if (dismissedAt != null) 'dismissed_at': dismissedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InboxEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? title,
    Value<String>? body,
    Value<String?>? itemId,
    Value<String?>? itemType,
    Value<String>? actionsJson,
    Value<DateTime>? createdAt,
    Value<DateTime?>? readAt,
    Value<DateTime?>? dismissedAt,
    Value<int>? rowid,
  }) {
    return InboxEntriesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      body: body ?? this.body,
      itemId: itemId ?? this.itemId,
      itemType: itemType ?? this.itemType,
      actionsJson: actionsJson ?? this.actionsJson,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<String>(itemType.value);
    }
    if (actionsJson.present) {
      map['actions_json'] = Variable<String>(actionsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<DateTime>(readAt.value);
    }
    if (dismissedAt.present) {
      map['dismissed_at'] = Variable<DateTime>(dismissedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InboxEntriesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('itemId: $itemId, ')
          ..write('itemType: $itemType, ')
          ..write('actionsJson: $actionsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('readAt: $readAt, ')
          ..write('dismissedAt: $dismissedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FocusSessionsTable extends FocusSessions
    with TableInfo<$FocusSessionsTable, FocusSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FocusSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMinutesMeta = const VerificationMeta(
    'durationMinutes',
  );
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
    'duration_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    startedAt,
    durationMinutes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'focus_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<FocusSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
        _durationMinutesMeta,
        durationMinutes.isAcceptableOrUnknown(
          data['duration_minutes']!,
          _durationMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationMinutesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FocusSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FocusSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      durationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_minutes'],
      )!,
    );
  }

  @override
  $FocusSessionsTable createAlias(String alias) {
    return $FocusSessionsTable(attachedDatabase, alias);
  }
}

class FocusSessionRow extends DataClass implements Insertable<FocusSessionRow> {
  final String id;
  final String? taskId;
  final DateTime startedAt;
  final int durationMinutes;
  const FocusSessionRow({
    required this.id,
    this.taskId,
    required this.startedAt,
    required this.durationMinutes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    map['duration_minutes'] = Variable<int>(durationMinutes);
    return map;
  }

  FocusSessionsCompanion toCompanion(bool nullToAbsent) {
    return FocusSessionsCompanion(
      id: Value(id),
      taskId: taskId == null && nullToAbsent
          ? const Value.absent()
          : Value(taskId),
      startedAt: Value(startedAt),
      durationMinutes: Value(durationMinutes),
    );
  }

  factory FocusSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FocusSessionRow(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String?>(json['taskId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      durationMinutes: serializer.fromJson<int>(json['durationMinutes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String?>(taskId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'durationMinutes': serializer.toJson<int>(durationMinutes),
    };
  }

  FocusSessionRow copyWith({
    String? id,
    Value<String?> taskId = const Value.absent(),
    DateTime? startedAt,
    int? durationMinutes,
  }) => FocusSessionRow(
    id: id ?? this.id,
    taskId: taskId.present ? taskId.value : this.taskId,
    startedAt: startedAt ?? this.startedAt,
    durationMinutes: durationMinutes ?? this.durationMinutes,
  );
  FocusSessionRow copyWithCompanion(FocusSessionsCompanion data) {
    return FocusSessionRow(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      durationMinutes: data.durationMinutes.present
          ? data.durationMinutes.value
          : this.durationMinutes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FocusSessionRow(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationMinutes: $durationMinutes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, taskId, startedAt, durationMinutes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FocusSessionRow &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.startedAt == this.startedAt &&
          other.durationMinutes == this.durationMinutes);
}

class FocusSessionsCompanion extends UpdateCompanion<FocusSessionRow> {
  final Value<String> id;
  final Value<String?> taskId;
  final Value<DateTime> startedAt;
  final Value<int> durationMinutes;
  final Value<int> rowid;
  const FocusSessionsCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FocusSessionsCompanion.insert({
    required String id,
    this.taskId = const Value.absent(),
    required DateTime startedAt,
    required int durationMinutes,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt),
       durationMinutes = Value(durationMinutes);
  static Insertable<FocusSessionRow> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<DateTime>? startedAt,
    Expression<int>? durationMinutes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (startedAt != null) 'started_at': startedAt,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FocusSessionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? taskId,
    Value<DateTime>? startedAt,
    Value<int>? durationMinutes,
    Value<int>? rowid,
  }) {
    return FocusSessionsCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      startedAt: startedAt ?? this.startedAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FocusSessionsCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BackupRecordsTable extends BackupRecords
    with TableInfo<$BackupRecordsTable, BackupRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BackupRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _itemCountMeta = const VerificationMeta(
    'itemCount',
  );
  @override
  late final GeneratedColumn<int> itemCount = GeneratedColumn<int>(
    'item_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isAutoMeta = const VerificationMeta('isAuto');
  @override
  late final GeneratedColumn<bool> isAuto = GeneratedColumn<bool>(
    'is_auto',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_auto" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isEncryptedMeta = const VerificationMeta(
    'isEncrypted',
  );
  @override
  late final GeneratedColumn<bool> isEncrypted = GeneratedColumn<bool>(
    'is_encrypted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_encrypted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _driveFileIdMeta = const VerificationMeta(
    'driveFileId',
  );
  @override
  late final GeneratedColumn<String> driveFileId = GeneratedColumn<String>(
    'drive_file_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    location,
    createdAt,
    sizeBytes,
    itemCount,
    isAuto,
    isEncrypted,
    driveFileId,
    localPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'backup_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<BackupRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    } else if (isInserting) {
      context.missing(_locationMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('item_count')) {
      context.handle(
        _itemCountMeta,
        itemCount.isAcceptableOrUnknown(data['item_count']!, _itemCountMeta),
      );
    }
    if (data.containsKey('is_auto')) {
      context.handle(
        _isAutoMeta,
        isAuto.isAcceptableOrUnknown(data['is_auto']!, _isAutoMeta),
      );
    }
    if (data.containsKey('is_encrypted')) {
      context.handle(
        _isEncryptedMeta,
        isEncrypted.isAcceptableOrUnknown(
          data['is_encrypted']!,
          _isEncryptedMeta,
        ),
      );
    }
    if (data.containsKey('drive_file_id')) {
      context.handle(
        _driveFileIdMeta,
        driveFileId.isAcceptableOrUnknown(
          data['drive_file_id']!,
          _driveFileIdMeta,
        ),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BackupRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BackupRecordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      itemCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_count'],
      )!,
      isAuto: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_auto'],
      )!,
      isEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_encrypted'],
      )!,
      driveFileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}drive_file_id'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
    );
  }

  @override
  $BackupRecordsTable createAlias(String alias) {
    return $BackupRecordsTable(attachedDatabase, alias);
  }
}

class BackupRecordRow extends DataClass implements Insertable<BackupRecordRow> {
  final String id;

  /// drive · local.
  final String location;
  final DateTime createdAt;
  final int sizeBytes;
  final int itemCount;
  final bool isAuto;
  final bool isEncrypted;
  final String? driveFileId;
  final String? localPath;
  const BackupRecordRow({
    required this.id,
    required this.location,
    required this.createdAt,
    required this.sizeBytes,
    required this.itemCount,
    required this.isAuto,
    required this.isEncrypted,
    this.driveFileId,
    this.localPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['location'] = Variable<String>(location);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['item_count'] = Variable<int>(itemCount);
    map['is_auto'] = Variable<bool>(isAuto);
    map['is_encrypted'] = Variable<bool>(isEncrypted);
    if (!nullToAbsent || driveFileId != null) {
      map['drive_file_id'] = Variable<String>(driveFileId);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    return map;
  }

  BackupRecordsCompanion toCompanion(bool nullToAbsent) {
    return BackupRecordsCompanion(
      id: Value(id),
      location: Value(location),
      createdAt: Value(createdAt),
      sizeBytes: Value(sizeBytes),
      itemCount: Value(itemCount),
      isAuto: Value(isAuto),
      isEncrypted: Value(isEncrypted),
      driveFileId: driveFileId == null && nullToAbsent
          ? const Value.absent()
          : Value(driveFileId),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
    );
  }

  factory BackupRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BackupRecordRow(
      id: serializer.fromJson<String>(json['id']),
      location: serializer.fromJson<String>(json['location']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      itemCount: serializer.fromJson<int>(json['itemCount']),
      isAuto: serializer.fromJson<bool>(json['isAuto']),
      isEncrypted: serializer.fromJson<bool>(json['isEncrypted']),
      driveFileId: serializer.fromJson<String?>(json['driveFileId']),
      localPath: serializer.fromJson<String?>(json['localPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'location': serializer.toJson<String>(location),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'itemCount': serializer.toJson<int>(itemCount),
      'isAuto': serializer.toJson<bool>(isAuto),
      'isEncrypted': serializer.toJson<bool>(isEncrypted),
      'driveFileId': serializer.toJson<String?>(driveFileId),
      'localPath': serializer.toJson<String?>(localPath),
    };
  }

  BackupRecordRow copyWith({
    String? id,
    String? location,
    DateTime? createdAt,
    int? sizeBytes,
    int? itemCount,
    bool? isAuto,
    bool? isEncrypted,
    Value<String?> driveFileId = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
  }) => BackupRecordRow(
    id: id ?? this.id,
    location: location ?? this.location,
    createdAt: createdAt ?? this.createdAt,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    itemCount: itemCount ?? this.itemCount,
    isAuto: isAuto ?? this.isAuto,
    isEncrypted: isEncrypted ?? this.isEncrypted,
    driveFileId: driveFileId.present ? driveFileId.value : this.driveFileId,
    localPath: localPath.present ? localPath.value : this.localPath,
  );
  BackupRecordRow copyWithCompanion(BackupRecordsCompanion data) {
    return BackupRecordRow(
      id: data.id.present ? data.id.value : this.id,
      location: data.location.present ? data.location.value : this.location,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      itemCount: data.itemCount.present ? data.itemCount.value : this.itemCount,
      isAuto: data.isAuto.present ? data.isAuto.value : this.isAuto,
      isEncrypted: data.isEncrypted.present
          ? data.isEncrypted.value
          : this.isEncrypted,
      driveFileId: data.driveFileId.present
          ? data.driveFileId.value
          : this.driveFileId,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BackupRecordRow(')
          ..write('id: $id, ')
          ..write('location: $location, ')
          ..write('createdAt: $createdAt, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('itemCount: $itemCount, ')
          ..write('isAuto: $isAuto, ')
          ..write('isEncrypted: $isEncrypted, ')
          ..write('driveFileId: $driveFileId, ')
          ..write('localPath: $localPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    location,
    createdAt,
    sizeBytes,
    itemCount,
    isAuto,
    isEncrypted,
    driveFileId,
    localPath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BackupRecordRow &&
          other.id == this.id &&
          other.location == this.location &&
          other.createdAt == this.createdAt &&
          other.sizeBytes == this.sizeBytes &&
          other.itemCount == this.itemCount &&
          other.isAuto == this.isAuto &&
          other.isEncrypted == this.isEncrypted &&
          other.driveFileId == this.driveFileId &&
          other.localPath == this.localPath);
}

class BackupRecordsCompanion extends UpdateCompanion<BackupRecordRow> {
  final Value<String> id;
  final Value<String> location;
  final Value<DateTime> createdAt;
  final Value<int> sizeBytes;
  final Value<int> itemCount;
  final Value<bool> isAuto;
  final Value<bool> isEncrypted;
  final Value<String?> driveFileId;
  final Value<String?> localPath;
  final Value<int> rowid;
  const BackupRecordsCompanion({
    this.id = const Value.absent(),
    this.location = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.isAuto = const Value.absent(),
    this.isEncrypted = const Value.absent(),
    this.driveFileId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BackupRecordsCompanion.insert({
    required String id,
    required String location,
    required DateTime createdAt,
    this.sizeBytes = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.isAuto = const Value.absent(),
    this.isEncrypted = const Value.absent(),
    this.driveFileId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       location = Value(location),
       createdAt = Value(createdAt);
  static Insertable<BackupRecordRow> custom({
    Expression<String>? id,
    Expression<String>? location,
    Expression<DateTime>? createdAt,
    Expression<int>? sizeBytes,
    Expression<int>? itemCount,
    Expression<bool>? isAuto,
    Expression<bool>? isEncrypted,
    Expression<String>? driveFileId,
    Expression<String>? localPath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (location != null) 'location': location,
      if (createdAt != null) 'created_at': createdAt,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (itemCount != null) 'item_count': itemCount,
      if (isAuto != null) 'is_auto': isAuto,
      if (isEncrypted != null) 'is_encrypted': isEncrypted,
      if (driveFileId != null) 'drive_file_id': driveFileId,
      if (localPath != null) 'local_path': localPath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BackupRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? location,
    Value<DateTime>? createdAt,
    Value<int>? sizeBytes,
    Value<int>? itemCount,
    Value<bool>? isAuto,
    Value<bool>? isEncrypted,
    Value<String?>? driveFileId,
    Value<String?>? localPath,
    Value<int>? rowid,
  }) {
    return BackupRecordsCompanion(
      id: id ?? this.id,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      itemCount: itemCount ?? this.itemCount,
      isAuto: isAuto ?? this.isAuto,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      driveFileId: driveFileId ?? this.driveFileId,
      localPath: localPath ?? this.localPath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (itemCount.present) {
      map['item_count'] = Variable<int>(itemCount.value);
    }
    if (isAuto.present) {
      map['is_auto'] = Variable<bool>(isAuto.value);
    }
    if (isEncrypted.present) {
      map['is_encrypted'] = Variable<bool>(isEncrypted.value);
    }
    if (driveFileId.present) {
      map['drive_file_id'] = Variable<String>(driveFileId.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BackupRecordsCompanion(')
          ..write('id: $id, ')
          ..write('location: $location, ')
          ..write('createdAt: $createdAt, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('itemCount: $itemCount, ')
          ..write('isAuto: $isAuto, ')
          ..write('isEncrypted: $isEncrypted, ')
          ..write('driveFileId: $driveFileId, ')
          ..write('localPath: $localPath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TombstonesTable extends Tombstones
    with TableInfo<$TombstonesTable, TombstoneRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TombstonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [entity, entityId, deletedAt, deviceId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tombstones';
  @override
  VerificationContext validateIntegrity(
    Insertable<TombstoneRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entity, entityId};
  @override
  TombstoneRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TombstoneRow(
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $TombstonesTable createAlias(String alias) {
    return $TombstonesTable(attachedDatabase, alias);
  }
}

class TombstoneRow extends DataClass implements Insertable<TombstoneRow> {
  /// What was deleted: an `ItemType.key` (`note`, `task`, `reminder`,
  /// `habit`, `vault`) or `tag`, `folder`, `habit_log`, `focus_session`.
  final String entity;

  /// The deleted row's id — for habit logs the natural key
  /// `habitId|yyyy-MM-dd` (log ids differ between devices).
  final String entityId;
  final DateTime deletedAt;

  /// Device that deleted it; '' until the next backup stamps it.
  final String deviceId;
  const TombstoneRow({
    required this.entity,
    required this.entityId,
    required this.deletedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity'] = Variable<String>(entity);
    map['entity_id'] = Variable<String>(entityId);
    map['deleted_at'] = Variable<DateTime>(deletedAt);
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  TombstonesCompanion toCompanion(bool nullToAbsent) {
    return TombstonesCompanion(
      entity: Value(entity),
      entityId: Value(entityId),
      deletedAt: Value(deletedAt),
      deviceId: Value(deviceId),
    );
  }

  factory TombstoneRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TombstoneRow(
      entity: serializer.fromJson<String>(json['entity']),
      entityId: serializer.fromJson<String>(json['entityId']),
      deletedAt: serializer.fromJson<DateTime>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entity': serializer.toJson<String>(entity),
      'entityId': serializer.toJson<String>(entityId),
      'deletedAt': serializer.toJson<DateTime>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  TombstoneRow copyWith({
    String? entity,
    String? entityId,
    DateTime? deletedAt,
    String? deviceId,
  }) => TombstoneRow(
    entity: entity ?? this.entity,
    entityId: entityId ?? this.entityId,
    deletedAt: deletedAt ?? this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  TombstoneRow copyWithCompanion(TombstonesCompanion data) {
    return TombstoneRow(
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TombstoneRow(')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entity, entityId, deletedAt, deviceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TombstoneRow &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId);
}

class TombstonesCompanion extends UpdateCompanion<TombstoneRow> {
  final Value<String> entity;
  final Value<String> entityId;
  final Value<DateTime> deletedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const TombstonesCompanion({
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TombstonesCompanion.insert({
    required String entity,
    required String entityId,
    required DateTime deletedAt,
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : entity = Value(entity),
       entityId = Value(entityId),
       deletedAt = Value(deletedAt);
  static Insertable<TombstoneRow> custom({
    Expression<String>? entity,
    Expression<String>? entityId,
    Expression<DateTime>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TombstonesCompanion copyWith({
    Value<String>? entity,
    Value<String>? entityId,
    Value<DateTime>? deletedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return TombstonesCompanion(
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TombstonesCompanion(')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $SubtasksTable subtasks = $SubtasksTable(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  late final $HabitsTable habits = $HabitsTable(this);
  late final $HabitLogsTable habitLogs = $HabitLogsTable(this);
  late final $VaultItemsTable vaultItems = $VaultItemsTable(this);
  late final $VaultHistoryTable vaultHistory = $VaultHistoryTable(this);
  late final $GeneratorHistoryTable generatorHistory = $GeneratorHistoryTable(
    this,
  );
  late final $FoldersTable folders = $FoldersTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $ItemTagsTable itemTags = $ItemTagsTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  late final $InboxEntriesTable inboxEntries = $InboxEntriesTable(this);
  late final $FocusSessionsTable focusSessions = $FocusSessionsTable(this);
  late final $BackupRecordsTable backupRecords = $BackupRecordsTable(this);
  late final $TombstonesTable tombstones = $TombstonesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    notes,
    tasks,
    subtasks,
    reminders,
    habits,
    habitLogs,
    vaultItems,
    vaultHistory,
    generatorHistory,
    folders,
    tags,
    itemTags,
    attachments,
    inboxEntries,
    focusSessions,
    backupRecords,
    tombstones,
  ];
}

typedef $$NotesTableCreateCompanionBuilder =
    NotesCompanion Function({
      required String id,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> archivedAt,
      Value<DateTime?> deletedAt,
      Value<bool> isPinned,
      Value<bool> isFavorite,
      Value<String?> colorHex,
      Value<String?> folderId,
      Value<double> sortOrder,
      Value<int> syncVersion,
      Value<DateTime?> lastSyncedAt,
      Value<String> deviceId,
      Value<String> title,
      Value<String> contentDelta,
      Value<String> plainText,
      Value<String> checklistJson,
      Value<String?> coverImagePath,
      Value<bool> isLocked,
      Value<String?> lockVerifier,
      Value<int> wordCount,
      Value<String?> reminderId,
      Value<int> rowid,
    });
typedef $$NotesTableUpdateCompanionBuilder =
    NotesCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> archivedAt,
      Value<DateTime?> deletedAt,
      Value<bool> isPinned,
      Value<bool> isFavorite,
      Value<String?> colorHex,
      Value<String?> folderId,
      Value<double> sortOrder,
      Value<int> syncVersion,
      Value<DateTime?> lastSyncedAt,
      Value<String> deviceId,
      Value<String> title,
      Value<String> contentDelta,
      Value<String> plainText,
      Value<String> checklistJson,
      Value<String?> coverImagePath,
      Value<bool> isLocked,
      Value<String?> lockVerifier,
      Value<int> wordCount,
      Value<String?> reminderId,
      Value<int> rowid,
    });

class $$NotesTableFilterComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentDelta => $composableBuilder(
    column: $table.contentDelta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plainText => $composableBuilder(
    column: $table.plainText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checklistJson => $composableBuilder(
    column: $table.checklistJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverImagePath => $composableBuilder(
    column: $table.coverImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLocked => $composableBuilder(
    column: $table.isLocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lockVerifier => $composableBuilder(
    column: $table.lockVerifier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderId => $composableBuilder(
    column: $table.reminderId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentDelta => $composableBuilder(
    column: $table.contentDelta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plainText => $composableBuilder(
    column: $table.plainText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checklistJson => $composableBuilder(
    column: $table.checklistJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverImagePath => $composableBuilder(
    column: $table.coverImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLocked => $composableBuilder(
    column: $table.isLocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lockVerifier => $composableBuilder(
    column: $table.lockVerifier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderId => $composableBuilder(
    column: $table.reminderId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<double> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get contentDelta => $composableBuilder(
    column: $table.contentDelta,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plainText =>
      $composableBuilder(column: $table.plainText, builder: (column) => column);

  GeneratedColumn<String> get checklistJson => $composableBuilder(
    column: $table.checklistJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverImagePath => $composableBuilder(
    column: $table.coverImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isLocked =>
      $composableBuilder(column: $table.isLocked, builder: (column) => column);

  GeneratedColumn<String> get lockVerifier => $composableBuilder(
    column: $table.lockVerifier,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  GeneratedColumn<String> get reminderId => $composableBuilder(
    column: $table.reminderId,
    builder: (column) => column,
  );
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotesTable,
          NoteRow,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (NoteRow, BaseReferences<_$AppDatabase, $NotesTable, NoteRow>),
          NoteRow,
          PrefetchHooks Function()
        > {
  $$NotesTableTableManager(_$AppDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> contentDelta = const Value.absent(),
                Value<String> plainText = const Value.absent(),
                Value<String> checklistJson = const Value.absent(),
                Value<String?> coverImagePath = const Value.absent(),
                Value<bool> isLocked = const Value.absent(),
                Value<String?> lockVerifier = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                Value<String?> reminderId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                isPinned: isPinned,
                isFavorite: isFavorite,
                colorHex: colorHex,
                folderId: folderId,
                sortOrder: sortOrder,
                syncVersion: syncVersion,
                lastSyncedAt: lastSyncedAt,
                deviceId: deviceId,
                title: title,
                contentDelta: contentDelta,
                plainText: plainText,
                checklistJson: checklistJson,
                coverImagePath: coverImagePath,
                isLocked: isLocked,
                lockVerifier: lockVerifier,
                wordCount: wordCount,
                reminderId: reminderId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> contentDelta = const Value.absent(),
                Value<String> plainText = const Value.absent(),
                Value<String> checklistJson = const Value.absent(),
                Value<String?> coverImagePath = const Value.absent(),
                Value<bool> isLocked = const Value.absent(),
                Value<String?> lockVerifier = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                Value<String?> reminderId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                isPinned: isPinned,
                isFavorite: isFavorite,
                colorHex: colorHex,
                folderId: folderId,
                sortOrder: sortOrder,
                syncVersion: syncVersion,
                lastSyncedAt: lastSyncedAt,
                deviceId: deviceId,
                title: title,
                contentDelta: contentDelta,
                plainText: plainText,
                checklistJson: checklistJson,
                coverImagePath: coverImagePath,
                isLocked: isLocked,
                lockVerifier: lockVerifier,
                wordCount: wordCount,
                reminderId: reminderId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NotesTable, NoteRow>(table),
                  BaseReferences<_$AppDatabase, $NotesTable, NoteRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotesTable,
      NoteRow,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (NoteRow, BaseReferences<_$AppDatabase, $NotesTable, NoteRow>),
      NoteRow,
      PrefetchHooks Function()
    >;
typedef $$TasksTableCreateCompanionBuilder =
    TasksCompanion Function({
      required String id,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> archivedAt,
      Value<DateTime?> deletedAt,
      Value<bool> isPinned,
      Value<bool> isFavorite,
      Value<String?> colorHex,
      Value<String?> folderId,
      Value<double> sortOrder,
      Value<int> syncVersion,
      Value<DateTime?> lastSyncedAt,
      Value<String> deviceId,
      Value<String> title,
      Value<String> notes,
      Value<DateTime?> dueDate,
      Value<int?> dueTimeMinutes,
      Value<int> priority,
      Value<String?> repeatRule,
      Value<int?> remindOffsetMinutes,
      Value<String?> reminderId,
      Value<String?> linkedNoteId,
      Value<DateTime?> completedAt,
      Value<int> boardStatus,
      Value<int> rowid,
    });
typedef $$TasksTableUpdateCompanionBuilder =
    TasksCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> archivedAt,
      Value<DateTime?> deletedAt,
      Value<bool> isPinned,
      Value<bool> isFavorite,
      Value<String?> colorHex,
      Value<String?> folderId,
      Value<double> sortOrder,
      Value<int> syncVersion,
      Value<DateTime?> lastSyncedAt,
      Value<String> deviceId,
      Value<String> title,
      Value<String> notes,
      Value<DateTime?> dueDate,
      Value<int?> dueTimeMinutes,
      Value<int> priority,
      Value<String?> repeatRule,
      Value<int?> remindOffsetMinutes,
      Value<String?> reminderId,
      Value<String?> linkedNoteId,
      Value<DateTime?> completedAt,
      Value<int> boardStatus,
      Value<int> rowid,
    });

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueTimeMinutes => $composableBuilder(
    column: $table.dueTimeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remindOffsetMinutes => $composableBuilder(
    column: $table.remindOffsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderId => $composableBuilder(
    column: $table.reminderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedNoteId => $composableBuilder(
    column: $table.linkedNoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get boardStatus => $composableBuilder(
    column: $table.boardStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueTimeMinutes => $composableBuilder(
    column: $table.dueTimeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remindOffsetMinutes => $composableBuilder(
    column: $table.remindOffsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderId => $composableBuilder(
    column: $table.reminderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedNoteId => $composableBuilder(
    column: $table.linkedNoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get boardStatus => $composableBuilder(
    column: $table.boardStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<double> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<int> get dueTimeMinutes => $composableBuilder(
    column: $table.dueTimeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remindOffsetMinutes => $composableBuilder(
    column: $table.remindOffsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reminderId => $composableBuilder(
    column: $table.reminderId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkedNoteId => $composableBuilder(
    column: $table.linkedNoteId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get boardStatus => $composableBuilder(
    column: $table.boardStatus,
    builder: (column) => column,
  );
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          TaskRow,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (TaskRow, BaseReferences<_$AppDatabase, $TasksTable, TaskRow>),
          TaskRow,
          PrefetchHooks Function()
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<int?> dueTimeMinutes = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String?> repeatRule = const Value.absent(),
                Value<int?> remindOffsetMinutes = const Value.absent(),
                Value<String?> reminderId = const Value.absent(),
                Value<String?> linkedNoteId = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> boardStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                isPinned: isPinned,
                isFavorite: isFavorite,
                colorHex: colorHex,
                folderId: folderId,
                sortOrder: sortOrder,
                syncVersion: syncVersion,
                lastSyncedAt: lastSyncedAt,
                deviceId: deviceId,
                title: title,
                notes: notes,
                dueDate: dueDate,
                dueTimeMinutes: dueTimeMinutes,
                priority: priority,
                repeatRule: repeatRule,
                remindOffsetMinutes: remindOffsetMinutes,
                reminderId: reminderId,
                linkedNoteId: linkedNoteId,
                completedAt: completedAt,
                boardStatus: boardStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<int?> dueTimeMinutes = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String?> repeatRule = const Value.absent(),
                Value<int?> remindOffsetMinutes = const Value.absent(),
                Value<String?> reminderId = const Value.absent(),
                Value<String?> linkedNoteId = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> boardStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                isPinned: isPinned,
                isFavorite: isFavorite,
                colorHex: colorHex,
                folderId: folderId,
                sortOrder: sortOrder,
                syncVersion: syncVersion,
                lastSyncedAt: lastSyncedAt,
                deviceId: deviceId,
                title: title,
                notes: notes,
                dueDate: dueDate,
                dueTimeMinutes: dueTimeMinutes,
                priority: priority,
                repeatRule: repeatRule,
                remindOffsetMinutes: remindOffsetMinutes,
                reminderId: reminderId,
                linkedNoteId: linkedNoteId,
                completedAt: completedAt,
                boardStatus: boardStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TasksTable, TaskRow>(table),
                  BaseReferences<_$AppDatabase, $TasksTable, TaskRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      TaskRow,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (TaskRow, BaseReferences<_$AppDatabase, $TasksTable, TaskRow>),
      TaskRow,
      PrefetchHooks Function()
    >;
typedef $$SubtasksTableCreateCompanionBuilder =
    SubtasksCompanion Function({
      required String id,
      required String taskId,
      Value<String> title,
      Value<bool> done,
      Value<double> sortOrder,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SubtasksTableUpdateCompanionBuilder =
    SubtasksCompanion Function({
      Value<String> id,
      Value<String> taskId,
      Value<String> title,
      Value<bool> done,
      Value<double> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SubtasksTableFilterComposer
    extends Composer<_$AppDatabase, $SubtasksTable> {
  $$SubtasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SubtasksTableOrderingComposer
    extends Composer<_$AppDatabase, $SubtasksTable> {
  $$SubtasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubtasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubtasksTable> {
  $$SubtasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<double> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SubtasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubtasksTable,
          SubtaskRow,
          $$SubtasksTableFilterComposer,
          $$SubtasksTableOrderingComposer,
          $$SubtasksTableAnnotationComposer,
          $$SubtasksTableCreateCompanionBuilder,
          $$SubtasksTableUpdateCompanionBuilder,
          (
            SubtaskRow,
            BaseReferences<_$AppDatabase, $SubtasksTable, SubtaskRow>,
          ),
          SubtaskRow,
          PrefetchHooks Function()
        > {
  $$SubtasksTableTableManager(_$AppDatabase db, $SubtasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubtasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubtasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubtasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubtasksCompanion(
                id: id,
                taskId: taskId,
                title: title,
                done: done,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                Value<String> title = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SubtasksCompanion.insert(
                id: id,
                taskId: taskId,
                title: title,
                done: done,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SubtasksTable, SubtaskRow>(table),
                  BaseReferences<_$AppDatabase, $SubtasksTable, SubtaskRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SubtasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubtasksTable,
      SubtaskRow,
      $$SubtasksTableFilterComposer,
      $$SubtasksTableOrderingComposer,
      $$SubtasksTableAnnotationComposer,
      $$SubtasksTableCreateCompanionBuilder,
      $$SubtasksTableUpdateCompanionBuilder,
      (SubtaskRow, BaseReferences<_$AppDatabase, $SubtasksTable, SubtaskRow>),
      SubtaskRow,
      PrefetchHooks Function()
    >;
typedef $$RemindersTableCreateCompanionBuilder =
    RemindersCompanion Function({
      required String id,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> archivedAt,
      Value<DateTime?> deletedAt,
      Value<bool> isPinned,
      Value<bool> isFavorite,
      Value<String?> colorHex,
      Value<String?> folderId,
      Value<double> sortOrder,
      Value<int> syncVersion,
      Value<DateTime?> lastSyncedAt,
      Value<String> deviceId,
      Value<String> title,
      Value<String> note,
      required DateTime triggerAt,
      Value<String?> repeatRule,
      Value<int> alertStyle,
      Value<String> sound,
      Value<int> snoozeMinutes,
      Value<DateTime?> snoozedUntil,
      Value<String?> locationJson,
      Value<String?> linkedItemId,
      Value<String?> linkedItemType,
      Value<bool> isEnabled,
      Value<DateTime?> lastFiredAt,
      Value<DateTime?> completedAt,
      required int notificationId,
      Value<int> rowid,
    });
typedef $$RemindersTableUpdateCompanionBuilder =
    RemindersCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> archivedAt,
      Value<DateTime?> deletedAt,
      Value<bool> isPinned,
      Value<bool> isFavorite,
      Value<String?> colorHex,
      Value<String?> folderId,
      Value<double> sortOrder,
      Value<int> syncVersion,
      Value<DateTime?> lastSyncedAt,
      Value<String> deviceId,
      Value<String> title,
      Value<String> note,
      Value<DateTime> triggerAt,
      Value<String?> repeatRule,
      Value<int> alertStyle,
      Value<String> sound,
      Value<int> snoozeMinutes,
      Value<DateTime?> snoozedUntil,
      Value<String?> locationJson,
      Value<String?> linkedItemId,
      Value<String?> linkedItemType,
      Value<bool> isEnabled,
      Value<DateTime?> lastFiredAt,
      Value<DateTime?> completedAt,
      Value<int> notificationId,
      Value<int> rowid,
    });

class $$RemindersTableFilterComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get triggerAt => $composableBuilder(
    column: $table.triggerAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get alertStyle => $composableBuilder(
    column: $table.alertStyle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sound => $composableBuilder(
    column: $table.sound,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozeMinutes => $composableBuilder(
    column: $table.snoozeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationJson => $composableBuilder(
    column: $table.locationJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedItemId => $composableBuilder(
    column: $table.linkedItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedItemType => $composableBuilder(
    column: $table.linkedItemType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastFiredAt => $composableBuilder(
    column: $table.lastFiredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get triggerAt => $composableBuilder(
    column: $table.triggerAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get alertStyle => $composableBuilder(
    column: $table.alertStyle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sound => $composableBuilder(
    column: $table.sound,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozeMinutes => $composableBuilder(
    column: $table.snoozeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationJson => $composableBuilder(
    column: $table.locationJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedItemId => $composableBuilder(
    column: $table.linkedItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedItemType => $composableBuilder(
    column: $table.linkedItemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastFiredAt => $composableBuilder(
    column: $table.lastFiredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<double> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get triggerAt =>
      $composableBuilder(column: $table.triggerAt, builder: (column) => column);

  GeneratedColumn<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => column,
  );

  GeneratedColumn<int> get alertStyle => $composableBuilder(
    column: $table.alertStyle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sound =>
      $composableBuilder(column: $table.sound, builder: (column) => column);

  GeneratedColumn<int> get snoozeMinutes => $composableBuilder(
    column: $table.snoozeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<String> get locationJson => $composableBuilder(
    column: $table.locationJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkedItemId => $composableBuilder(
    column: $table.linkedItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkedItemType => $composableBuilder(
    column: $table.linkedItemType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<DateTime> get lastFiredAt => $composableBuilder(
    column: $table.lastFiredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => column,
  );
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemindersTable,
          ReminderRow,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (
            ReminderRow,
            BaseReferences<_$AppDatabase, $RemindersTable, ReminderRow>,
          ),
          ReminderRow,
          PrefetchHooks Function()
        > {
  $$RemindersTableTableManager(_$AppDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<DateTime> triggerAt = const Value.absent(),
                Value<String?> repeatRule = const Value.absent(),
                Value<int> alertStyle = const Value.absent(),
                Value<String> sound = const Value.absent(),
                Value<int> snoozeMinutes = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<String?> locationJson = const Value.absent(),
                Value<String?> linkedItemId = const Value.absent(),
                Value<String?> linkedItemType = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime?> lastFiredAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> notificationId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                isPinned: isPinned,
                isFavorite: isFavorite,
                colorHex: colorHex,
                folderId: folderId,
                sortOrder: sortOrder,
                syncVersion: syncVersion,
                lastSyncedAt: lastSyncedAt,
                deviceId: deviceId,
                title: title,
                note: note,
                triggerAt: triggerAt,
                repeatRule: repeatRule,
                alertStyle: alertStyle,
                sound: sound,
                snoozeMinutes: snoozeMinutes,
                snoozedUntil: snoozedUntil,
                locationJson: locationJson,
                linkedItemId: linkedItemId,
                linkedItemType: linkedItemType,
                isEnabled: isEnabled,
                lastFiredAt: lastFiredAt,
                completedAt: completedAt,
                notificationId: notificationId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> note = const Value.absent(),
                required DateTime triggerAt,
                Value<String?> repeatRule = const Value.absent(),
                Value<int> alertStyle = const Value.absent(),
                Value<String> sound = const Value.absent(),
                Value<int> snoozeMinutes = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<String?> locationJson = const Value.absent(),
                Value<String?> linkedItemId = const Value.absent(),
                Value<String?> linkedItemType = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime?> lastFiredAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                required int notificationId,
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                isPinned: isPinned,
                isFavorite: isFavorite,
                colorHex: colorHex,
                folderId: folderId,
                sortOrder: sortOrder,
                syncVersion: syncVersion,
                lastSyncedAt: lastSyncedAt,
                deviceId: deviceId,
                title: title,
                note: note,
                triggerAt: triggerAt,
                repeatRule: repeatRule,
                alertStyle: alertStyle,
                sound: sound,
                snoozeMinutes: snoozeMinutes,
                snoozedUntil: snoozedUntil,
                locationJson: locationJson,
                linkedItemId: linkedItemId,
                linkedItemType: linkedItemType,
                isEnabled: isEnabled,
                lastFiredAt: lastFiredAt,
                completedAt: completedAt,
                notificationId: notificationId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RemindersTable, ReminderRow>(table),
                  BaseReferences<_$AppDatabase, $RemindersTable, ReminderRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemindersTable,
      ReminderRow,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (
        ReminderRow,
        BaseReferences<_$AppDatabase, $RemindersTable, ReminderRow>,
      ),
      ReminderRow,
      PrefetchHooks Function()
    >;
typedef $$HabitsTableCreateCompanionBuilder =
    HabitsCompanion Function({
      required String id,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> archivedAt,
      Value<DateTime?> deletedAt,
      Value<bool> isPinned,
      Value<bool> isFavorite,
      Value<String?> colorHex,
      Value<String?> folderId,
      Value<double> sortOrder,
      Value<int> syncVersion,
      Value<DateTime?> lastSyncedAt,
      Value<String> deviceId,
      Value<String> name,
      Value<String> iconKey,
      Value<String> category,
      Value<int> habitType,
      Value<int> targetCount,
      Value<String> unit,
      Value<int> frequencyType,
      Value<int> weekdaysMask,
      Value<int> timesPerWeek,
      Value<int> everyNDays,
      Value<int> partOfDay,
      Value<bool> reminderEnabled,
      Value<String> reminderTimesJson,
      required String startDate,
      Value<bool> isPaused,
      Value<int> rowid,
    });
typedef $$HabitsTableUpdateCompanionBuilder =
    HabitsCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> archivedAt,
      Value<DateTime?> deletedAt,
      Value<bool> isPinned,
      Value<bool> isFavorite,
      Value<String?> colorHex,
      Value<String?> folderId,
      Value<double> sortOrder,
      Value<int> syncVersion,
      Value<DateTime?> lastSyncedAt,
      Value<String> deviceId,
      Value<String> name,
      Value<String> iconKey,
      Value<String> category,
      Value<int> habitType,
      Value<int> targetCount,
      Value<String> unit,
      Value<int> frequencyType,
      Value<int> weekdaysMask,
      Value<int> timesPerWeek,
      Value<int> everyNDays,
      Value<int> partOfDay,
      Value<bool> reminderEnabled,
      Value<String> reminderTimesJson,
      Value<String> startDate,
      Value<bool> isPaused,
      Value<int> rowid,
    });

class $$HabitsTableFilterComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get habitType => $composableBuilder(
    column: $table.habitType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetCount => $composableBuilder(
    column: $table.targetCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get frequencyType => $composableBuilder(
    column: $table.frequencyType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekdaysMask => $composableBuilder(
    column: $table.weekdaysMask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timesPerWeek => $composableBuilder(
    column: $table.timesPerWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get everyNDays => $composableBuilder(
    column: $table.everyNDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get partOfDay => $composableBuilder(
    column: $table.partOfDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderTimesJson => $composableBuilder(
    column: $table.reminderTimesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPaused => $composableBuilder(
    column: $table.isPaused,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HabitsTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get habitType => $composableBuilder(
    column: $table.habitType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetCount => $composableBuilder(
    column: $table.targetCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get frequencyType => $composableBuilder(
    column: $table.frequencyType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekdaysMask => $composableBuilder(
    column: $table.weekdaysMask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timesPerWeek => $composableBuilder(
    column: $table.timesPerWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get everyNDays => $composableBuilder(
    column: $table.everyNDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get partOfDay => $composableBuilder(
    column: $table.partOfDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderTimesJson => $composableBuilder(
    column: $table.reminderTimesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPaused => $composableBuilder(
    column: $table.isPaused,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<double> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get habitType =>
      $composableBuilder(column: $table.habitType, builder: (column) => column);

  GeneratedColumn<int> get targetCount => $composableBuilder(
    column: $table.targetCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get frequencyType => $composableBuilder(
    column: $table.frequencyType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get weekdaysMask => $composableBuilder(
    column: $table.weekdaysMask,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timesPerWeek => $composableBuilder(
    column: $table.timesPerWeek,
    builder: (column) => column,
  );

  GeneratedColumn<int> get everyNDays => $composableBuilder(
    column: $table.everyNDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get partOfDay =>
      $composableBuilder(column: $table.partOfDay, builder: (column) => column);

  GeneratedColumn<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reminderTimesJson => $composableBuilder(
    column: $table.reminderTimesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<bool> get isPaused =>
      $composableBuilder(column: $table.isPaused, builder: (column) => column);
}

class $$HabitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitsTable,
          HabitRow,
          $$HabitsTableFilterComposer,
          $$HabitsTableOrderingComposer,
          $$HabitsTableAnnotationComposer,
          $$HabitsTableCreateCompanionBuilder,
          $$HabitsTableUpdateCompanionBuilder,
          (HabitRow, BaseReferences<_$AppDatabase, $HabitsTable, HabitRow>),
          HabitRow,
          PrefetchHooks Function()
        > {
  $$HabitsTableTableManager(_$AppDatabase db, $HabitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> iconKey = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int> habitType = const Value.absent(),
                Value<int> targetCount = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<int> frequencyType = const Value.absent(),
                Value<int> weekdaysMask = const Value.absent(),
                Value<int> timesPerWeek = const Value.absent(),
                Value<int> everyNDays = const Value.absent(),
                Value<int> partOfDay = const Value.absent(),
                Value<bool> reminderEnabled = const Value.absent(),
                Value<String> reminderTimesJson = const Value.absent(),
                Value<String> startDate = const Value.absent(),
                Value<bool> isPaused = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                isPinned: isPinned,
                isFavorite: isFavorite,
                colorHex: colorHex,
                folderId: folderId,
                sortOrder: sortOrder,
                syncVersion: syncVersion,
                lastSyncedAt: lastSyncedAt,
                deviceId: deviceId,
                name: name,
                iconKey: iconKey,
                category: category,
                habitType: habitType,
                targetCount: targetCount,
                unit: unit,
                frequencyType: frequencyType,
                weekdaysMask: weekdaysMask,
                timesPerWeek: timesPerWeek,
                everyNDays: everyNDays,
                partOfDay: partOfDay,
                reminderEnabled: reminderEnabled,
                reminderTimesJson: reminderTimesJson,
                startDate: startDate,
                isPaused: isPaused,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> iconKey = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int> habitType = const Value.absent(),
                Value<int> targetCount = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<int> frequencyType = const Value.absent(),
                Value<int> weekdaysMask = const Value.absent(),
                Value<int> timesPerWeek = const Value.absent(),
                Value<int> everyNDays = const Value.absent(),
                Value<int> partOfDay = const Value.absent(),
                Value<bool> reminderEnabled = const Value.absent(),
                Value<String> reminderTimesJson = const Value.absent(),
                required String startDate,
                Value<bool> isPaused = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                isPinned: isPinned,
                isFavorite: isFavorite,
                colorHex: colorHex,
                folderId: folderId,
                sortOrder: sortOrder,
                syncVersion: syncVersion,
                lastSyncedAt: lastSyncedAt,
                deviceId: deviceId,
                name: name,
                iconKey: iconKey,
                category: category,
                habitType: habitType,
                targetCount: targetCount,
                unit: unit,
                frequencyType: frequencyType,
                weekdaysMask: weekdaysMask,
                timesPerWeek: timesPerWeek,
                everyNDays: everyNDays,
                partOfDay: partOfDay,
                reminderEnabled: reminderEnabled,
                reminderTimesJson: reminderTimesJson,
                startDate: startDate,
                isPaused: isPaused,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HabitsTable, HabitRow>(table),
                  BaseReferences<_$AppDatabase, $HabitsTable, HabitRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HabitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitsTable,
      HabitRow,
      $$HabitsTableFilterComposer,
      $$HabitsTableOrderingComposer,
      $$HabitsTableAnnotationComposer,
      $$HabitsTableCreateCompanionBuilder,
      $$HabitsTableUpdateCompanionBuilder,
      (HabitRow, BaseReferences<_$AppDatabase, $HabitsTable, HabitRow>),
      HabitRow,
      PrefetchHooks Function()
    >;
typedef $$HabitLogsTableCreateCompanionBuilder =
    HabitLogsCompanion Function({
      required String id,
      required String habitId,
      required String date,
      Value<int> count,
      Value<bool> skipped,
      Value<String?> note,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$HabitLogsTableUpdateCompanionBuilder =
    HabitLogsCompanion Function({
      Value<String> id,
      Value<String> habitId,
      Value<String> date,
      Value<int> count,
      Value<bool> skipped,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$HabitLogsTableFilterComposer
    extends Composer<_$AppDatabase, $HabitLogsTable> {
  $$HabitLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get skipped => $composableBuilder(
    column: $table.skipped,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HabitLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitLogsTable> {
  $$HabitLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get skipped => $composableBuilder(
    column: $table.skipped,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitLogsTable> {
  $$HabitLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<bool> get skipped =>
      $composableBuilder(column: $table.skipped, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$HabitLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitLogsTable,
          HabitLogRow,
          $$HabitLogsTableFilterComposer,
          $$HabitLogsTableOrderingComposer,
          $$HabitLogsTableAnnotationComposer,
          $$HabitLogsTableCreateCompanionBuilder,
          $$HabitLogsTableUpdateCompanionBuilder,
          (
            HabitLogRow,
            BaseReferences<_$AppDatabase, $HabitLogsTable, HabitLogRow>,
          ),
          HabitLogRow,
          PrefetchHooks Function()
        > {
  $$HabitLogsTableTableManager(_$AppDatabase db, $HabitLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> habitId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<bool> skipped = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitLogsCompanion(
                id: id,
                habitId: habitId,
                date: date,
                count: count,
                skipped: skipped,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String habitId,
                required String date,
                Value<int> count = const Value.absent(),
                Value<bool> skipped = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => HabitLogsCompanion.insert(
                id: id,
                habitId: habitId,
                date: date,
                count: count,
                skipped: skipped,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HabitLogsTable, HabitLogRow>(table),
                  BaseReferences<_$AppDatabase, $HabitLogsTable, HabitLogRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HabitLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitLogsTable,
      HabitLogRow,
      $$HabitLogsTableFilterComposer,
      $$HabitLogsTableOrderingComposer,
      $$HabitLogsTableAnnotationComposer,
      $$HabitLogsTableCreateCompanionBuilder,
      $$HabitLogsTableUpdateCompanionBuilder,
      (
        HabitLogRow,
        BaseReferences<_$AppDatabase, $HabitLogsTable, HabitLogRow>,
      ),
      HabitLogRow,
      PrefetchHooks Function()
    >;
typedef $$VaultItemsTableCreateCompanionBuilder =
    VaultItemsCompanion Function({
      required String id,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> archivedAt,
      Value<DateTime?> deletedAt,
      Value<bool> isPinned,
      Value<bool> isFavorite,
      Value<String?> colorHex,
      Value<String?> folderId,
      Value<double> sortOrder,
      Value<int> syncVersion,
      Value<DateTime?> lastSyncedAt,
      Value<String> deviceId,
      Value<int> itemType,
      Value<String> title,
      Value<String?> iconKey,
      required Uint8List encryptedPayload,
      Value<int?> passwordStrength,
      Value<DateTime?> passwordUpdatedAt,
      Value<String?> passwordFingerprint,
      Value<int?> breachCount,
      Value<DateTime?> breachCheckedAt,
      Value<bool> hasTotp,
      Value<int?> expiryDays,
      Value<int> rowid,
    });
typedef $$VaultItemsTableUpdateCompanionBuilder =
    VaultItemsCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> archivedAt,
      Value<DateTime?> deletedAt,
      Value<bool> isPinned,
      Value<bool> isFavorite,
      Value<String?> colorHex,
      Value<String?> folderId,
      Value<double> sortOrder,
      Value<int> syncVersion,
      Value<DateTime?> lastSyncedAt,
      Value<String> deviceId,
      Value<int> itemType,
      Value<String> title,
      Value<String?> iconKey,
      Value<Uint8List> encryptedPayload,
      Value<int?> passwordStrength,
      Value<DateTime?> passwordUpdatedAt,
      Value<String?> passwordFingerprint,
      Value<int?> breachCount,
      Value<DateTime?> breachCheckedAt,
      Value<bool> hasTotp,
      Value<int?> expiryDays,
      Value<int> rowid,
    });

class $$VaultItemsTableFilterComposer
    extends Composer<_$AppDatabase, $VaultItemsTable> {
  $$VaultItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get passwordStrength => $composableBuilder(
    column: $table.passwordStrength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get passwordUpdatedAt => $composableBuilder(
    column: $table.passwordUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passwordFingerprint => $composableBuilder(
    column: $table.passwordFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get breachCount => $composableBuilder(
    column: $table.breachCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get breachCheckedAt => $composableBuilder(
    column: $table.breachCheckedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasTotp => $composableBuilder(
    column: $table.hasTotp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiryDays => $composableBuilder(
    column: $table.expiryDays,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $VaultItemsTable> {
  $$VaultItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get passwordStrength => $composableBuilder(
    column: $table.passwordStrength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get passwordUpdatedAt => $composableBuilder(
    column: $table.passwordUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passwordFingerprint => $composableBuilder(
    column: $table.passwordFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get breachCount => $composableBuilder(
    column: $table.breachCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get breachCheckedAt => $composableBuilder(
    column: $table.breachCheckedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasTotp => $composableBuilder(
    column: $table.hasTotp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiryDays => $composableBuilder(
    column: $table.expiryDays,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VaultItemsTable> {
  $$VaultItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<double> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<Uint8List> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => column,
  );

  GeneratedColumn<int> get passwordStrength => $composableBuilder(
    column: $table.passwordStrength,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get passwordUpdatedAt => $composableBuilder(
    column: $table.passwordUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get passwordFingerprint => $composableBuilder(
    column: $table.passwordFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<int> get breachCount => $composableBuilder(
    column: $table.breachCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get breachCheckedAt => $composableBuilder(
    column: $table.breachCheckedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasTotp =>
      $composableBuilder(column: $table.hasTotp, builder: (column) => column);

  GeneratedColumn<int> get expiryDays => $composableBuilder(
    column: $table.expiryDays,
    builder: (column) => column,
  );
}

class $$VaultItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VaultItemsTable,
          VaultItemRow,
          $$VaultItemsTableFilterComposer,
          $$VaultItemsTableOrderingComposer,
          $$VaultItemsTableAnnotationComposer,
          $$VaultItemsTableCreateCompanionBuilder,
          $$VaultItemsTableUpdateCompanionBuilder,
          (
            VaultItemRow,
            BaseReferences<_$AppDatabase, $VaultItemsTable, VaultItemRow>,
          ),
          VaultItemRow,
          PrefetchHooks Function()
        > {
  $$VaultItemsTableTableManager(_$AppDatabase db, $VaultItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> itemType = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> iconKey = const Value.absent(),
                Value<Uint8List> encryptedPayload = const Value.absent(),
                Value<int?> passwordStrength = const Value.absent(),
                Value<DateTime?> passwordUpdatedAt = const Value.absent(),
                Value<String?> passwordFingerprint = const Value.absent(),
                Value<int?> breachCount = const Value.absent(),
                Value<DateTime?> breachCheckedAt = const Value.absent(),
                Value<bool> hasTotp = const Value.absent(),
                Value<int?> expiryDays = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultItemsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                isPinned: isPinned,
                isFavorite: isFavorite,
                colorHex: colorHex,
                folderId: folderId,
                sortOrder: sortOrder,
                syncVersion: syncVersion,
                lastSyncedAt: lastSyncedAt,
                deviceId: deviceId,
                itemType: itemType,
                title: title,
                iconKey: iconKey,
                encryptedPayload: encryptedPayload,
                passwordStrength: passwordStrength,
                passwordUpdatedAt: passwordUpdatedAt,
                passwordFingerprint: passwordFingerprint,
                breachCount: breachCount,
                breachCheckedAt: breachCheckedAt,
                hasTotp: hasTotp,
                expiryDays: expiryDays,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> itemType = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> iconKey = const Value.absent(),
                required Uint8List encryptedPayload,
                Value<int?> passwordStrength = const Value.absent(),
                Value<DateTime?> passwordUpdatedAt = const Value.absent(),
                Value<String?> passwordFingerprint = const Value.absent(),
                Value<int?> breachCount = const Value.absent(),
                Value<DateTime?> breachCheckedAt = const Value.absent(),
                Value<bool> hasTotp = const Value.absent(),
                Value<int?> expiryDays = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultItemsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                isPinned: isPinned,
                isFavorite: isFavorite,
                colorHex: colorHex,
                folderId: folderId,
                sortOrder: sortOrder,
                syncVersion: syncVersion,
                lastSyncedAt: lastSyncedAt,
                deviceId: deviceId,
                itemType: itemType,
                title: title,
                iconKey: iconKey,
                encryptedPayload: encryptedPayload,
                passwordStrength: passwordStrength,
                passwordUpdatedAt: passwordUpdatedAt,
                passwordFingerprint: passwordFingerprint,
                breachCount: breachCount,
                breachCheckedAt: breachCheckedAt,
                hasTotp: hasTotp,
                expiryDays: expiryDays,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VaultItemsTable, VaultItemRow>(table),
                  BaseReferences<_$AppDatabase, $VaultItemsTable, VaultItemRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VaultItemsTable,
      VaultItemRow,
      $$VaultItemsTableFilterComposer,
      $$VaultItemsTableOrderingComposer,
      $$VaultItemsTableAnnotationComposer,
      $$VaultItemsTableCreateCompanionBuilder,
      $$VaultItemsTableUpdateCompanionBuilder,
      (
        VaultItemRow,
        BaseReferences<_$AppDatabase, $VaultItemsTable, VaultItemRow>,
      ),
      VaultItemRow,
      PrefetchHooks Function()
    >;
typedef $$VaultHistoryTableCreateCompanionBuilder =
    VaultHistoryCompanion Function({
      required String id,
      required String itemId,
      required Uint8List encryptedPassword,
      required DateTime changedAt,
      Value<int> rowid,
    });
typedef $$VaultHistoryTableUpdateCompanionBuilder =
    VaultHistoryCompanion Function({
      Value<String> id,
      Value<String> itemId,
      Value<Uint8List> encryptedPassword,
      Value<DateTime> changedAt,
      Value<int> rowid,
    });

class $$VaultHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $VaultHistoryTable> {
  $$VaultHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get encryptedPassword => $composableBuilder(
    column: $table.encryptedPassword,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $VaultHistoryTable> {
  $$VaultHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get encryptedPassword => $composableBuilder(
    column: $table.encryptedPassword,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $VaultHistoryTable> {
  $$VaultHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<Uint8List> get encryptedPassword => $composableBuilder(
    column: $table.encryptedPassword,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => column);
}

class $$VaultHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VaultHistoryTable,
          VaultHistoryRow,
          $$VaultHistoryTableFilterComposer,
          $$VaultHistoryTableOrderingComposer,
          $$VaultHistoryTableAnnotationComposer,
          $$VaultHistoryTableCreateCompanionBuilder,
          $$VaultHistoryTableUpdateCompanionBuilder,
          (
            VaultHistoryRow,
            BaseReferences<_$AppDatabase, $VaultHistoryTable, VaultHistoryRow>,
          ),
          VaultHistoryRow,
          PrefetchHooks Function()
        > {
  $$VaultHistoryTableTableManager(_$AppDatabase db, $VaultHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<Uint8List> encryptedPassword = const Value.absent(),
                Value<DateTime> changedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultHistoryCompanion(
                id: id,
                itemId: itemId,
                encryptedPassword: encryptedPassword,
                changedAt: changedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String itemId,
                required Uint8List encryptedPassword,
                required DateTime changedAt,
                Value<int> rowid = const Value.absent(),
              }) => VaultHistoryCompanion.insert(
                id: id,
                itemId: itemId,
                encryptedPassword: encryptedPassword,
                changedAt: changedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VaultHistoryTable, VaultHistoryRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $VaultHistoryTable,
                    VaultHistoryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VaultHistoryTable,
      VaultHistoryRow,
      $$VaultHistoryTableFilterComposer,
      $$VaultHistoryTableOrderingComposer,
      $$VaultHistoryTableAnnotationComposer,
      $$VaultHistoryTableCreateCompanionBuilder,
      $$VaultHistoryTableUpdateCompanionBuilder,
      (
        VaultHistoryRow,
        BaseReferences<_$AppDatabase, $VaultHistoryTable, VaultHistoryRow>,
      ),
      VaultHistoryRow,
      PrefetchHooks Function()
    >;
typedef $$GeneratorHistoryTableCreateCompanionBuilder =
    GeneratorHistoryCompanion Function({
      required String id,
      required Uint8List encryptedValue,
      Value<String> mode,
      Value<int> entropyBits,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$GeneratorHistoryTableUpdateCompanionBuilder =
    GeneratorHistoryCompanion Function({
      Value<String> id,
      Value<Uint8List> encryptedValue,
      Value<String> mode,
      Value<int> entropyBits,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$GeneratorHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $GeneratorHistoryTable> {
  $$GeneratorHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get encryptedValue => $composableBuilder(
    column: $table.encryptedValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get entropyBits => $composableBuilder(
    column: $table.entropyBits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GeneratorHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $GeneratorHistoryTable> {
  $$GeneratorHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get encryptedValue => $composableBuilder(
    column: $table.encryptedValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entropyBits => $composableBuilder(
    column: $table.entropyBits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GeneratorHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $GeneratorHistoryTable> {
  $$GeneratorHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get encryptedValue => $composableBuilder(
    column: $table.encryptedValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get entropyBits => $composableBuilder(
    column: $table.entropyBits,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$GeneratorHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GeneratorHistoryTable,
          GeneratorHistoryRow,
          $$GeneratorHistoryTableFilterComposer,
          $$GeneratorHistoryTableOrderingComposer,
          $$GeneratorHistoryTableAnnotationComposer,
          $$GeneratorHistoryTableCreateCompanionBuilder,
          $$GeneratorHistoryTableUpdateCompanionBuilder,
          (
            GeneratorHistoryRow,
            BaseReferences<
              _$AppDatabase,
              $GeneratorHistoryTable,
              GeneratorHistoryRow
            >,
          ),
          GeneratorHistoryRow,
          PrefetchHooks Function()
        > {
  $$GeneratorHistoryTableTableManager(
    _$AppDatabase db,
    $GeneratorHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GeneratorHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GeneratorHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GeneratorHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<Uint8List> encryptedValue = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int> entropyBits = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GeneratorHistoryCompanion(
                id: id,
                encryptedValue: encryptedValue,
                mode: mode,
                entropyBits: entropyBits,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required Uint8List encryptedValue,
                Value<String> mode = const Value.absent(),
                Value<int> entropyBits = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => GeneratorHistoryCompanion.insert(
                id: id,
                encryptedValue: encryptedValue,
                mode: mode,
                entropyBits: entropyBits,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GeneratorHistoryTable, GeneratorHistoryRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $GeneratorHistoryTable,
                    GeneratorHistoryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GeneratorHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GeneratorHistoryTable,
      GeneratorHistoryRow,
      $$GeneratorHistoryTableFilterComposer,
      $$GeneratorHistoryTableOrderingComposer,
      $$GeneratorHistoryTableAnnotationComposer,
      $$GeneratorHistoryTableCreateCompanionBuilder,
      $$GeneratorHistoryTableUpdateCompanionBuilder,
      (
        GeneratorHistoryRow,
        BaseReferences<
          _$AppDatabase,
          $GeneratorHistoryTable,
          GeneratorHistoryRow
        >,
      ),
      GeneratorHistoryRow,
      PrefetchHooks Function()
    >;
typedef $$FoldersTableCreateCompanionBuilder =
    FoldersCompanion Function({
      required String id,
      required String module,
      required String name,
      Value<String?> colorHex,
      Value<String?> iconKey,
      Value<double> sortOrder,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$FoldersTableUpdateCompanionBuilder =
    FoldersCompanion Function({
      Value<String> id,
      Value<String> module,
      Value<String> name,
      Value<String?> colorHex,
      Value<String?> iconKey,
      Value<double> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$FoldersTableFilterComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get module =>
      $composableBuilder(column: $table.module, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<double> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$FoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoldersTable,
          FolderRow,
          $$FoldersTableFilterComposer,
          $$FoldersTableOrderingComposer,
          $$FoldersTableAnnotationComposer,
          $$FoldersTableCreateCompanionBuilder,
          $$FoldersTableUpdateCompanionBuilder,
          (FolderRow, BaseReferences<_$AppDatabase, $FoldersTable, FolderRow>),
          FolderRow,
          PrefetchHooks Function()
        > {
  $$FoldersTableTableManager(_$AppDatabase db, $FoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> module = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<String?> iconKey = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion(
                id: id,
                module: module,
                name: name,
                colorHex: colorHex,
                iconKey: iconKey,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String module,
                required String name,
                Value<String?> colorHex = const Value.absent(),
                Value<String?> iconKey = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion.insert(
                id: id,
                module: module,
                name: name,
                colorHex: colorHex,
                iconKey: iconKey,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FoldersTable, FolderRow>(table),
                  BaseReferences<_$AppDatabase, $FoldersTable, FolderRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoldersTable,
      FolderRow,
      $$FoldersTableFilterComposer,
      $$FoldersTableOrderingComposer,
      $$FoldersTableAnnotationComposer,
      $$FoldersTableCreateCompanionBuilder,
      $$FoldersTableUpdateCompanionBuilder,
      (FolderRow, BaseReferences<_$AppDatabase, $FoldersTable, FolderRow>),
      FolderRow,
      PrefetchHooks Function()
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      required String id,
      required String name,
      Value<String?> colorHex,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> colorHex,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          TagRow,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (TagRow, BaseReferences<_$AppDatabase, $TagsTable, TagRow>),
          TagRow,
          PrefetchHooks Function()
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                colorHex: colorHex,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> colorHex = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                colorHex: colorHex,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagsTable, TagRow>(table),
                  BaseReferences<_$AppDatabase, $TagsTable, TagRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      TagRow,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (TagRow, BaseReferences<_$AppDatabase, $TagsTable, TagRow>),
      TagRow,
      PrefetchHooks Function()
    >;
typedef $$ItemTagsTableCreateCompanionBuilder =
    ItemTagsCompanion Function({
      required String itemId,
      required String itemType,
      required String tagId,
      Value<int> rowid,
    });
typedef $$ItemTagsTableUpdateCompanionBuilder =
    ItemTagsCompanion Function({
      Value<String> itemId,
      Value<String> itemType,
      Value<String> tagId,
      Value<int> rowid,
    });

class $$ItemTagsTableFilterComposer
    extends Composer<_$AppDatabase, $ItemTagsTable> {
  $$ItemTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ItemTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemTagsTable> {
  $$ItemTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ItemTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemTagsTable> {
  $$ItemTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);
}

class $$ItemTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemTagsTable,
          ItemTagRow,
          $$ItemTagsTableFilterComposer,
          $$ItemTagsTableOrderingComposer,
          $$ItemTagsTableAnnotationComposer,
          $$ItemTagsTableCreateCompanionBuilder,
          $$ItemTagsTableUpdateCompanionBuilder,
          (
            ItemTagRow,
            BaseReferences<_$AppDatabase, $ItemTagsTable, ItemTagRow>,
          ),
          ItemTagRow,
          PrefetchHooks Function()
        > {
  $$ItemTagsTableTableManager(_$AppDatabase db, $ItemTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<String> itemType = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemTagsCompanion(
                itemId: itemId,
                itemType: itemType,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                required String itemType,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => ItemTagsCompanion.insert(
                itemId: itemId,
                itemType: itemType,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ItemTagsTable, ItemTagRow>(table),
                  BaseReferences<_$AppDatabase, $ItemTagsTable, ItemTagRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ItemTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemTagsTable,
      ItemTagRow,
      $$ItemTagsTableFilterComposer,
      $$ItemTagsTableOrderingComposer,
      $$ItemTagsTableAnnotationComposer,
      $$ItemTagsTableCreateCompanionBuilder,
      $$ItemTagsTableUpdateCompanionBuilder,
      (ItemTagRow, BaseReferences<_$AppDatabase, $ItemTagsTable, ItemTagRow>),
      ItemTagRow,
      PrefetchHooks Function()
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      required String id,
      required String itemId,
      required String itemType,
      required String fileName,
      Value<String> mimeType,
      Value<int> sizeBytes,
      required String localPath,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<String> id,
      Value<String> itemId,
      Value<String> itemType,
      Value<String> fileName,
      Value<String> mimeType,
      Value<int> sizeBytes,
      Value<String> localPath,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$AttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentsTable,
          AttachmentRow,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (
            AttachmentRow,
            BaseReferences<_$AppDatabase, $AttachmentsTable, AttachmentRow>,
          ),
          AttachmentRow,
          PrefetchHooks Function()
        > {
  $$AttachmentsTableTableManager(_$AppDatabase db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> itemType = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                itemId: itemId,
                itemType: itemType,
                fileName: fileName,
                mimeType: mimeType,
                sizeBytes: sizeBytes,
                localPath: localPath,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String itemId,
                required String itemType,
                required String fileName,
                Value<String> mimeType = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                required String localPath,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                id: id,
                itemId: itemId,
                itemType: itemType,
                fileName: fileName,
                mimeType: mimeType,
                sizeBytes: sizeBytes,
                localPath: localPath,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttachmentsTable, AttachmentRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AttachmentsTable,
                    AttachmentRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentsTable,
      AttachmentRow,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (
        AttachmentRow,
        BaseReferences<_$AppDatabase, $AttachmentsTable, AttachmentRow>,
      ),
      AttachmentRow,
      PrefetchHooks Function()
    >;
typedef $$InboxEntriesTableCreateCompanionBuilder =
    InboxEntriesCompanion Function({
      required String id,
      required String kind,
      required String title,
      Value<String> body,
      Value<String?> itemId,
      Value<String?> itemType,
      Value<String> actionsJson,
      required DateTime createdAt,
      Value<DateTime?> readAt,
      Value<DateTime?> dismissedAt,
      Value<int> rowid,
    });
typedef $$InboxEntriesTableUpdateCompanionBuilder =
    InboxEntriesCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> title,
      Value<String> body,
      Value<String?> itemId,
      Value<String?> itemType,
      Value<String> actionsJson,
      Value<DateTime> createdAt,
      Value<DateTime?> readAt,
      Value<DateTime?> dismissedAt,
      Value<int> rowid,
    });

class $$InboxEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $InboxEntriesTable> {
  $$InboxEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actionsJson => $composableBuilder(
    column: $table.actionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InboxEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $InboxEntriesTable> {
  $$InboxEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionsJson => $composableBuilder(
    column: $table.actionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InboxEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InboxEntriesTable> {
  $$InboxEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<String> get actionsJson => $composableBuilder(
    column: $table.actionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<DateTime> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => column,
  );
}

class $$InboxEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InboxEntriesTable,
          InboxRow,
          $$InboxEntriesTableFilterComposer,
          $$InboxEntriesTableOrderingComposer,
          $$InboxEntriesTableAnnotationComposer,
          $$InboxEntriesTableCreateCompanionBuilder,
          $$InboxEntriesTableUpdateCompanionBuilder,
          (
            InboxRow,
            BaseReferences<_$AppDatabase, $InboxEntriesTable, InboxRow>,
          ),
          InboxRow,
          PrefetchHooks Function()
        > {
  $$InboxEntriesTableTableManager(_$AppDatabase db, $InboxEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InboxEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InboxEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InboxEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String?> itemType = const Value.absent(),
                Value<String> actionsJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> readAt = const Value.absent(),
                Value<DateTime?> dismissedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InboxEntriesCompanion(
                id: id,
                kind: kind,
                title: title,
                body: body,
                itemId: itemId,
                itemType: itemType,
                actionsJson: actionsJson,
                createdAt: createdAt,
                readAt: readAt,
                dismissedAt: dismissedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String title,
                Value<String> body = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String?> itemType = const Value.absent(),
                Value<String> actionsJson = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> readAt = const Value.absent(),
                Value<DateTime?> dismissedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InboxEntriesCompanion.insert(
                id: id,
                kind: kind,
                title: title,
                body: body,
                itemId: itemId,
                itemType: itemType,
                actionsJson: actionsJson,
                createdAt: createdAt,
                readAt: readAt,
                dismissedAt: dismissedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InboxEntriesTable, InboxRow>(table),
                  BaseReferences<_$AppDatabase, $InboxEntriesTable, InboxRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InboxEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InboxEntriesTable,
      InboxRow,
      $$InboxEntriesTableFilterComposer,
      $$InboxEntriesTableOrderingComposer,
      $$InboxEntriesTableAnnotationComposer,
      $$InboxEntriesTableCreateCompanionBuilder,
      $$InboxEntriesTableUpdateCompanionBuilder,
      (InboxRow, BaseReferences<_$AppDatabase, $InboxEntriesTable, InboxRow>),
      InboxRow,
      PrefetchHooks Function()
    >;
typedef $$FocusSessionsTableCreateCompanionBuilder =
    FocusSessionsCompanion Function({
      required String id,
      Value<String?> taskId,
      required DateTime startedAt,
      required int durationMinutes,
      Value<int> rowid,
    });
typedef $$FocusSessionsTableUpdateCompanionBuilder =
    FocusSessionsCompanion Function({
      Value<String> id,
      Value<String?> taskId,
      Value<DateTime> startedAt,
      Value<int> durationMinutes,
      Value<int> rowid,
    });

class $$FocusSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FocusSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FocusSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => column,
  );
}

class $$FocusSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FocusSessionsTable,
          FocusSessionRow,
          $$FocusSessionsTableFilterComposer,
          $$FocusSessionsTableOrderingComposer,
          $$FocusSessionsTableAnnotationComposer,
          $$FocusSessionsTableCreateCompanionBuilder,
          $$FocusSessionsTableUpdateCompanionBuilder,
          (
            FocusSessionRow,
            BaseReferences<_$AppDatabase, $FocusSessionsTable, FocusSessionRow>,
          ),
          FocusSessionRow,
          PrefetchHooks Function()
        > {
  $$FocusSessionsTableTableManager(_$AppDatabase db, $FocusSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FocusSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FocusSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FocusSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FocusSessionsCompanion(
                id: id,
                taskId: taskId,
                startedAt: startedAt,
                durationMinutes: durationMinutes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> taskId = const Value.absent(),
                required DateTime startedAt,
                required int durationMinutes,
                Value<int> rowid = const Value.absent(),
              }) => FocusSessionsCompanion.insert(
                id: id,
                taskId: taskId,
                startedAt: startedAt,
                durationMinutes: durationMinutes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FocusSessionsTable, FocusSessionRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $FocusSessionsTable,
                    FocusSessionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FocusSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FocusSessionsTable,
      FocusSessionRow,
      $$FocusSessionsTableFilterComposer,
      $$FocusSessionsTableOrderingComposer,
      $$FocusSessionsTableAnnotationComposer,
      $$FocusSessionsTableCreateCompanionBuilder,
      $$FocusSessionsTableUpdateCompanionBuilder,
      (
        FocusSessionRow,
        BaseReferences<_$AppDatabase, $FocusSessionsTable, FocusSessionRow>,
      ),
      FocusSessionRow,
      PrefetchHooks Function()
    >;
typedef $$BackupRecordsTableCreateCompanionBuilder =
    BackupRecordsCompanion Function({
      required String id,
      required String location,
      required DateTime createdAt,
      Value<int> sizeBytes,
      Value<int> itemCount,
      Value<bool> isAuto,
      Value<bool> isEncrypted,
      Value<String?> driveFileId,
      Value<String?> localPath,
      Value<int> rowid,
    });
typedef $$BackupRecordsTableUpdateCompanionBuilder =
    BackupRecordsCompanion Function({
      Value<String> id,
      Value<String> location,
      Value<DateTime> createdAt,
      Value<int> sizeBytes,
      Value<int> itemCount,
      Value<bool> isAuto,
      Value<bool> isEncrypted,
      Value<String?> driveFileId,
      Value<String?> localPath,
      Value<int> rowid,
    });

class $$BackupRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $BackupRecordsTable> {
  $$BackupRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAuto => $composableBuilder(
    column: $table.isAuto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEncrypted => $composableBuilder(
    column: $table.isEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get driveFileId => $composableBuilder(
    column: $table.driveFileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BackupRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $BackupRecordsTable> {
  $$BackupRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAuto => $composableBuilder(
    column: $table.isAuto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEncrypted => $composableBuilder(
    column: $table.isEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get driveFileId => $composableBuilder(
    column: $table.driveFileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BackupRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BackupRecordsTable> {
  $$BackupRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get itemCount =>
      $composableBuilder(column: $table.itemCount, builder: (column) => column);

  GeneratedColumn<bool> get isAuto =>
      $composableBuilder(column: $table.isAuto, builder: (column) => column);

  GeneratedColumn<bool> get isEncrypted => $composableBuilder(
    column: $table.isEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get driveFileId => $composableBuilder(
    column: $table.driveFileId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);
}

class $$BackupRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BackupRecordsTable,
          BackupRecordRow,
          $$BackupRecordsTableFilterComposer,
          $$BackupRecordsTableOrderingComposer,
          $$BackupRecordsTableAnnotationComposer,
          $$BackupRecordsTableCreateCompanionBuilder,
          $$BackupRecordsTableUpdateCompanionBuilder,
          (
            BackupRecordRow,
            BaseReferences<_$AppDatabase, $BackupRecordsTable, BackupRecordRow>,
          ),
          BackupRecordRow,
          PrefetchHooks Function()
        > {
  $$BackupRecordsTableTableManager(_$AppDatabase db, $BackupRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BackupRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BackupRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BackupRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> itemCount = const Value.absent(),
                Value<bool> isAuto = const Value.absent(),
                Value<bool> isEncrypted = const Value.absent(),
                Value<String?> driveFileId = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BackupRecordsCompanion(
                id: id,
                location: location,
                createdAt: createdAt,
                sizeBytes: sizeBytes,
                itemCount: itemCount,
                isAuto: isAuto,
                isEncrypted: isEncrypted,
                driveFileId: driveFileId,
                localPath: localPath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String location,
                required DateTime createdAt,
                Value<int> sizeBytes = const Value.absent(),
                Value<int> itemCount = const Value.absent(),
                Value<bool> isAuto = const Value.absent(),
                Value<bool> isEncrypted = const Value.absent(),
                Value<String?> driveFileId = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BackupRecordsCompanion.insert(
                id: id,
                location: location,
                createdAt: createdAt,
                sizeBytes: sizeBytes,
                itemCount: itemCount,
                isAuto: isAuto,
                isEncrypted: isEncrypted,
                driveFileId: driveFileId,
                localPath: localPath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BackupRecordsTable, BackupRecordRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $BackupRecordsTable,
                    BackupRecordRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BackupRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BackupRecordsTable,
      BackupRecordRow,
      $$BackupRecordsTableFilterComposer,
      $$BackupRecordsTableOrderingComposer,
      $$BackupRecordsTableAnnotationComposer,
      $$BackupRecordsTableCreateCompanionBuilder,
      $$BackupRecordsTableUpdateCompanionBuilder,
      (
        BackupRecordRow,
        BaseReferences<_$AppDatabase, $BackupRecordsTable, BackupRecordRow>,
      ),
      BackupRecordRow,
      PrefetchHooks Function()
    >;
typedef $$TombstonesTableCreateCompanionBuilder =
    TombstonesCompanion Function({
      required String entity,
      required String entityId,
      required DateTime deletedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });
typedef $$TombstonesTableUpdateCompanionBuilder =
    TombstonesCompanion Function({
      Value<String> entity,
      Value<String> entityId,
      Value<DateTime> deletedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$TombstonesTableFilterComposer
    extends Composer<_$AppDatabase, $TombstonesTable> {
  $$TombstonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TombstonesTableOrderingComposer
    extends Composer<_$AppDatabase, $TombstonesTable> {
  $$TombstonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TombstonesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TombstonesTable> {
  $$TombstonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$TombstonesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TombstonesTable,
          TombstoneRow,
          $$TombstonesTableFilterComposer,
          $$TombstonesTableOrderingComposer,
          $$TombstonesTableAnnotationComposer,
          $$TombstonesTableCreateCompanionBuilder,
          $$TombstonesTableUpdateCompanionBuilder,
          (
            TombstoneRow,
            BaseReferences<_$AppDatabase, $TombstonesTable, TombstoneRow>,
          ),
          TombstoneRow,
          PrefetchHooks Function()
        > {
  $$TombstonesTableTableManager(_$AppDatabase db, $TombstonesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TombstonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TombstonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TombstonesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entity = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<DateTime> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TombstonesCompanion(
                entity: entity,
                entityId: entityId,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entity,
                required String entityId,
                required DateTime deletedAt,
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TombstonesCompanion.insert(
                entity: entity,
                entityId: entityId,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TombstonesTable, TombstoneRow>(table),
                  BaseReferences<_$AppDatabase, $TombstonesTable, TombstoneRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TombstonesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TombstonesTable,
      TombstoneRow,
      $$TombstonesTableFilterComposer,
      $$TombstonesTableOrderingComposer,
      $$TombstonesTableAnnotationComposer,
      $$TombstonesTableCreateCompanionBuilder,
      $$TombstonesTableUpdateCompanionBuilder,
      (
        TombstoneRow,
        BaseReferences<_$AppDatabase, $TombstonesTable, TombstoneRow>,
      ),
      TombstoneRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$SubtasksTableTableManager get subtasks =>
      $$SubtasksTableTableManager(_db, _db.subtasks);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
  $$HabitsTableTableManager get habits =>
      $$HabitsTableTableManager(_db, _db.habits);
  $$HabitLogsTableTableManager get habitLogs =>
      $$HabitLogsTableTableManager(_db, _db.habitLogs);
  $$VaultItemsTableTableManager get vaultItems =>
      $$VaultItemsTableTableManager(_db, _db.vaultItems);
  $$VaultHistoryTableTableManager get vaultHistory =>
      $$VaultHistoryTableTableManager(_db, _db.vaultHistory);
  $$GeneratorHistoryTableTableManager get generatorHistory =>
      $$GeneratorHistoryTableTableManager(_db, _db.generatorHistory);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$ItemTagsTableTableManager get itemTags =>
      $$ItemTagsTableTableManager(_db, _db.itemTags);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
  $$InboxEntriesTableTableManager get inboxEntries =>
      $$InboxEntriesTableTableManager(_db, _db.inboxEntries);
  $$FocusSessionsTableTableManager get focusSessions =>
      $$FocusSessionsTableTableManager(_db, _db.focusSessions);
  $$BackupRecordsTableTableManager get backupRecords =>
      $$BackupRecordsTableTableManager(_db, _db.backupRecords);
  $$TombstonesTableTableManager get tombstones =>
      $$TombstonesTableTableManager(_db, _db.tombstones);
}
