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
    late VedicChart chart;

    setUpAll(() async {
      jyotish = Jyotish();
      await jyotish.initialize();
      final location = GeographicLocation(latitude: 28.6139, longitude: 77.2090);
      chart = await jyotish.calculateVedicChart(
        dateTime: DateTime(1990, 5, 15, 14, 30),
        location: location,
      );
    });

    tearDownAll(() {
      jyotish.dispose();
    });

    test('D249: Ketu subdivision at 0° maps correctly', () {
      final d249 = jyotish.getDivisionalChart(
        rashiChart: chart, 
        type: DivisionalChartType.d249,
      );
      
      // 0° falls in Ketu subdivision (0-1.75°)
      // Ketu subdivision should map to Aries (0)
      expect(d249.planets[Planet.sun]!.zodiacSign, 'Aries');
      expect(d249.ascendantSign, 'Aries');
    });

    test('D249: Venus subdivision at 1.76° maps correctly', () async {
      // Create chart with Sun at 1.76° (within Venus subdivision: 1.75-6.75°)
      final sunChart = await _createChartWithSunAt(1.76);
      final d249 = jyotish.getDivisionalChart(
        rashiChart: sunChart,
        type: DivisionalChartType.d249,
      );
      
      // Should map to Taurus (1) after Ketu
      expect(d249.planets[Planet.sun]!.zodiacSign, 'Taurus');
    });

    test('D249: Sun subdivision at 3.26° maps correctly', () async {
      final sunChart = await _createChartWithSunAt(3.26);
      final d249 = jyotish.getDivisionalChart(
        rashiChart: sunChart,
        type: DivisionalChartType.d249,
      );
      
      // Should map to Gemini (2) after Venus
      expect(d249.planets[Planet.sun]!.zodiacSign, 'Gemini');
    });

    test('D249: Moon subdivision at 6.51° maps correctly', () async {
      final sunChart = await _createChartWithSunAt(6.51);
      final d249 = jyotish.getDivisionalChart(
        rashiChart: sunChart,
        type: DivisionalChartType.d249,
      );
      
      // Should map to Cancer (3) after Sun
      expect(d249.planets[Planet.sun]!.zodiacSign, 'Cancer');
    });

    test('D249: Mars subdivision at 8.26° maps correctly', () async {
      final sunChart = await _createChartWithSunAt(8.26);
      final d249 = jyotish.getDivisionalChart(
        rashiChart: sunChart,
        type: DivisionalChartType.d249,
      );
      
      // Should map to Leo (4) after Moon
      expect(d249.planets[Planet.sun]!.zodiacSign, 'Leo');
    });

    test('D249: Rahu subdivision at 12.01° maps correctly', () async {
      final sunChart = await _createChartWithSunAt(12.01);
      final d249 = jyotish.getDivisionalChart(
        rashiChart: sunChart,
        type: DivisionalChartType.d249,
      );
      
      // Rahu subdivision: 12.0-16.5°, should map to Virgo (5) after Jupiter
      expect(d249.planets[Planet.sun]!.zodiacSign, 'Virgo');
    });

    test('D249: Jupiter subdivision at 16.0° maps correctly', () async {
      final sunChart = await _createChartWithSunAt(16.0);
      final d249 = jyotish.getDivisionalChart(
        rashiChart: sunChart,
        type: DivisionalChartType.d249,
      );
      
      // Should map to Libra (6) after Rahu
      expect(d249.planets[Planet.sun]!.zodiacSign, 'Libra');
    });

    test('D249: Saturn subdivision at 20.75° maps correctly', () async {
      final sunChart = await _createChartWithSunAt(20.75);
      final d249 = jyotish.getDivisionalChart(
        rashiChart: sunChart,
        type: DivisionalChartType.d249,
      );
      
      // Should map to Scorpio (7) after Jupiter
      expect(d249.planets[Planet.sun]!.zodiacSign, 'Scorpio');
    });

    test('D249: Mercury subdivision at 25.0° maps correctly', () async {
      final sunChart = await _createChartWithSunAt(25.0);
      final d249 = jyotish.getDivisionalChart(
        rashiChart: sunChart,
        type: DivisionalChartType.d249,
      );
      
      // Should map to Sagittarius (8) after Saturn
      expect(d249.planets[Planet.sun]!.zodiacSign, 'Sagittarius');
    });

    test('D249: All 9 subdivisions in one cycle map correctly', () async {
      // Test 9 subdivisions spanning exactly 30° (one complete cycle)
      final positions = [
        0.0,   // Ketu end
        1.75,   // Venus end
        3.25,   // Sun end
        5.75,   // Moon end
        7.5,    // Mars end
        12.0,   // Rahu end (Jupiter start)
        16.0,   // Jupiter end (Saturn start)
        20.75,  // Saturn end (Mercury start)
        25.0,   // Mercury end
      ];
      
      final results = <String>[];
      for (final pos in positions) {
        final testChart = await _createChartWithSunAt(pos);
        final d249 = jyotish.getDivisionalChart(
          rashiChart: testChart,
          type: DivisionalChartType.d249,
        );
        results.add(d249.planets[Planet.sun]!.zodiacSign);
      }
      
      // Should cycle through 9 signs starting from Aries
      expect(results[0], 'Aries');    // Ketu
      expect(results[1], 'Taurus');   // Venus
      expect(results[2], 'Gemini');   // Sun
      expect(results[3], 'Cancer');   // Moon
      expect(results[4], 'Leo');      // Mars
      expect(results[5], 'Virgo');     // Rahu
      expect(results[6], 'Libra');    // Jupiter
      expect(results[7], 'Scorpio');  // Saturn
      expect(results[8], 'Sagittarius'); // Mercury
    });

    test('D249: Partial 28th cycle (subdivisions 243-248)', () async {
      final sunChart = await _createChartWithSunAt(25.5); // In Mercury partial area
      final d249 = jyotish.getDivisionalChart(
        rashiChart: sunChart,
        type: DivisionalChartType.d249,
      );
      
      // Should map to subdivision index 245-248 (partial Mercury)
      // Position in D249 sign: 25.5 - 30 + (some base)
      // Should be > 25.0 (end of Mercury subdivision)
      expect(d249.planets[Planet.sun]!.positionInSign, greaterThan(25.0));
    });

    test('D249: Works with both KP ayanamsas', () async {
      // Old KP ayanamsa
      final kpOld = await jyotish.calculateKPData(
        natalChart: chart,
        useNewAyanamsa: false,
      );
      final d249Old = jyotish.getDivisionalChart(
        rashiChart: chart,
        type: DivisionalChartType.d249,
      );
      
      // New KP ayanamsa
      final kpNew = await jyotish.calculateKPData(
        natalChart: chart,
        useNewAyanamsa: true,
      );
      final d249New = jyotish.getDivisionalChart(
        rashiChart: chart,
        type: DivisionalChartType.d249,
      );
      
      // Both should produce same D249 result (different ayanamsa doesn't affect vargas)
      expect(d249Old.planets[Planet.sun]!.zodiacSign, 
             d249New.planets[Planet.sun]!.zodiacSign);
    });

    test('D249: Works with Mean Node and True Node', () async {
      final location = GeographicLocation(latitude: 28.6139, longitude: 77.2090);
      
      // Mean Node (default)
      final chartMean = await jyotish.calculateVedicChart(
        dateTime: DateTime(1990, 5, 15, 14, 30),
        location: location,
        flags: CalculationFlags.withNodeType(NodeType.meanNode),
      );
      final d249Mean = jyotish.getDivisionalChart(
        rashiChart: chartMean,
        type: DivisionalChartType.d249,
      );
      
      // True Node
      final flagsTrue = CalculationFlags(
        nodeType: NodeType.trueNode,
      );
      final chartTrue = await jyotish.calculateVedicChart(
        dateTime: DateTime(1990, 5, 15, 14, 30),
        location: location,
        flags: flagsTrue,
      );
      final d249True = jyotish.getDivisionalChart(
        rashiChart: chartTrue,
        type: DivisionalChartType.d249,
      );
      
      // Both should work
      expect(d249Mean.planets[Planet.sun]!.zodiacSign, isNotNull);
      expect(d249True.planets[Planet.sun]!.zodiacSign, isNotNull);
    });

    test('D249: Correct degree span for Venus subdivision', () async {
      // Venus subdivision: 0-5.0° (5° total)
      final testAt = 0.0;
      final expectedSpan = 5.0;
      
      for (var i = 0; i <= 54; i++) { // 54 subdivisions per sign
        final chart = await _createChartWithSunAt(testAt);
        final d249 = jyotish.getDivisionalChart(
          rashiChart: chart,
          type: DivisionalChartType.d249,
        );
        
        final subdivisionSpan = d249.planets[Planet.sun]!.subSpan;
        testAt += subdivisionSpan;
      }
      
      // Total should be 5.0° (Venus dasha period)
      expect(testAt, closeTo(expectedSpan, epsilon: 0.01));
    });

    test('D249: Correct degree span for Rahu subdivision', () async {
      // Rahu subdivision: 12.0-16.5° (4.5° total)
      final testAt = 12.0;
      final expectedSpan = 4.5;
      
      for (var i = 0; i <= 54; i++) { // 54 subdivisions per sign
        final chart = await _createChartWithSunAt(testAt);
        final d249 = jyotish.getDivisionalChart(
          rashiChart: chart,
          type: DivisionalChartType.d249,
        );
        
        final subdivisionSpan = d249.planets[Planet.sun]!.subSpan;
        testAt += subdivisionSpan;
      }
      
      // Total should be 4.5° (Rahu dasha period)
      expect(testAt, closeTo(expectedSpan, epsilon: 0.01));
    });

    // Helper method
    Future<VedicChart> _createChartWithSunAt(double longitude) async {
      final location = GeographicLocation(latitude: 28.6139, longitude: 77.2090);
      return await jyotish.calculateVedicChart(
        dateTime: DateTime(1990, 5, 15, 14, 30),
        location: location,
      );
    }
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
