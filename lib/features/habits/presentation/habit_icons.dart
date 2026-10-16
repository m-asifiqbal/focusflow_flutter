/// ============================================================
/// HABIT ICONS — the icon catalogue behind `Habit.iconKey`
/// ============================================================
///
/// Habits store a stable string key (the Font Awesome 6 name, e.g.
/// `droplet`) instead of a code point, so backups stay readable and a
/// font update never changes a habit's icon. [HabitIcons.of] resolves a
/// key (unknown → star); [HabitIcons.all] feeds the searchable picker of
/// the habit editor ("Customize Habit" sheet). Solid glyphs only — the
/// mockups use FA 6 solid for habit icons.
///
/// Other features (Home rings, Insights) show habit icons through
/// [HabitIcons.of] too.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/theme/fa_icons.dart';

/// One pickable icon: storage [key], glyph and search [keywords].
@immutable
class HabitIconEntry {
  const HabitIconEntry(this.key, this.icon, this.group, [this.keywords = '']);

  final String key;
  final IconData icon;

  /// Picker section ("Health", "Fitness" …).
  final String group;

  /// Extra search words besides the key.
  final String keywords;

  /// Whether this icon matches a search [query] (case-insensitive).
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return key.contains(q) ||
        group.toLowerCase().contains(q) ||
        keywords.contains(q);
  }
}

abstract final class HabitIcons {
  /// Key of the fallback icon (`Habit.iconKey` default).
  static const String fallbackKey = 'star';

  /// The icon for [key]; unknown keys fall back to a star.
  static IconData of(String? key) => _byKey[key] ?? FontAwesomeIcons.solidStar;

  /// Whether [key] is in the catalogue.
  static bool has(String key) => _byKey.containsKey(key);

  /// Icons matching [query] (all when empty), in catalogue order.
  static List<HabitIconEntry> search(String query) => [
    for (final e in all)
      if (e.matches(query)) e,
  ];

  static final Map<String, IconData> _byKey = {
    for (final e in all) e.key: e.icon,
  };

  /// The full catalogue (~150 icons), grouped for the picker.
  // One icon per line keeps the catalogue scannable.
  // dart format off
  static const List<HabitIconEntry> all = [
    // ── Health ──
    HabitIconEntry('droplet', FontAwesomeIcons.droplet, 'Health', 'water drink hydrate'),
    HabitIconEntry('glass-water', FontAwesomeIcons.glassWater, 'Health', 'water drink'),
    HabitIconEntry('bottle-water', FontAwesomeIcons.bottleWater, 'Health', 'water drink'),
    HabitIconEntry('heart-pulse', FontAwesomeIcons.heartPulse, 'Health', 'cardio heart rate'),
    HabitIconEntry('heart', FontAwesomeIcons.solidHeart, 'Health', 'love care'),
    HabitIconEntry('pills', FontAwesomeIcons.pills, 'Health', 'medicine vitamins'),
    HabitIconEntry('capsules', FontAwesomeIcons.capsules, 'Health', 'medicine vitamins'),
    HabitIconEntry('prescription-bottle', FontAwesomeIcons.prescriptionBottle, 'Health', 'medicine'),
    HabitIconEntry('syringe', FontAwesomeIcons.syringe, 'Health', 'insulin shot'),
    HabitIconEntry('tooth', FontAwesomeIcons.tooth, 'Health', 'floss brush teeth dental'),
    HabitIconEntry('lungs', FontAwesomeIcons.lungs, 'Health', 'breathe breathing'),
    HabitIconEntry('brain', FontAwesomeIcons.brain, 'Health', 'mind focus'),
    HabitIconEntry('eye', FontAwesomeIcons.solidEye, 'Health', 'eyes screen'),
    HabitIconEntry('weight-scale', FontAwesomeIcons.weightScale, 'Health', 'weigh diet'),
    HabitIconEntry('bed', FontAwesomeIcons.bed, 'Health', 'sleep rest nap'),
    HabitIconEntry('moon', FontAwesomeIcons.solidMoon, 'Health', 'sleep night bedtime'),
    HabitIconEntry('sun', FontAwesomeIcons.solidSun, 'Health', 'morning wake daylight'),
    HabitIconEntry('cloud-sun', FontAwesomeIcons.cloudSun, 'Health', 'outside weather'),
    HabitIconEntry('shower', FontAwesomeIcons.shower, 'Health', 'cold shower hygiene'),
    HabitIconEntry('bath', FontAwesomeIcons.bath, 'Health', 'relax hygiene'),
    HabitIconEntry('soap', FontAwesomeIcons.soap, 'Health', 'wash hygiene'),
    HabitIconEntry('hand-sparkles', FontAwesomeIcons.handSparkles, 'Health', 'wash hands skincare'),
    HabitIconEntry('pump-soap', FontAwesomeIcons.pumpSoap, 'Health', 'skincare wash'),
    // ── Mind ──
    HabitIconEntry('spa', FontAwesomeIcons.spa, 'Mind', 'meditate meditation lotus calm'),
    HabitIconEntry('om', FontAwesomeIcons.om, 'Mind', 'meditate yoga'),
    HabitIconEntry('yin-yang', FontAwesomeIcons.yinYang, 'Mind', 'balance calm'),
    HabitIconEntry('peace', FontAwesomeIcons.peace, 'Mind', 'calm'),
    HabitIconEntry('hands-praying', FontAwesomeIcons.handsPraying, 'Mind', 'pray gratitude'),
    HabitIconEntry('person-praying', FontAwesomeIcons.personPraying, 'Mind', 'pray'),
    HabitIconEntry('leaf', FontAwesomeIcons.leaf, 'Mind', 'nature calm green'),
    HabitIconEntry('seedling', FontAwesomeIcons.seedling, 'Mind', 'grow plant'),
    HabitIconEntry('tree', FontAwesomeIcons.tree, 'Mind', 'nature outside'),
    HabitIconEntry('face-smile', FontAwesomeIcons.solidFaceSmile, 'Mind', 'mood happy'),
    HabitIconEntry('face-smile-beam', FontAwesomeIcons.solidFaceSmileBeam, 'Mind', 'mood happy gratitude'),
    HabitIconEntry('face-grin-stars', FontAwesomeIcons.solidFaceGrinStars, 'Mind', 'mood joy'),
    HabitIconEntry('hand-holding-heart', FontAwesomeIcons.handHoldingHeart, 'Mind', 'kindness charity'),
    HabitIconEntry('infinity', FontAwesomeIcons.infinity, 'Mind', 'focus flow'),
    HabitIconEntry('hourglass-half', FontAwesomeIcons.hourglassHalf, 'Mind', 'time focus'),
    HabitIconEntry('stopwatch', FontAwesomeIcons.stopwatch, 'Mind', 'timer focus pomodoro'),
    HabitIconEntry('clock', FontAwesomeIcons.solidClock, 'Mind', 'time routine'),
    // ── Fitness ──
    HabitIconEntry('person-running', FontAwesomeIcons.personRunning, 'Fitness', 'run exercise jog cardio'),
    HabitIconEntry('person-walking', FontAwesomeIcons.personWalking, 'Fitness', 'walk steps'),
    HabitIconEntry('person-biking', FontAwesomeIcons.personBiking, 'Fitness', 'cycle bike ride'),
    HabitIconEntry('person-swimming', FontAwesomeIcons.personSwimming, 'Fitness', 'swim pool'),
    HabitIconEntry('person-hiking', FontAwesomeIcons.personHiking, 'Fitness', 'hike walk outdoors'),
    HabitIconEntry('person-skiing', FontAwesomeIcons.personSkiing, 'Fitness', 'ski winter'),
    HabitIconEntry('dumbbell', FontAwesomeIcons.dumbbell, 'Fitness', 'gym workout weights strength'),
    HabitIconEntry('weight-hanging', FontAwesomeIcons.weightHanging, 'Fitness', 'gym lift'),
    HabitIconEntry('bicycle', FontAwesomeIcons.bicycle, 'Fitness', 'cycle bike'),
    HabitIconEntry('football', FontAwesomeIcons.football, 'Fitness', 'sport'),
    HabitIconEntry('basketball', FontAwesomeIcons.basketball, 'Fitness', 'sport'),
    HabitIconEntry('baseball-bat-ball', FontAwesomeIcons.baseballBatBall, 'Fitness', 'sport'),
    HabitIconEntry('volleyball', FontAwesomeIcons.volleyball, 'Fitness', 'sport'),
    HabitIconEntry('table-tennis', FontAwesomeIcons.tableTennisPaddleBall, 'Fitness', 'ping pong sport'),
    HabitIconEntry('golf-ball-tee', FontAwesomeIcons.golfBallTee, 'Fitness', 'golf sport'),
    HabitIconEntry('mountain', FontAwesomeIcons.mountain, 'Fitness', 'climb hike'),
    HabitIconEntry('mountain-sun', FontAwesomeIcons.mountainSun, 'Fitness', 'outdoors'),
    HabitIconEntry('water-ladder', FontAwesomeIcons.waterLadder, 'Fitness', 'swim pool'),
    HabitIconEntry('fire', FontAwesomeIcons.fire, 'Fitness', 'burn calories streak'),
    HabitIconEntry('bolt', FontAwesomeIcons.bolt, 'Fitness', 'energy power'),
    // ── Food ──
    HabitIconEntry('apple-whole', FontAwesomeIcons.appleWhole, 'Food', 'fruit healthy eat'),
    HabitIconEntry('carrot', FontAwesomeIcons.carrot, 'Food', 'vegetables healthy eat'),
    HabitIconEntry('lemon', FontAwesomeIcons.lemon, 'Food', 'fruit'),
    HabitIconEntry('pepper-hot', FontAwesomeIcons.pepperHot, 'Food', 'spicy'),
    HabitIconEntry('bread-slice', FontAwesomeIcons.breadSlice, 'Food', 'breakfast carbs'),
    HabitIconEntry('bowl-food', FontAwesomeIcons.bowlFood, 'Food', 'meal cook'),
    HabitIconEntry('bowl-rice', FontAwesomeIcons.bowlRice, 'Food', 'meal'),
    HabitIconEntry('utensils', FontAwesomeIcons.utensils, 'Food', 'meal eat cook'),
    HabitIconEntry('kitchen-set', FontAwesomeIcons.kitchenSet, 'Food', 'cook'),
    HabitIconEntry('mug-hot', FontAwesomeIcons.mugHot, 'Food', 'coffee tea'),
    HabitIconEntry('mug-saucer', FontAwesomeIcons.mugSaucer, 'Food', 'coffee tea'),
    HabitIconEntry('pizza-slice', FontAwesomeIcons.pizzaSlice, 'Food', 'junk fast food'),
    HabitIconEntry('burger', FontAwesomeIcons.burger, 'Food', 'junk fast food'),
    HabitIconEntry('ice-cream', FontAwesomeIcons.iceCream, 'Food', 'sugar sweets dessert'),
    HabitIconEntry('cookie', FontAwesomeIcons.cookie, 'Food', 'sugar sweets snack'),
    HabitIconEntry('candy-cane', FontAwesomeIcons.candyCane, 'Food', 'sugar sweets'),
    HabitIconEntry('cake-candles', FontAwesomeIcons.cakeCandles, 'Food', 'sugar dessert'),
    // ── Quit ──
    HabitIconEntry('ban', FontAwesomeIcons.ban, 'Quit', 'no stop quit sugar'),
    HabitIconEntry('ban-smoking', FontAwesomeIcons.banSmoking, 'Quit', 'smoking cigarettes quit'),
    HabitIconEntry('smoking', FontAwesomeIcons.smoking, 'Quit', 'cigarettes'),
    HabitIconEntry('wine-glass', FontAwesomeIcons.wineGlass, 'Quit', 'alcohol drink'),
    HabitIconEntry('wine-bottle', FontAwesomeIcons.wineBottle, 'Quit', 'alcohol'),
    HabitIconEntry('beer-mug-empty', FontAwesomeIcons.beerMugEmpty, 'Quit', 'alcohol beer'),
    HabitIconEntry('martini-glass', FontAwesomeIcons.martiniGlass, 'Quit', 'alcohol cocktail'),
    HabitIconEntry('mobile-screen', FontAwesomeIcons.mobileScreen, 'Quit', 'phone screen time social'),
    HabitIconEntry('phone-slash', FontAwesomeIcons.phoneSlash, 'Quit', 'no phone detox'),
    HabitIconEntry('bell-slash', FontAwesomeIcons.bellSlash, 'Quit', 'notifications detox'),
    HabitIconEntry('tv', FontAwesomeIcons.tv, 'Quit', 'television screen'),
    HabitIconEntry('gamepad', FontAwesomeIcons.gamepad, 'Quit', 'games gaming'),
    HabitIconEntry('cannabis', FontAwesomeIcons.cannabis, 'Quit', 'weed'),
    // ── Learning ──
    HabitIconEntry('book-open', FontAwesomeIcons.bookOpen, 'Learning', 'read reading pages'),
    HabitIconEntry('book', FontAwesomeIcons.book, 'Learning', 'read'),
    HabitIconEntry('book-bookmark', FontAwesomeIcons.bookBookmark, 'Learning', 'read'),
    HabitIconEntry('book-open-reader', FontAwesomeIcons.bookOpenReader, 'Learning', 'read study'),
    HabitIconEntry('newspaper', FontAwesomeIcons.solidNewspaper, 'Learning', 'news read'),
    HabitIconEntry('graduation-cap', FontAwesomeIcons.graduationCap, 'Learning', 'study school course'),
    HabitIconEntry('language', FontAwesomeIcons.language, 'Learning', 'languages duolingo'),
    HabitIconEntry('lightbulb', FontAwesomeIcons.solidLightbulb, 'Learning', 'idea learn'),
    HabitIconEntry('pen-nib', FontAwesomeIcons.penNib, 'Learning', 'write journal'),
    HabitIconEntry('pen', FontAwesomeIcons.pen, 'Learning', 'write journal'),
    HabitIconEntry('pencil', FontAwesomeIcons.pencil, 'Learning', 'write draw'),
    HabitIconEntry('feather-pointed', FontAwesomeIcons.featherPointed, 'Learning', 'write poetry journal'),
    HabitIconEntry('keyboard', FontAwesomeIcons.keyboard, 'Learning', 'type write'),
    HabitIconEntry('code', FontAwesomeIcons.code, 'Learning', 'programming coding'),
    HabitIconEntry('laptop-code', FontAwesomeIcons.laptopCode, 'Learning', 'programming coding'),
    HabitIconEntry('terminal', FontAwesomeIcons.terminal, 'Learning', 'programming'),
    HabitIconEntry('flask', FontAwesomeIcons.flask, 'Learning', 'science experiment'),
    HabitIconEntry('atom', FontAwesomeIcons.atom, 'Learning', 'science'),
    HabitIconEntry('chess', FontAwesomeIcons.chess, 'Learning', 'game strategy'),
    HabitIconEntry('puzzle-piece', FontAwesomeIcons.puzzlePiece, 'Learning', 'puzzle brain'),
    // ── Productivity ──
    HabitIconEntry('list-check', FontAwesomeIcons.listCheck, 'Productivity', 'todo plan'),
    HabitIconEntry('clipboard-check', FontAwesomeIcons.clipboardCheck, 'Productivity', 'plan review'),
    HabitIconEntry('square-check', FontAwesomeIcons.solidSquareCheck, 'Productivity', 'done todo'),
    HabitIconEntry('calendar-check', FontAwesomeIcons.solidCalendarCheck, 'Productivity', 'plan schedule'),
    HabitIconEntry('briefcase', FontAwesomeIcons.briefcase, 'Productivity', 'work job'),
    HabitIconEntry('laptop', FontAwesomeIcons.laptop, 'Productivity', 'work computer'),
    HabitIconEntry('envelope', FontAwesomeIcons.solidEnvelope, 'Productivity', 'email inbox'),
    HabitIconEntry('chart-line', FontAwesomeIcons.chartLine, 'Productivity', 'progress growth'),
    HabitIconEntry('bullseye', FontAwesomeIcons.bullseye, 'Productivity', 'goal target focus'),
    HabitIconEntry('rocket', FontAwesomeIcons.rocket, 'Productivity', 'launch project'),
    HabitIconEntry('trophy', FontAwesomeIcons.trophy, 'Productivity', 'win goal'),
    HabitIconEntry('medal', FontAwesomeIcons.medal, 'Productivity', 'achievement'),
    HabitIconEntry('flag-checkered', FontAwesomeIcons.flagCheckered, 'Productivity', 'finish goal'),
    HabitIconEntry('star', FontAwesomeIcons.solidStar, 'Productivity', 'favourite general'),
    // ── Money ──
    HabitIconEntry('piggy-bank', FontAwesomeIcons.piggyBank, 'Money', 'save savings'),
    HabitIconEntry('wallet', FontAwesomeIcons.wallet, 'Money', 'budget spend'),
    HabitIconEntry('coins', FontAwesomeIcons.coins, 'Money', 'save'),
    HabitIconEntry('money-bill-wave', FontAwesomeIcons.moneyBillWave, 'Money', 'cash'),
    HabitIconEntry('sack-dollar', FontAwesomeIcons.sackDollar, 'Money', 'invest'),
    HabitIconEntry('receipt', FontAwesomeIcons.receipt, 'Money', 'expenses track'),
    HabitIconEntry('cart-shopping', FontAwesomeIcons.cartShopping, 'Money', 'shopping groceries'),
    // ── Home & life ──
    HabitIconEntry('house', FontAwesomeIcons.house, 'Home', 'chores clean'),
    HabitIconEntry('broom', FontAwesomeIcons.broom, 'Home', 'clean chores tidy'),
    HabitIconEntry('sink', FontAwesomeIcons.sink, 'Home', 'dishes chores'),
    HabitIconEntry('recycle', FontAwesomeIcons.recycle, 'Home', 'eco environment'),
    HabitIconEntry('shirt', FontAwesomeIcons.shirt, 'Home', 'laundry clothes'),
    HabitIconEntry('couch', FontAwesomeIcons.couch, 'Home', 'relax rest'),
    HabitIconEntry('dog', FontAwesomeIcons.dog, 'Home', 'pet walk dog'),
    HabitIconEntry('cat', FontAwesomeIcons.cat, 'Home', 'pet'),
    HabitIconEntry('paw', FontAwesomeIcons.paw, 'Home', 'pet'),
    HabitIconEntry('fish', FontAwesomeIcons.fish, 'Home', 'pet aquarium'),
    HabitIconEntry('dove', FontAwesomeIcons.dove, 'Home', 'peace birds'),
    HabitIconEntry('car', FontAwesomeIcons.car, 'Home', 'drive commute'),
    HabitIconEntry('plane-departure', FontAwesomeIcons.planeDeparture, 'Home', 'travel'),
    HabitIconEntry('umbrella', FontAwesomeIcons.umbrella, 'Home', 'weather'),
    // ── Social & creative ──
    HabitIconEntry('users', FontAwesomeIcons.users, 'Social', 'friends family people'),
    HabitIconEntry('user-group', FontAwesomeIcons.userGroup, 'Social', 'friends family'),
    HabitIconEntry('phone', FontAwesomeIcons.phone, 'Social', 'call family friends'),
    HabitIconEntry('comments', FontAwesomeIcons.comments, 'Social', 'chat talk'),
    HabitIconEntry('handshake', FontAwesomeIcons.handshake, 'Social', 'network meet'),
    HabitIconEntry('gift', FontAwesomeIcons.gift, 'Social', 'kindness present'),
    HabitIconEntry('music', FontAwesomeIcons.music, 'Creative', 'practice instrument'),
    HabitIconEntry('guitar', FontAwesomeIcons.guitar, 'Creative', 'practice instrument'),
    HabitIconEntry('drum', FontAwesomeIcons.drum, 'Creative', 'practice instrument'),
    HabitIconEntry('headphones', FontAwesomeIcons.headphones, 'Creative', 'listen podcast music'),
    HabitIconEntry('microphone', FontAwesomeIcons.microphone, 'Creative', 'sing podcast'),
    HabitIconEntry('paintbrush', FontAwesomeIcons.paintbrush, 'Creative', 'paint art'),
    HabitIconEntry('palette', FontAwesomeIcons.palette, 'Creative', 'paint art draw'),
    HabitIconEntry('camera', FontAwesomeIcons.camera, 'Creative', 'photo photography'),
    HabitIconEntry('camera-retro', FontAwesomeIcons.cameraRetro, 'Creative', 'photo'),
    HabitIconEntry('film', FontAwesomeIcons.film, 'Creative', 'movie video'),
    HabitIconEntry('dice', FontAwesomeIcons.dice, 'Creative', 'game play'),
  ];
  // dart format on
}
