/// ============================================================
/// PRAYER TIPS — the "Prayer tip of the day" catalogue (Prayer page)
/// ============================================================
///
/// What: practical habits that make a prayer life steadier, in the active
/// language: tips for everyone plus a few for the tradition chosen in
/// setup, woven together so roughly every third day is a tradition tip.
/// [FFTipCard] picks one per day.
/// Why: works for every faith (and none in particular — "Your own
/// practice" gets the general tips only). The tips are practical, not
/// doctrinal: no rulings and no quotations that could be misattributed.
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';

abstract final class PrayerTips {
  /// The tips for [tradition]: two general tips, then one of the
  /// tradition's, repeated until both lists are used up.
  static List<String> forTradition(PrayerTradition tradition) {
    final general = _general;
    final own = _of(tradition);
    final out = <String>[];
    var g = 0;
    var o = 0;
    while (g < general.length || o < own.length) {
      for (var k = 0; k < 2 && g < general.length; k++) {
        out.add(general[g++]);
      }
      if (o < own.length) out.add(own[o++]);
    }
    return out;
  }

  static List<String> get _general => [
    tr('Keep a quiet corner for prayer. A set place helps you settle faster.'),
    tr('Put your phone on silent before you begin.'),
    tr(
      'Pair a prayer with something you already do every day, like waking up or a meal.',
    ),
    tr(
      'Missed a prayer? Don\'t give up on the day. Start again with the next one.',
    ),
    tr(
      'Slow down. A few words said with attention are better than many said in a rush.',
    ),
    tr('This week, learn the meaning of one line of a prayer you say often.'),
    tr('Go to bed a little earlier to make an early-morning prayer easier.'),
    tr('Pray with family or friends now and then. Company keeps you steady.'),
    tr('End the day by recalling three things you are grateful for.'),
    tr(
      'Set your reminder a few minutes before the start, so you can get ready calmly.',
    ),
    tr(
      'Small and steady beats big and rare. A short daily practice lasts longer.',
    ),
    tr(
      'Keep a short journal of your prayers and intentions, and look back at it each month.',
    ),
    tr('Help someone today. Kindness is part of every tradition.'),
    tr(
      'Before you start, take three slow breaths and let the rush of the day settle.',
    ),
  ];

  static List<String> _of(PrayerTradition t) => switch (t) {
    PrayerTradition.islam => [
      tr('Make wudu before you sleep and put your Fajr alarm across the room.'),
      tr('Pray early in the window when you can. There is less to rush.'),
      tr(
        'Keep a clean prayer mat in a fixed place at home, and one at work if you can.',
      ),
      tr('Learn a new short surah and recite it in your next Sunnah prayers.'),
      tr('Say your dhikr after each salah, before you pick up your phone.'),
      tr(
        'On fasting days, eat a balanced suhoor, drink water, and break the fast gently.',
      ),
    ],
    PrayerTradition.christianity => [
      tr('Begin the day with a short prayer before you check your messages.'),
      tr(
        'Read a short passage of Scripture and carry one verse with you through the day.',
      ),
      tr('Keep a list of people to pray for and update it every week.'),
      tr(
        'At night, look back on the day: give thanks, and ask for help with tomorrow.',
      ),
      tr('Join a service or a prayer group this week.'),
    ],
    PrayerTradition.hinduism => [
      tr('Light a lamp at your altar at the same time each morning.'),
      tr('Chant your mantra with a mala to keep count and stay focused.'),
      tr('Offer a flower, fruit or water with gratitude before you eat.'),
      tr(
        'Read a few verses of a sacred text you love and think about one during the day.',
      ),
      tr(
        'Keep your puja space clean and simple. A little care each day is enough.',
      ),
    ],
    PrayerTradition.buddhism => [
      tr(
        'Start with five minutes of sitting meditation and add a minute each week.',
      ),
      tr('Begin your practice by taking refuge or with a short chant.'),
      tr('Try mindful walking: notice each step for a few minutes.'),
      tr('End your practice by wishing others well and sharing the merit.'),
      tr('Bring full attention to one everyday task, like washing the dishes.'),
    ],
    PrayerTradition.judaism => [
      tr('Say Modeh Ani as soon as you wake up.'),
      tr('Keep a siddur where you will see it, so it is easy to pick up.'),
      tr('Learn a little Torah each day, even a few lines.'),
      tr('Try to join a minyan for one service this week.'),
      tr('Prepare for Shabbat early, so you can welcome it calmly.'),
    ],
    PrayerTradition.custom => const [],
  };
}
