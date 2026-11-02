/// ============================================================
/// PRAYER SCHOOL — the branch of a tradition (Hanafi, Catholic, Reform …)
/// ============================================================
///
/// What: the main schools, denominations, movements and streams of each
/// tradition, as the people inside it name themselves. Optional: the
/// first-run and "+" pickers offer them ("Which school do you follow?" —
/// skippable) and pick a better starting set from the answer: Asr by the
/// Hanafi shadow, the Orthodox prayer rule, Reform's lighter daily
/// services, a Vaishnava's Ekadashi, a Zen sit or a Pure Land nembutsu.
/// Why: one faith is many practices. A school only changes defaults —
/// it never hides, locks or ranks anything, and everything stays editable.
/// Stored by [key] in the prayer settings (one per tradition).
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';

enum PrayerSchool {
  // Islam.
  hanafi('hanafi', PrayerTradition.islam),
  shafii('shafii', PrayerTradition.islam),
  maliki('maliki', PrayerTradition.islam),
  hanbali('hanbali', PrayerTradition.islam),
  jafari('jafari', PrayerTradition.islam),

  // Christianity.
  catholic('catholic', PrayerTradition.christianity),
  easternOrthodox('easternOrthodox', PrayerTradition.christianity),
  orientalOrthodox('orientalOrthodox', PrayerTradition.christianity),
  anglican('anglican', PrayerTradition.christianity),
  protestant('protestant', PrayerTradition.christianity),

  // Judaism.
  jewishOrthodox('jewishOrthodox', PrayerTradition.judaism),
  conservative('conservative', PrayerTradition.judaism),
  reform('reform', PrayerTradition.judaism),

  // Hinduism.
  smarta('smarta', PrayerTradition.hinduism),
  vaishnava('vaishnava', PrayerTradition.hinduism),
  gaudiya('gaudiya', PrayerTradition.hinduism),
  shaiva('shaiva', PrayerTradition.hinduism),
  shakta('shakta', PrayerTradition.hinduism),
  aryaSamaj('aryaSamaj', PrayerTradition.hinduism),

  // Buddhism.
  theravada('theravada', PrayerTradition.buddhism),
  zen('zen', PrayerTradition.buddhism),
  pureLand('pureLand', PrayerTradition.buddhism),
  nichiren('nichiren', PrayerTradition.buddhism),
  tibetan('tibetan', PrayerTradition.buddhism),
  insight('insight', PrayerTradition.buddhism);

  const PrayerSchool(this.key, this.tradition);

  final String key;
  final PrayerTradition tradition;

  String get label => switch (this) {
    hanafi => tr('Hanafi'),
    shafii => tr('Shafi\'i'),
    maliki => tr('Maliki'),
    hanbali => tr('Hanbali'),
    jafari => tr('Jafari (Shia)'),
    catholic => tr('Catholic'),
    easternOrthodox => tr('Eastern Orthodox'),
    orientalOrthodox => tr('Oriental Orthodox'),
    anglican => tr('Anglican or Episcopal'),
    protestant => tr('Protestant or evangelical'),
    jewishOrthodox => tr('Orthodox'),
    conservative => tr('Conservative or Masorti'),
    reform => tr('Reform or Progressive'),
    smarta => tr('Smarta'),
    vaishnava => tr('Vaishnava'),
    gaudiya => tr('Gaudiya (ISKCON)'),
    shaiva => tr('Shaiva'),
    shakta => tr('Shakta'),
    aryaSamaj => tr('Arya Samaj'),
    theravada => tr('Theravada'),
    zen => tr('Zen, Chan or Seon'),
    pureLand => tr('Pure Land'),
    nichiren => tr('Nichiren'),
    tibetan => tr('Tibetan'),
    insight => tr('Insight or secular'),
  };

  /// The schools of [t], in the order a person of that tradition expects.
  static List<PrayerSchool> of(PrayerTradition t) => [
    for (final s in values)
      if (s.tradition == t) s,
  ];

  static PrayerSchool? fromKey(String? key) =>
      values.where((s) => s.key == key).firstOrNull;
}

/// The question that goes with the picker, in the tradition's own terms.
extension PrayerSchoolQuestion on PrayerTradition {
  /// "Which school do you follow?" — null where there is nothing to ask.
  String? get schoolQuestion => switch (this) {
    PrayerTradition.islam => tr('Which school of prayer do you follow?'),
    PrayerTradition.christianity => tr('Which Christian tradition?'),
    PrayerTradition.judaism => tr('Which movement?'),
    PrayerTradition.hinduism => tr('Which stream of Hinduism?'),
    PrayerTradition.buddhism => tr('Which school of Buddhism?'),
    PrayerTradition.custom => null,
  };
}
