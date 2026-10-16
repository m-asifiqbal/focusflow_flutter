/// ============================================================
/// STREAM UTILS — combineLatest without rxdart
/// ============================================================
///
/// Used where one screen-level value is derived from several repository
/// streams (e.g. Library counts = SQL counts + reminders + habits).
/// ============================================================
library;

import 'dart:async';

/// Emits [combine] of the latest value of every stream once each has
/// emitted at least once, then on every new value. Errors are forwarded;
/// the result closes when all sources are done.
Stream<R> combineLatestList<R>(
  List<Stream<Object?>> streams,
  R Function(List<Object?> values) combine,
) {
  final subs = <StreamSubscription<Object?>>[];
  late final StreamController<R> controller;
  controller = StreamController<R>(
    onListen: () {
      final values = List<Object?>.filled(streams.length, null);
      final seen = List<bool>.filled(streams.length, false);
      var waiting = streams.length;
      var done = 0;
      for (var i = 0; i < streams.length; i++) {
        subs.add(
          streams[i].listen(
            (v) {
              values[i] = v;
              if (!seen[i]) {
                seen[i] = true;
                waiting--;
              }
              if (waiting == 0) {
                try {
                  controller.add(combine(List.unmodifiable(values)));
                } catch (e, s) {
                  controller.addError(e, s);
                }
              }
            },
            onError: controller.addError,
            onDone: () {
              if (++done == streams.length) controller.close();
            },
          ),
        );
      }
      if (streams.isEmpty) controller.close();
    },
    onPause: () {
      for (final s in subs) {
        s.pause();
      }
    },
    onResume: () {
      for (final s in subs) {
        s.resume();
      }
    },
    onCancel: () => Future.wait(subs.map((s) => s.cancel())),
  );
  return controller.stream;
}

/// Typed two-stream variant of [combineLatestList].
Stream<R> combineLatest2<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A a, B b) combine,
) => combineLatestList([a, b], (v) => combine(v[0] as A, v[1] as B));

/// Typed three-stream variant of [combineLatestList].
Stream<R> combineLatest3<A, B, C, R>(
  Stream<A> a,
  Stream<B> b,
  Stream<C> c,
  R Function(A a, B b, C c) combine,
) => combineLatestList([
  a,
  b,
  c,
], (v) => combine(v[0] as A, v[1] as B, v[2] as C));
