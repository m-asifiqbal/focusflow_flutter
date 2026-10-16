/// Recent searches: the list rules (newest first, case-insensitive dedupe,
/// max 10), secure-store persistence, graceful storage failures, and the
/// one-time migration out of plaintext settings.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/storage/secure_store.dart';
import 'package:focusflow/features/search/data/datasource/recent_searches_store.dart';
import 'package:focusflow/features/search/presentation/providers/search_providers.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../core/sync/drive_fakes.dart' show MemorySecureStore;
import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';

/// A Keychain that is unavailable (locked device, no plugin).
class _BrokenSecureStore extends SecureStore {
  @override
  Future<String?> read(String key) async => throw StateError('locked');

  @override
  Future<void> write(String key, String value) async =>
      throw StateError('locked');

  @override
  Future<void> delete(String key) async => throw StateError('locked');
}

void main() {
  const key = RecentSearchesStore.storageKey;

  group('list rules', () {
    test('push: newest first, trimmed, case-insensitive dedupe', () {
      var list = RecentSearchesStore.push(const [], ' design ');
      list = RecentSearchesStore.push(list, 'groceries');
      list = RecentSearchesStore.push(list, 'Design');
      expect(list, ['Design', 'groceries']);
      expect(RecentSearchesStore.push(list, '   '), list);
    });

    test('keeps at most 10', () {
      var list = <String>[];
      for (var i = 0; i < 15; i++) {
        list = RecentSearchesStore.push(list, 'term $i');
      }
      expect(list, hasLength(RecentSearchesStore.max));
      expect(list.first, 'term 14');
      expect(list.last, 'term 5');
    });

    test('merge: newer first, older fills the rest', () {
      expect(RecentSearchesStore.merge(['a', 'b'], ['B', 'c']), [
        'a',
        'b',
        'c',
      ]);
    });
  });

  group('persistence', () {
    test('round-trips through the secure store as JSON', () async {
      final secure = MemorySecureStore();
      final store = RecentSearchesStore(secure);
      expect(await store.read(), isEmpty);
      expect(await store.write(['netflix', 'Q3']), isTrue);
      expect(secure.values[key], '["netflix","Q3"]');
      expect(await store.read(), ['netflix', 'Q3']);
      expect(await store.clear(), isTrue);
      expect(secure.values.containsKey(key), isFalse);
    });

    test(
      'corrupt or unavailable storage reads as empty, writes fail',
      () async {
        expect(
          await RecentSearchesStore(MemorySecureStore({key: '{oops'})).read(),
          isEmpty,
        );
        final broken = RecentSearchesStore(_BrokenSecureStore());
        expect(await broken.read(), isEmpty);
        expect(await broken.write(['x']), isFalse);
      },
    );
  });

  group('controller + migration', () {
    late TestHarness h;
    late MemorySecureStore secure;

    Future<void> boot({SecureStore? store}) async {
      secure = MemorySecureStore();
      h = await TestHarness.create(
        now: DateTime(2026, 6, 10, 9),
        overrides: [secureStoreProvider.overrideWithValue(store ?? secure)],
      );
      addTearDown(h.dispose);
    }

    test('plaintext settings terms move to the secure store once', () async {
      await boot();
      secure.values[key] = '["kiwi"]';
      await h.updateSettings(
        (s) => s.copyWith(recentSearches: const ['groceries', 'KIWI', 'tax']),
      );
      final list = await h.read(recentSearchesProvider.future);
      expect(list, ['kiwi', 'groceries', 'tax']);
      expect(secure.values[key], '["kiwi","groceries","tax"]');
      expect(h.read(settingsProvider).recentSearches, isEmpty);
    });

    test('add / clear persist to the secure store only', () async {
      await boot();
      final notifier = h.read(recentSearchesProvider.notifier);
      await notifier.add('design');
      await notifier.add('mobile');
      expect(h.read(recentSearchesProvider).value, ['mobile', 'design']);
      expect(secure.values[key], '["mobile","design"]');
      expect(h.read(settingsProvider).recentSearches, isEmpty);
      await notifier.clear();
      expect(h.read(recentSearchesProvider).value, isEmpty);
      expect(secure.values.containsKey(key), isFalse);
    });

    test('secure store unavailable: legacy terms kept, list works', () async {
      await boot(store: _BrokenSecureStore());
      await h.updateSettings(
        (s) => s.copyWith(recentSearches: const ['groceries']),
      );
      expect(await h.read(recentSearchesProvider.future), ['groceries']);
      // Not cleared: the copy is the only one until the Keychain works.
      expect(h.read(settingsProvider).recentSearches, ['groceries']);
      await h.read(recentSearchesProvider.notifier).add('tax');
      expect(h.read(recentSearchesProvider).value, ['tax', 'groceries']);
    });
  });
}
