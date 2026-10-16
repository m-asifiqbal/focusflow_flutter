// Behaviour tests for the interactive design-system widgets: delete
// confirmation choices, undo snackbar, swipe actions (LTR + RTL, outside
// tap, full swipe), check circle + haptics, chip/segment selection, action
// sheet and typed confirmation.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/widgets/dev/gallery_demos_composites.dart';
import 'package:focusflow/core/widgets/widgets.dart';

import 'ff_test_harness.dart';

/// A button that runs [onPressed] with a context under the Navigator.
Widget _launcher(void Function(BuildContext context) onPressed) => Builder(
  builder: (context) =>
      FFTextButton(label: 'go', onPressed: () => onPressed(context)),
);

void main() {
  group('confirmDelete', () {
    Future<DeleteChoice?> run(
      WidgetTester tester,
      Future<void> Function() act, {
      bool permanent = false,
      bool offerArchive = true,
      int count = 2,
    }) async {
      DeleteChoice? result;
      await pumpFF(
        tester,
        _launcher((context) async {
          result = await confirmDelete(
            context,
            count: count,
            noun: 'note',
            permanent: permanent,
            offerArchive: offerArchive,
          );
        }),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await act();
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('Delete → DeleteChoice.delete', (tester) async {
      final r = await run(tester, () async {
        expect(find.text('Delete 2 notes?'), findsOneWidget);
        expect(
          find.textContaining('Recently Deleted', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('30 days', findRichText: true),
          findsOneWidget,
        );
        await tester.tap(find.text('Delete'));
      });
      expect(r, DeleteChoice.delete);
      expect(find.text('Delete 2 notes?'), findsNothing);
    });

    testWidgets('Archive instead → DeleteChoice.archive', (tester) async {
      final r = await run(
        tester,
        () => tester.tap(find.text('Archive instead')),
      );
      expect(r, DeleteChoice.archive);
    });

    testWidgets('Cancel → DeleteChoice.cancel', (tester) async {
      final r = await run(tester, () => tester.tap(find.text('Cancel')));
      expect(r, DeleteChoice.cancel);
    });

    testWidgets('barrier tap → DeleteChoice.cancel', (tester) async {
      final r = await run(tester, () => tester.tapAt(const Offset(8, 8)));
      expect(r, DeleteChoice.cancel);
    });

    testWidgets('permanent: "Delete forever?" and no archive option', (
      tester,
    ) async {
      final r = await run(tester, permanent: true, count: 1, () async {
        expect(find.text('Delete forever?'), findsOneWidget);
        expect(find.text('Archive instead'), findsNothing);
        await tester.tap(find.text('Delete forever'));
      });
      expect(r, DeleteChoice.delete);
    });

    testWidgets('single item uses singular copy; offerArchive false hides it', (
      tester,
    ) async {
      await run(tester, count: 1, offerArchive: false, () async {
        expect(find.text('Delete this note?'), findsOneWidget);
        expect(find.text('Archive instead'), findsNothing);
        await tester.tap(find.text('Cancel'));
      });
    });
  });

  group('showUndoSnackbar', () {
    testWidgets('UNDO calls onUndo once and hides the snackbar', (
      tester,
    ) async {
      var undone = 0;
      await pumpFF(
        tester,
        _launcher(
          (context) => showUndoSnackbar(
            context,
            message: 'Note archived',
            icon: Icons.archive,
            onUndo: () => undone++,
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Note archived'), findsOneWidget);

      await tester.tap(find.text('UNDO'));
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(find.text('Note archived'), findsNothing);
    });

    testWidgets('times out after 5 s without calling onUndo', (tester) async {
      var undone = 0;
      await pumpFF(
        tester,
        _launcher(
          (context) => showUndoSnackbar(
            context,
            message: 'Task deleted',
            onUndo: () => undone++,
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Task deleted'), findsNothing);
      expect(undone, 0);
    });

    testWidgets('only one snackbar at a time', (tester) async {
      var n = 0;
      await pumpFF(
        tester,
        _launcher((context) {
          n++;
          showUndoSnackbar(context, message: 'Item $n', onUndo: () {});
        }),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Item 1'), findsNothing);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.byType(FFSnackbar), findsOneWidget);

      showFFToast(tester.element(find.text('go')), 'Copied');
      await tester.pumpAndSettle();
      expect(find.text('Item 2'), findsNothing);
      expect(find.text('Copied'), findsOneWidget);
    });
  });

  group('FFSwipeActions', () {
    late int archived;
    late int deleted;
    late int completed;

    Widget row() => FFSwipeActions(
      group: FFSwipeGroup(),
      startAction: FFSwipeAction.complete(onTap: () => completed++),
      endActions: [
        FFSwipeAction.archive(onTap: () => archived++),
        FFSwipeAction.delete(onTap: () => deleted++),
      ],
      child: const FFCard(child: SizedBox(height: 60, child: Text('Row'))),
    );

    setUp(() {
      archived = 0;
      deleted = 0;
      completed = 0;
    });

    testWidgets('swipe toward start reveals Archive + Delete; tap runs it', (
      tester,
    ) async {
      await pumpFF(tester, row(), textScale: 1);
      expect(find.text('Delete'), findsNothing);

      await tester.drag(find.text('Row'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(deleted, 1);
      expect(archived, 0);
      expect(find.text('Delete'), findsNothing, reason: 'row closes after');
    });

    testWidgets('tapping outside closes the open row', (tester) async {
      await pumpFF(tester, row(), textScale: 1);
      await tester.drag(find.text('Row'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(find.text('Archive'), findsOneWidget);

      await tester.tapAt(const Offset(180, 700));
      await tester.pumpAndSettle();
      expect(find.text('Archive'), findsNothing);
      expect(archived + deleted, 0);
    });

    testWidgets('full swipe toward end runs the start action', (tester) async {
      await pumpFF(tester, row(), textScale: 1);
      await tester.drag(find.text('Row'), const Offset(260, 0));
      await tester.pumpAndSettle();
      expect(completed, 1);
      expect(find.text('Complete'), findsNothing);
    });

    testWidgets('RTL: swipe right reveals the end actions', (tester) async {
      await pumpFF(
        tester,
        row(),
        textScale: 1,
        textDirection: TextDirection.rtl,
      );
      await tester.drag(find.text('Row'), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(find.text('Delete'), findsOneWidget);
      // In RTL the panel sits on the left edge.
      expect(
        tester.getCenter(find.text('Delete')).dx,
        lessThan(tester.getCenter(find.text('Row')).dx),
      );
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(archived, 1);
    });

    testWidgets('only one row open per group', (tester) async {
      final group = FFSwipeGroup();
      Widget r(String label) => FFSwipeActions(
        group: group,
        endActions: [FFSwipeAction.delete(onTap: () {})],
        child: FFCard(child: SizedBox(height: 60, child: Text(label))),
      );
      await pumpFF(
        tester,
        Column(children: [r('A'), const SizedBox(height: 12), r('B')]),
        textScale: 1,
      );
      await tester.drag(find.text('A'), const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(find.text('Delete'), findsOneWidget);
      await tester.drag(find.text('B'), const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(find.text('Delete'), findsOneWidget);
    });
  });

  testWidgets('FFCheckCircle toggles with a bounce + light haptic', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    var checked = false;
    await pumpFF(
      tester,
      StatefulBuilder(
        builder: (context, setState) => FFCheckCircle(
          checked: checked,
          semanticLabel: 'Complete task',
          onChanged: (v) => setState(() => checked = v),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FFCheckCircle)), const Size(44, 44));

    await tester.tap(find.byType(FFCheckCircle));
    await tester.pumpAndSettle();
    expect(checked, isTrue);
    expect(
      calls.where(
        (c) =>
            c.method == 'HapticFeedback.vibrate' &&
            c.arguments == 'HapticFeedbackType.lightImpact',
      ),
      hasLength(1),
    );
    expect(
      tester.getSemantics(find.byType(FFCheckCircle)),
      isSemantics(label: 'Complete task', isChecked: true),
    );

    await tester.tap(find.byType(FFCheckCircle));
    await tester.pumpAndSettle();
    expect(checked, isFalse);
  });

  testWidgets('FFChipBar selects the tapped chip', (tester) async {
    var selected = 'all';
    await pumpFF(
      tester,
      StatefulBuilder(
        builder: (context, setState) => FFChipBar<String>(
          selected: selected,
          onSelected: (v) => setState(() => selected = v),
          items: const [
            FFChipItem(value: 'all', label: 'All', count: 3),
            FFChipItem(value: 'work', label: 'Work'),
            FFChipItem(value: 'ideas', label: 'Ideas'),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(selected, 'work');
    expect(
      tester.getSemantics(find.byType(FFChip).at(1)),
      isSemantics(label: 'Work', isSelected: true, isButton: true),
    );
    expect(
      tester.getSemantics(find.byType(FFChip).first),
      isSemantics(label: 'All, 3', isSelected: false),
    );
  });

  testWidgets('FFSegmented reports the tapped segment', (tester) async {
    var value = 0;
    await pumpFF(
      tester,
      StatefulBuilder(
        builder: (context, setState) => FFSegmented<int>(
          value: value,
          onChanged: (v) => setState(() => value = v),
          segments: const [
            FFSegment(value: 0, label: 'Week'),
            FFSegment(value: 1, label: 'Month'),
            FFSegment(value: 2, label: 'Agenda'),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(value, 2);
  });

  testWidgets('showFFActionSheet closes then runs the action', (tester) async {
    var taps = 0;
    await pumpFF(
      tester,
      _launcher(
        (context) => showFFActionSheet(
          context,
          demoActionSheetData(onAny: () => taps++),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Mobile App Design Trends 2024'), findsOneWidget);
    await tester.tap(find.text('Pin to top'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.text('Pin to top'), findsNothing);
  });

  testWidgets('showFFTextConfirm only confirms after typing the word', (
    tester,
  ) async {
    bool? result;
    await pumpFF(
      tester,
      _launcher((context) async {
        result = await showFFTextConfirm(context, title: 'Erase all data?');
      }),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(result, isNull, reason: 'disabled until the word is typed');

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('FFBottomNav reports tab taps and FAB', (tester) async {
    var tab = -1;
    var fab = 0;
    await pumpFF(
      tester,
      FFBottomNav(currentIndex: 0, onTap: (i) => tab = i, onFab: () => fab++),
    );
    await tester.tap(find.text('Insights'));
    await tester.tap(find.bySemanticsLabel('Quick add'));
    await tester.pumpAndSettle();
    expect(tab, 2);
    expect(fab, 1);
  });
}
