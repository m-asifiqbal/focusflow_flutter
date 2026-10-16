/// Quick-capture parser (screen 04): days, times, repeats, tags, priority,
/// kind selection and title clean-up for English phrases.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/quick_add/domain/entities/quick_capture.dart';
import 'package:focusflow/features/quick_add/domain/services/quick_capture_parser.dart';
import 'package:focusflow/features/quick_add/domain/services/quick_capture_preview.dart';

/// Wednesday 14 Oct 2026, 10:00.
final _now = DateTime(2026, 10, 14, 10);
DateTime _d(int m, int d, [int y = 2026]) => DateTime(y, m, d);
const _parser = QuickCaptureParser();

QuickCapture p(String s, {DateTime? defaultDay, int weekStartsOn = 1}) =>
    QuickCaptureParser(
      weekStartsOn: weekStartsOn,
    ).parse(s, _now, defaultDay: defaultDay);

void main() {
  group('kind', () {
    test('plain text is a note', () {
      final c = p('Ideas for the garden');
      expect(c.kind, QuickCaptureKind.note);
      expect(c.title, 'Ideas for the garden');
      expect(c.day, isNull);
    });

    test('mockup phrase: Pay rent tomorrow 9am → reminder', () {
      final c = p('Pay rent tomorrow 9am');
      expect(c.kind, QuickCaptureKind.reminder);
      expect(c.title, 'Pay rent');
      expect(c.at, DateTime(2026, 10, 15, 9));
    });

    test('date without time → task', () {
      final c = p('Submit report friday');
      expect(c.kind, QuickCaptureKind.task);
      expect(c.day, _d(10, 16));
      expect(c.timeMinutes, isNull);
      expect(c.dayKey, '2026-10-16');
    });

    test('priority alone makes a task', () {
      final c = p('Fix the leak !high');
      expect(c.kind, QuickCaptureKind.task);
      expect(c.priority, 3);
      expect(c.title, 'Fix the leak');
    });

    test('"remind me to" forces a reminder at the default time', () {
      final c = p('Remind me to call mom');
      expect(c.kind, QuickCaptureKind.reminder);
      expect(c.title, 'Call mom');
      // 09:00 has passed today (10:00) → tomorrow.
      expect(c.at, DateTime(2026, 10, 15, 9));
    });

    test('calendar default day turns plain text into a task that day', () {
      final c = p('Buy flowers', defaultDay: DateTime(2026, 10, 20, 15));
      expect(c.kind, QuickCaptureKind.task);
      expect(c.day, _d(10, 20));
    });
  });

  group('days', () {
    final cases = <String, DateTime>{
      'Gym today': _d(10, 14),
      'Gym tomorrow': _d(10, 15),
      'Gym tmrw': _d(10, 15),
      'Gym day after tomorrow': _d(10, 16),
      'Gym on Monday': _d(10, 19),
      'Gym mon': _d(10, 19),
      'Gym wednesday': _d(10, 14),
      'Gym next week': _d(10, 19),
      'Gym next month': _d(11, 1),
      'Gym in 3 days': _d(10, 17),
      'Gym in a week': _d(10, 21),
      'Gym in 2 weeks': _d(10, 28),
      'Gym in 2 months': _d(12, 14),
      'Gym this weekend': _d(10, 17),
      'Gym on sat': _d(10, 17),
      'Gym Jun 20': _d(6, 20, 2027),
      'Gym 20 December': _d(12, 20),
      'Gym dec 31st 2027': _d(12, 31, 2027),
      'Gym on the 3rd': _d(11, 3),
      'Gym 2026-11-05': _d(11, 5),
      'Gym by friday': _d(10, 16),
    };
    cases.forEach((phrase, day) {
      test(phrase, () {
        final c = p(phrase);
        expect(c.day, day, reason: c.toString());
        expect(c.title, 'Gym');
      });
    });

    test('"next tue" is Tuesday of next week (week starts Monday)', () {
      expect(p('Call next tue').day, _d(10, 20));
    });

    test('"next week" follows the week start setting (Sunday)', () {
      expect(
        p('Plan next week', weekStartsOn: DateTime.sunday).day,
        _d(10, 18),
      );
    });

    test('ambiguous abbreviations need a lead-in', () {
      final c = p('Watch the sun set');
      expect(c.kind, QuickCaptureKind.note);
      expect(c.title, 'Watch the sun set');
    });

    test('invalid dates are left in the title', () {
      final c = p('Party feb 30');
      expect(c.day, isNull);
      expect(c.title, 'Party feb 30');
    });
  });

  group('times', () {
    final cases = <String, int>{
      'Call 9am': 9 * 60,
      'Call 9:30 pm': 21 * 60 + 30,
      'Call at 7.15a.m.': 7 * 60 + 15,
      'Call 21:30': 21 * 60 + 30,
      'Call at 9': 9 * 60,
      'Call at 3': 15 * 60,
      'Call @ 18': 18 * 60,
      'Call at noon': 12 * 60,
      'Call 12am': 0,
      'Call 12pm': 12 * 60,
      "Call 5 o'clock": 17 * 60,
      'Call in the evening': 18 * 60,
    };
    cases.forEach((phrase, minutes) {
      test(phrase, () {
        final c = p(phrase);
        expect(c.kind, QuickCaptureKind.reminder);
        expect(c.timeMinutes, minutes, reason: c.toString());
        expect(c.title, 'Call');
      });
    });

    test(
      'a time later today stays today, an earlier one moves to tomorrow',
      () {
        expect(p('Stretch at 4pm').day, _d(10, 14));
        expect(p('Stretch at 8am').day, _d(10, 15));
      },
    );

    test('tonight → today 20:00; "tonight at 8" → 20:00', () {
      expect(p('Movie tonight').at, DateTime(2026, 10, 14, 20));
      expect(p('Movie tonight at 8').at, DateTime(2026, 10, 14, 20));
    });

    test('tomorrow evening at 7:30 → 19:30', () {
      expect(
        p('Dinner tomorrow evening at 7:30').at,
        DateTime(2026, 10, 15, 19, 30),
      );
    });

    test('in 2 hours / in 30 min / in half an hour', () {
      expect(p('Check oven in 2 hours').at, DateTime(2026, 10, 14, 12));
      expect(p('Check oven in 30min').at, DateTime(2026, 10, 14, 10, 30));
      expect(
        p('Check oven in half an hour').at,
        DateTime(2026, 10, 14, 10, 30),
      );
    });

    test('bare weekday that is today rolls a week when its time passed', () {
      expect(p('Standup wednesday 9am').day, _d(10, 21));
      expect(p('Standup wednesday 11am').day, _d(10, 14));
    });

    test('numbers that are not times stay in the title', () {
      final c = p('Buy 3 apples');
      expect(c.kind, QuickCaptureKind.note);
      expect(c.title, 'Buy 3 apples');
    });
  });

  group('repeat', () {
    test('every day at 8am', () {
      final c = p('Take vitamins every day at 8am');
      expect(c.repeatRule, 'FREQ=DAILY');
      expect(c.kind, QuickCaptureKind.reminder);
      expect(c.title, 'Take vitamins');
    });

    test('every monday and wednesday', () {
      final c = p('Gym every monday and wednesday');
      expect(c.repeatRule, 'FREQ=WEEKLY;BYDAY=MO,WE');
      expect(c.day, _d(10, 14));
      expect(c.kind, QuickCaptureKind.task);
    });

    test('weekly anchors on the day', () {
      final c = p('Review budget weekly friday');
      expect(c.repeatRule, 'FREQ=WEEKLY;BYDAY=FR');
      expect(c.day, _d(10, 16));
    });

    test('every other week / every 3 months / monthly / every weekday', () {
      expect(
        p('Clean every other week').repeatRule,
        'FREQ=WEEKLY;INTERVAL=2;BYDAY=WE',
      );
      expect(
        p('Haircut every 3 months').repeatRule,
        'FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=14',
      );
      expect(p('Pay rent monthly').repeatRule, 'FREQ=MONTHLY;BYMONTHDAY=14');
      expect(
        p('Standup every weekday').repeatRule,
        'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
      );
    });

    test('every morning → daily 09:00', () {
      final c = p('Meditate every morning');
      expect(c.repeatRule, 'FREQ=DAILY');
      expect(c.timeMinutes, 9 * 60);
    });
  });

  group('tags and priority', () {
    test('#tags are collected, deduplicated and removed', () {
      final c = p('Buy milk #home #Errands #home tomorrow');
      expect(c.tags, ['home', 'Errands']);
      expect(c.title, 'Buy milk');
    });

    test('a # inside a word is not a tag', () {
      expect(p('Learn C# basics').tags, isEmpty);
    });

    test('priority spellings', () {
      expect(p('a !!!').priority, 3);
      expect(p('a !!').priority, 2);
      expect(p('a !').priority, 1);
      expect(p('a !med').priority, 2);
      expect(p('a !low').priority, 1);
      expect(p('a p1').priority, 3);
      expect(p('a P3').priority, 1);
      expect(p('Wow!').priority, isNull);
    });
  });

  group('title', () {
    test('dangling prepositions and punctuation are trimmed', () {
      expect(
        p('Meet Sam for coffee on Friday at 3pm').title,
        'Meet Sam for coffee',
      );
      expect(p('call bank, tomorrow').title, 'Call bank');
    });

    test('only date tokens → empty title', () {
      expect(p('tomorrow 9am').title, '');
    });

    test('case of the rest of the title is kept', () {
      expect(p('email ACME re: Q3 tomorrow').title, 'Email ACME re: Q3');
    });
  });

  group('preview', () {
    test('mockup example summary', () {
      final c = p('Pay rent tomorrow 9am #home');
      expect(
        QuickCapturePreview.summary(c, _now),
        'Reminder · Tomorrow 09:00 AM',
      );
      expect(
        QuickCapturePreview.summary(p('Pay rent tomorrow #home'), _now),
        'Task · Tomorrow · #home',
      );
    });

    test('task with repeat and priority', () {
      final c = p('Gym every monday !high');
      expect(
        QuickCapturePreview.summary(c, _now, use24h: true),
        startsWith('Task · Mon, Oct 19 · Weekly'),
      );
      expect(QuickCapturePreview.summary(c, _now), endsWith('High'));
    });
  });

  group('edge cases', () {
    QuickCapture at(String s, DateTime now) =>
        const QuickCaptureParser().parse(s, now);

    test('"sun cream" is not Sunday; "on sun" is', () {
      final c = p('Buy sun cream');
      expect(c.kind, QuickCaptureKind.note);
      expect(c.day, isNull);
      expect(c.title, 'Buy sun cream');
      expect(p('Picnic on sun').day, _d(10, 18));
    });

    test('"in 1 month" on Jan 31 clamps to the end of February', () {
      expect(
        at('Renew pass in 1 month', DateTime(2026, 1, 31, 10)).day,
        DateTime(2026, 2, 28),
      );
      expect(
        at('Renew pass in 1 month', DateTime(2028, 1, 31, 10)).day,
        DateTime(2028, 2, 29),
      );
      expect(
        at('Renew pass in a month', DateTime(2026, 12, 31, 10)).day,
        DateTime(2027, 1, 31),
      );
    });

    test('p1 / !!! are high priority and leave the title', () {
      final a = p('File taxes p1');
      expect(a.priority, 3);
      expect(a.title, 'File taxes');
      final b = p('!!! Call the plumber');
      expect(b.priority, 3);
      expect(b.title, 'Call the plumber');
      expect(p('Version p4 notes').priority, isNull);
      expect(p('Wow !!!!').priority, isNull);
    });

    test('bare weekday that is today: today without a time', () {
      // Rule (parser header + _day): only a passed *time* rolls a week.
      final c = p('Submit report wednesday');
      expect(c.day, _d(10, 14));
      expect(c.kind, QuickCaptureKind.task);
      expect(p('Submit report next wednesday').day, _d(10, 21));
    });

    test('only the first tag is previewed (the editors take one tag)', () {
      final c = p('Pay bills tomorrow #home #money');
      expect(c.tags, ['home', 'money']);
      expect(c.savedTag, 'home');
      expect(QuickCapturePreview.summary(c, _now), 'Task · Tomorrow · #home');
      expect(p('No tags here').savedTag, isNull);
    });
  });

  test('default parser instance works', () {
    expect(_parser.parse('x', _now).kind, QuickCaptureKind.note);
  });
}
