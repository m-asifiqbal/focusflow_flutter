/// ============================================================
/// WORLD CITIES — an offline gazetteer for prayer locations
/// ============================================================
///
/// What: ~545 cities with coordinates — every Bangladeshi district
/// headquarters (all 64), the major cities of the countries with large
/// Muslim communities plus the UK, USA, Canada and Australia, and every
/// national capital. Used for (a) "Search a city" when location access is
/// denied and (b) naming GPS coordinates ("Near Dhaka") — both without a
/// network geocoder (CLAUDE.md rule 1). Also feeds
/// `PrayerCalcMethod.suggestedFor` (country of the nearest city).
/// Names are English exonyms and proper nouns, so they are not translated;
/// older spellings ("Chittagong", "Bombay") are kept as search aliases.
/// Coordinates are city centres to ~0.01° — plenty for sun times (1° of
/// longitude moves them by 4 minutes).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';

/// One city of the offline list.
@immutable
class WorldCity {
  const WorldCity(
    this.name,
    this.country,
    this.latitude,
    this.longitude, [
    this.aliases = const [],
  ]);

  final String name;
  final String country;
  final double latitude;
  final double longitude;

  /// Other spellings the search also matches (never shown).
  final List<String> aliases;

  GeoPoint get point => GeoPoint(latitude, longitude);

  /// "Dhaka, Bangladesh".
  String get label => '$name, $country';

  @override
  bool operator ==(Object other) =>
      other is WorldCity &&
      other.name == name &&
      other.country == country &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(name, country, latitude, longitude);

  @override
  String toString() => 'WorldCity($label)';
}

abstract final class WorldCities {
  /// Search: exact name, then name prefix, then a word of the name, then
  /// the country, then anywhere in "name country" — each tier in list order
  /// (Bangladesh first, then roughly by region).
  static List<WorldCity> search(String query, {int limit = 20}) {
    final q = _fold(query);
    if (q.isEmpty || limit <= 0) return const [];
    final tiers = List.generate(5, (_) => <WorldCity>[]);
    for (var i = 0; i < all.length; i++) {
      final tier = _tierOf(_keys[i], q);
      if (tier != null) tiers[tier].add(all[i]);
    }
    return tiers.expand((t) => t).take(limit).toList();
  }

  /// The nearest city to [p] and its distance in km; null when none is
  /// within [maxKm].
  static ({WorldCity city, double km})? nearest(
    GeoPoint p, {
    double maxKm = 150,
  }) {
    WorldCity? best;
    var bestKm = double.infinity;
    for (final c in all) {
      final km = p.distanceKm(c.point);
      if (km < bestKm) {
        best = c;
        bestKm = km;
      }
    }
    if (best == null || bestKm > maxKm) return null;
    return (city: best, km: bestKm);
  }

  static int? _tierOf(_Key k, String q) {
    if (k.names.any((n) => n == q)) return 0;
    if (k.names.any((n) => n.startsWith(q))) return 1;
    if (k.names.any((n) => n.contains(' $q'))) return 2;
    if (k.country.startsWith(q) || k.country.contains(' $q')) return 3;
    if (k.all.contains(q)) return 4;
    return null;
  }

  /// Folded search keys, built once on first search.
  static final List<_Key> _keys = [
    for (final c in all)
      _Key(
        [_fold(c.name), for (final a in c.aliases) _fold(a)],
        _fold(c.country),
        _fold('${c.name} ${c.country} ${c.aliases.join(' ')}'),
      ),
  ];

  /// Lower case, accents and apostrophes removed, '-' / '.' / ',' as
  /// spaces, single spaces: "Cox's Bazar" → "coxs bazar",
  /// "Bogotá" → "bogota", "Port-au-Prince" → "port au prince".
  static String _fold(String s) {
    final out = StringBuffer();
    for (final r in s.toLowerCase().runes) {
      if (r >= 0x300 && r <= 0x36F) continue; // combining marks
      final c = String.fromCharCode(r);
      if ("'’ʻ`".contains(c)) continue;
      if ('-.,/'.contains(c)) {
        out.write(' ');
        continue;
      }
      out.write(_plain[r] ?? c);
    }
    return out.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static final Map<int, String> _plain = {
    for (final e in const {
      'a': 'àáâãäåāăą',
      'c': 'çćč',
      'd': 'ďđ',
      'e': 'èéêëēėęě',
      'g': 'ğ',
      'i': 'ìíîïīıį',
      'l': 'ł',
      'n': 'ñńň',
      'o': 'òóôõöøōő',
      'r': 'ř',
      's': 'śşšș',
      't': 'ťţț',
      'u': 'ùúûüūůű',
      'y': 'ýÿ',
      'z': 'źżž',
      'ss': 'ß',
      'ae': 'æ',
      'oe': 'œ',
    }.entries)
      for (final r in e.value.runes) r: e.key,
  };

  /// The list. Bangladesh first (all 64 district headquarters), then by
  /// region; each country's capital before its other cities.
  static const List<WorldCity> all = [
    // Bangladesh — Dhaka division.
    WorldCity('Dhaka', 'Bangladesh', 23.8103, 90.4125),
    WorldCity('Gazipur', 'Bangladesh', 23.9999, 90.4203),
    WorldCity('Narayanganj', 'Bangladesh', 23.6238, 90.5000),
    WorldCity('Narsingdi', 'Bangladesh', 23.9229, 90.7177),
    WorldCity('Manikganj', 'Bangladesh', 23.8617, 90.0003),
    WorldCity('Munshiganj', 'Bangladesh', 23.5422, 90.5305),
    WorldCity('Faridpur', 'Bangladesh', 23.6070, 89.8429),
    WorldCity('Gopalganj', 'Bangladesh', 23.0050, 89.8266),
    WorldCity('Madaripur', 'Bangladesh', 23.1641, 90.1897),
    WorldCity('Rajbari', 'Bangladesh', 23.7574, 89.6445),
    WorldCity('Shariatpur', 'Bangladesh', 23.2167, 90.3500),
    WorldCity('Kishoreganj', 'Bangladesh', 24.4449, 90.7766),
    WorldCity('Tangail', 'Bangladesh', 24.2513, 89.9167),
    // Bangladesh — Chattogram division.
    WorldCity('Chattogram', 'Bangladesh', 22.3569, 91.7832, ['Chittagong']),
    WorldCity("Cox's Bazar", 'Bangladesh', 21.4272, 92.0058),
    WorldCity('Rangamati', 'Bangladesh', 22.6533, 92.1750),
    WorldCity('Bandarban', 'Bangladesh', 22.1953, 92.2184),
    WorldCity('Khagrachhari', 'Bangladesh', 23.1193, 91.9847, ['Khagrachari']),
    WorldCity('Feni', 'Bangladesh', 23.0159, 91.3976),
    WorldCity('Noakhali', 'Bangladesh', 22.8696, 91.0995, ['Maijdee']),
    WorldCity('Lakshmipur', 'Bangladesh', 22.9447, 90.8282, ['Laxmipur']),
    WorldCity('Cumilla', 'Bangladesh', 23.4607, 91.1809, ['Comilla']),
    WorldCity('Chandpur', 'Bangladesh', 23.2333, 90.6713),
    WorldCity('Brahmanbaria', 'Bangladesh', 23.9571, 91.1119),
    // Bangladesh — Rajshahi division.
    WorldCity('Rajshahi', 'Bangladesh', 24.3745, 88.6042),
    WorldCity('Bogura', 'Bangladesh', 24.8466, 89.3773, ['Bogra']),
    WorldCity('Joypurhat', 'Bangladesh', 25.0968, 89.0227),
    WorldCity('Naogaon', 'Bangladesh', 24.7936, 88.9318),
    WorldCity('Natore', 'Bangladesh', 24.4102, 89.0076),
    WorldCity('Chapainawabganj', 'Bangladesh', 24.5965, 88.2776, ['Nawabganj']),
    WorldCity('Pabna', 'Bangladesh', 24.0064, 89.2372),
    WorldCity('Sirajganj', 'Bangladesh', 24.4534, 89.7007),
    // Bangladesh — Khulna division.
    WorldCity('Khulna', 'Bangladesh', 22.8456, 89.5403),
    WorldCity('Bagerhat', 'Bangladesh', 22.6516, 89.7859),
    WorldCity('Satkhira', 'Bangladesh', 22.7185, 89.0705),
    WorldCity('Jashore', 'Bangladesh', 23.1664, 89.2081, ['Jessore']),
    WorldCity('Jhenaidah', 'Bangladesh', 23.5448, 89.1726),
    WorldCity('Magura', 'Bangladesh', 23.4873, 89.4199),
    WorldCity('Narail', 'Bangladesh', 23.1725, 89.5126),
    WorldCity('Kushtia', 'Bangladesh', 23.9013, 89.1205),
    WorldCity('Chuadanga', 'Bangladesh', 23.6402, 88.8418),
    WorldCity('Meherpur', 'Bangladesh', 23.7622, 88.6318),
    // Bangladesh — Barishal division.
    WorldCity('Barishal', 'Bangladesh', 22.7010, 90.3535, ['Barisal']),
    WorldCity('Bhola', 'Bangladesh', 22.6859, 90.6482),
    WorldCity('Patuakhali', 'Bangladesh', 22.3596, 90.3299),
    WorldCity('Pirojpur', 'Bangladesh', 22.5841, 89.9720),
    WorldCity('Jhalokathi', 'Bangladesh', 22.6406, 90.1987, ['Jhalakati']),
    WorldCity('Barguna', 'Bangladesh', 22.1591, 90.1262),
    // Bangladesh — Sylhet division.
    WorldCity('Sylhet', 'Bangladesh', 24.8949, 91.8687),
    WorldCity('Moulvibazar', 'Bangladesh', 24.4829, 91.7774, ['Maulvibazar']),
    WorldCity('Habiganj', 'Bangladesh', 24.3745, 91.4155),
    WorldCity('Sunamganj', 'Bangladesh', 25.0658, 91.3950),
    // Bangladesh — Rangpur division.
    WorldCity('Rangpur', 'Bangladesh', 25.7439, 89.2752),
    WorldCity('Dinajpur', 'Bangladesh', 25.6217, 88.6355),
    WorldCity('Kurigram', 'Bangladesh', 25.8054, 89.6362),
    WorldCity('Gaibandha', 'Bangladesh', 25.3288, 89.5285),
    WorldCity('Nilphamari', 'Bangladesh', 25.9318, 88.8560),
    WorldCity('Lalmonirhat', 'Bangladesh', 25.9923, 89.2847),
    WorldCity('Thakurgaon', 'Bangladesh', 26.0336, 88.4616),
    WorldCity('Panchagarh', 'Bangladesh', 26.3411, 88.5542),
    // Bangladesh — Mymensingh division.
    WorldCity('Mymensingh', 'Bangladesh', 24.7471, 90.4203),
    WorldCity('Jamalpur', 'Bangladesh', 24.9375, 89.9378),
    WorldCity('Sherpur', 'Bangladesh', 25.0205, 90.0153),
    WorldCity('Netrokona', 'Bangladesh', 24.8709, 90.7279, ['Netrakona']),
    // South Asia.
    WorldCity('New Delhi', 'India', 28.6139, 77.2090, ['Delhi']),
    WorldCity('Mumbai', 'India', 19.0760, 72.8777, ['Bombay']),
    WorldCity('Kolkata', 'India', 22.5726, 88.3639, ['Calcutta']),
    WorldCity('Chennai', 'India', 13.0827, 80.2707, ['Madras']),
    WorldCity('Bengaluru', 'India', 12.9716, 77.5946, ['Bangalore']),
    WorldCity('Hyderabad', 'India', 17.3850, 78.4867),
    WorldCity('Ahmedabad', 'India', 23.0225, 72.5714),
    WorldCity('Pune', 'India', 18.5204, 73.8567),
    WorldCity('Surat', 'India', 21.1702, 72.8311),
    WorldCity('Jaipur', 'India', 26.9124, 75.7873),
    WorldCity('Lucknow', 'India', 26.8467, 80.9462),
    WorldCity('Kanpur', 'India', 26.4499, 80.3319),
    WorldCity('Nagpur', 'India', 21.1458, 79.0882),
    WorldCity('Indore', 'India', 22.7196, 75.8577),
    WorldCity('Bhopal', 'India', 23.2599, 77.4126),
    WorldCity('Patna', 'India', 25.5941, 85.1376),
    WorldCity('Varanasi', 'India', 25.3176, 82.9739),
    WorldCity('Agra', 'India', 27.1767, 78.0081),
    WorldCity('Amritsar', 'India', 31.6340, 74.8723),
    WorldCity('Chandigarh', 'India', 30.7333, 76.7794),
    WorldCity('Srinagar', 'India', 34.0837, 74.7973),
    WorldCity('Guwahati', 'India', 26.1445, 91.7362),
    WorldCity('Shillong', 'India', 25.5788, 91.8933),
    WorldCity('Agartala', 'India', 23.8315, 91.2868),
    WorldCity('Siliguri', 'India', 26.7271, 88.3953),
    WorldCity('Bhubaneswar', 'India', 20.2961, 85.8245),
    WorldCity('Visakhapatnam', 'India', 17.6868, 83.2185),
    WorldCity('Kochi', 'India', 9.9312, 76.2673, ['Cochin']),
    WorldCity('Kozhikode', 'India', 11.2588, 75.7804, ['Calicut']),
    WorldCity('Thiruvananthapuram', 'India', 8.5241, 76.9366, ['Trivandrum']),
    WorldCity('Islamabad', 'Pakistan', 33.6844, 73.0479),
    WorldCity('Karachi', 'Pakistan', 24.8607, 67.0011),
    WorldCity('Lahore', 'Pakistan', 31.5204, 74.3587),
    WorldCity('Faisalabad', 'Pakistan', 31.4504, 73.1350),
    WorldCity('Rawalpindi', 'Pakistan', 33.5651, 73.0169),
    WorldCity('Multan', 'Pakistan', 30.1575, 71.5249),
    WorldCity('Hyderabad', 'Pakistan', 25.3960, 68.3578),
    WorldCity('Peshawar', 'Pakistan', 34.0151, 71.5249),
    WorldCity('Quetta', 'Pakistan', 30.1798, 66.9750),
    WorldCity('Gujranwala', 'Pakistan', 32.1877, 74.1945),
    WorldCity('Sialkot', 'Pakistan', 32.4945, 74.5229),
    WorldCity('Bahawalpur', 'Pakistan', 29.3956, 71.6836),
    WorldCity('Sukkur', 'Pakistan', 27.7052, 68.8574),
    WorldCity('Kabul', 'Afghanistan', 34.5553, 69.2075),
    WorldCity('Kandahar', 'Afghanistan', 31.6289, 65.7372),
    WorldCity('Herat', 'Afghanistan', 34.3529, 62.2040),
    WorldCity('Mazar-i-Sharif', 'Afghanistan', 36.7090, 67.1109),
    WorldCity('Kathmandu', 'Nepal', 27.7172, 85.3240),
    WorldCity('Thimphu', 'Bhutan', 27.4728, 89.6390),
    WorldCity('Sri Jayawardenepura Kotte', 'Sri Lanka', 6.8868, 79.9187),
    WorldCity('Colombo', 'Sri Lanka', 6.9271, 79.8612),
    WorldCity('Malé', 'Maldives', 4.1755, 73.5093),
    // Arabian Peninsula.
    WorldCity('Riyadh', 'Saudi Arabia', 24.7136, 46.6753),
    WorldCity('Makkah', 'Saudi Arabia', 21.3891, 39.8579, ['Mecca']),
    WorldCity('Medina', 'Saudi Arabia', 24.5247, 39.5692, ['Madinah']),
    WorldCity('Jeddah', 'Saudi Arabia', 21.4858, 39.1925, ['Jidda']),
    WorldCity('Dammam', 'Saudi Arabia', 26.4207, 50.0888),
    WorldCity('Khobar', 'Saudi Arabia', 26.2172, 50.1971, ['Al Khobar']),
    WorldCity('Hofuf', 'Saudi Arabia', 25.3647, 49.5876, ['Al Ahsa']),
    WorldCity('Taif', 'Saudi Arabia', 21.2703, 40.4158),
    WorldCity('Tabuk', 'Saudi Arabia', 28.3835, 36.5662),
    WorldCity('Buraydah', 'Saudi Arabia', 26.3260, 43.9750),
    WorldCity('Hail', 'Saudi Arabia', 27.5114, 41.7208),
    WorldCity('Abha', 'Saudi Arabia', 18.2164, 42.5053),
    WorldCity('Jizan', 'Saudi Arabia', 16.8892, 42.5511),
    WorldCity('Najran', 'Saudi Arabia', 17.5656, 44.2289),
    WorldCity('Abu Dhabi', 'United Arab Emirates', 24.4539, 54.3773),
    WorldCity('Dubai', 'United Arab Emirates', 25.2048, 55.2708),
    WorldCity('Sharjah', 'United Arab Emirates', 25.3463, 55.4209),
    WorldCity('Ajman', 'United Arab Emirates', 25.4052, 55.5136),
    WorldCity('Al Ain', 'United Arab Emirates', 24.2075, 55.7447),
    WorldCity('Ras Al Khaimah', 'United Arab Emirates', 25.8007, 55.9762),
    WorldCity('Fujairah', 'United Arab Emirates', 25.1288, 56.3265),
    WorldCity('Doha', 'Qatar', 25.2854, 51.5310),
    WorldCity('Al Wakrah', 'Qatar', 25.1659, 51.5976),
    WorldCity('Kuwait City', 'Kuwait', 29.3759, 47.9774),
    WorldCity('Al Jahra', 'Kuwait', 29.3375, 47.6581),
    WorldCity('Manama', 'Bahrain', 26.2285, 50.5860),
    WorldCity('Muharraq', 'Bahrain', 26.2572, 50.6119),
    WorldCity('Muscat', 'Oman', 23.5880, 58.3829),
    WorldCity('Salalah', 'Oman', 17.0151, 54.0924),
    WorldCity('Sohar', 'Oman', 24.3470, 56.7097),
    WorldCity('Nizwa', 'Oman', 22.9333, 57.5333),
    WorldCity('Sanaa', 'Yemen', 15.3694, 44.1910, ["Sana'a"]),
    WorldCity('Aden', 'Yemen', 12.7855, 45.0187),
    WorldCity('Taiz', 'Yemen', 13.5795, 44.0209),
    WorldCity('Hodeidah', 'Yemen', 14.7978, 42.9545),
    WorldCity('Mukalla', 'Yemen', 14.5425, 49.1242),
    // Levant, Iraq, Iran, Turkey, Caucasus.
    WorldCity('Baghdad', 'Iraq', 33.3152, 44.3661),
    WorldCity('Basra', 'Iraq', 30.5085, 47.7804),
    WorldCity('Mosul', 'Iraq', 36.3489, 43.1577),
    WorldCity('Erbil', 'Iraq', 36.1911, 44.0092),
    WorldCity('Najaf', 'Iraq', 32.0259, 44.3462),
    WorldCity('Karbala', 'Iraq', 32.6160, 44.0249),
    WorldCity('Kirkuk', 'Iraq', 35.4681, 44.3922),
    WorldCity('Sulaymaniyah', 'Iraq', 35.5613, 45.4304),
    WorldCity('Nasiriyah', 'Iraq', 31.0439, 46.2575),
    WorldCity('Tehran', 'Iran', 35.6892, 51.3890),
    WorldCity('Mashhad', 'Iran', 36.2605, 59.6168),
    WorldCity('Isfahan', 'Iran', 32.6546, 51.6680),
    WorldCity('Karaj', 'Iran', 35.8400, 50.9391),
    WorldCity('Shiraz', 'Iran', 29.5918, 52.5837),
    WorldCity('Tabriz', 'Iran', 38.0962, 46.2738),
    WorldCity('Qom', 'Iran', 34.6416, 50.8746),
    WorldCity('Ahvaz', 'Iran', 31.3183, 48.6706),
    WorldCity('Kermanshah', 'Iran', 34.3142, 47.0650),
    WorldCity('Urmia', 'Iran', 37.5527, 45.0761),
    WorldCity('Rasht', 'Iran', 37.2808, 49.5832),
    WorldCity('Kerman', 'Iran', 30.2839, 57.0834),
    WorldCity('Yazd', 'Iran', 31.8974, 54.3569),
    WorldCity('Zahedan', 'Iran', 29.4963, 60.8629),
    WorldCity('Bandar Abbas', 'Iran', 27.1832, 56.2666),
    WorldCity('Bushehr', 'Iran', 28.9234, 50.8203),
    WorldCity('Amman', 'Jordan', 31.9454, 35.9284),
    WorldCity('Zarqa', 'Jordan', 32.0728, 36.0880),
    WorldCity('Irbid', 'Jordan', 32.5556, 35.8500),
    WorldCity('Aqaba', 'Jordan', 29.5321, 35.0063),
    WorldCity('Damascus', 'Syria', 33.5138, 36.2765),
    WorldCity('Aleppo', 'Syria', 36.2021, 37.1343),
    WorldCity('Homs', 'Syria', 34.7324, 36.7137),
    WorldCity('Latakia', 'Syria', 35.5317, 35.7901),
    WorldCity('Beirut', 'Lebanon', 33.8938, 35.5018),
    WorldCity('Tripoli', 'Lebanon', 34.4367, 35.8497),
    WorldCity('Sidon', 'Lebanon', 33.5571, 35.3729),
    WorldCity('Ramallah', 'Palestine', 31.9038, 35.2034),
    WorldCity('Gaza', 'Palestine', 31.5017, 34.4668),
    WorldCity('Hebron', 'Palestine', 31.5326, 35.0998),
    WorldCity('Nablus', 'Palestine', 32.2211, 35.2544),
    WorldCity('Tel Aviv', 'Israel', 32.0853, 34.7818),
    WorldCity('Haifa', 'Israel', 32.7940, 34.9896),
    WorldCity('Nicosia', 'Cyprus', 35.1856, 33.3823),
    WorldCity('Ankara', 'Turkey', 39.9334, 32.8597),
    WorldCity('Istanbul', 'Turkey', 41.0082, 28.9784),
    WorldCity('Izmir', 'Turkey', 38.4237, 27.1428),
    WorldCity('Bursa', 'Turkey', 40.1885, 29.0610),
    WorldCity('Antalya', 'Turkey', 36.8969, 30.7133),
    WorldCity('Adana', 'Turkey', 37.0000, 35.3213),
    WorldCity('Mersin', 'Turkey', 36.8121, 34.6415),
    WorldCity('Konya', 'Turkey', 37.8746, 32.4932),
    WorldCity('Kayseri', 'Turkey', 38.7312, 35.4787),
    WorldCity('Gaziantep', 'Turkey', 37.0662, 37.3833),
    WorldCity('Şanlıurfa', 'Turkey', 37.1591, 38.7969, ['Urfa']),
    WorldCity('Diyarbakır', 'Turkey', 37.9144, 40.2306),
    WorldCity('Erzurum', 'Turkey', 39.9043, 41.2679),
    WorldCity('Trabzon', 'Turkey', 41.0027, 39.7168),
    WorldCity('Baku', 'Azerbaijan', 40.4093, 49.8671),
    WorldCity('Tbilisi', 'Georgia', 41.7151, 44.8271),
    WorldCity('Yerevan', 'Armenia', 40.1792, 44.4991),
    // Central Asia.
    WorldCity('Astana', 'Kazakhstan', 51.1694, 71.4491),
    WorldCity('Almaty', 'Kazakhstan', 43.2220, 76.8512),
    WorldCity('Tashkent', 'Uzbekistan', 41.2995, 69.2401),
    WorldCity('Samarkand', 'Uzbekistan', 39.6270, 66.9750),
    WorldCity('Bishkek', 'Kyrgyzstan', 42.8746, 74.5698),
    WorldCity('Dushanbe', 'Tajikistan', 38.5598, 68.7870),
    WorldCity('Ashgabat', 'Turkmenistan', 37.9601, 58.3261),
    // Southeast Asia.
    WorldCity('Jakarta', 'Indonesia', -6.2088, 106.8456),
    WorldCity('Surabaya', 'Indonesia', -7.2575, 112.7521),
    WorldCity('Bandung', 'Indonesia', -6.9175, 107.6191),
    WorldCity('Medan', 'Indonesia', 3.5952, 98.6722),
    WorldCity('Semarang', 'Indonesia', -6.9667, 110.4167),
    WorldCity('Makassar', 'Indonesia', -5.1477, 119.4327),
    WorldCity('Palembang', 'Indonesia', -2.9761, 104.7754),
    WorldCity('Yogyakarta', 'Indonesia', -7.7956, 110.3695),
    WorldCity('Denpasar', 'Indonesia', -8.6705, 115.2126),
    WorldCity('Banda Aceh', 'Indonesia', 5.5483, 95.3238),
    WorldCity('Pontianak', 'Indonesia', -0.0263, 109.3425),
    WorldCity('Balikpapan', 'Indonesia', -1.2379, 116.8529),
    WorldCity('Manado', 'Indonesia', 1.4748, 124.8421),
    WorldCity('Jayapura', 'Indonesia', -2.5337, 140.7181),
    WorldCity('Kuala Lumpur', 'Malaysia', 3.1390, 101.6869),
    WorldCity('Putrajaya', 'Malaysia', 2.9264, 101.6964),
    WorldCity('George Town', 'Malaysia', 5.4141, 100.3288, ['Penang']),
    WorldCity('Johor Bahru', 'Malaysia', 1.4927, 103.7414),
    WorldCity('Ipoh', 'Malaysia', 4.5975, 101.0901),
    WorldCity('Kota Bharu', 'Malaysia', 6.1254, 102.2381),
    WorldCity('Kuantan', 'Malaysia', 3.8077, 103.3260),
    WorldCity('Kota Kinabalu', 'Malaysia', 5.9804, 116.0735),
    WorldCity('Kuching', 'Malaysia', 1.5533, 110.3592),
    WorldCity('Singapore', 'Singapore', 1.3521, 103.8198),
    WorldCity('Bandar Seri Begawan', 'Brunei', 4.9031, 114.9398),
    WorldCity('Bangkok', 'Thailand', 13.7563, 100.5018),
    WorldCity('Pattani', 'Thailand', 6.8691, 101.2501),
    WorldCity('Manila', 'Philippines', 14.5995, 120.9842),
    WorldCity('Davao', 'Philippines', 7.1907, 125.4553),
    WorldCity('Zamboanga', 'Philippines', 6.9214, 122.0790),
    WorldCity('Hanoi', 'Vietnam', 21.0278, 105.8342),
    WorldCity('Ho Chi Minh City', 'Vietnam', 10.8231, 106.6297, ['Saigon']),
    WorldCity('Phnom Penh', 'Cambodia', 11.5564, 104.9282),
    WorldCity('Vientiane', 'Laos', 17.9757, 102.6331),
    WorldCity('Naypyidaw', 'Myanmar', 19.7633, 96.0785),
    WorldCity('Yangon', 'Myanmar', 16.8409, 96.1735, ['Rangoon']),
    WorldCity('Dili', 'East Timor', -8.5569, 125.5603),
    // East Asia.
    WorldCity('Beijing', 'China', 39.9042, 116.4074),
    WorldCity('Shanghai', 'China', 31.2304, 121.4737),
    WorldCity('Guangzhou', 'China', 23.1291, 113.2644),
    WorldCity('Urumqi', 'China', 43.8256, 87.6168),
    WorldCity('Hong Kong', 'China', 22.3193, 114.1694),
    WorldCity('Taipei', 'Taiwan', 25.0330, 121.5654),
    WorldCity('Tokyo', 'Japan', 35.6762, 139.6503),
    WorldCity('Osaka', 'Japan', 34.6937, 135.5023),
    WorldCity('Seoul', 'South Korea', 37.5665, 126.9780),
    WorldCity('Pyongyang', 'North Korea', 39.0392, 125.7625),
    WorldCity('Ulaanbaatar', 'Mongolia', 47.8864, 106.9057),
    // North Africa.
    WorldCity('Cairo', 'Egypt', 30.0444, 31.2357),
    WorldCity('Alexandria', 'Egypt', 31.2001, 29.9187),
    WorldCity('Giza', 'Egypt', 30.0131, 31.2089),
    WorldCity('Port Said', 'Egypt', 31.2653, 32.3019),
    WorldCity('Suez', 'Egypt', 29.9668, 32.5498),
    WorldCity('Mansoura', 'Egypt', 31.0409, 31.3785),
    WorldCity('Asyut', 'Egypt', 27.1783, 31.1859),
    WorldCity('Luxor', 'Egypt', 25.6872, 32.6396),
    WorldCity('Aswan', 'Egypt', 24.0889, 32.8998),
    WorldCity('Hurghada', 'Egypt', 27.2579, 33.8116),
    WorldCity('Khartoum', 'Sudan', 15.5007, 32.5599),
    WorldCity('Omdurman', 'Sudan', 15.6445, 32.4777),
    WorldCity('Port Sudan', 'Sudan', 19.6158, 37.2164),
    WorldCity('Tripoli', 'Libya', 32.8872, 13.1913),
    WorldCity('Benghazi', 'Libya', 32.1167, 20.0667),
    WorldCity('Misrata', 'Libya', 32.3754, 15.0925),
    WorldCity('Tunis', 'Tunisia', 36.8065, 10.1815),
    WorldCity('Sfax', 'Tunisia', 34.7406, 10.7603),
    WorldCity('Sousse', 'Tunisia', 35.8256, 10.6084),
    WorldCity('Kairouan', 'Tunisia', 35.6781, 10.0963),
    WorldCity('Algiers', 'Algeria', 36.7538, 3.0588),
    WorldCity('Oran', 'Algeria', 35.6971, -0.6308),
    WorldCity('Constantine', 'Algeria', 36.3650, 6.6147),
    WorldCity('Annaba', 'Algeria', 36.9000, 7.7667),
    WorldCity('Blida', 'Algeria', 36.4700, 2.8277),
    WorldCity('Sétif', 'Algeria', 36.1911, 5.4137),
    WorldCity('Tlemcen', 'Algeria', 34.8783, -1.3150),
    WorldCity('Rabat', 'Morocco', 34.0209, -6.8416),
    WorldCity('Casablanca', 'Morocco', 33.5731, -7.5898),
    WorldCity('Marrakesh', 'Morocco', 31.6295, -7.9811, ['Marrakech']),
    WorldCity('Fes', 'Morocco', 34.0181, -5.0078, ['Fez']),
    WorldCity('Tangier', 'Morocco', 35.7595, -5.8340),
    WorldCity('Meknes', 'Morocco', 33.8935, -5.5473),
    WorldCity('Agadir', 'Morocco', 30.4278, -9.5981),
    WorldCity('Oujda', 'Morocco', 34.6814, -1.9086),
    WorldCity('Nouakchott', 'Mauritania', 18.0735, -15.9582),
    // West and Central Africa.
    WorldCity('Dakar', 'Senegal', 14.7167, -17.4677),
    WorldCity('Touba', 'Senegal', 14.8500, -15.8833),
    WorldCity('Banjul', 'Gambia', 13.4549, -16.5790),
    WorldCity('Bissau', 'Guinea-Bissau', 11.8636, -15.5977),
    WorldCity('Conakry', 'Guinea', 9.6412, -13.5784),
    WorldCity('Freetown', 'Sierra Leone', 8.4657, -13.2317),
    WorldCity('Monrovia', 'Liberia', 6.3156, -10.8074),
    WorldCity('Yamoussoukro', 'Ivory Coast', 6.8276, -5.2893),
    WorldCity('Abidjan', 'Ivory Coast', 5.3600, -4.0083),
    WorldCity('Bamako', 'Mali', 12.6392, -8.0029),
    WorldCity('Ouagadougou', 'Burkina Faso', 12.3714, -1.5197),
    WorldCity('Niamey', 'Niger', 13.5116, 2.1254),
    WorldCity('Accra', 'Ghana', 5.6037, -0.1870),
    WorldCity('Kumasi', 'Ghana', 6.6885, -1.6244),
    WorldCity('Lomé', 'Togo', 6.1375, 1.2123),
    WorldCity('Porto-Novo', 'Benin', 6.4969, 2.6289),
    WorldCity('Cotonou', 'Benin', 6.3703, 2.3912),
    WorldCity('Abuja', 'Nigeria', 9.0765, 7.3986),
    WorldCity('Lagos', 'Nigeria', 6.5244, 3.3792),
    WorldCity('Kano', 'Nigeria', 12.0022, 8.5920),
    WorldCity('Ibadan', 'Nigeria', 7.3775, 3.9470),
    WorldCity('Kaduna', 'Nigeria', 10.5105, 7.4165),
    WorldCity('Zaria', 'Nigeria', 11.0855, 7.7199),
    WorldCity('Sokoto', 'Nigeria', 13.0059, 5.2476),
    WorldCity('Maiduguri', 'Nigeria', 11.8311, 13.1510),
    WorldCity('Ilorin', 'Nigeria', 8.4966, 4.5421),
    WorldCity('Port Harcourt', 'Nigeria', 4.8156, 7.0498),
    WorldCity('Yaoundé', 'Cameroon', 3.8480, 11.5021),
    WorldCity('Douala', 'Cameroon', 4.0511, 9.7679),
    WorldCity("N'Djamena", 'Chad', 12.1348, 15.0557),
    WorldCity('Bangui', 'Central African Republic', 4.3947, 18.5582),
    WorldCity('Malabo', 'Equatorial Guinea', 3.7504, 8.7371),
    WorldCity('Libreville', 'Gabon', 0.4162, 9.4673),
    WorldCity('São Tomé', 'São Tomé and Príncipe', 0.3365, 6.7273),
    WorldCity('Brazzaville', 'Republic of the Congo', -4.2634, 15.2429),
    WorldCity('Kinshasa', 'DR Congo', -4.4419, 15.2663),
    WorldCity('Luanda', 'Angola', -8.8390, 13.2894),
    WorldCity('Praia', 'Cape Verde', 14.9330, -23.5133),
    // East Africa.
    WorldCity('Addis Ababa', 'Ethiopia', 9.0300, 38.7400),
    WorldCity('Asmara', 'Eritrea', 15.3229, 38.9251),
    WorldCity('Djibouti', 'Djibouti', 11.5721, 43.1456),
    WorldCity('Mogadishu', 'Somalia', 2.0469, 45.3182),
    WorldCity('Hargeisa', 'Somalia', 9.5600, 44.0650),
    WorldCity('Nairobi', 'Kenya', -1.2921, 36.8219),
    WorldCity('Mombasa', 'Kenya', -4.0435, 39.6682),
    WorldCity('Kisumu', 'Kenya', -0.0917, 34.7680),
    WorldCity('Nakuru', 'Kenya', -0.3031, 36.0800),
    WorldCity('Kampala', 'Uganda', 0.3476, 32.5825),
    WorldCity('Kigali', 'Rwanda', -1.9441, 30.0619),
    WorldCity('Gitega', 'Burundi', -3.4264, 29.9306),
    WorldCity('Bujumbura', 'Burundi', -3.3614, 29.3599),
    WorldCity('Dodoma', 'Tanzania', -6.1630, 35.7516),
    WorldCity('Dar es Salaam', 'Tanzania', -6.7924, 39.2083),
    WorldCity('Zanzibar City', 'Tanzania', -6.1659, 39.2026, ['Zanzibar']),
    WorldCity('Juba', 'South Sudan', 4.8594, 31.5713),
    WorldCity('Moroni', 'Comoros', -11.7172, 43.2473),
    WorldCity('Victoria', 'Seychelles', -4.6191, 55.4513),
    WorldCity('Port Louis', 'Mauritius', -20.1609, 57.5012),
    WorldCity('Antananarivo', 'Madagascar', -18.8792, 47.5079),
    // Southern Africa.
    WorldCity('Pretoria', 'South Africa', -25.7479, 28.2293),
    WorldCity('Cape Town', 'South Africa', -33.9249, 18.4241),
    WorldCity('Johannesburg', 'South Africa', -26.2041, 28.0473),
    WorldCity('Durban', 'South Africa', -29.8587, 31.0218),
    WorldCity('Gqeberha', 'South Africa', -33.9608, 25.6022, [
      'Port Elizabeth',
    ]),
    WorldCity('Bloemfontein', 'South Africa', -29.0852, 26.1596),
    WorldCity('Lilongwe', 'Malawi', -13.9626, 33.7741),
    WorldCity('Lusaka', 'Zambia', -15.3875, 28.3228),
    WorldCity('Harare', 'Zimbabwe', -17.8252, 31.0335),
    WorldCity('Maputo', 'Mozambique', -25.9692, 32.5732),
    WorldCity('Gaborone', 'Botswana', -24.6282, 25.9231),
    WorldCity('Windhoek', 'Namibia', -22.5609, 17.0658),
    WorldCity('Maseru', 'Lesotho', -29.3151, 27.4869),
    WorldCity('Mbabane', 'Eswatini', -26.3054, 31.1367),
    // Europe.
    WorldCity('London', 'United Kingdom', 51.5074, -0.1278),
    WorldCity('Birmingham', 'United Kingdom', 52.4862, -1.8904),
    WorldCity('Manchester', 'United Kingdom', 53.4808, -2.2426),
    WorldCity('Leeds', 'United Kingdom', 53.8008, -1.5491),
    WorldCity('Bradford', 'United Kingdom', 53.7960, -1.7594),
    WorldCity('Sheffield', 'United Kingdom', 53.3811, -1.4701),
    WorldCity('Liverpool', 'United Kingdom', 53.4084, -2.9916),
    WorldCity('Leicester', 'United Kingdom', 52.6369, -1.1398),
    WorldCity('Bristol', 'United Kingdom', 51.4545, -2.5879),
    WorldCity('Cardiff', 'United Kingdom', 51.4816, -3.1791),
    WorldCity('Glasgow', 'United Kingdom', 55.8642, -4.2518),
    WorldCity('Edinburgh', 'United Kingdom', 55.9533, -3.1883),
    WorldCity('Belfast', 'United Kingdom', 54.5973, -5.9301),
    WorldCity('Dublin', 'Ireland', 53.3498, -6.2603),
    WorldCity('Paris', 'France', 48.8566, 2.3522),
    WorldCity('Marseille', 'France', 43.2965, 5.3698),
    WorldCity('Lyon', 'France', 45.7640, 4.8357),
    WorldCity('Berlin', 'Germany', 52.5200, 13.4050),
    WorldCity('Hamburg', 'Germany', 53.5511, 9.9937),
    WorldCity('Munich', 'Germany', 48.1351, 11.5820),
    WorldCity('Frankfurt', 'Germany', 50.1109, 8.6821),
    WorldCity('Cologne', 'Germany', 50.9375, 6.9603),
    WorldCity('Amsterdam', 'Netherlands', 52.3676, 4.9041),
    WorldCity('Rotterdam', 'Netherlands', 51.9244, 4.4777),
    WorldCity('The Hague', 'Netherlands', 52.0705, 4.3007),
    WorldCity('Brussels', 'Belgium', 50.8503, 4.3517),
    WorldCity('Antwerp', 'Belgium', 51.2194, 4.4025),
    WorldCity('Luxembourg', 'Luxembourg', 49.6116, 6.1319),
    WorldCity('Madrid', 'Spain', 40.4168, -3.7038),
    WorldCity('Barcelona', 'Spain', 41.3851, 2.1734),
    WorldCity('Lisbon', 'Portugal', 38.7223, -9.1393),
    WorldCity('Andorra la Vella', 'Andorra', 42.5063, 1.5218),
    WorldCity('Rome', 'Italy', 41.9028, 12.4964),
    WorldCity('Milan', 'Italy', 45.4642, 9.1900),
    WorldCity('Vatican City', 'Vatican City', 41.9029, 12.4534),
    WorldCity('San Marino', 'San Marino', 43.9424, 12.4578),
    WorldCity('Valletta', 'Malta', 35.8989, 14.5146),
    WorldCity('Monaco', 'Monaco', 43.7384, 7.4246),
    WorldCity('Bern', 'Switzerland', 46.9480, 7.4474),
    WorldCity('Zurich', 'Switzerland', 47.3769, 8.5417),
    WorldCity('Geneva', 'Switzerland', 46.2044, 6.1432),
    WorldCity('Vaduz', 'Liechtenstein', 47.1410, 9.5209),
    WorldCity('Vienna', 'Austria', 48.2082, 16.3738),
    WorldCity('Prague', 'Czechia', 50.0755, 14.4378),
    WorldCity('Bratislava', 'Slovakia', 48.1486, 17.1077),
    WorldCity('Budapest', 'Hungary', 47.4979, 19.0402),
    WorldCity('Warsaw', 'Poland', 52.2297, 21.0122),
    WorldCity('Ljubljana', 'Slovenia', 46.0569, 14.5058),
    WorldCity('Zagreb', 'Croatia', 45.8150, 15.9819),
    WorldCity('Sarajevo', 'Bosnia and Herzegovina', 43.8563, 18.4131),
    WorldCity('Belgrade', 'Serbia', 44.7866, 20.4489),
    WorldCity('Podgorica', 'Montenegro', 42.4304, 19.2594),
    WorldCity('Pristina', 'Kosovo', 42.6629, 21.1655),
    WorldCity('Skopje', 'North Macedonia', 41.9981, 21.4254),
    WorldCity('Tirana', 'Albania', 41.3275, 19.8187),
    WorldCity('Athens', 'Greece', 37.9838, 23.7275),
    WorldCity('Sofia', 'Bulgaria', 42.6977, 23.3219),
    WorldCity('Bucharest', 'Romania', 44.4268, 26.1025),
    WorldCity('Chișinău', 'Moldova', 47.0105, 28.8638),
    WorldCity('Kyiv', 'Ukraine', 50.4501, 30.5234, ['Kiev']),
    WorldCity('Minsk', 'Belarus', 53.9006, 27.5590),
    WorldCity('Vilnius', 'Lithuania', 54.6872, 25.2797),
    WorldCity('Riga', 'Latvia', 56.9496, 24.1052),
    WorldCity('Tallinn', 'Estonia', 59.4370, 24.7536),
    WorldCity('Helsinki', 'Finland', 60.1699, 24.9384),
    WorldCity('Stockholm', 'Sweden', 59.3293, 18.0686),
    WorldCity('Gothenburg', 'Sweden', 57.7089, 11.9746),
    WorldCity('Oslo', 'Norway', 59.9139, 10.7522),
    WorldCity('Copenhagen', 'Denmark', 55.6761, 12.5683),
    WorldCity('Reykjavík', 'Iceland', 64.1466, -21.9426),
    WorldCity('Moscow', 'Russia', 55.7558, 37.6173),
    WorldCity('Saint Petersburg', 'Russia', 59.9311, 30.3609),
    WorldCity('Kazan', 'Russia', 55.7963, 49.1088),
    // North America.
    WorldCity('Washington', 'United States', 38.9072, -77.0369, [
      'Washington DC',
    ]),
    WorldCity('New York', 'United States', 40.7128, -74.0060, ['NYC']),
    WorldCity('Los Angeles', 'United States', 34.0522, -118.2437),
    WorldCity('Chicago', 'United States', 41.8781, -87.6298),
    WorldCity('Houston', 'United States', 29.7604, -95.3698),
    WorldCity('Phoenix', 'United States', 33.4484, -112.0740),
    WorldCity('Philadelphia', 'United States', 39.9526, -75.1652),
    WorldCity('Dallas', 'United States', 32.7767, -96.7970),
    WorldCity('San Francisco', 'United States', 37.7749, -122.4194),
    WorldCity('Seattle', 'United States', 47.6062, -122.3321),
    WorldCity('Denver', 'United States', 39.7392, -104.9903),
    WorldCity('Boston', 'United States', 42.3601, -71.0589),
    WorldCity('Detroit', 'United States', 42.3314, -83.0458),
    WorldCity('Atlanta', 'United States', 33.7490, -84.3880),
    WorldCity('Miami', 'United States', 25.7617, -80.1918),
    WorldCity('Minneapolis', 'United States', 44.9778, -93.2650),
    WorldCity('Las Vegas', 'United States', 36.1699, -115.1398),
    WorldCity('Kansas City', 'United States', 39.0997, -94.5786),
    WorldCity('Salt Lake City', 'United States', 40.7608, -111.8910),
    WorldCity('New Orleans', 'United States', 29.9511, -90.0715),
    WorldCity('Anchorage', 'United States', 61.2181, -149.9003),
    WorldCity('Honolulu', 'United States', 21.3069, -157.8583),
    WorldCity('Ottawa', 'Canada', 45.4215, -75.6972),
    WorldCity('Toronto', 'Canada', 43.6532, -79.3832),
    WorldCity('Montreal', 'Canada', 45.5017, -73.5673),
    WorldCity('Vancouver', 'Canada', 49.2827, -123.1207),
    WorldCity('Calgary', 'Canada', 51.0447, -114.0719),
    WorldCity('Edmonton', 'Canada', 53.5461, -113.4938),
    WorldCity('Winnipeg', 'Canada', 49.8951, -97.1384),
    WorldCity('Saskatoon', 'Canada', 52.1579, -106.6702),
    WorldCity('Quebec City', 'Canada', 46.8139, -71.2080),
    WorldCity('Halifax', 'Canada', 44.6488, -63.5752),
    WorldCity('Whitehorse', 'Canada', 60.7212, -135.0568),
    WorldCity('Yellowknife', 'Canada', 62.4540, -114.3718),
    WorldCity('Iqaluit', 'Canada', 63.7467, -68.5170),
    WorldCity('Mexico City', 'Mexico', 19.4326, -99.1332),
    WorldCity('Guadalajara', 'Mexico', 20.6597, -103.3496),
    WorldCity('Monterrey', 'Mexico', 25.6866, -100.3161),
    WorldCity('Tijuana', 'Mexico', 32.5149, -117.0382),
    // Central America and the Caribbean.
    WorldCity('Guatemala City', 'Guatemala', 14.6349, -90.5069),
    WorldCity('Belmopan', 'Belize', 17.2510, -88.7590),
    WorldCity('San Salvador', 'El Salvador', 13.6929, -89.2182),
    WorldCity('Tegucigalpa', 'Honduras', 14.0723, -87.1921),
    WorldCity('Managua', 'Nicaragua', 12.1140, -86.2362),
    WorldCity('San José', 'Costa Rica', 9.9281, -84.0907),
    WorldCity('Panama City', 'Panama', 8.9824, -79.5199),
    WorldCity('Havana', 'Cuba', 23.1136, -82.3666),
    WorldCity('Nassau', 'Bahamas', 25.0443, -77.3504),
    WorldCity('Kingston', 'Jamaica', 17.9714, -76.7920),
    WorldCity('Port-au-Prince', 'Haiti', 18.5944, -72.3074),
    WorldCity('Santo Domingo', 'Dominican Republic', 18.4861, -69.9312),
    WorldCity('Basseterre', 'Saint Kitts and Nevis', 17.3026, -62.7177),
    WorldCity("Saint John's", 'Antigua and Barbuda', 17.1274, -61.8468),
    WorldCity('Roseau', 'Dominica', 15.3017, -61.3881),
    WorldCity('Castries', 'Saint Lucia', 14.0101, -60.9875),
    WorldCity(
      'Kingstown',
      'Saint Vincent and the Grenadines',
      13.1600,
      -61.2248,
    ),
    WorldCity('Bridgetown', 'Barbados', 13.0975, -59.6167),
    WorldCity("Saint George's", 'Grenada', 12.0561, -61.7488),
    WorldCity('Port of Spain', 'Trinidad and Tobago', 10.6549, -61.5019),
    // South America.
    WorldCity('Caracas', 'Venezuela', 10.4806, -66.9036),
    WorldCity('Bogotá', 'Colombia', 4.7110, -74.0721),
    WorldCity('Quito', 'Ecuador', -0.1807, -78.4678),
    WorldCity('Lima', 'Peru', -12.0464, -77.0428),
    WorldCity('La Paz', 'Bolivia', -16.4897, -68.1193),
    WorldCity('Sucre', 'Bolivia', -19.0196, -65.2619),
    WorldCity('Santiago', 'Chile', -33.4489, -70.6693),
    WorldCity('Buenos Aires', 'Argentina', -34.6037, -58.3816),
    WorldCity('Montevideo', 'Uruguay', -34.9011, -56.1645),
    WorldCity('Asunción', 'Paraguay', -25.2637, -57.5759),
    WorldCity('Brasília', 'Brazil', -15.7975, -47.8919),
    WorldCity('São Paulo', 'Brazil', -23.5505, -46.6333),
    WorldCity('Rio de Janeiro', 'Brazil', -22.9068, -43.1729),
    WorldCity('Georgetown', 'Guyana', 6.8013, -58.1551),
    WorldCity('Paramaribo', 'Suriname', 5.8520, -55.2038),
    // Oceania.
    WorldCity('Canberra', 'Australia', -35.2809, 149.1300),
    WorldCity('Sydney', 'Australia', -33.8688, 151.2093),
    WorldCity('Melbourne', 'Australia', -37.8136, 144.9631),
    WorldCity('Brisbane', 'Australia', -27.4698, 153.0251),
    WorldCity('Perth', 'Australia', -31.9505, 115.8605),
    WorldCity('Adelaide', 'Australia', -34.9285, 138.6007),
    WorldCity('Darwin', 'Australia', -12.4634, 130.8456),
    WorldCity('Hobart', 'Australia', -42.8821, 147.3272),
    WorldCity('Wellington', 'New Zealand', -41.2865, 174.7762),
    WorldCity('Auckland', 'New Zealand', -36.8485, 174.7633),
    WorldCity('Port Moresby', 'Papua New Guinea', -9.4438, 147.1803),
    WorldCity('Honiara', 'Solomon Islands', -9.4456, 159.9729),
    WorldCity('Port Vila', 'Vanuatu', -17.7333, 168.3273),
    WorldCity('Suva', 'Fiji', -18.1416, 178.4419),
    WorldCity('Apia', 'Samoa', -13.8507, -171.7514),
    WorldCity("Nuku'alofa", 'Tonga', -21.1394, -175.2049),
    WorldCity('Funafuti', 'Tuvalu', -8.5211, 179.1983),
    WorldCity('South Tarawa', 'Kiribati', 1.3290, 172.9790),
    WorldCity('Yaren', 'Nauru', -0.5477, 166.9209),
    WorldCity('Majuro', 'Marshall Islands', 7.0833, 171.3833),
    WorldCity('Palikir', 'Micronesia', 6.9248, 158.1610),
    WorldCity('Ngerulmud', 'Palau', 7.5006, 134.6242),
  ];
}

/// The folded search keys of one city.
class _Key {
  const _Key(this.names, this.country, this.all);

  /// Name and aliases.
  final List<String> names;
  final String country;

  /// "name country aliases".
  final String all;
}
