/// Regression: buttons wrapped in `Semantics(excludeSemantics: true)` must
/// still expose a tap action, or TalkBack / VoiceOver cannot activate them
/// (TaskEditorRow, the priority chips, the reminder action pills).
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/reminders/presentation/widgets/reminder_card_parts.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/presentation/widgets/editor/task_editor_row.dart';
import 'package:focusflow/features/tasks/presentation/widgets/editor/task_priority_selector.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../../reminders/isolated_notifications.dart';

/// Performs the semantics tap on the node labelled [label]; fails when the
/// node has no tap action.
void _semanticTap(WidgetTester tester, Pattern label) {
  final node = tester.getSemantics(find.bySemanticsLabel(label));
  expect(
    node.getSemanticsData().hasAction(SemanticsAction.tap),
    isTrue,
    reason: '$label has no tap action',
  );
  node.owner!.performAction(node.id, SemanticsAction.tap);
}

void main() {
  testWidgets('row, chip and pill expose and perform the tap action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final h = (await tester.runAsync(
      () => TestHarness.create(
        now: DateTime(2026, 10, 13, 9, 35),
        overrides: isolatedNotifications(),
      ),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));

    var rowTaps = 0;
    var pillTaps = 0;
    TaskPriority? picked;
    await pumpScreen(
      tester,
      h,
      Scaffold(
        body: Column(
          children: [
            TaskEditorRow(
              icon: FontAwesomeIcons.calendar,
              colors: ItemType.task.style.colors,
              title: 'Date',
              value: 'Today',
              onTap: () => rowTaps++,
            ),
            TaskPrioritySelector(
              value: TaskPriority.none,
              onChanged: (p) => picked = p,
            ),
            ReminderActionPill(label: 'SNOOZE 10m', onTap: () => pillTaps++),
          ],
        ),
      ),
    );

    _semanticTap(tester, 'Date, Today');
    _semanticTap(tester, 'High priority');
    _semanticTap(tester, 'SNOOZE 10m');
    await tester.pump();
    expect(rowTaps, 1);
    expect(picked, TaskPriority.high);
    expect(pillTaps, 1);
    semantics.dispose();
  });
}
