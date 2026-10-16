/// FFHaptics: the design system's haptics follow the Settings switch
/// (provided by app.dart as an FFHaptics scope). Without a scope haptics
/// stay on (default setting), so other screens and tests are unaffected.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/widgets/ff_haptics.dart';
import 'package:focusflow/core/widgets/widgets.dart';

import 'ff_test_harness.dart';

void main() {
  late List<MethodCall> calls;

  void recordHaptics(WidgetTester tester) {
    calls = [];
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
  }

  int vibrations() =>
      calls.where((c) => c.method == 'HapticFeedback.vibrate').length;

  Widget checkCircle() {
    var checked = false;
    return StatefulBuilder(
      builder: (context, setState) => FFCheckCircle(
        checked: checked,
        semanticLabel: 'Complete task',
        onChanged: (v) => setState(() => checked = v),
      ),
    );
  }

  Widget swipeRow(VoidCallback onArchive) => FFSwipeActions(
    group: FFSwipeGroup(),
    endActions: [
      FFSwipeAction.archive(onTap: onArchive),
      FFSwipeAction.delete(onTap: () {}),
    ],
    child: const FFCard(child: SizedBox(height: 60, child: Text('Row'))),
  );

  testWidgets('enabledOf: true without a scope, the flag inside one', (
    tester,
  ) async {
    late bool outside;
    late bool inside;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          outside = FFHaptics.enabledOf(context);
          return FFHaptics(
            enabled: false,
            child: Builder(
              builder: (context) {
                inside = FFHaptics.enabledOf(context);
                return const SizedBox();
              },
            ),
          );
        },
      ),
    );
    expect(outside, isTrue);
    expect(inside, isFalse);
  });

  testWidgets('FFCheckCircle: haptic without a scope (default on)', (
    tester,
  ) async {
    recordHaptics(tester);
    await pumpFF(tester, checkCircle());
    await tester.tap(find.byType(FFCheckCircle));
    await tester.pumpAndSettle();
    expect(vibrations(), 1);
  });

  testWidgets('FFCheckCircle: no haptic when haptics are off', (
    tester,
  ) async {
    recordHaptics(tester);
    await pumpFF(tester, FFHaptics(enabled: false, child: checkCircle()));
    await tester.tap(find.byType(FFCheckCircle));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FFCheckCircle));
    await tester.pumpAndSettle();
    expect(vibrations(), 0);
  });

  testWidgets('FFSwipeActions: threshold + action haptics follow the scope', (
    tester,
  ) async {
    recordHaptics(tester);
    var archived = 0;
    await pumpFF(tester, swipeRow(() => archived++), textScale: 1);
    await tester.drag(find.text('Row'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(archived, 1);
    final withHaptics = vibrations();
    expect(withHaptics, greaterThanOrEqualTo(2), reason: 'open tick + tap');

    recordHaptics(tester);
    await pumpFF(
      tester,
      FFHaptics(enabled: false, child: swipeRow(() => archived++)),
      textScale: 1,
    );
    await tester.drag(find.text('Row'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(archived, 2);
    expect(vibrations(), 0);
  });
}
