import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish/jyotish.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Public API Exposure & Facade Getters', () {
    late Jyotish jyotish;

    setUpAll(() async {
      jyotish = Jyotish();
      await jyotish.initialize();
    });

    test('All core services have direct getters on Jyotish facade', () {
      expect(jyotish.ephemeris, isA<EphemerisService>());
      expect(jyotish.eclipse, isA<EclipseService>());
      expect(jyotish.aspect, isA<AspectService>());
      expect(jyotish.careerAnalysis, isA<CareerAnalysisService>());
      expect(jyotish.compatibility, isA<CompatibilityService>());
      expect(jyotish.divisionalChart, isA<DivisionalChartService>());
      expect(jyotish.dosha, isA<DoshaService>());
      expect(jyotish.eventTiming, isA<EventTimingService>());
      expect(jyotish.grahaYuddha, isA<GrahaYuddhaService>());
      expect(jyotish.progeny, isA<ProgenyService>());
      expect(jyotish.sudarshanChakra, isA<SudarshanChakraService>());
      expect(jyotish.vedicChart, isA<VedicChartService>());
      expect(jyotish.yoga, isA<YogaService>());
      expect(jyotish.specialLagnas, isA<SpecialLagnasService>());
      expect(jyotish.udayaLagna, isA<UdayaLagnaService>());
      expect(jyotish.choghadiya, isA<ChoghadiyaService>());
      expect(jyotish.gowriPanchangam, isA<GowriPanchangamService>());
      expect(jyotish.hora, isA<HoraService>());
      expect(jyotish.muhurtaScoring, isA<MuhurtaScoringService>());
      expect(jyotish.muhurta, isA<MuhurtaService>());
      expect(jyotish.ritual, isA<RitualService>());
      expect(jyotish.nadi, isA<NadiService>());
      expect(jyotish.masa, isA<MasaService>());
      expect(jyotish.panchanga, isA<PanchangaService>());
      expect(jyotish.bhavaBala, isA<BhavaBalaService>());
      expect(jyotish.bhavaChalit, isA<BhavaChalitService>());
      expect(jyotish.grahaAvastha, isA<GrahaAvasthaService>());
      expect(jyotish.houseStrength, isA<HouseStrengthService>());
      expect(jyotish.panchangStrength, isA<PanchangStrengthService>());
      expect(jyotish.planetaryRelationship, isA<PlanetaryRelationshipService>());
      expect(jyotish.strengthAnalysis, isA<StrengthAnalysisService>());
      expect(jyotish.strengthReport, isA<StrengthReportService>());
      expect(jyotish.argala, isA<ArgalaService>());
      expect(jyotish.arudhaPada, isA<ArudhaPadaService>());
      expect(jyotish.ashtakavarga, isA<AshtakavargaService>());
      expect(jyotish.dasha, isA<DashaService>());
      expect(jyotish.jaimini, isA<JaiminiService>());
      expect(jyotish.kp, isA<KPService>());
      expect(jyotish.prashna, isA<PrashnaService>());
      expect(jyotish.shadbala, isA<ShadbalaService>());
      expect(jyotish.tajaka, isA<TajakaService>());
      expect(jyotish.varshapal, isA<VarshapalService>());
      expect(jyotish.gocharaVedha, isA<GocharaVedhaService>());
      expect(jyotish.sarvatobhadra, isA<SarvatobhadraService>());
      expect(jyotish.specialTransit, isA<SpecialTransitService>());
      expect(jyotish.transit, isA<TransitService>());
    });

    test('JyotishSystems delegates directly to identical service instances', () {
      expect(jyotish.systems.transit, same(jyotish.transit));
      expect(jyotish.systems.dasha, same(jyotish.dasha));
      expect(jyotish.systems.yoga, same(jyotish.yoga));
      expect(jyotish.systems.dosha, same(jyotish.dosha));
      expect(jyotish.systems.divisionalChart, same(jyotish.divisionalChart));
      expect(jyotish.systems.ashtakavarga, same(jyotish.ashtakavarga));
      expect(jyotish.systems.shadbala, same(jyotish.shadbala));
      expect(jyotish.systems.varshapal, same(jyotish.varshapal));
    });

    test('Jyotish.getCurrentVarshaNumber static proxy works correctly', () {
      expect(Jyotish.getCurrentVarshaNumber(DateTime(1987, 5, 1)), 1); // Prabhava
      expect(Jyotish.getCurrentVarshaNumber(DateTime(2026, 5, 1)), 40); // Paraabhava
    });

    test('TajakaService public methods calculateSahams and detectYogas', () async {
      const loc = GeographicLocation(latitude: 28.6139, longitude: 77.2090);
      final chart = await jyotish.calculateVedicChart(
        dateTime: DateTime(2026, 1, 1, 12, 0),
        location: loc,
      );

      final sahams = jyotish.tajaka.calculateSahams(chart);
      expect(sahams.containsKey('Punya'), isTrue);
      expect(sahams.containsKey('Vidya'), isTrue);
      expect(sahams.length, 14);

      final yogas = jyotish.tajaka.detectYogas(chart, Planet.sun, Planet.moon);
      expect(yogas, isA<List<TajakaYoga>>());
    });

    test('SarvatobhadraService getVedhaNakshatras and getNakshatra', () {
      final sbc = jyotish.sarvatobhadra;
      final vedhas = sbc.getVedhaNakshatras(1); // Ashwini
      expect(vedhas, isNotEmpty);
      expect(sbc.getNakshatra(0.0), 1); // 0° Aries -> Ashwini
    });

    test('NadiService getNadiInfo and characteristics public methods', () {
      final nadi = jyotish.nadi;
      final info = nadi.getNadiInfo(1);
      expect(info.nadiNumber, 1);
      expect(info.nadiName, 'Agneya');
      expect(nadi.getNadiType(1), NadiType.agasthiya);
      expect(nadi.getNadiRulingPlanet(1), Planet.sun);
      expect(nadi.getNadiElement(1), 'Fire');
      expect(nadi.getNadiCharacteristics(1), isNotEmpty);
    });

    test('SpecialTransitService calculateSadeSati, calculateDhaiya, calculatePanchak', () async {
      final sts = jyotish.specialTransit;
      final sadeSati = await sts.calculateSadeSati(
        natalMoonLongitude: 0.0, // Aries
        transitSaturnLongitude: 335.0, // Pisces (12th -> rising)
        checkDate: DateTime(2026, 1, 1),
      );
      expect(sadeSati.isActive, isTrue);
      expect(sadeSati.phase, SadeSatiPhase.rising);
      expect(sadeSati.transitedHouse, 12);

      final peakSadeSati = await sts.calculateSadeSati(
        natalMoonLongitude: 10.0, // Aries
        transitSaturnLongitude: 15.0, // Aries (1st -> peak)
        checkDate: DateTime(2026, 1, 1),
      );
      expect(peakSadeSati.isActive, isTrue);
      expect(peakSadeSati.phase, SadeSatiPhase.peak);
      expect(peakSadeSati.transitedHouse, 1);

      final settingSadeSati = await sts.calculateSadeSati(
        natalMoonLongitude: 10.0, // Aries
        transitSaturnLongitude: 45.0, // Taurus (2nd -> setting)
        checkDate: DateTime(2026, 1, 1),
      );
      expect(settingSadeSati.isActive, isTrue);
      expect(settingSadeSati.phase, SadeSatiPhase.setting);
      expect(settingSadeSati.transitedHouse, 2);

      final dhaiya = await sts.calculateDhaiya(
        natalMoonLongitude: 0.0, // Aries
        transitSaturnLongitude: 95.0, // Cancer (4th -> kantaka)
        checkDate: DateTime(2026, 1, 1),
      );
      expect(dhaiya.isActive, isTrue);
      expect(dhaiya.type, DhaiyaType.fourth);
      expect(dhaiya.transitedHouse, 4);

      final ashtamaDhaiya = await sts.calculateDhaiya(
        natalMoonLongitude: 0.0, // Aries
        transitSaturnLongitude: 215.0, // Scorpio (8th -> ashtama)
        checkDate: DateTime(2026, 1, 1),
      );
      expect(ashtamaDhaiya.isActive, isTrue);
      expect(ashtamaDhaiya.type, DhaiyaType.eighth);
      expect(ashtamaDhaiya.transitedHouse, 8);

      final panchak = sts.calculatePanchak(
        transitMoonLongitude: 310.0, // Aquarius (Dhanishta 2nd half to Revati)
        checkDate: DateTime(2026, 1, 1),
      );
      expect(panchak.isActive, isTrue);
    });

    test('TransitService calculateTransitAspects public method', () async {
      const loc = GeographicLocation(latitude: 28.6139, longitude: 77.2090);
      final chart = await jyotish.calculateVedicChart(
        dateTime: DateTime(2026, 1, 1, 12, 0),
        location: loc,
      );

      final sunPos = chart.getPlanet(Planet.sun)!.position;
      final aspects = jyotish.transit.calculateTransitAspects(sunPos, chart);
      expect(aspects, isNotEmpty);
    });

    test('BhavaBalaService helper methods', () async {
      const loc = GeographicLocation(latitude: 28.6139, longitude: 77.2090);
      final chart = await jyotish.calculateVedicChart(
        dateTime: DateTime(2026, 1, 1, 12, 0),
        location: loc,
      );

      expect(jyotish.bhavaBala.getHouseLord(chart, 1), isNotNull);
      expect(jyotish.bhavaBala.calculateBhavaDigBala(1, chart.ascendant), 60.0);
      expect(
        jyotish.bhavaBala.getBhavaStrengthCategory(500.0),
        BhavaStrengthCategory.veryStrong,
      );
    });
  });
}
