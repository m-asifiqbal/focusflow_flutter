/// The prayers repository against a real (encrypted, temp-file) database:
/// save / update keeps pin & pause, rules round-trip (auto + fixed + no
/// end), logs are one row per day (mark, re-mark, restore to "not
/// marked"), dhikr counts reach their goal and back, snooze, setup's
/// addAll in order, and permanent delete removes the logs too.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/repository/prayers_repository.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  final now = DateTime(2026, 10, 23, 15, 50);
  final day = DateTime(2026, 10, 23);

  Prayer draft({String name = 'Asr', PrayerKind kind = PrayerKind.salah}) =>
      Prayer(
        id: '',
        name: name,
        kind: kind,
        tradition: PrayerTradition.islam,
        start: const PrayerTimeRule.auto(
          SolarEvent.asr,
          offset: 5,
          minutes: 945,
        ),
        end: const PrayerTimeRule.fixed(17 * 60 + 45),
        weekdaysMask: 0x1F,
        priority: PrayerPriority.high,
        remindBefore: 10,
        remindBeforeEnd: 20,
        place: 'Mosque',
        colorHex: '10B981',
        targetCount: kind == PrayerKind.dhikr ? 3 : null,
        createdAt: now,
        updatedAt: now,
      );

  test('save round-trips every field; update keeps pause', () async {
    final h = await TestHarness.create(now: now);
    addTearDown(h.dispose);
    final repo = h.read(prayersRepositoryProvider);
    final id = await repo.save(draft());
    final p = (await repo.getPrayer(id))!;
    expect(p.name, 'Asr');
    expect(p.kind, PrayerKind.salah);
    expect(p.tradition, PrayerTradition.islam);
    expect(
      p.start,
      const PrayerTimeRule.auto(SolarEvent.asr, offset: 5, minutes: 945),
    );
    expect(p.end, const PrayerTimeRule.fixed(17 * 60 + 45));
    expect(p.weekdaysMask, 0x1F);
    expect(p.priority, PrayerPriority.high);
    expect((p.remindBefore, p.remindBeforeEnd), (10, 20));
    expect(p.place, 'Mosque');
    await repo.setPaused(id, true);
    await repo.save(p.copyWith(name: 'Asr prayer', clearEnd: true));
    final again = (await repo.getPrayer(id))!;
    expect(again.name, 'Asr prayer');
    expect(again.end, isNull);
    expect(again.isPaused, isTrue);
    expect(await repo.schedulable(), isEmpty);
  });

  test('one log per day: mark, re-mark, restore to not marked', () async {
    final h = await TestHarness.create(now: now);
    addTearDown(h.dispose);
    final repo = h.read(prayersRepositoryProvider);
    final id = await repo.save(draft());
    await repo.mark(id, day, PrayerStatus.onTime, place: 'Home');
    var log = (await repo.log(id, day))!;
    expect(log.status, PrayerStatus.onTime);
    expect(log.place, 'Home');
    await repo.mark(id, day, PrayerStatus.madeUp, congregation: true);
    log = (await repo.log(id, day))!;
    expect(log.status, PrayerStatus.madeUp);
    expect(log.place, 'Home');
    expect(log.congregation, isTrue);
    final logs = await repo.logsBetween(day, day);
    expect(logs, hasLength(1));
    expect(logs.single.id, PrayerLog.idFor(id, '2026-10-23'));
    await repo.restoreLog(id, day, null);
    expect(await repo.log(id, day), isNull);
    await repo.restoreLog(id, day, log);
    expect((await repo.log(id, day))!.status, PrayerStatus.madeUp);
  });

  test('a tally reaches its goal (done) and drops back (not done)', () async {
    final h = await TestHarness.create(now: now);
    addTearDown(h.dispose);
    final repo = h.read(prayersRepositoryProvider);
    final id = await repo.save(draft(name: 'Dhikr', kind: PrayerKind.dhikr));
    for (var i = 0; i < 3; i++) {
      await repo.addCount(id, day, 1, target: 3);
    }
    expect((await repo.log(id, day))!.status, PrayerStatus.onTime);
    expect(await repo.addCount(id, day, -1, target: 3), 2);
    expect((await repo.log(id, day))!.status, PrayerStatus.pending);
    expect(await repo.addCount(id, day, -5, target: 3), 0);
    expect(await repo.log(id, day), isNull);
  });

  test('snooze keeps the day pending until the given time', () async {
    final h = await TestHarness.create(now: now);
    addTearDown(h.dispose);
    final repo = h.read(prayersRepositoryProvider);
    final id = await repo.save(draft());
    await repo.snooze(id, day, DateTime(2026, 10, 23, 16));
    final log = (await repo.log(id, day))!;
    expect(log.status, PrayerStatus.pending);
    expect(log.snoozedUntil, DateTime(2026, 10, 23, 16));
  });

  test('setup adds in order; delete forever removes the logs', () async {
    final h = await TestHarness.create(now: now);
    addTearDown(h.dispose);
    final repo = h.read(prayersRepositoryProvider);
    final ids = await repo.addAll([
      draft(name: 'Fajr'),
      draft(name: 'Dhuhr'),
      draft(name: 'Asr'),
    ]);
    final list = await repo.watchPrayers(PrayersScope.active).first;
    expect(list.map((p) => p.name), ['Fajr', 'Dhuhr', 'Asr']);
    await repo.mark(ids.first, day, PrayerStatus.onTime);
    final items = h.read(itemsRepositoryProvider);
    final ref = ItemRef(ItemType.prayer, ids.first);
    await items.moveToTrash([ref]);
    await items.deleteForever([ref]);
    expect(await repo.getPrayer(ids.first), isNull);
    expect(await repo.logsBetween(day, day), isEmpty);
  });
}
