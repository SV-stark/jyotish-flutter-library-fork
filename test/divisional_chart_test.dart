import 'package:test/test.dart';
import 'package:jyotish/jyotish.dart';

void main() {
  group('Divisional Charts', () {
    late VedicChart sampleChart;

    setUp(() {
      // Create a sample chart manually or mock one
      // Since we don't have Swiss Ephemeris in unit tests (usually),
      // we must rely on manual construction or ensure tests run where FFI is not needed for logic.
      // The logic in DivisionalChartService is pure math, so it doesn't need FFI.
      // We just need a manual VedicChart.

      final houses = HouseSystem(
        system: 'Placidus',
        cusps: List.filled(12, 0.0), // Dummy
        ascendant: 10.0, // 10° Aries
        midheaven: 270.0,
      );

      final planets = <Planet, VedicPlanetInfo>{
        Planet.sun: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.sun,
            dateTime: DateTime.now(),
            longitude: 10.1, // 10° 06' Aries (Aswini 4)
            latitude: 0, distance: 1, longitudeSpeed: 1, latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: 1,
          dignity: PlanetaryDignity.exalted,
        ),
        Planet.moon: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.moon,
            dateTime: DateTime.now(),
            longitude: 175.5, // 25° 30' Virgo (Chitra 1 or 2)
            // 175.5 = 5 signs * 30 + 25.5
            latitude: 0, distance: 1, longitudeSpeed: 12, latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: 6,
          dignity: PlanetaryDignity.friendSign,
        ),
      };

      sampleChart = VedicChart(
        dateTime: DateTime.now(),
        location: 'Test Location',
        latitude: 0,
        longitudeCoord: 0,
        houses: houses,
        planets: planets,
        rahu: planets[Planet.sun]!, // Dummy
        ketu: KetuPosition(rahuPosition: planets[Planet.sun]!.position),
      );
    });

    test('D1 calculation returns original chart', () {
      // Accessing via internal service via public method
      // Note: Jyotish.getDivisionalChart is an instance method.
      // We need to call it.

      final d1 = Jyotish().getDivisionalChart(
        rashiChart: sampleChart,
        type: DivisionalChartType.d1,
      );

      expect(d1, sampleChart);
    });

    test('D9 (Navamsa) calculation', () {
      // 1. Sun at 10.1° Aries.
      // Aries is Fire (1,5,9). Starts Aries.
      // 0-3.20 (1), 3.20-6.40 (2), 6.40-10.00 (3), 10.00-13.20 (4).
      // 10.1 is in 4th Pada.
      // 4th from Aries is Cancer.
      // So Sun should be in Cancer in D9.

      final d9 = Jyotish().getDivisionalChart(
        rashiChart: sampleChart,
        type: DivisionalChartType.d9,
      );

      final sunD9 = d9.getPlanet(Planet.sun)!;
      expect(sunD9.zodiacSign, 'Cancer');
    });

    test('D9 (Navamsa) calculation - Moon', () {
      // Moon at 25.5° Virgo.
      // Virgo is Earth (2,6,10). Starts Capricorn.
      // 25.5 / 3.333...
      // 0-3.20(1), 3.20-6.40(2)...
      // 23.20-26.40 is 8th Pada.
      // 8th from Capricorn: Cap(1), Aq(2), Pis(3), Ari(4), Tau(5), Gem(6), Can(7), Leo(8).
      // So Moon should be in Leo.

      final d9 = Jyotish().getDivisionalChart(
        rashiChart: sampleChart,
        type: DivisionalChartType.d9,
      );

      final moonD9 = d9.getPlanet(Planet.moon)!;
      expect(moonD9.zodiacSign, 'Leo');
    });

    test('D10 (Dasamsa) calculation', () {
      // Sun 10.1 Aries (Odd).
      // Starts from same: Aries.
      // 10.1 / 3 = 3rd part (9-12).
      // So 3rd part -> 3rd sign from Aries = Gemini.

      final d10 = Jyotish().getDivisionalChart(
        rashiChart: sampleChart,
        type: DivisionalChartType.d10,
      );

      expect(d10.getPlanet(Planet.sun)!.zodiacSign, 'Cancer');
    });

    test('D10 (Dasamsa) calculation - Even Sign', () {
      // Moon 25.5 Virgo (Even).
      // Starts from 9th from Virgo = Taurus.
      // 25.5 / 3 = 8th part (24-27).
      // 8th from Taurus = Sagittarius.

      final d10 = Jyotish().getDivisionalChart(
        rashiChart: sampleChart,
        type: DivisionalChartType.d10,
      );

      expect(d10.getPlanet(Planet.moon)!.zodiacSign, 'Capricorn');
    });

    test('D1 Ascendant maps correctly to D9 Ascendant', () {
      // Ascendant 10.0 Aries.
      // 4th Pada (10.0 is boundary? Let's check logic: 10.0 is exact start of 4th pada usually).
      // 10.0 / 3.3333 = 3.0 -> Index 3 (4th part).
      // Aries start -> 4th sign = Cancer.

      // HOWEVER, floating point might be tricky.
      // Let's check logic implementation:
      // (degreeInSign / (30/9)).floor()
      // 10.0 / 3.3333 = 3.000003 -> 3.
      // Index 3 = 4th part. Correct.

      final d9 = Jyotish().getDivisionalChart(
        rashiChart: sampleChart,
        type: DivisionalChartType.d9,
      );

      expect(d9.ascendantSign, 'Cancer');
    });
  });
}
