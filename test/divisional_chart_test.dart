import 'package:jyotish/jyotish.dart';
import 'package:test/test.dart';

void main() {
  group('DivisionalChartService - D60 Mapping', () {
    late Jyotish jyotish;

    setUp(() {
      jyotish = Jyotish();
    });

    VedicChart createMockChart(double longitude, {int signIndex = 0}) {
      final absoluteLongitude = (signIndex * 30.0) + longitude;

      final houses = HouseSystem(
        system: 'Whole Sign',
        cusps: List.generate(12, (i) => i * 30.0),
        ascendant: 10.0,
        midheaven: 270.0,
      );

      final planets = {
        Planet.sun: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.sun,
            dateTime: DateTime.now(),
            longitude: absoluteLongitude,
            latitude: 0,
            distance: 1,
            longitudeSpeed: 1,
            latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: (absoluteLongitude / 30).floor() + 1,
          dignity: PlanetaryDignity.neutralSign,
        ),
      };

      return VedicChart(
        dateTime: DateTime.now(),
        location: 'Test',
        latitude: 0,
        longitudeCoord: 0,
        houses: houses,
        planets: planets,
        rahu: planets[Planet.sun]!,
        ketu: KetuPosition(rahuPosition: planets[Planet.sun]!.position),
      );
    }

    test('D60 - Aries (Odd Sign) at 0°15 (Part 0) starts from Aries', () {
      // Aries is index 0. Degree 0.25 (15 min) -> Part 0.
      // Rule (Odd): signIndex (0) + part (0) = 0 (Aries)
      final chart = createMockChart(0.25, signIndex: 0);
      final d60 = jyotish.getDivisionalChart(
          rashiChart: chart, type: DivisionalChartType.d60);

      expect(d60.planets[Planet.sun]!.zodiacSign, 'Aries');
    });

    test('D60 - Aries (Odd Sign) at 29°45 (Part 59) mapping to Pisces', () {
      // Aries is index 0. Degree 29.75 -> Part 59.
      // Rule (Odd): (0 + 59) % 12 = 11 (Pisces)
      final chart = createMockChart(29.75, signIndex: 0);
      final d60 = jyotish.getDivisionalChart(
          rashiChart: chart, type: DivisionalChartType.d60);

      expect(d60.planets[Planet.sun]!.zodiacSign, 'Pisces');
    });

    test(
        'D60 - Taurus (Even Sign) at 0°15 (Part 0) starts from 9th sign (Capricorn)',
        () {
      // Taurus is index 1. Degree 0.25 -> Part 0.
      // Rule (Even): signIndex (1) + 8 (9th from self) + part (0) = 9 (Capricorn)
      final chart = createMockChart(0.25, signIndex: 1);
      final d60 = jyotish.getDivisionalChart(
          rashiChart: chart, type: DivisionalChartType.d60);

      expect(d60.planets[Planet.sun]!.zodiacSign, 'Capricorn');
    });

    test('D60 - Taurus (Even Sign) at 29°45 (Part 59) mapping to Sagittarius',
        () {
      // Taurus is index 1. Degree 29.75 -> Part 59.
      // Rule (Even): signIndex (1) + 8 + part (59) = 68. 68 % 12 = 8 (Sagittarius)
      final chart = createMockChart(29.75, signIndex: 1);
      final d60 = jyotish.getDivisionalChart(
          rashiChart: chart, type: DivisionalChartType.d60);

      expect(d60.planets[Planet.sun]!.zodiacSign, 'Sagittarius');
    });

    test(
        'D60 - Cancer (Even Sign) at 0°15 (Part 0) starts from 9th sign (Pisces)',
        () {
      // Cancer is index 3. Degree 0.25 -> Part 0.
      // Rule (Even): signIndex (3) + 8 + part (0) = 11 (Pisces)
      final chart = createMockChart(0.25, signIndex: 3);
      final d60 = jyotish.getDivisionalChart(
          rashiChart: chart, type: DivisionalChartType.d60);

      expect(d60.planets[Planet.sun]!.zodiacSign, 'Pisces');
    });
  });
}
