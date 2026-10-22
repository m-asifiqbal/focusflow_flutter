/// ============================================================
/// ARGON2 RUNNER — one safe way to run Argon2id (vault PIN + backup PIN)
/// ============================================================
///
/// What: [Argon2Runner.derive] computes Argon2id for every PIN in the app
/// (the vault key wrap, the encrypted-backup key, a note's PIN). It
///   * validates the cost first ([Argon2Runner.accept]) — parameters come
///     from a key bundle or a backup *file*, so a damaged or crafted one
///     must never ask for gigabytes or hundreds of passes;
///   * runs the whole computation in ONE dedicated, short-lived isolate,
///     single threaded, in ordinary Dart memory;
///   * gives up after a time limit (the isolate is killed, its memory goes
///     with it) and reports every failure as an [Argon2Failure].
/// Tiny derivations (tests, a few KiB) run inline: an isolate costs more
/// than they do.
///
/// Why not just `Argon2id(...)` / `DartArgon2id(...)` from package:cryptography?
/// Its default pure-Dart implementation spawns its own worker isolates that
/// share a native `malloc` buffer, waits for each segment with a hard 10 s
/// timeout, and frees that buffer immediately when a computation throws —
/// while a worker may still be writing into it. On a phone that is slower
/// or more memory-starved than the one the parameters were chosen on (a
/// restored backup brings the OLD phone's parameters) that is exactly the
/// "PIN keeps verifying … then the app crashes" failure: the timeout throws,
/// nothing catches it, and the freed buffer is written to afterwards.
/// Argon2id with one lane needs no worker isolates at all, so
/// `maxIsolates: 0` keeps everything inside the isolate we control.
/// ============================================================
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// Argon2 could not produce a key: unacceptable parameters, too slow for
/// the time limit, out of memory, or the worker died. Never a wrong PIN.
class Argon2Failure implements Exception {
  const Argon2Failure(this.reason);

  /// Short technical reason for logs (never a PIN, key or salt).
  final String reason;

  @override
  String toString() => 'Argon2Failure($reason)';
}

abstract final class Argon2Runner {
  /// Largest memory cost accepted: the app's strongest setting is 64 MiB.
  static const int maxMemoryKiB = 128 * 1024;

  /// Most passes accepted: the app's strongest setting is 3.
  static const int maxIterations = 6;

  /// Most lanes accepted (the app always uses 1).
  static const int maxParallelism = 4;

  /// Longest a single derivation may take. A phone that needs more than this
  /// for the stored cost cannot use that PIN setting at all.
  static const Duration defaultTimeout = Duration(seconds: 60);

  /// `memoryKiB × iterations` up to which a derivation runs inline (tests,
  /// toy parameters). The smallest real setting is 32 MiB · 2 = 65 536.
  static const int inlineBudget = 4096;

  /// Whether a cost is something this app would ever have written.
  static bool accept({
    required int memoryKiB,
    required int iterations,
    int parallelism = 1,
  }) =>
      parallelism >= 1 &&
      parallelism <= maxParallelism &&
      iterations >= 1 &&
      iterations <= maxIterations &&
      memoryKiB >= 8 * parallelism &&
      memoryKiB <= maxMemoryKiB;

  /// Argon2id([password], [salt]) → [hashLength] bytes.
  ///
  /// Throws [Argon2Failure] (see the class comment); a wrong PIN is NOT a
  /// failure — the caller finds that out when the derived key does not open
  /// its ciphertext. [inline] forces / forbids the isolate (default: by cost).
  static Future<Uint8List> derive({
    required List<int> password,
    required List<int> salt,
    required int memoryKiB,
    required int iterations,
    int parallelism = 1,
    int hashLength = 32,
    bool? inline,
    Duration timeout = defaultTimeout,
  }) async {
    if (!accept(
      memoryKiB: memoryKiB,
      iterations: iterations,
      parallelism: parallelism,
    )) {
      throw const Argon2Failure('parameters out of range');
    }
    final job = _Job(
      password: Uint8List.fromList(password),
      salt: Uint8List.fromList(salt),
      memoryKiB: memoryKiB,
      iterations: iterations,
      parallelism: parallelism,
      hashLength: hashLength,
    );
    final runInline = inline ?? memoryKiB * iterations <= inlineBudget;
    try {
      if (runInline) return await _compute(job, yieldToOthers: true);
      return await _inWorker(job, timeout);
    } on Argon2Failure {
      rethrow;
    } on Object catch (e) {
      throw Argon2Failure(e.runtimeType.toString());
    } finally {
      job.password.fillRange(0, job.password.length, 0);
    }
  }

  static Future<Uint8List> _compute(
    _Job job, {
    required bool yieldToOthers,
  }) async {
    final algo = DartArgon2id(
      parallelism: job.parallelism,
      memory: job.memoryKiB,
      iterations: job.iterations,
      hashLength: job.hashLength,
      // No worker isolates / shared native buffer (see the file header).
      maxIsolates: 0,
      // Alone in its isolate: never pause between blocks. Inline, keep the
      // package's default so the UI isolate is not starved.
      blocksPerProcessingChunk: yieldToOthers ? null : -1,
    );
    final key = await algo.deriveKey(
      secretKey: SecretKey(job.password),
      nonce: job.salt,
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  static Future<Uint8List> _inWorker(_Job job, Duration timeout) async {
    final result = ReceivePort();
    final errors = ReceivePort();
    final exited = ReceivePort();
    final done = Completer<Uint8List>();
    Isolate? worker;
    var closed = false;

    void fail(String reason) {
      if (!closed && !done.isCompleted) {
        done.completeError(Argon2Failure(reason));
      }
    }

    result.listen((Object? message) {
      if (closed || done.isCompleted) return;
      if (message is TransferableTypedData) {
        done.complete(message.materialize().asUint8List());
      } else {
        fail(message is String ? message : 'unexpected reply');
      }
    });
    errors.listen((Object? _) => fail('worker error'));
    // The worker answered with Isolate.exit (reply first, then this); give a
    // normal reply a moment to be handled before calling an exit a death.
    exited.listen((Object? _) {
      Timer(const Duration(milliseconds: 100), () => fail('worker stopped'));
    });

    try {
      worker = await Isolate.spawn<(_Job, SendPort)>(
        _entry,
        (job, result.sendPort),
        onError: errors.sendPort,
        onExit: exited.sendPort,
        errorsAreFatal: true,
      );
      return await done.future.timeout(
        timeout,
        onTimeout: () => throw const Argon2Failure('timed out'),
      );
    } finally {
      // Whatever happened, nothing of this derivation stays alive.
      closed = true;
      worker?.kill(priority: Isolate.immediate);
      result.close();
      errors.close();
      exited.close();
    }
  }

  static Future<void> _entry((_Job, SendPort) message) async {
    final (job, reply) = message;
    try {
      final bytes = await _compute(job, yieldToOthers: false);
      Isolate.exit(reply, TransferableTypedData.fromList([bytes]));
    } on Object catch (e) {
      Isolate.exit(reply, 'failed: ${e.runtimeType}');
    }
  }
}

/// Plain data for the worker isolate.
class _Job {
  const _Job({
    required this.password,
    required this.salt,
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
    required this.hashLength,
  });

  final Uint8List password;
  final Uint8List salt;
  final int memoryKiB;
  final int iterations;
  final int parallelism;
  final int hashLength;
}
