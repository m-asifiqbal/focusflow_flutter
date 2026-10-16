/// ============================================================
/// GOOGLE DRIVE STORE — DriveStore over googleapis (Drive v3, appDataFolder)
/// ============================================================
///
/// Every request carries a short-lived access token from google_sign_in
/// (never stored by us). A 401 drops that token and retries once with a
/// fresh one fetched silently ("token expired → re-auth silently"); if
/// that fails the caller gets [DriveFailureKind.authExpired] and the UI
/// asks the user to sign in again. Network errors → offline (also while
/// fetching a token); quota → full.
/// Every call has a deadline ([requestTimeout]; uploads get more time per
/// MB) so a dead connection can never leave "Sync now" spinning forever.
/// Files over [resumableThreshold] upload resumably (1 MB chunks, retried).
/// ============================================================
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:focusflow/core/sync/drive_store.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// Supplies Drive access tokens (see GoogleAuthGateway).
abstract interface class DriveTokenSource {
  /// A token, or null when none can be had without the user.
  Future<String?> token({bool interactive = false});

  /// Called with a token Drive rejected.
  Future<void> invalidate(String token);
}

class GoogleDriveStore implements DriveStore {
  GoogleDriveStore(
    this._tokens, {
    http.Client? httpClient,
    this.interactive = false,
    this.requestTimeout = const Duration(seconds: 45),
  }) : _http = httpClient ?? http.Client();

  final DriveTokenSource _tokens;
  final http.Client _http;

  /// Whether the first token request may show consent UI.
  final bool interactive;

  /// Deadline of one Drive call (and of a silent token fetch).
  final Duration requestTimeout;

  /// Uploads larger than this use Drive's resumable protocol.
  static const int resumableThreshold = 5 * 1024 * 1024;

  /// Deadline of an upload of [bytes]: [requestTimeout] plus time at a
  /// slow-but-alive 32 KB/s.
  Duration uploadTimeout(int bytes) =>
      requestTimeout + Duration(seconds: bytes ~/ (32 * 1024));

  static const String _space = 'appDataFolder';
  static const String _fileFields = 'id,name,createdTime,size,appProperties';
  static const int _chunk = 64 * 1024;

  Future<T> _call<T>(
    Future<T> Function(drive.DriveApi api) body, {
    Duration? timeout,
  }) async {
    for (var attempt = 0; ; attempt++) {
      final token = await _token(interactive: interactive && attempt == 0);
      final api = drive.DriveApi(_BearerClient(_http, token));
      try {
        return await body(api).timeout(timeout ?? requestTimeout);
      } on drive.DetailedApiRequestError catch (e) {
        if (e.status == 401 && attempt == 0) {
          await _tokens.invalidate(token);
          continue;
        }
        throw mapError(e);
      } on Object catch (e) {
        throw mapTransportError(e);
      }
    }
  }

  /// A token, with network trouble told apart from a revoked sign-in.
  Future<String> _token({required bool interactive}) async {
    final String? token;
    try {
      final pending = _tokens.token(interactive: interactive);
      // The consent sheet waits for the user; a silent fetch must not hang.
      token = interactive
          ? await pending
          : await pending.timeout(requestTimeout);
    } on Object catch (e) {
      throw mapTokenError(e);
    }
    if (token == null) {
      throw const DriveFailure(DriveFailureKind.authExpired, 'no token');
    }
    return token;
  }

  /// A failed token fetch → [DriveFailure]: socket / HTTP-client / timeout
  /// / "network" platform errors mean offline; anything else means the
  /// sign-in needs the user again. Public for tests.
  static DriveFailure mapTokenError(Object e) {
    if (e is DriveFailure) return e;
    if (_isNetwork(e)) {
      return DriveFailure(DriveFailureKind.offline, e.runtimeType.toString());
    }
    return DriveFailure(DriveFailureKind.authExpired, e.runtimeType.toString());
  }

  /// A non-HTTP-status failure of a Drive call → [DriveFailure].
  static DriveFailure mapTransportError(Object e) {
    if (e is DriveFailure) return e;
    if (_isNetwork(e)) {
      return DriveFailure(DriveFailureKind.offline, e.runtimeType.toString());
    }
    if (e is drive.ApiRequestError) {
      return DriveFailure(DriveFailureKind.unknown, e.message);
    }
    return DriveFailure(DriveFailureKind.unknown, e.runtimeType.toString());
  }

  static bool _isNetwork(Object e) {
    if (e is IOException || e is TimeoutException) return true;
    if (e is http.ClientException) return true;
    // google_sign_in surfaces network trouble as a platform / auth error
    // whose text names it ("network_error", "NETWORK_ERROR", code 7).
    final text = e.toString().toLowerCase();
    return text.contains('network') ||
        text.contains('timed out') ||
        text.contains('timeout') ||
        text.contains('offline') ||
        text.contains('unreachable') ||
        text.contains('internet');
  }

  /// HTTP error → [DriveFailure] (public for tests).
  static DriveFailure mapError(drive.DetailedApiRequestError e) {
    final reasons = e.errors.map((d) => d.reason ?? '').toSet();
    if (e.status == 401) {
      return const DriveFailure(DriveFailureKind.authExpired, '401');
    }
    if (reasons.contains('storageQuotaExceeded') ||
        reasons.contains('quotaExceeded') ||
        (e.message ?? '').toLowerCase().contains('storage quota')) {
      return DriveFailure(DriveFailureKind.quota, '${e.status}');
    }
    return DriveFailure(DriveFailureKind.unknown, '${e.status}');
  }

  static DriveFile _toFile(drive.File f) => DriveFile(
    id: f.id ?? '',
    name: f.name ?? '',
    createdAt: (f.createdTime ?? DateTime.fromMillisecondsSinceEpoch(0))
        .toLocal(),
    sizeBytes: int.tryParse(f.size ?? '') ?? 0,
    properties: {
      for (final e in (f.appProperties ?? const <String, String?>{}).entries)
        if (e.value != null) e.key: e.value!,
    },
  );

  @override
  Future<List<DriveFile>> list() => _call((api) async {
    final out = <DriveFile>[];
    String? page;
    do {
      final res = await api.files.list(
        spaces: _space,
        pageSize: 200,
        pageToken: page,
        orderBy: 'createdTime desc',
        $fields: 'nextPageToken,files($_fileFields)',
      );
      out.addAll((res.files ?? const []).map(_toFile));
      page = res.nextPageToken;
    } while (page != null);
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  });

  @override
  Future<DriveFile> upload(
    String name,
    Uint8List bytes, {
    Map<String, String> properties = const {},
    String mimeType = 'application/octet-stream',
    void Function(double progress)? onProgress,
  }) => _call((api) async {
    final meta = drive.File()
      ..name = name
      ..parents = [_space]
      ..mimeType = mimeType
      ..appProperties = properties;
    final created = await api.files.create(
      meta,
      uploadMedia: drive.Media(
        _chunks(bytes, onProgress),
        bytes.length,
        contentType: mimeType,
      ),
      uploadOptions: bytes.length > resumableThreshold
          ? drive.UploadOptions.resumable
          : drive.UploadOptions.defaultOptions,
      $fields: _fileFields,
    );
    onProgress?.call(1);
    return _toFile(created);
  }, timeout: uploadTimeout(bytes.length));

  @override
  Future<void> overwrite(String fileId, Uint8List bytes) => _call((api) async {
    await api.files.update(
      drive.File(),
      fileId,
      uploadMedia: drive.Media(_chunks(bytes, null), bytes.length),
    );
  }, timeout: uploadTimeout(bytes.length));

  @override
  Future<Uint8List> download(String fileId) => _call((api) async {
    final media =
        await api.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;
    final builder = BytesBuilder(copy: false);
    await media.stream.forEach(builder.add);
    return builder.takeBytes();
    // Size unknown up front: allow what a 16 MB upload would get.
  }, timeout: uploadTimeout(16 * 1024 * 1024));

  @override
  Future<void> delete(String fileId) => _call((api) async {
    try {
      await api.files.delete(fileId);
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status != 404) rethrow;
    }
  });

  @override
  Future<int?> storageLimit() => _call((api) async {
    final about = await api.about.get($fields: 'storageQuota(limit)');
    return int.tryParse(about.storageQuota?.limit ?? '');
  });

  /// [bytes] as a chunked stream, reporting how much has been handed to
  /// the HTTP request (Drive's upload progress, near enough).
  static Stream<List<int>> _chunks(
    Uint8List bytes,
    void Function(double progress)? onProgress,
  ) async* {
    if (bytes.isEmpty) return;
    for (var start = 0; start < bytes.length; start += _chunk) {
      final end = math.min(start + _chunk, bytes.length);
      yield Uint8List.sublistView(bytes, start, end);
      onProgress?.call(end / bytes.length * 0.95);
    }
  }
}

/// Adds `Authorization: Bearer …` to every request (token held in memory
/// only for this store's lifetime).
class _BearerClient extends http.BaseClient {
  _BearerClient(this._inner, this._token);

  final http.Client _inner;
  final String _token;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }
}
