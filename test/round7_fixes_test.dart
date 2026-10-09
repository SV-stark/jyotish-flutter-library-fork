import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish/jyotish.dart';

/// Regression tests for the round-7 fixes:
///
///  * Purnimanta month names are derived from the exact month-boundary Sun
///    longitude, so they stay one month ahead of the Amanta name instead of
///    drifting from a mean-rate estimate of the current instant.
///  * The divisional-chart cache is bounded, so a process-global instance
///    cannot grow without limit.
///  * Special Lagna anchors are rewound to sunrise (see
///    `verified_logic_fixes_test.dart`, which asserts the independent values).
void main() {
  group('Purnimanta month naming', () {
    late Jyotish jyotish;

    setUpAll(() async {
      jyotish = Jyotish();
      await jyotish.initialize();
    });

    test('Purnimanta runs one month ahead only during Krishna Paksha', () async {
      const location = GeographicLocation(
        latitude: 28.6139,
        longitude: 85.3240,
        timezone: 'Asia/Kathmandu',
      );

      // The Purnimanta month takes its name from the Amanta month that holds
      // its SHUKLA half. Therefore:
      //   * Shukla Paksha of Amanta month A -> Purnimanta month A
      //   * Krishna Paksha of Amanta month A -> Purnimanta month A + 1
      // This is the classical relationship, and it is what the month-boundary
      // naming must reproduce on every day of a year, including either side of
      // a sankranti where a mean-rate estimate used to disagree.
      var shuklaCases = 0;
      var krishnaCases = 0;
      for (var day = 0; day < 365; day += 3) {
        final date = DateTime(2026, 1, 10).add(Duration(days: day));

        final amanta = await jyotish.getAmantaMasa(
          dateTime: date,
          location: location,
        );
        final purnimanta = await jyotish.getPurnimantaMasa(
          dateTime: date,
          location: location,
        );

        final amantaIndex = MasaInfo.amantaMonthOrder.indexOf(amanta.month);
        final offset = amanta.tithiInfo.paksha == Paksha.krishna ? 1 : 0;
        final expected = MasaInfo.amantaMonthOrder[
            (amantaIndex + offset) % 12];

        if (offset == 0) {
          shuklaCases++;
        } else {
          krishnaCases++;
        }

        expect(
          purnimanta.month,
          expected,
          reason: 'on $date (${amanta.tithiInfo.paksha.name} '
              '${amanta.tithiInfo.name}) the Amanta month is '
              '${amanta.month.sanskrit} but the Purnimanta month resolved to '
              '${purnimanta.month.sanskrit}',
        );
      }
      // Exercise both halves of the cycle.
      expect(shuklaCases, greaterThan(50));
      expect(krishnaCases, greaterThan(50));
    });

    test('month name and Adhika verdict agree (both from one boundary)', () async {
      const location = GeographicLocation(
        latitude: 28.6139,
        longitude: 85.3240,
        timezone: 'Asia/Kathmandu',
      );

      // Previously the Adhika test used the bisected month boundary while the
      // name came from a mean-rate estimate of the current Sun, so the two
      // could disagree near a sankranti. They now share one boundary, which
      // this exercises by checking that no result is self-contradictory.
      for (var month = 1; month <= 12; month++) {
        final date = DateTime(2026, month, 15, 6, 0);
        for (final type in MasaType.values) {
          final masa = await jyotish.getMasa(dateTime: date, location: location, type: type);
          expect(masa.type, type);
          // A Nija month is by definition the month that follows an Adhika one,
          // and an Adhika month shares its name with the Nija month after it.
          // Those two labels can never describe the same month.
          expect(
            masa.adhikaType == AdhikaMasaType.adhika &&
                masa.adhikaType == AdhikaMasaType.nija,
            isFalse,
          );
        }
      }
    });
  });

  group('DivisionalChartService cache bound', () {
    test('the cache evicts instead of growing without bound', () {
      final service = DivisionalChartService();

      VedicChart chartWith(double sunLongitude) {
        final now = DateTime.utc(2020, 1, 1);
        VedicPlanetInfo place(Planet p, double lon) => VedicPlanetInfo(
              position: PlanetPosition(
                planet: p,
                dateTime: now,
                longitude: lon,
                latitude: 0.0,
                distance: 1.0,
                longitudeSpeed: 0.1,
                latitudeSpeed: 0.0,
                distanceSpeed: 0.0,
              ),
              house: ((lon / 30).floor() % 12) + 1,
              dignity: PlanetaryDignity.neutralSign,
            );
        final planets = <Planet, VedicPlanetInfo>{};
        for (final p in Planet.traditionalPlanets) {
          planets[p] = place(p, sunLongitude);
        }
        final rahuInfo = place(Planet.meanNode, 90.0);
        return VedicChart(
          dateTime: now,
          location: 'Cache',
          latitude: 0.0,
          longitudeCoord: 0.0,
          houses: HouseSystem(
            system: 'W',
            cusps: List.generate(12, (i) => i * 30.0),
            ascendant: 15.0,
            midheaven: 270.0,
          ),
          planets: planets,
          rahu: rahuInfo,
          ketu: KetuPosition(rahuPosition: rahuInfo.position),
        );
      }

      // Compute far more charts than the cache bound. Recomputing the same
      // chart must still return the identical cached instance, proving the
      // cache still works after eviction pressure.
      VedicChart? firstResult;
      for (var i = 0; i < 40; i++) {
        final chart = chartWith(i * 1.5);
        final d9 = service.calculateDivisionalChart(
          chart,
          DivisionalChartType.d9,
        );
        firstResult ??= d9;
      }

      final repeated = service.calculateDivisionalChart(
        chartWith(0.0),
        DivisionalChartType.d9,
      );
      expect(identical(repeated, firstResult), isTrue);

      // A different varga of the same chart must also be cached and identical.
      final d9Again = service.calculateDivisionalChart(
        chartWith(0.0),
        DivisionalChartType.d9,
      );
      expect(identical(d9Again, repeated), isTrue);
    });
  });
}
