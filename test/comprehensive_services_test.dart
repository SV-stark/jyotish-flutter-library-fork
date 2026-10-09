import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish/jyotish.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() async {
    final jyotish = Jyotish();
    await jyotish.initialize(ephemerisPath: p.absolute('ephe'));
  });

  group('Comprehensive Services Integration Test Suite', () {
    late VedicChart chart;
    const location = GeographicLocation(
      latitude: 28.6139,
      longitude: 77.2090,
      altitude: 216.0,
      timezone: 'Asia/Kolkata',
    );

    setUp(() async {
      chart = await Jyotish().calculateVedicChart(
        dateTime: DateTime(1995, 8, 20, 10, 15),
        location: location,
      );
    });

    // 1. AspectService Tests
    group('AspectService', () {
      final aspectService = AspectService();

      test('calculates Vedic Graha Drishti aspects accurately', () {
        final positions = chart.planets.map((k, v) => MapEntry(k, v.position));
        final aspects = aspectService.calculateAspects(
          positions,
          config: AspectConfig.vedic,
        );

        expect(aspects, isNotEmpty);
        for (final aspect in aspects) {
          expect(aspect.strength, greaterThanOrEqualTo(0.0));
          expect(aspect.aspectingPlanet, isNotNull);
          expect(aspect.aspectedPlanet, isNotNull);
        }
      });

      test('gets aspects for specific planet', () {
        final positions = chart.planets.map((k, v) => MapEntry(k, v.position));
        final sunAspects = aspectService.getAspectsForPlanet(
          Planet.sun,
          positions,
        );

        expect(sunAspects, isA<List<AspectInfo>>());
      });

      test('calculates Jaimini Rashi Drishti sign aspects', () {
        final rashiAspects = aspectService.getRashiAspects(chart, activeOnly: true);
        expect(rashiAspects, isNotNull);
        expect(rashiAspects, isA<List<RashiDrishtiInfo>>());
      });
    });

    // 2. StrengthAnalysisService Tests
    group('StrengthAnalysisService', () {
      final strengthService = StrengthAnalysisService();

      test('computes Ishtaphala and Kashtaphala correctly', () {
        final ishtaSun = strengthService.getIshtaphala(
          planet: Planet.sun,
          chart: chart,
          shadbalaStrength: 450.0,
        );
        final kashtaSun = strengthService.getKashtaphala(
          planet: Planet.sun,
          chart: chart,
          shadbalaStrength: 450.0,
        );

        expect(ishtaSun, inInclusiveRange(0.0, 1.0));
        expect(kashtaSun, inInclusiveRange(0.0, 1.0));
      });

      test('computes Bhava Bala across all 12 houses', () {
        final shadbalaMap = <Planet, double>{
          Planet.sun: 420.0,
          Planet.moon: 380.0,
          Planet.mars: 410.0,
          Planet.mercury: 390.0,
          Planet.jupiter: 460.0,
          Planet.venus: 370.0,
          Planet.saturn: 350.0,
        };

        final bhavaBala = strengthService.getBhavaBala(
          chart: chart,
          shadbalaResults: shadbalaMap,
        );

        expect(bhavaBala.length, equals(12));
        for (var h = 1; h <= 12; h++) {
          expect(bhavaBala[h], isNotNull);
          expect(bhavaBala[h]!, greaterThanOrEqualTo(0.0));
        }
      });
    });

    // 3. GocharaVedhaService Tests
    group('GocharaVedhaService', () {
      final vedhaService = GocharaVedhaService();

      test('identifies favorable positions and Vedha obstructions', () {
        // Sun transiting 3rd house from Moon (favorable, Vedha in 9th)
        final vedha = vedhaService.calculateVedha(
          transitPlanet: Planet.sun,
          houseFromMoon: 3,
          moonNakshatra: 4,
          otherTransits: {
            Planet.mars: 9, // Mars in 9th causes Vedha obstruction
          },
        );

        expect(vedha.isFavorablePosition, isTrue);
        expect(vedha.isObstructed, isTrue);
        expect(vedha.obstructingPlanets, contains(Planet.mars));
      });

      test('handles Vipareeta Vedha exceptions (Sun-Saturn father-son)', () {
        expect(
          GocharaVedhaService.isVipareetaVedhaException(Planet.sun, Planet.saturn),
          isTrue,
        );
        expect(
          GocharaVedhaService.isVipareetaVedhaException(Planet.moon, Planet.mercury),
          isTrue,
        );
        expect(
          GocharaVedhaService.isVipareetaVedhaException(Planet.sun, Planet.mars),
          isFalse,
        );
      });
    });

    // 4. JaiminiService Tests
    group('JaiminiService', () {
      final jaiminiService = const JaiminiService();

      test('calculates Chara Karakas ranking', () {
        final result8 = jaiminiService.getCharaKarakas(chart, useEightKarakaScheme: true);
        expect(result8.karakas.length, equals(8));

        final result7 = jaiminiService.getCharaKarakas(chart, useEightKarakaScheme: false);
        expect(result7.karakas.length, equals(7));

        final atmakaraka = jaiminiService.getAtmakaraka(chart);
        expect(atmakaraka, equals(result8.atmakaraka));
      });
    });

    // 5. ArudhaPadaService Tests
    group('ArudhaPadaService', () {
      final arudhaService = ArudhaPadaService();

      test('calculates all 12 Arudha Padas including AL and UL', () {
        final result = arudhaService.calculateArudhaPadas(chart);
        expect(result.allPadas.length, equals(12));
        expect(result.arudhaLagna, equals(result.allPadas[1]));
        expect(result.upapada, equals(result.allPadas[12]));
        expect(result.arudhaLagna.sign, isNotNull);
      });
    });

    // 6. TajakaService Tests
    group('TajakaService', () {
      final tajakaService = TajakaService();

      test('calculates Tajaka Muntha and Sahams', () async {
        final annualChart = await Jyotish().calculateVedicChart(
          dateTime: DateTime(2025, 8, 20, 10, 15),
          location: location,
        );

        final tajaka = tajakaService.calculateTajakaEnhancements(
          natalChart: chart,
          annualChart: annualChart,
          age: 30,
        );

        expect(tajaka.munthaHouse, inInclusiveRange(1, 12));
        expect(tajaka.munthaLord, isNotNull);
        expect(tajaka.sahams, isNotEmpty);
      });
    });

    // 7. NadiService Tests
    group('NadiService', () {
      final nadiService = NadiService();

      test('resolves Nadi from longitude and seeds', () {
        final nadi = nadiService.getNadiFromLongitude(45.5);
        expect(nadi.nadiNumber, inInclusiveRange(1, 150));
        expect(nadi.nadiName, isNotEmpty);
        expect(nadi.rulingPlanet, isNotNull);

        final seed = nadiService.identifyNadiSeed(1, 1);
        expect(seed.seedNumber, inInclusiveRange(1, 150));
        expect(seed.primaryNadi, isNotNull);
      });

      test('calculates full Nadi chart', () {
        final nadiChart = nadiService.calculateNadiChart(chart);
        expect(nadiChart.moonNadi, isNotNull);
        expect(nadiChart.sunNadi, isNotNull);
        expect(nadiChart.ascendantNadi, isNotNull);
      });
    });

    // 8. JyotishCompute Background Runner Tests
    group('JyotishCompute', () {
      test('safely executes calculation in background isolate', () async {
        final result = await JyotishCompute.run(() {
          return 42 * 2;
        });
        expect(result, equals(84));
      });
    });
  });
}
