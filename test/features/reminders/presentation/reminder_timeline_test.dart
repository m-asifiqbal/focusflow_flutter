/// Pure logic of the reminders list (screen 12): timeline sections,
/// next-due detection, meta lines and the header subtitle.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:focusflow/features/reminders/presentation/reminder_style.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_labels.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_timeline.dart';

final _now = DateTime(2026, 10, 13, 9, 35);

Reminder _r(
  String id,
  DateTime at, {
  String title = 'R',
  String? rrule,
  bool enabled = true,
  ItemRef? link,
  String? linkedTitle,
  ReminderLocation? location,
  List<Tag> tags = const [],
}) => Reminder(
  id: id,
  title: title,
  triggerAt: at,
  repeatRule: rrule,
  isEnabled: enabled,
  linkedRef: link,
  linkedTitle: linkedTitle,
  location: location,
  tags: tags,
  createdAt: _now,
  updatedAt: _now,
);

ReminderOccurrence _o(Reminder r, {DateTime? at, bool done = false}) =>
    ReminderOccurrence(reminder: r, at: at ?? r.triggerAt, isDone: done);

void main() {
  group('ReminderTimeline.forDay', () {
    final day = DateTime(2026, 10, 13);
    final vitamins = _r('v', DateTime(2026, 10, 14, 7), rrule: 'FREQ=DAILY');
    final bank = _r('b', DateTime(2026, 10, 13, 10));
    final review = _r('rv', DateTime(2026, 10, 13, 15));
    final rent = _r('p', DateTime(2026, 10, 14, 9));
    final missed = _r('m', DateTime(2026, 10, 12, 17));

    test('splits morning / afternoon, previews tomorrow, finds next', () {
      final t = ReminderTimeline.forDay(
        day: day,
        now: _now,
        dayItems: [
          _o(vitamins, at: DateTime(2026, 10, 13, 7), done: true),
          _o(bank),
          _o(review),
        ],
        nextDayItems: [_o(vitamins), _o(rent)],
        missed: [_o(missed)],
      );
      expect(t.sections.map((s) => s.label), [
        'MISSED',
        'MORNING',
        'AFTERNOON & EVENING',
        'TOMORROW',
      ]);
      expect(t.sections.first.isMissed, isTrue);
      // Daily vitamins already listed today → not repeated tomorrow.
      expect(t.sections.last.items.map((o) => o.id), ['p']);
      expect(t.next?.id, 'b');
      expect(t.isNext(_o(bank)), isTrue);
      expect(t.isNext(_o(review)), isFalse);
    });

    test('other days: no MISSED, next day labelled by date', () {
      final t = ReminderTimeline.forDay(
        day: DateTime(2026, 10, 15),
        now: _now,
        dayItems: const [],
        nextDayItems: [_o(_r('x', DateTime(2026, 10, 16, 9)))],
        missed: [_o(missed)],
      );
      expect(t.sections.single.label, 'FRI, OCT 16');
    });

    test('a picked future day highlights no next-due card', () {
      final thu = _r('t', DateTime(2026, 10, 15, 9));
      final t = ReminderTimeline.forDay(
        day: DateTime(2026, 10, 15),
        now: _now,
        dayItems: [_o(thu)],
        nextDayItems: [_o(_r('x', DateTime(2026, 10, 16, 9)))],
      );
      expect(t.sections.first.items.single.id, 't');
      expect(t.next, isNull);
      expect(t.isNext(_o(thu)), isFalse);
    });

    test('disabled and done rows are never the next-due card', () {
      final off = _r('off', DateTime(2026, 10, 13, 10), enabled: false);
      final t = ReminderTimeline.forDay(
        day: day,
        now: _now,
        dayItems: [_o(off), _o(review)],
        nextDayItems: const [],
      );
      expect(t.next?.id, 'rv');
      expect(ReminderTimeline.empty.isEmpty, isTrue);
    });
  });

  test('byDay groups by relative day', () {
    final t = ReminderTimeline.byDay([
      _o(_r('a', DateTime(2026, 10, 13, 11))),
      _o(_r('b', DateTime(2026, 10, 14, 8))),
      _o(_r('c', DateTime(2026, 10, 14, 9))),
    ], _now);
    expect(t.sections.map((s) => s.label), ['TODAY', 'TOMORROW']);
    expect(t.sections.last.items.length, 2);
    expect(t.next?.id, 'a');
  });

  group('ReminderLabels', () {
    test('meta lines match the mockup copy', () {
      expect(
        ReminderLabels.meta(
          _o(_r('v', DateTime(2026, 10, 13, 7), rrule: 'FREQ=DAILY')),
          _now,
        ),
        'Daily · Repeats every day',
      );
      expect(
        ReminderLabels.meta(_o(_r('b', DateTime(2026, 10, 13, 10))), _now),
        'Today · in 25 min',
      );
      expect(
        ReminderLabels.meta(
          _o(
            _r(
              'l',
              DateTime(2026, 10, 13, 15),
              link: const ItemRef(ItemType.task, 't'),
              linkedTitle: 'Design Home v2',
            ),
          ),
          _now,
        ),
        'Linked task · Design Home v2',
      );
      expect(
        ReminderLabels.meta(
          _o(
            _r(
              'g',
              DateTime(2026, 10, 13, 18, 30),
              location: const ReminderLocation(
                lat: 0,
                lng: 0,
                onEnter: false,
                label: 'office',
              ),
            ),
          ),
          _now,
        ),
        'When I leave office · Location',
      );
      expect(
        ReminderLabels.meta(
          _o(
            _r(
              'w',
              DateTime(2026, 10, 13, 21, 30),
              rrule: 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
            ),
          ),
          _now,
        ),
        'Weekdays · Mon–Fri',
      );
      expect(
        ReminderLabels.meta(
          _o(
            _r(
              'p',
              DateTime(2026, 10, 14, 9),
              rrule: 'FREQ=MONTHLY;BYMONTHDAY=14',
              tags: const [Tag(id: 't', name: 'high-priority')],
            ),
          ),
          _now,
        ),
        'Monthly · 14th · High priority',
      );
      expect(
        ReminderLabels.meta(_o(_r('m', DateTime(2026, 10, 12, 17))), _now),
        'Yesterday · Missed',
      );
    });

    test('header subtitle and time column', () {
      expect(
        ReminderLabels.headerSubtitle(
          today: 3,
          next: DateTime(2026, 10, 13, 10),
          now: _now,
        ),
        '3 today · next in 25 min',
      );
      expect(
        ReminderLabels.headerSubtitle(
          today: 0,
          next: DateTime(2026, 10, 16, 9),
          now: _now,
        ),
        'next fri, oct 16',
      );
      expect(
        ReminderLabels.headerSubtitle(today: 0, next: null, now: _now),
        'Nothing scheduled',
      );
      final t = DateTime(2026, 10, 13, 18, 30);
      expect(ReminderLabels.time(t), '06:30');
      expect(ReminderLabels.meridiem(t), 'PM');
      expect(ReminderLabels.time(t, use24h: true), '18:30');
      expect(ReminderLabels.meridiem(t, use24h: true), isNull);
    });
  });

  test('ReminderStyle: link, location, topic, default, colour override', () {
    final at = DateTime(2026, 10, 13, 9);
    expect(
      ReminderStyle.of(
        _r('a', at, link: const ItemRef(ItemType.task, 't')),
      ).icon,
      FontAwesomeIcons.link,
    );
    expect(
      ReminderStyle.of(
        _r('b', at, location: const ReminderLocation(lat: 0, lng: 0)),
      ).icon,
      FontAwesomeIcons.locationDot,
    );
    expect(
      ReminderStyle.of(_r('c', at, title: 'Take vitamins')).icon,
      FontAwesomeIcons.pills,
    );
    final plain = ReminderStyle.of(_r('d', at, title: 'Call the bank'));
    expect(plain.icon, FontAwesomeIcons.solidBell);
    expect(plain.colors.solid, ModuleStyle.reminders.solid);
    final blue = ReminderStyle.of(
      _r('e', at, title: 'Call the bank').copyWith(colorHex: 'DBEAFE'),
    );
    expect(blue.colors.solid, ModuleStyle.tasks.solid);
  });
}
