/// Recently Deleted purge (screen 24 acceptance): items deleted more than
/// 30 days ago are removed for good; younger ones and archived items stay.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/test_container.dart';
import 'archive_fixtures.dart';

void main() {
  test('purgeExpired removes only items deleted over 30 days ago', () async {
    final h = await TestHarness.create(now: kArchiveNow);
    addTearDown(h.dispose);
    final items = h.read(itemsRepositoryProvider);
    await seedArchive(h); // 2 archived + "Random thoughts" deleted now.

    h.clock.advance(const Duration(days: 29));
    expect(await items.purgeExpired(), 0);
    expect((await items.watchTrash().first).length, 1);

    h.clock.advance(const Duration(days: 2));
    expect(await items.purgeExpired(), 1);
    expect(await items.watchTrash().first, isEmpty);
    expect((await items.watchArchived().first).length, 2);
  });
}
