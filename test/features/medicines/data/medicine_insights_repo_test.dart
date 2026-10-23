/// MedicinesRepository.watchInsights: every period computes from the real
/// database, the yearly one on a background isolate.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_insights.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  test('daily, monthly and yearly insights from the database', () async {
    final h = await TestHarness.create(now: DateTime(2026, 10, 23, 9));
    addTearDown(h.dispose);
    final repo = h.read(medicinesRepositoryProvider);
    final id = await repo.save(
      Medicine.draft(startDate: DateTime(2026, 10, 20), name: 'Metformin'),
    );
    await repo.markTaken(id, DateTime(2026, 10, 21), 480);
    for (final p in MedicinePeriod.values) {
      final s = await repo
          .watchInsights(p, DateTime(2026, 10, 23, 9))
          .first
          .timeout(const Duration(seconds: 20));
      expect(s.counts.total, 4, reason: p.name); // Oct 20–23 at 08:00
      expect(s.counts.taken, 1, reason: p.name);
    }
  });
}
