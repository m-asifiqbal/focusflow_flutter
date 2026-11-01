/// ============================================================
/// HEALTH TIPS — the "Health tip of the day" catalogue (Medicine insights)
/// ============================================================
///
/// What: short, general wellness and medicine-safety habits, in the active
/// language. The order mixes topics (medicines, sleep, food, movement) so
/// consecutive days feel different; [FFTipCard] picks one per day.
/// Why: offline and fixed — no feed, no network. Nothing here replaces a
/// doctor: tips stay general, point to the leaflet / pharmacist / doctor
/// for anything personal, and the card says so in its footnote.
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';

abstract final class HealthTips {
  /// Shown under every tip.
  static String get footnote =>
      tr('General wellness information, not medical advice.');

  /// Every tip (a getter, so a language switch re-translates).
  static List<String> get all => [
    tr(
      'Take your medicines at the same time each day. Linking them to a daily habit, like breakfast, makes them easier to remember.',
    ),
    tr(
      'Aim for 7–9 hours of sleep. Regular bed and wake times make it easier.',
    ),
    tr(
      'Missed a dose? Check the leaflet or ask your pharmacist before taking two together.',
    ),
    tr('A short walk after meals helps your energy and your digestion.'),
    tr(
      'Store medicines in a cool, dry place. A bathroom cabinet is often too warm and humid.',
    ),
    tr('Fill half your plate with vegetables and fruit at most meals.'),
    tr(
      'Bring a list of everything you take, including vitamins and herbal remedies, to every appointment.',
    ),
    tr(
      'Drink water through the day. Pale yellow urine is a good sign you are drinking enough.',
    ),
    tr(
      'Don\'t stop a prescribed medicine on your own, even if you feel better. Ask your doctor first.',
    ),
    tr('Stand up and stretch for a minute for every hour you sit.'),
    tr(
      'Check expiry dates once a month and take old medicines back to a pharmacy.',
    ),
    tr(
      'Feeling stressed? Take a few slow breaths, breathing out for longer than you breathe in.',
    ),
    tr(
      'Some medicines don\'t mix with grapefruit or alcohol. Read the leaflet or ask your pharmacist.',
    ),
    tr('Spend some time outdoors in daylight each day. It helps you sleep.'),
    tr('Refill before you run out. A few days\' buffer avoids missed doses.'),
    tr('Limit salty snacks. Too much salt can raise blood pressure.'),
    tr(
      'Keep medicines out of sight and reach of children, in their original packaging.',
    ),
    tr('Screens off 30 minutes before bed helps you fall asleep faster.'),
    tr('Tell your doctor about side effects. There is often another option.'),
    tr('Small steps count: a 10-minute walk is better than none.'),
    tr(
      'A weekly pill organiser shows at a glance whether today\'s dose is taken.',
    ),
    tr('Brush your teeth twice a day and see a dentist regularly.'),
    tr(
      'Ask whether a medicine should be taken with food or on an empty stomach.',
    ),
    tr(
      'Keep sugary drinks for now and then. Water, milk or unsweetened tea are better every day.',
    ),
    tr(
      'Travelling? Keep your medicines in your hand luggage with a copy of your prescription.',
    ),
    tr('Wash your hands before handling medicines, eye drops or inhalers.'),
    tr(
      'Don\'t share prescription medicines, even when the symptoms look the same.',
    ),
    tr('Keep your vaccinations up to date. Ask your doctor what is due.'),
    tr(
      'Some medicines, like insulin, need the fridge. Check how yours should be stored once opened.',
    ),
    tr(
      'Use an inhaler? Ask your nurse or pharmacist to check your technique now and then.',
    ),
  ];
}
