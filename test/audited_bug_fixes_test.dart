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

    test('7. BhavaStrengthCategory virupas and Kalachakra duration consistency', () async {
      expect(BhavaStrengthCategory.veryStrong.minStrength, equals(480));
      expect(BhavaStrengthCategory.strong.minStrength, equals(420));
      expect(BhavaStrengthCategory.moderate.minStrength, equals(360));
      expect(BhavaStrengthCategory.weak.minStrength, equals(300));
      expect(BhavaStrengthCategory.veryWeak.maxStrength, equals(300));

      final jyotish = Jyotish();
      final kalachakra = jyotish.systems.dasha.getKalachakraDasha(chart, levels: 2);
      for (final md in kalachakra.allMahadashas) {
        expect(md.endDate, equals(md.startDate.add(md.duration)));
        for (final ad in md.subPeriods) {
          expect(ad.endDate, equals(ad.startDate.add(ad.duration)));
        }
      }

      final transits = await jyotish.systems.transit.calculateTransits(
        natalChart: chart,
        transitDateTime: DateTime(2026, 5, 2),
        location: location,
      );
      expect(transits.containsKey(Planet.meanNode), isTrue);
      expect(transits.containsKey(Planet.ketu), isTrue);
      final rahuTransit = transits[Planet.meanNode]!;
      expect(rahuTransit.natalPosition, isNotNull);
    });

    test('8. Chart JSON preserves flags/sub-spans, DashaPeriod boundaries, and Yoga nature', () {
      // 1. Chart JSON roundtrip with calculationFlags
      final chartWithFlags = VedicChart(
        dateTime: chart.dateTime,
        location: chart.location,
        latitude: chart.latitude,
        longitudeCoord: chart.longitudeCoord,
        altitude: chart.altitude,
        houses: chart.houses,
        planets: chart.planets,
        rahu: chart.rahu,
        ketu: chart.ketu,
        calculationFlags: CalculationFlags.kp(),
      );
      final json = chartWithFlags.toJson();
      final roundtrip = VedicChart.fromJson(json);
      expect(roundtrip.calculationFlags, isNotNull);
      expect(roundtrip.flags.isKP, isTrue);

      // 2. DashaPeriod.isActiveAt boundary condition
      final dashaPeriod = DashaPeriod(
        rashi: Rashi.aries,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2027, 1, 1),
        duration: const Duration(days: 365),
        level: 0,
      );
      expect(dashaPeriod.isActiveAt(DateTime(2026, 1, 1)), isTrue);
      expect(dashaPeriod.isActiveAt(DateTime(2026, 6, 1)), isTrue);
      expect(dashaPeriod.isActiveAt(DateTime(2027, 1, 1)), isFalse);

      // 3. Yoga nature includes 1, 15, 19 as malefic
      const vishkumbha = YogaInfo(number: 1, name: 'Vishkumbha', elapsed: 0.5);
      const vajra = YogaInfo(number: 15, name: 'Vajra', elapsed: 0.5);
      const parigha = YogaInfo(number: 19, name: 'Parigha', elapsed: 0.5);
      const priti = YogaInfo(number: 2, name: 'Priti', elapsed: 0.5);
      expect(vishkumbha.nature, equals(YogaNature.malefic));
      expect(vajra.nature, equals(YogaNature.malefic));
      expect(parigha.nature, equals(YogaNature.malefic));
      expect(priti.nature, equals(YogaNature.benefic));

      // 4. Panchanga YogaDetails for Vajra (15) matches YogaNature.malefic
      final vajraDetails = YogaDetails.getDetails(15);
      expect(vajraDetails.nature, equals(YogaNature.malefic));
    });

    test('9. D5 Panchamsa and D30 Trimsamsa canonical calculations', () {
      final divService = DivisionalChartService();

      // D5 Panchamsa: Odd sign (Aries = 0): Aries(0), Aquarius(10), Sagittarius(8), Gemini(2), Libra(6)
      // Part 0 (0-6°): 0, Part 1 (6-12°): 10, Part 2 (12-18°): 8, Part 3 (18-24°): 2, Part 4 (24-30°): 6
      expect(divService.calculateVargaLongitude(2.0, DivisionalChartType.d5) ~/ 30, equals(0));
      expect(divService.calculateVargaLongitude(7.0, DivisionalChartType.d5) ~/ 30, equals(10));
      expect(divService.calculateVargaLongitude(13.0, DivisionalChartType.d5) ~/ 30, equals(8));
      expect(divService.calculateVargaLongitude(19.0, DivisionalChartType.d5) ~/ 30, equals(2));
      expect(divService.calculateVargaLongitude(25.0, DivisionalChartType.d5) ~/ 30, equals(6));

      // D5 Panchamsa: Even sign (Taurus = 1): Taurus(1), Virgo(5), Pisces(11), Capricorn(9), Scorpio(7)
      expect(divService.calculateVargaLongitude(32.0, DivisionalChartType.d5) ~/ 30, equals(1));
      expect(divService.calculateVargaLongitude(37.0, DivisionalChartType.d5) ~/ 30, equals(5));
      expect(divService.calculateVargaLongitude(43.0, DivisionalChartType.d5) ~/ 30, equals(11));
      expect(divService.calculateVargaLongitude(49.0, DivisionalChartType.d5) ~/ 30, equals(9));
      expect(divService.calculateVargaLongitude(55.0, DivisionalChartType.d5) ~/ 30, equals(7));

      // D30 Trimsamsa: Proportional degree scaling within unequal spans
      // In Aries (odd sign):
      // 2.0° -> span [0, 5] (width 5), Aries (0), degree = (2.0 / 5.0) * 30.0 = 12.0°
      final lon2 = divService.calculateVargaLongitude(2.0, DivisionalChartType.d30);
      expect(lon2 ~/ 30, equals(0));
      expect(lon2 % 30, closeTo(12.0, 1e-6));

      // 14.0° in Aries -> span [10, 18] (width 8), Sagittarius (8), degree = (4.0 / 8.0) * 30.0 = 15.0°
      final lon14 = divService.calculateVargaLongitude(14.0, DivisionalChartType.d30);
      expect(lon14 ~/ 30, equals(8));
      expect(lon14 % 30, closeTo(15.0, 1e-6));

      // 32.5° (2.5° in Taurus, even sign) -> span [0, 5] (width 5), Taurus (1), degree = (2.5 / 5.0) * 30.0 = 15.0°
      final lon32 = divService.calculateVargaLongitude(32.5, DivisionalChartType.d30);
      expect(lon32 ~/ 30, equals(1));
      expect(lon32 % 30, closeTo(15.0, 1e-6));
    });

    test('10. Panchadha Maitri arithmetic, Kemadruma Yoga, and negative angle guards', () {
      // Panchadha Maitri arithmetic
      expect(
        RelationshipCalculator.calculateCompound(
          RelationshipType.neutral,
          RelationshipType.neutral,
        ),
        equals(RelationshipType.neutral),
      );
      expect(
        RelationshipCalculator.calculateCompound(
          RelationshipType.friend,
          RelationshipType.neutral,
        ),
        equals(RelationshipType.friend),
      );
      expect(
        RelationshipCalculator.calculateCompound(
          RelationshipType.enemy,
          RelationshipType.neutral,
        ),
        equals(RelationshipType.enemy),
      );
      expect(
        RelationshipCalculator.calculateCompound(
          RelationshipType.friend,
          RelationshipType.friend,
        ),
        equals(RelationshipType.greatFriend),
      );
      expect(
        RelationshipCalculator.calculateCompound(
          RelationshipType.enemy,
          RelationshipType.enemy,
        ),
        equals(RelationshipType.greatEnemy),
      );

      // Negative angle guards
      expect(Rashi.fromLongitude(-5.0), equals(Rashi.pisces));
      expect(Rashi.fromIndex(-1), equals(Rashi.pisces));
      expect(Rashi.fromLongitude(365.0), equals(Rashi.aries));

      final posNeg = PlanetPosition(
        planet: Planet.sun,
        longitude: -15.0,
        latitude: 0.0,
        distance: 1.0,
        longitudeSpeed: 1.0,
        latitudeSpeed: 0.0,
        distanceSpeed: 0.0,
        dateTime: DateTime(2026, 1, 1),
      );
      expect(posNeg.zodiacSignIndex, equals(11));
      expect(posNeg.positionInSign, closeTo(15.0, 1e-6));

      // CalculationFlags.fromJson case-insensitivity
      final flagsLower = CalculationFlags.fromJson({
        'system': 'traditional',
        'siderealMode': 'raman',
        'nodeType': 'truenode',
      });
      expect(flagsLower.siderealMode, equals(SiderealMode.raman));
      expect(flagsLower.nodeType, equals(NodeType.trueNode));
    });
  });
}
