/// ============================================================
/// TRADITION PROFILE — how a tradition says things in the Prayer module
/// ============================================================
///
/// What: for each [PrayerTradition], the words and options its followers
/// expect: the kinds of practice offered and what they are called (Fard ·
/// Sunnah · Nafl for Islam; Puja · Sandhya · Japa for Hinduism; Sitting ·
/// Chanting · Mala for Buddhism …), the sun-based times offered and their
/// names (zmanim for Judaism, muhurta anchors for Hinduism, canonical
/// hours for Christianity), how a fast, the congregation (jamaat, minyan,
/// Mass, satsang, sangha), a place of worship and a mark are worded, the
/// adjustments and goals that suit it, and the wording of the editor.
/// Why: the Prayer module started from Islam, so its base words were
/// Islamic for everyone. Every screen now asks the practice's profile, so a
/// Jewish prayer reads Jewish and a Buddhist sit reads Buddhist, and a
/// person who keeps several traditions sees each in its own words. Built
/// from the research in docs/prayer_traditions.md. Pure; every text goes
/// through `tr` in getters (never in initialisers).
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';

/// The words of a fast (or a fast-like observance) in one tradition.
class FastWords {
  const FastWords._(this._t);

  final PrayerTradition _t;

  bool get _islam => _t == PrayerTradition.islam;
  bool get _hindu => _t == PrayerTradition.hinduism;
  bool get _buddhist => _t == PrayerTradition.buddhism;

  /// Editor: the start / end of the window.
  String get startLabel => _islam
      ? tr('Starts (Suhoor ends)')
      : _buddhist
      ? tr('Observance begins')
      : tr('Fast begins');

  String get endLabel => _islam
      ? tr('Ends (Iftar)')
      : _hindu
      ? tr('Ends (parana)')
      : _buddhist
      ? tr('Observance ends')
      : tr('Fast ends');

  /// Editor: the reminders before the start and before the end.
  String get remindStartLabel => _islam
      ? tr('Suhoor reminder')
      : _buddhist
      ? tr('Reminder before the observance')
      : tr('Reminder before the fast');

  String get remindEndLabel => _islam
      ? tr('Iftar reminder')
      : _hindu
      ? tr('Parana reminder')
      : _buddhist
      ? tr('Reminder before it ends')
      : tr('Reminder before the fast ends');

  /// Notification: the fast begins ("Suhoor ends at 5:02 AM").
  String startsAt(String time) => _islam
      ? tr('Suhoor ends at {time}', {'time': time})
      : _buddhist
      ? tr('Observance begins at {time}', {'time': time})
      : tr('Fast begins at {time}', {'time': time});

  /// Notification: the fast ends now / in [m] minutes.
  String get endsNow => _islam
      ? tr('Iftar time')
      : _hindu
      ? tr('Time to break the fast')
      : _buddhist
      ? tr('The observance ends')
      : tr('The fast ends');

  String endsIn(int m) => _islam
      ? tr('Iftar in {m} min', {'m': m})
      : _hindu
      ? tr('Break the fast in {m} min', {'m': m})
      : _buddhist
      ? tr('The observance ends in {m} min', {'m': m})
      : tr('The fast ends in {m} min', {'m': m});

  /// A card / row: "Iftar 5:45 PM" ([when] is a time or a countdown).
  String endsWhen(String when) => _islam
      ? tr('Iftar {when}', {'when': when})
      : _hindu
      ? tr('Parana {when}', {'when': when})
      : _buddhist
      ? tr('Ends {when}', {'when': when})
      : tr('Fast ends {when}', {'when': when});

  /// A card: "Suhoor ends in 20 min" (before the fast begins).
  String startsWhen(String when) => _islam
      ? tr('Suhoor ends {when}', {'when': when})
      : _buddhist
      ? tr('Begins {when}', {'when': when})
      : tr('Fast begins {when}', {'when': when});

  /// A card: "Suhoor ends 5:02 AM · Iftar 5:45 PM".
  String span(String start, String end) => _islam
      ? tr('Suhoor ends {start} · Iftar {end}', {'start': start, 'end': end})
      : _hindu
      ? tr('Fast from {start} · parana {end}', {'start': start, 'end': end})
      : _buddhist
      ? tr('From {start} to {end}', {'start': start, 'end': end})
      : tr('Fast from {start} to {end}', {'start': start, 'end': end});

  /// Row action: "Mark fasted" (a Buddhist day of precepts is "kept").
  String get markLabel => _buddhist ? tr('Mark kept') : tr('Mark fasted');
}

class PrayerTraditionProfile {
  const PrayerTraditionProfile._(this.tradition);

  factory PrayerTraditionProfile.of(PrayerTradition t) =>
      PrayerTraditionProfile._(t);

  final PrayerTradition tradition;

  bool get _islam => tradition == PrayerTradition.islam;
  bool get _christian => tradition == PrayerTradition.christianity;
  bool get _jewish => tradition == PrayerTradition.judaism;
  bool get _hindu => tradition == PrayerTradition.hinduism;
  bool get _buddhist => tradition == PrayerTradition.buddhism;

  FastWords get fast => FastWords._(tradition);

  // ---- the editor's own words ---------------------------------------

  /// "New prayer" / "New practice".
  String get newTitle =>
      _islam || _christian ? tr('New prayer') : tr('New practice');

  String get editTitle =>
      _islam || _christian ? tr('Edit prayer') : tr('Edit practice');

  String get nameHint =>
      _islam || _christian ? tr('Prayer name') : tr('Practice name');

  String get notesHint => switch (tradition) {
    PrayerTradition.islam => tr('e.g. pray with family'),
    PrayerTradition.christianity => tr(
      'e.g. intentions, readings or the book you use',
    ),
    PrayerTradition.judaism => tr(
      'e.g. the tractate, portion or siddur you use',
    ),
    PrayerTradition.hinduism => tr(
      'e.g. the mantra, deity or number of rounds',
    ),
    PrayerTradition.buddhism => tr('e.g. the technique, teacher or intention'),
    PrayerTradition.custom => tr('e.g. who you practise with'),
  };

  // ---- kinds --------------------------------------------------------

  /// The kinds the editor offers, in this tradition's order.
  List<PrayerKind> get kinds => switch (tradition) {
    PrayerTradition.islam => const [
      PrayerKind.salah,
      PrayerKind.nafl,
      PrayerKind.dhikr,
      PrayerKind.recitation,
      PrayerKind.fasting,
      PrayerKind.custom,
    ],
    PrayerTradition.christianity => const [
      PrayerKind.salah,
      PrayerKind.service,
      PrayerKind.dhikr,
      PrayerKind.recitation,
      PrayerKind.meditation,
      PrayerKind.fasting,
      PrayerKind.custom,
    ],
    PrayerTradition.judaism => const [
      PrayerKind.salah,
      PrayerKind.recitation,
      PrayerKind.service,
      PrayerKind.dhikr,
      PrayerKind.fasting,
      PrayerKind.custom,
    ],
    PrayerTradition.hinduism => const [
      PrayerKind.service,
      PrayerKind.salah,
      PrayerKind.dhikr,
      PrayerKind.recitation,
      PrayerKind.nafl,
      PrayerKind.meditation,
      PrayerKind.fasting,
      PrayerKind.custom,
    ],
    PrayerTradition.buddhism => const [
      PrayerKind.meditation,
      PrayerKind.recitation,
      PrayerKind.dhikr,
      PrayerKind.service,
      PrayerKind.fasting,
      PrayerKind.custom,
    ],
    PrayerTradition.custom => PrayerKind.values,
  };

  /// A chip's word for [k].
  String kindShort(PrayerKind k) => switch (tradition) {
    PrayerTradition.islam => switch (k) {
      PrayerKind.salah => tr('Fard'),
      PrayerKind.nafl => tr('Sunnah and nafl'),
      PrayerKind.fasting => tr('Fast'),
      PrayerKind.dhikr => tr('Dhikr'),
      PrayerKind.recitation => tr('Quran'),
      _ => k.short,
    },
    PrayerTradition.christianity => switch (k) {
      PrayerKind.salah => tr('Prayer'),
      PrayerKind.nafl => tr('Devotion'),
      PrayerKind.service => tr('Service'),
      PrayerKind.dhikr => tr('Beads'),
      PrayerKind.recitation => tr('Reading'),
      PrayerKind.meditation => tr('Silent prayer'),
      PrayerKind.fasting => tr('Fast'),
      PrayerKind.custom => tr('Other'),
    },
    PrayerTradition.judaism => switch (k) {
      PrayerKind.salah => tr('Tefillah'),
      PrayerKind.nafl => tr('Extra prayer'),
      PrayerKind.recitation => tr('Study'),
      PrayerKind.service => tr('Observance'),
      PrayerKind.dhikr => tr('Counted'),
      PrayerKind.fasting => tr('Fast'),
      _ => k.short,
    },
    PrayerTradition.hinduism => switch (k) {
      PrayerKind.service => tr('Puja'),
      PrayerKind.salah => tr('Sandhya'),
      PrayerKind.dhikr => tr('Japa'),
      PrayerKind.recitation => tr('Path'),
      PrayerKind.nafl => tr('Bhajan'),
      PrayerKind.meditation => tr('Dhyana'),
      PrayerKind.fasting => tr('Vrata'),
      PrayerKind.custom => tr('Other'),
    },
    PrayerTradition.buddhism => switch (k) {
      PrayerKind.meditation => tr('Sitting'),
      PrayerKind.recitation => tr('Chanting'),
      PrayerKind.dhikr => tr('Mala'),
      PrayerKind.service => tr('Offering'),
      PrayerKind.fasting => tr('Observance'),
      PrayerKind.salah => tr('Practice'),
      PrayerKind.nafl => tr('Extra practice'),
      PrayerKind.custom => tr('Other'),
    },
    PrayerTradition.custom => switch (k) {
      PrayerKind.salah => tr('Prayer'),
      PrayerKind.nafl => tr('Extra prayer'),
      PrayerKind.dhikr => tr('Counted'),
      PrayerKind.recitation => tr('Reading'),
      PrayerKind.service => tr('Service'),
      PrayerKind.meditation => tr('Meditation'),
      PrayerKind.fasting => tr('Fast'),
      PrayerKind.custom => tr('Other'),
    },
  };

  /// A longer name for [k] (accessibility, details).
  String kindLabel(PrayerKind k) => switch (tradition) {
    PrayerTradition.islam => switch (k) {
      PrayerKind.salah => tr('Fard prayer'),
      PrayerKind.nafl => tr('Sunnah or nafl prayer'),
      PrayerKind.fasting => tr('Fast (sawm)'),
      PrayerKind.dhikr => tr('Remembrance (dhikr)'),
      PrayerKind.recitation => tr('Quran reading'),
      _ => k.label,
    },
    PrayerTradition.christianity => switch (k) {
      PrayerKind.salah => tr('Prayer or Office'),
      PrayerKind.nafl => tr('Devotion'),
      PrayerKind.service => tr('Mass or service'),
      PrayerKind.dhikr => tr('Rosary or prayer rope'),
      PrayerKind.recitation => tr('Scripture reading'),
      PrayerKind.meditation => tr('Silent prayer or lectio'),
      PrayerKind.fasting => tr('Fast or abstinence'),
      PrayerKind.custom => tr('Other'),
    },
    PrayerTradition.judaism => switch (k) {
      PrayerKind.salah => tr('Prayer service (tefillah)'),
      PrayerKind.nafl => tr('Extra prayer'),
      PrayerKind.recitation => tr('Torah study or reading'),
      PrayerKind.service => tr('Shabbat or festival observance'),
      PrayerKind.dhikr => tr('Counted (Omer, Tehillim)'),
      PrayerKind.fasting => tr('Fast (ta\'anit)'),
      _ => k.label,
    },
    PrayerTradition.hinduism => switch (k) {
      PrayerKind.service => tr('Puja or aarti'),
      PrayerKind.salah => tr('Sandhya or prayer'),
      PrayerKind.dhikr => tr('Japa (mala)'),
      PrayerKind.recitation => tr('Path (recitation or reading)'),
      PrayerKind.nafl => tr('Bhajan or kirtan'),
      PrayerKind.meditation => tr('Dhyana (meditation)'),
      PrayerKind.fasting => tr('Vrata (fast)'),
      PrayerKind.custom => tr('Other'),
    },
    PrayerTradition.buddhism => switch (k) {
      PrayerKind.meditation => tr('Meditation (sitting or walking)'),
      PrayerKind.recitation => tr('Chanting or sutra reading'),
      PrayerKind.dhikr => tr('Mantra or mala rounds'),
      PrayerKind.service => tr('Offering or group practice'),
      PrayerKind.fasting => tr('Eight-precepts or midday fast'),
      PrayerKind.salah => tr('Practice'),
      PrayerKind.nafl => tr('Extra practice'),
      PrayerKind.custom => tr('Other'),
    },
    PrayerTradition.custom => switch (k) {
      PrayerKind.salah => tr('Prayer'),
      PrayerKind.nafl => tr('Extra prayer'),
      PrayerKind.dhikr => tr('Counted repetition'),
      PrayerKind.recitation => tr('Reading or recitation'),
      PrayerKind.service => tr('Service or worship'),
      PrayerKind.meditation => tr('Meditation'),
      PrayerKind.fasting => tr('Fast'),
      PrayerKind.custom => tr('Other'),
    },
  };

  /// "Mark prayed" / "Mark done" / "Mark practised" for a non-fast [kind].
  String markLabel(PrayerKind kind) {
    if (kind.isFast) return fast.markLabel;
    if (_buddhist) return tr('Mark practised');
    if (_hindu) return tr('Mark done');
    if (_jewish && kind == PrayerKind.recitation) return tr('Mark studied');
    if (tradition == PrayerTradition.custom) return tr('Mark done');
    return switch (kind) {
      PrayerKind.salah || PrayerKind.nafl => tr('Mark prayed'),
      PrayerKind.recitation => tr('Mark read'),
      _ => tr('Mark done'),
    };
  }

  /// The log sheet's question about the place.
  String get wherePrompt => _islam || _christian || _jewish
      ? tr('Where did you pray?')
      : tr('Where did you practise?');

  // ---- times --------------------------------------------------------

  /// "Auto (sun)" — the zmanim for Judaism.
  String get autoLabel => _jewish ? tr('Zmanim') : tr('Auto (sun)');

  /// The row that picks the sun event.
  String get sunEventTitle => _jewish ? tr('Halachic time') : tr('Sun event');

  /// The sun events offered, in order of the day.
  List<SolarEvent> get sunEvents => switch (tradition) {
    PrayerTradition.islam => const [
      SolarEvent.dawn,
      SolarEvent.sunrise,
      SolarEvent.noon,
      SolarEvent.asr,
      SolarEvent.sunset,
      SolarEvent.nightfall,
      SolarEvent.midnight,
      SolarEvent.lastThird,
    ],
    PrayerTradition.christianity => const [
      SolarEvent.dawn,
      SolarEvent.sunrise,
      SolarEvent.noon,
      SolarEvent.sunset,
      SolarEvent.nightfall,
      SolarEvent.midnight,
    ],
    PrayerTradition.judaism => const [
      SolarEvent.sunrise,
      SolarEvent.sofZmanShema,
      SolarEvent.sofZmanTefillah,
      SolarEvent.noon,
      SolarEvent.plagHamincha,
      SolarEvent.sunset,
      SolarEvent.midnight,
    ],
    PrayerTradition.hinduism => const [
      SolarEvent.sunrise,
      SolarEvent.noon,
      SolarEvent.sunset,
      SolarEvent.midnight,
    ],
    PrayerTradition.buddhism => const [
      SolarEvent.dawn,
      SolarEvent.sunrise,
      SolarEvent.noon,
      SolarEvent.sunset,
      SolarEvent.nightfall,
    ],
    PrayerTradition.custom => const [
      SolarEvent.dawn,
      SolarEvent.sunrise,
      SolarEvent.noon,
      SolarEvent.asr,
      SolarEvent.sunset,
      SolarEvent.nightfall,
      SolarEvent.midnight,
      SolarEvent.lastThird,
    ],
  };

  /// [e] by this tradition's name.
  String eventLabel(SolarEvent e) => switch (tradition) {
    PrayerTradition.islam => e.label,
    PrayerTradition.judaism => switch (e) {
      SolarEvent.sunrise => tr('Sunrise (netz)'),
      SolarEvent.sofZmanShema => tr('Latest Shema (sof zman Shema)'),
      SolarEvent.sofZmanTefillah => tr(
        'Latest morning prayer (sof zman Tefillah)',
      ),
      SolarEvent.noon => tr('Midday (chatzot)'),
      SolarEvent.plagHamincha => tr('Plag hamincha'),
      SolarEvent.sunset => tr('Sunset (shkia)'),
      SolarEvent.midnight => tr('Midnight (chatzot halayla)'),
      _ => _plainEvent(e),
    },
    PrayerTradition.hinduism => switch (e) {
      SolarEvent.sunrise => tr('Sunrise (pratah)'),
      SolarEvent.noon => tr('Midday (madhyahna)'),
      SolarEvent.sunset => tr('Sunset (sayam)'),
      SolarEvent.midnight => tr('Midnight (nishita)'),
      _ => _plainEvent(e),
    },
    _ => _plainEvent(e),
  };

  static String _plainEvent(SolarEvent e) => switch (e) {
    SolarEvent.dawn => tr('Dawn'),
    SolarEvent.sunrise => tr('Sunrise'),
    SolarEvent.noon => tr('Midday'),
    SolarEvent.asr => tr('Afternoon'),
    SolarEvent.sunset => tr('Sunset'),
    SolarEvent.nightfall => tr('Nightfall'),
    SolarEvent.midnight => tr('Midnight'),
    SolarEvent.lastThird => tr('Last third of the night'),
    SolarEvent.sofZmanShema => tr('Latest Shema'),
    SolarEvent.sofZmanTefillah => tr('Latest morning prayer'),
    SolarEvent.plagHamincha => tr('Plag hamincha'),
  };

  /// The "Adjust by" choices (minutes): the offsets that matter to this
  /// tradition (Jewish candle lighting 18 before and nightfall 42 / 50 /
  /// 72 after sunset, Brahma muhurta 96 before sunrise …).
  List<int> get offsets => switch (tradition) {
    PrayerTradition.judaism => const [
      -72,
      -40,
      -30,
      -18,
      -10,
      0,
      10,
      30,
      42,
      50,
      72,
    ],
    PrayerTradition.hinduism => const [
      -96,
      -72,
      -48,
      -30,
      -15,
      0,
      15,
      30,
      48,
      72,
      144,
    ],
    PrayerTradition.buddhism || PrayerTradition.christianity => const [
      -60,
      -30,
      -20,
      -15,
      -10,
      -5,
      0,
      5,
      10,
      15,
      20,
      30,
      45,
      60,
    ],
    _ => const [-30, -20, -15, -10, -5, 0, 5, 10, 15, 20, 30],
  };

  /// A new fast's window: Islam dawn to sunset; Judaism's minor fasts from
  /// alot (72 minutes before sunrise) to tzeit (42 after sunset); a
  /// Buddhist eight-precepts day from midday to the next dawn; every other
  /// tradition sunrise to sunset.
  (PrayerTimeRule, PrayerTimeRule) get fastWindow => switch (tradition) {
    PrayerTradition.islam => (
      const PrayerTimeRule.auto(SolarEvent.dawn, minutes: 5 * 60),
      const PrayerTimeRule.auto(SolarEvent.sunset, minutes: 18 * 60),
    ),
    PrayerTradition.judaism => (
      const PrayerTimeRule.auto(
        SolarEvent.sunrise,
        offset: -72,
        minutes: 5 * 60,
      ),
      const PrayerTimeRule.auto(
        SolarEvent.sunset,
        offset: 42,
        minutes: 18 * 60 + 30,
      ),
    ),
    PrayerTradition.buddhism => (
      const PrayerTimeRule.auto(SolarEvent.noon, minutes: 12 * 60),
      const PrayerTimeRule.auto(SolarEvent.dawn, minutes: 5 * 60),
    ),
    _ => (
      const PrayerTimeRule.auto(SolarEvent.sunrise, minutes: 6 * 60),
      const PrayerTimeRule.auto(SolarEvent.sunset, minutes: 18 * 60),
    ),
  };

  // ---- congregation -------------------------------------------------

  /// Section title: "Jamaat (congregation)", "Minyan (quorum of ten)" …
  String get congregationTitle => switch (tradition) {
    PrayerTradition.islam => tr('Jamaat (congregation)'),
    PrayerTradition.christianity => tr('Mass or service time'),
    PrayerTradition.judaism => tr('Minyan (quorum of ten)'),
    PrayerTradition.hinduism => tr('Satsang or aarti time'),
    PrayerTradition.buddhism => tr('Sangha or group practice time'),
    PrayerTradition.custom => tr('Congregation time'),
  };

  /// The row that sets the clock time.
  String get congregationTimeLabel => switch (tradition) {
    PrayerTradition.islam => tr('Jamaat time'),
    PrayerTradition.christianity => tr('Service time'),
    PrayerTradition.judaism => tr('Minyan time'),
    PrayerTradition.hinduism => tr('Satsang time'),
    PrayerTradition.buddhism => tr('Group practice time'),
    PrayerTradition.custom => tr('Congregation time'),
  };

  /// The reminder choice "at the …".
  String get congregationAtLabel => switch (tradition) {
    PrayerTradition.islam => tr('At the jamaat'),
    PrayerTradition.christianity => tr('At the service'),
    PrayerTradition.judaism => tr('At the minyan'),
    PrayerTradition.hinduism => tr('At the satsang'),
    PrayerTradition.buddhism => tr('At the group practice'),
    PrayerTradition.custom => tr('At the gathering'),
  };

  /// "Today: jamaat at 1:15 PM".
  String congregationToday(String time) => switch (tradition) {
    PrayerTradition.islam => tr('Today: jamaat at {time}', {'time': time}),
    PrayerTradition.christianity => tr('Today: service at {time}', {
      'time': time,
    }),
    PrayerTradition.judaism => tr('Today: minyan at {time}', {'time': time}),
    PrayerTradition.hinduism => tr('Today: satsang at {time}', {'time': time}),
    PrayerTradition.buddhism => tr('Today: group practice at {time}', {
      'time': time,
    }),
    PrayerTradition.custom => tr('Today: congregation at {time}', {
      'time': time,
    }),
  };

  /// The hero / row line: "Jamaat 1:15 PM".
  String congregationLine(String time) => switch (tradition) {
    PrayerTradition.islam => tr('Jamaat {time}', {'time': time}),
    PrayerTradition.christianity => tr('Service {time}', {'time': time}),
    PrayerTradition.judaism => tr('Minyan {time}', {'time': time}),
    PrayerTradition.hinduism => tr('Satsang {time}', {'time': time}),
    PrayerTradition.buddhism => tr('Group practice {time}', {'time': time}),
    PrayerTradition.custom => tr('Congregation {time}', {'time': time}),
  };

  /// The log sheet's switch.
  String get inCongregation => switch (tradition) {
    PrayerTradition.islam => tr('In congregation'),
    PrayerTradition.christianity => tr('At a service'),
    PrayerTradition.judaism => tr('With a minyan'),
    PrayerTradition.hinduism => tr('With others'),
    PrayerTradition.buddhism => tr('With the sangha'),
    PrayerTradition.custom => tr('In congregation'),
  };

  /// Notification: "{name} jamaat now" — the congregation is gathering.
  String congregationNow(String name) => switch (tradition) {
    PrayerTradition.islam => tr('{name} jamaat now', {'name': name}),
    PrayerTradition.judaism => tr('{name} with the minyan now', {'name': name}),
    PrayerTradition.buddhism => tr('{name} with the sangha now', {
      'name': name,
    }),
    _ => tr('{name} with the congregation now', {'name': name}),
  };

  String congregationSoon(String name, int m) => switch (tradition) {
    PrayerTradition.islam => tr('{name} jamaat in {m} min', {
      'name': name,
      'm': m,
    }),
    PrayerTradition.judaism => tr('{name} with the minyan in {m} min', {
      'name': name,
      'm': m,
    }),
    PrayerTradition.buddhism => tr('{name} with the sangha in {m} min', {
      'name': name,
      'm': m,
    }),
    _ => tr('{name} with the congregation in {m} min', {'name': name, 'm': m}),
  };

  /// Notification body: "Jamaat at 1:15 PM".
  String congregationBody(String time) => switch (tradition) {
    PrayerTradition.islam => tr('Jamaat at {time}', {'time': time}),
    PrayerTradition.christianity => tr('Service at {time}', {'time': time}),
    PrayerTradition.judaism => tr('Minyan at {time}', {'time': time}),
    PrayerTradition.hinduism => tr('Satsang at {time}', {'time': time}),
    PrayerTradition.buddhism => tr('Group practice at {time}', {'time': time}),
    PrayerTradition.custom => tr('Congregation at {time}', {'time': time}),
  };

  /// "Auto": an offline estimate of a typical mosque's time exists for the
  /// five daily prayers only.
  bool get hasCongregationEstimate => _islam;

  // ---- places -------------------------------------------------------

  /// The places offered (English; shown translated by `tr` where it has an
  /// entry, kept as typed otherwise).
  List<String> get places => switch (tradition) {
    PrayerTradition.islam => [tr('Home'), tr('Mosque'), tr('Work')],
    PrayerTradition.christianity => [tr('Home'), tr('Church'), tr('Work')],
    PrayerTradition.judaism => [
      tr('Home'),
      tr('Synagogue'),
      tr('Study hall'),
      tr('Work'),
    ],
    PrayerTradition.hinduism => [tr('Home shrine'), tr('Temple'), tr('Work')],
    PrayerTradition.buddhism => [
      tr('Home shrine'),
      tr('Meditation hall'),
      tr('Temple'),
      tr('Outdoors'),
    ],
    PrayerTradition.custom => [tr('Home'), tr('Place of worship'), tr('Work')],
  };

  // ---- counting -----------------------------------------------------

  /// The daily-goal choices of a counted practice.
  List<int> get goals => switch (tradition) {
    PrayerTradition.islam => const [33, 34, 99, 100, 1000],
    PrayerTradition.christianity => const [10, 33, 50, 100, 150],
    PrayerTradition.judaism => const [10, 18, 30, 100, 150],
    PrayerTradition.hinduism => const [11, 21, 27, 54, 108, 1008],
    PrayerTradition.buddhism => const [21, 27, 54, 108, 1000],
    PrayerTradition.custom => const [33, 50, 100, 108, 1000],
  };

  /// What a new counted practice starts with (33 beads of the Jesus Prayer
  /// is common, a mala is 108).
  int get defaultGoal => switch (tradition) {
    PrayerTradition.christianity => 50,
    PrayerTradition.hinduism || PrayerTradition.buddhism => 108,
    _ => 100,
  };

  /// Many Buddhists (Pure Land, Zen) count nothing: "No goal" first.
  String get goalTitle =>
      _buddhist ? tr('Daily rounds or count') : tr('Daily goal');
}
