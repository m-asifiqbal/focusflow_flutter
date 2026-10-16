/// Pure Archive / Trash logic: filter + sections + sort (ArchiveView) and
/// the row copy (ArchiveFormat), against the design/23 and design/24 data.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/archive/domain/archive_view.dart';
import 'package:focusflow/features/archive/presentation/archive_format.dart';

import 'archive_fixtures.dart';

void main() {
  List<String> titles(ArchiveView v) => [
    for (final s in v.items) s.displayTitle,
  ];

  test('counts every module; chip + search filter the rows', () {
    final v = ArchiveView.from(
      kMockupArchived,
      const ArchiveFilter(type: ItemType.task),
      kArchiveNow,
    );
    expect(v.total, 7);
    expect(v.counts[ItemType.note], 2);
    expect(v.counts[ItemType.vault], 1);
    expect(titles(v), ['Migrate to new CI pipeline', 'Q1 OKR review']);

    final q = ArchiveView.from(
      kMockupArchived,
      const ArchiveFilter(query: 'OLD'),
      kArchiveNow,
    );
    expect(q.total, 7);
    expect(titles(q), [
      'Old project brief — Fresh LPG relaunch',
      'Old Twitter account',
    ]);
  });

  test('groups by calendar month; sort orders rows and sections', () {
    final v = ArchiveView.from(
      kMockupArchived,
      const ArchiveFilter(),
      kArchiveNow,
    );
    expect(v.groups.map((g) => g.section), [
      ArchiveSection.thisMonth,
      ArchiveSection.earlier,
    ]);
    expect(v.groups.first.items.single.displayTitle, startsWith('Old project'));

    final oldest = ArchiveView.from(
      kMockupArchived,
      const ArchiveFilter(sort: ArchiveSort.oldest),
      kArchiveNow,
    );
    expect(oldest.groups.first.section, ArchiveSection.earlier);
    expect(oldest.items.first.displayTitle, 'Q1 OKR review');

    final byTitle = ArchiveView.from(
      kMockupArchived,
      const ArchiveFilter(sort: ArchiveSort.title),
      kArchiveNow,
    );
    expect(
      byTitle.groups.last.items.first.displayTitle,
      'Conference notes 2022',
    );
  });

  test('row copy matches the mockups', () {
    final [note, task, ...] = kMockupArchived;
    expect(
      ArchiveFormat.archivedMeta(note, kArchiveNow),
      'Note · archived Jun 2',
    );
    expect(
      ArchiveFormat.archivedMeta(task, kArchiveNow),
      'Task · completed · archived May 28',
    );
    expect(
      [for (final s in kMockupTrash) ArchiveFormat.daysLeftOf(s, kArchiveNow)],
      [29, 28, 20, 16, 4],
    );
    expect(
      ArchiveFormat.deletedMeta(kMockupTrash[1], kArchiveNow),
      'Task · deleted yesterday',
    );
    expect(ArchiveFormat.daysLeft(1), '1 day');
    expect(ArchiveFormat.daysLeft(0), 'Today');
    expect(ArchiveFormat.countLabel(5, selected: 2), '2 selected · 5 items');
    expect(ArchiveFormat.searchHint(37), 'Search 37 archived items…');
  });
}
