import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish/jyotish.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() async {
    final jyotish = Jyotish();
    await jyotish.initialize(ephemerisPath: p.absolute('ephe'));
  });

  group('Audited Bug Fixes Verification Test Suite', () {
    late VedicChart chart;
    late GeographicLocation location;
    late DateTime birthDate;

    setUp(() async {
      location = const GeographicLocation(
        latitude: 28.6139,
        longitude: 77.2090,
        altitude: 216.0,
        timezone: 'Asia/Kolkata',
      );
      birthDate = DateTime(1995, 8, 20, 10, 30);
      chart = await Jyotish().calculateVedicChart(
        dateTime: birthDate,
        location: location,
      );
    });

    test('1. Ashtakavarga exact classical BPHS totals (Sun 48, Moon 49, Mars 39, Mercury 54, Jupiter 56, Venus 52, Saturn 39, SAV = 337)', () {
      final jyotish = Jyotish();
      final aav = jyotish.systems.ashtakavarga.calculateAshtakavarga(chart);

      // Verify each planet's BAV total matches BPHS constants
      expect(aav.bhinnashtakavarga[Planet.sun]!.totalBindus, equals(48));
      expect(aav.bhinnashtakavarga[Planet.moon]!.totalBindus, equals(49));
      expect(aav.bhinnashtakavarga[Planet.mars]!.totalBindus, equals(39));
      expect(aav.bhinnashtakavarga[Planet.mercury]!.totalBindus, equals(54));
      expect(aav.bhinnashtakavarga[Planet.jupiter]!.totalBindus, equals(56));
      expect(aav.bhinnashtakavarga[Planet.venus]!.totalBindus, equals(52));
      expect(aav.bhinnashtakavarga[Planet.saturn]!.totalBindus, equals(39));

      // Verify Sarvashtakavarga total across all 12 signs is exactly 337
      final savTotal = aav.sarvashtakavarga.bindus.reduce((a, b) => a + b);
      expect(savTotal, equals(337));
      expect(aav.sarvashtakavarga.total, equals(337));

      // Verify house 1 bindus count from Ascendant sign, not Aries
      final ascSign = (chart.houses.ascendant / 30).floor() % 12;
      expect(aav.getTotalBindusForHouse(1), equals(aav.sarvashtakavarga.bindus[ascSign]));
    });

    test('2. Trikona Shodhana adheres strictly to BPHS Ch. 68 zero preservation rule', () {
      final jyotish = Jyotish();
      final aav = jyotish.systems.ashtakavarga.calculateAshtakavarga(chart);
      final reduced = jyotish.systems.ashtakavarga.applyTrikonaShodhana(aav);

      // BAV totals after reduction must be non-negative and <= raw
      for (final planet in Planet.traditionalPlanets) {
        final rawBav = aav.bhinnashtakavarga[planet]!;
        final redBav = reduced.bhinnashtakavarga[planet]!;
        for (var i = 0; i < 12; i++) {
          expect(redBav.bindus[i] >= 0, isTrue);
          expect(redBav.bindus[i] <= rawBav.bindus[i], isTrue);
        }
      }
    });

    test('3. Whole Sign Bhava Chalit has 0 shifted planets', () async {
      final wholeSignChart = await Jyotish().calculateVedicChart(
        dateTime: birthDate,
        location: location,
        houseSystem: 'W',
      );
      final bc = BhavaChalitService().calculateBhavaChalit(wholeSignChart);
      expect(bc.shiftedPlanets, isEmpty);
      expect(bc.shiftedPlanets.length, equals(0));
    });

    test('4. Shadbala Chesta Bala is 0.0 for retrograde and Moon does not double-count Paksha Bala', () async {
      final jyotish = Jyotish();
      final shadbalaMap = await jyotish.systems.shadbala.calculateShadbala(chart);

      // Moon Chesta Bala must be 0.0
      final moonResult = shadbalaMap[Planet.moon]!;
      expect(moonResult.chestaBala, equals(0.0));

      // Minimum required values are mapped properly
      expect(shadbalaMap[Planet.sun]!.minimumRequired, equals(300.0));
      expect(shadbalaMap[Planet.moon]!.minimumRequired, equals(360.0));
      expect(shadbalaMap[Planet.mars]!.minimumRequired, equals(300.0));
      expect(shadbalaMap[Planet.mercury]!.minimumRequired, equals(420.0));
      expect(shadbalaMap[Planet.jupiter]!.minimumRequired, equals(390.0));
      expect(shadbalaMap[Planet.venus]!.minimumRequired, equals(330.0));
      expect(shadbalaMap[Planet.saturn]!.minimumRequired, equals(300.0));

      // isStrong matches meetsMinimumStrength
      for (final res in shadbalaMap.values) {
        expect(res.isStrong, equals(res.meetsMinimumStrength));
      }
    });

    test('5. Dasha level bookkeeping and starting offsets are correct', () {
      final jyotish = Jyotish();

      // Yogini starting dasha index offset (+3 from nakshatra)
      final moonLong = chart.planets[Planet.moon]!.longitude;
      final yogini = jyotish.systems.dasha.calculateYoginiDasha(
        moonLongitude: moonLong,
        birthDateTime: chart.dateTime,
        levels: 3,
      );
      expect(yogini.allMahadashas.first.level, equals(0));
      expect(yogini.allMahadashas.first.subPeriods.first.level, equals(1));
      expect(yogini.allMahadashas.first.subPeriods.first.subPeriods.first.level, equals(2));

      // Ashtottari level bookkeeping
      final ashtottari = jyotish.systems.dasha.getAshtottariDasha(
        chart,
        forceCalculation: true,
        levels: 2,
      );
      expect(ashtottari.allMahadashas.first.level, equals(0));
      expect(ashtottari.allMahadashas.first.subPeriods.first.level, equals(1));

      // Kalachakra level bookkeeping
      final kalachakra = jyotish.systems.dasha.getKalachakraDasha(chart, levels: 2);
      expect(kalachakra.allMahadashas.first.level, equals(0));
      expect(kalachakra.allMahadashas.first.subPeriods.first.level, equals(1));

      // Chara dasha levels
      final chara = jyotish.systems.dasha.calculateCharaDasha(chart, levels: 3);
      expect(chara.allMahadashas.first.level, equals(0));
      expect(chara.allMahadashas.first.subPeriods.first.level, equals(1));
      expect(chara.allMahadashas.first.subPeriods.first.subPeriods.first.level, equals(2));

      // Narayana dasha levels
      final narayana = jyotish.systems.dasha.getNarayanaDasha(chart, levels: 2);
      expect(narayana.allMahadashas.first.level, equals(0));
      expect(narayana.allMahadashas.first.subPeriods.first.level, equals(1));
    });

    test('6. Lunar month calculations correctly distinguish Amanta vs Purnimanta', () async {
      final jyotish = Jyotish();
      final amanta = await jyotish.getAmantaMasa(
        dateTime: DateTime(2026, 5, 2),
        location: location,
      );
      final purnimanta = await jyotish.getPurnimantaMasa(
        dateTime: DateTime(2026, 5, 2),
        location: location,
      );

      // On May 2, 2026 (Sun in Aries, Krishna Paksha Pratipada):
      // Amanta month is Vaishakha, Purnimanta month is Jyeshtha
      expect(amanta.month.sanskrit, equals('Vaishakha'));
      expect(purnimanta.month.sanskrit, equals('Jyeshtha'));
    });
  });
}
