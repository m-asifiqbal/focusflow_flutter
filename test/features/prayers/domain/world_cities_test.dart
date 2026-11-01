/// WorldCities: search ranking and folding, nearest-city lookup and the
/// sanity of the data itself.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/features/prayers/domain/services/world_cities.dart';

String _first(String q) => WorldCities.search(q).first.name;

void main() {
  test("search('dha') starts with Dhaka", () {
    final r = WorldCities.search('dha');
    expect(r.first.name, 'Dhaka');
    expect(r.first.label, 'Dhaka, Bangladesh');
  });

  test('search is case- and accent-insensitive', () {
    expect(_first('DHAKA'), 'Dhaka');
    expect(_first('bogota'), 'Bogotá');
    expect(_first('BOGOTÁ'), 'Bogotá');
    expect(_first('sanliurfa'), 'Şanlıurfa');
    expect(_first('reykjavik'), 'Reykjavík');
    expect(_first('coxs'), "Cox's Bazar");
    expect(_first("cox's bazar"), "Cox's Bazar");
    expect(_first('port au prince'), 'Port-au-Prince');
  });

  test('search finds old spellings, words and countries', () {
    expect(_first('Chittagong'), 'Chattogram');
    expect(_first('jessore'), 'Jashore');
    expect(_first('bazar'), "Cox's Bazar");
    expect(_first('york'), 'New York');
    final bd = WorldCities.search('bangladesh', limit: 100);
    expect(bd.length, 64);
    expect(bd.every((c) => c.country == 'Bangladesh'), isTrue);
  });

  test('search limits and blank queries', () {
    expect(WorldCities.search('a', limit: 5).length, 5);
    expect(WorldCities.search('   '), isEmpty);
    expect(WorldCities.search('zzzzqqq'), isEmpty);
  });

  test('nearest names GPS points', () {
    final r = WorldCities.nearest(const GeoPoint(23.80, 90.40));
    expect(r, isNotNull);
    expect(r!.city.name, 'Dhaka');
    expect(r.km, lessThan(5));
    final ctg = WorldCities.nearest(const GeoPoint(22.35, 91.80));
    expect(ctg!.city.name, 'Chattogram');
    expect(WorldCities.nearest(const GeoPoint(-30, -140)), isNull);
    expect(WorldCities.nearest(const GeoPoint(10, -140)), isNull);
  });

  test('the data is sane', () {
    final all = WorldCities.all;
    expect(all.length, greaterThan(300));
    final seen = <String>{};
    for (final c in all) {
      expect(seen.add('${c.name}|${c.country}'), isTrue, reason: c.label);
      expect(c.latitude, inInclusiveRange(-90, 90), reason: c.label);
      expect(c.longitude, inInclusiveRange(-180, 180), reason: c.label);
      expect(c.name.trim(), c.name);
      expect(c.country.trim(), c.country);
    }
    expect(all.where((c) => c.country == 'Bangladesh').length, 64);
  });
}
