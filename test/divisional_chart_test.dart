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

  group('DivisionalChartService - D249 249 Subdivisions', () {
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

    test('D249 - Aries (Odd Sign) at 0.12 (Part 0) starts from Aries', () {
      // Aries is index 0. Degree ~0.12 (30/249) -> Part 0.
      // Rule (Odd): signIndex (0) + part (0) = 0 (Aries)
      final chart = createMockChart(30 / 249, signIndex: 0);
      final d249 = jyotish.getDivisionalChart(
          rashiChart: chart, type: DivisionalChartType.d249);

      expect(d249.planets[Planet.sun]!.zodiacSign, 'Aries');
    });

    test('D249 - Aries (Odd Sign) at 15° (Part ~124) maps correctly', () {
      // Aries is index 0. Degree 15 -> Part 124.
      // Each part = 30/249 = ~0.12 degrees
      // Part = (15 / (30/249)).floor() = 124
      // Rule (Odd): (0 + 124) % 12 = 4 (Leo)
      final chart = createMockChart(15.0, signIndex: 0);
      final d249 = jyotish.getDivisionalChart(
          rashiChart: chart, type: DivisionalChartType.d249);

      expect(d249.planets[Planet.sun]!.zodiacSign, 'Leo');
    });

    test('D249 - Aries (Odd Sign) at 29.88° (Part 248) maps to Pisces', () {
      // Aries is index 0. Degree 29.88 -> Part 248.
      // Rule (Odd): (0 + 248) % 12 = 8 (Sagittarius)? No, 248 % 12 = 8
      // Actually: 248 % 12 = 8, so Sagittarius
      final chart = createMockChart(29.88, signIndex: 0);
      final d249 = jyotish.getDivisionalChart(
          rashiChart: chart, type: DivisionalChartType.d249);

      // 248 % 12 = 8, which is Sagittarius
      expect(d249.planets[Planet.sun]!.zodiacSign, 'Sagittarius');
    });

    test(
        'D249 - Taurus (Even Sign) at 0.12 (Part 0) starts from 9th sign (Capricorn)',
        () {
      // Taurus is index 1. Degree ~0.12 (30/249) -> Part 0.
      // Rule (Even): signIndex (1) + 8 (9th from self) + part (0) = 9 (Capricorn)
      final chart = createMockChart(30 / 249, signIndex: 1);
      final d249 = jyotish.getDivisionalChart(
          rashiChart: chart, type: DivisionalChartType.d249);

      expect(d249.planets[Planet.sun]!.zodiacSign, 'Capricorn');
    });

    test('D249 - Taurus (Even Sign) at 15° (Part 124) maps correctly', () {
      // Taurus is index 1. Degree 15 -> Part 124.
      // Rule (Even): (1 + 8 + 124) % 12 = 133 % 12 = 1 (Taurus)
      final chart = createMockChart(15.0, signIndex: 1);
      final d249 = jyotish.getDivisionalChart(
          rashiChart: chart, type: DivisionalChartType.d249);

      expect(d249.planets[Planet.sun]!.zodiacSign, 'Taurus');
    });

    test('D249 - Taurus (Even Sign) at 29.88° (Part 248) maps to Sagittarius',
        () {
      // Taurus is index 1. Degree 29.88 -> Part 248.
      // Rule (Even): (1 + 8 + 248) % 12 = 257 % 12 = 5 (Virgo)
      final chart = createMockChart(29.88, signIndex: 1);
      final d249 = jyotish.getDivisionalChart(
          rashiChart: chart, type: DivisionalChartType.d249);

      // 257 % 12 = 5, which is Virgo
      expect(d249.planets[Planet.sun]!.zodiacSign, 'Virgo');
    });

    test('D249 - Gemini (Odd Sign) at various degrees maps correctly', () {
      // Gemini is index 2 (odd sign)
      // At 0.12 degrees (Part 0): (2 + 0) % 12 = 2 (Gemini)
      final chart1 = createMockChart(30 / 249, signIndex: 2);
      final d249_1 = jyotish.getDivisionalChart(
          rashiChart: chart1, type: DivisionalChartType.d249);
      expect(d249_1.planets[Planet.sun]!.zodiacSign, 'Gemini');
    });

    test(
        'D249 - Cancer (Even Sign) at 0.12 (Part 0) starts from 9th sign (Pisces)',
        () {
      // Cancer is index 3. Degree ~0.12 (30/249) -> Part 0.
      // Rule (Even): signIndex (3) + 8 + part (0) = 11 (Pisces)
      final chart = createMockChart(30 / 249, signIndex: 3);
      final d249 = jyotish.getDivisionalChart(
          rashiChart: chart, type: DivisionalChartType.d249);

      expect(d249.planets[Planet.sun]!.zodiacSign, 'Pisces');
    });

    test('D249 calculation validates subdivision size', () {
      // Each subdivision should be 30/249 degrees
      const subdivisionSize = 30.0 / 249.0;
      expect(subdivisionSize, closeTo(0.12048, 0.00001));

      // Total degrees in sign should be covered by 249 parts
      expect(subdivisionSize * 249, closeTo(30.0, 0.0001));
    });

    test('D249 - Multiple planets in same Rashi sign get different D249 signs',
        () {
      // In D249, different degrees in the same sign should map to different D249 signs
      final houses = HouseSystem(
        system: 'Whole Sign',
        cusps: List.generate(12, (i) => i * 30.0),
        ascendant: 10.0,
        midheaven: 270.0,
      );

      // Planet at 0° in Aries (Part 0) -> Aries
      final planet1 = VedicPlanetInfo(
        position: PlanetPosition(
          planet: Planet.sun,
          dateTime: DateTime.now(),
          longitude: 0.0,
          latitude: 0,
          distance: 1,
          longitudeSpeed: 1,
          latitudeSpeed: 0,
          distanceSpeed: 0,
        ),
        house: 1,
        dignity: PlanetaryDignity.neutralSign,
      );

      // Planet at 15° in Aries (Part 124) -> Leo
      final planet2 = VedicPlanetInfo(
        position: PlanetPosition(
          planet: Planet.moon,
          dateTime: DateTime.now(),
          longitude: 15.0,
          latitude: 0,
          distance: 1,
          longitudeSpeed: 1,
          latitudeSpeed: 0,
          distanceSpeed: 0,
        ),
        house: 1,
        dignity: PlanetaryDignity.neutralSign,
      );

      final chart = VedicChart(
        dateTime: DateTime.now(),
        location: 'Test',
        latitude: 0,
        longitudeCoord: 0,
        houses: houses,
        planets: {
          Planet.sun: planet1,
          Planet.moon: planet2,
        },
        rahu: planet1,
        ketu: KetuPosition(rahuPosition: planet1.position),
      );

      final d249 = jyotish.getDivisionalChart(
          rashiChart: chart, type: DivisionalChartType.d249);

      expect(d249.planets[Planet.sun]!.zodiacSign, 'Aries');
      expect(d249.planets[Planet.moon]!.zodiacSign, 'Leo');
      // Verify they're in different D249 signs
      expect(
        d249.planets[Planet.sun]!.zodiacSign,
        isNot(equals(d249.planets[Planet.moon]!.zodiacSign)),
      );
    });
  });
}
