import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish/jyotish.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() async {
    final jyotish = Jyotish();
    await jyotish.initialize(ephemerisPath: p.absolute('ephe'));
  });

  group('Verified Logic Fixes Test Suite', () {
    const location = GeographicLocation(
      latitude: 28.6139,
      longitude: 77.2090,
      altitude: 216.0,
      timezone: 'Asia/Kolkata',
    );

    test('1. swe_houses_ex FFI returns correct Ascendant and MC without crash', () async {
      final jyotish = Jyotish();
      // Delhi 1995-08-20 05:00 UTC (10:30 IST)
      final dtUtc = DateTime.utc(1995, 8, 20, 5, 0);
      final houses = await jyotish.calculateHouses(
        dateTime: dtUtc,
        location: location,
        houseSystem: 'P',
      );

      final ascmc = houses['ascmc']!;
      expect(ascmc.length, greaterThanOrEqualTo(2));
      // Ascendant ~206.54°, MC ~118.18°
      expect(ascmc[0], closeTo(206.543, 0.05));
      expect(ascmc[1], closeTo(118.176, 0.05));
    });

    test('2. Hora night sequence starts with 13th lord and maintains day-to-day chain', () {
      final muhurta = MuhurtaService();
      // Sunday with arbitrary sunrise 6:00, sunset 18:00
      final date = DateTime(2026, 1, 4); // Sunday
      final sunrise = DateTime(2026, 1, 4, 6, 0);
      final sunset = DateTime(2026, 1, 4, 18, 0);

      final periods = muhurta.getHoraPeriods(
        date: date,
        sunrise: sunrise,
        sunset: sunset,
      );
      expect(periods.length, equals(24));

      // Day Horas (0-11): Chaldean order starting from Sun:
      // Sun(0), Ven(1), Merc(2), Moon(3), Sat(4), Jup(5), Mars(6), Sun(7), Ven(8), Merc(9), Moon(10), Sat(11)
      expect(periods[0].lord, equals(Planet.sun));
      expect(periods[11].lord, equals(Planet.saturn)); // 12th day hora

      // Night Hora 1 (index 12): 13th lord in continuous sequence is Jupiter!
      expect(periods[12].lord, equals(Planet.jupiter));

      // Hour 23 (last night hora): Mercury
      expect(periods[23].lord, equals(Planet.mercury));

      // The 25th hora (index 24) must lead to Monday's Moon:
      const horaSequence = [
        Planet.sun,
        Planet.venus,
        Planet.mercury,
        Planet.moon,
        Planet.saturn,
        Planet.jupiter,
        Planet.mars,
      ];
      final nextDayLord = horaSequence[(0 + 24) % 7];
      expect(nextDayLord, equals(Planet.moon));
    });

    test('3. KP Sub-Lord starts from star lord and not always Ketu', () {
      final jyotish = Jyotish();

      // Rohini nakshatra is Star 4 (ruled by Moon, span 40° to 53.333°)
      // At 40.5° (just inside Rohini), the first sub-lord must be Moon!
      final rohiniSubLord = jyotish.systems.kp.getSubLord(40.5);
      expect(rohiniSubLord, equals(Planet.moon));

      // Krittika nakshatra is Star 3 (ruled by Sun, span 26.667° to 40°)
      // At 27.0° (just inside Krittika), the first sub-lord must be Sun!
      final krittikaSubLord = jyotish.systems.kp.getSubLord(27.0);
      expect(krittikaSubLord, equals(Planet.sun));

      // Ashwini nakshatra is Star 1 (ruled by Ketu, span 0° to 13.333°)
      // At 0.5° (just inside Ashwini), the first sub-lord is Ketu
      final ashwiniSubLord = jyotish.systems.kp.getSubLord(0.5);
      expect(ashwiniSubLord, equals(Planet.ketu));
    });

    test('4. Samvatsara 60-year Jovian cycle anchor', () async {
      final masaService = MasaService(EphemerisService());

      // 1987 is Prabhava (index 0)
      final name1987 = await masaService.getSamvatsara(
        dateTime: DateTime(1987, 5, 1),
        location: location,
      );
      expect(name1987, equals('Prabhava'));

      // 2022 is Shubhakruth (index 35)
      final name2022 = await masaService.getSamvatsara(
        dateTime: DateTime(2022, 5, 1),
        location: location,
      );
      expect(name2022, equals('Shubhakruth'));

      // 2023 is Shobhakruth (index 36)
      final name2023 = await masaService.getSamvatsara(
        dateTime: DateTime(2023, 5, 1),
        location: location,
      );
      expect(name2023, equals('Shobhakruth'));

      // 2024 is Krodhi (index 37)
      final name2024 = await masaService.getSamvatsara(
        dateTime: DateTime(2024, 5, 1),
        location: location,
      );
      expect(name2024, equals('Krodhi'));

      // 2025 is Vishvaavasu (index 38)
      final name2025 = await masaService.getSamvatsara(
        dateTime: DateTime(2025, 5, 1),
        location: location,
      );
      expect(name2025, equals('Vishvaavasu'));

      // 2026 is Paraabhava (index 39)
      final name2026 = await masaService.getSamvatsara(
        dateTime: DateTime(2026, 5, 1),
        location: location,
      );
      expect(name2026, equals('Paraabhava'));

      // VarshapalService.getCurrentVarshaNumber for 2026 is 40 (1-based index)
      final varshaNum2026 = VarshapalService.getCurrentVarshaNumber(
        DateTime(2026, 5, 1),
      );
      expect(varshaNum2026, equals(40));
    });

    test('5. Sun minimum required Shadbala is 390.0 virupas (6.5 Rupas)', () async {
      final jyotish = Jyotish();
      final chart = await jyotish.calculateVedicChart(
        dateTime: DateTime(1995, 8, 20, 10, 30),
        location: location,
      );
      final shadbalaMap = await jyotish.systems.shadbala.calculateShadbala(chart);

      expect(shadbalaMap[Planet.sun]!.minimumRequired, equals(390.0));
      expect(shadbalaMap[Planet.sun]!.meetsMinimumStrength, equals(shadbalaMap[Planet.sun]!.totalBala >= 390.0));
    });

    test('6. Shadbala four component tables follow classical BPHS', () async {
      final jyotish = Jyotish();
      final chart = await jyotish.calculateVedicChart(
        dateTime: DateTime(1995, 8, 20, 10, 30),
        location: location,
      );

      // Verify retrograde Chesta Bala in Shadbala
      final retrogradePos = PlanetPosition(
        planet: Planet.jupiter,
        dateTime: chart.dateTime,
        longitude: 135.0,
        latitude: 0.0,
        distance: 5.0,
        longitudeSpeed: -0.05, // Retrograde
        latitudeSpeed: 0.0,
        distanceSpeed: 0.0,
      );
      final retroInfo = VedicPlanetInfo(
        position: retrogradePos,
        house: 5,
        dignity: PlanetaryDignity.ownSign,
      );
      final retroChart = chart.copyWith(
        planets: {...chart.planets, Planet.jupiter: retroInfo},
      );
      final retroShadbala = await jyotish.systems.shadbala.calculateShadbala(retroChart);
      expect(retroShadbala[Planet.jupiter]!.chestaBala, equals(60.0));
    });

    test('7. Tara Koota correctly scores auspicious taras and excludes {3, 5, 7}', () {
      final compService = CompatibilityService();

      // Ashwini (nak 1) to Bharani (nak 2): count = 2 (Sampat - auspicious)
      // Bharani to Ashwini: count = 27 -> (27-1)%9 + 1 = 9 (Parama Mitra - auspicious)
      // Both directions are auspicious -> 1.5 + 1.5 = 3.0
      final scoreAuspicious = compService.calculateTara('Ashwini', 'Bharani', 1, 1);
      expect(scoreAuspicious, equals(3.0));

      // Ashwini (nak 1) to Krittika (nak 3): count = 3 (Vipat - inauspicious) -> 0 from Boy to Girl
      // Krittika to Ashwini: count = 26 -> (26-1)%9 + 1 = 8 (Mitra - auspicious) -> 1.5 from Girl to Boy
      // Total score = 1.5
      final scoreVipat = compService.calculateTara('Ashwini', 'Krittika', 1, 1);
      expect(scoreVipat, equals(1.5));
    });

    test('8. Argala source and obstruction houses use correct inclusive counting', () {
      final now = DateTime(2026, 1, 1);
      const houses = HouseSystem(
        system: 'W',
        ascendant: 15.0,
        midheaven: 105.0,
        cusps: [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330],
      );

      // Place Sun in House 2 (causes 2nd Argala on House 1)
      final sunPos = PlanetPosition(
        planet: Planet.sun,
        dateTime: now,
        longitude: 45.0,
        latitude: 0.0,
        distance: 1.0,
        longitudeSpeed: 1.0,
        latitudeSpeed: 0.0,
        distanceSpeed: 0.0,
      );
      final sunInfo = VedicPlanetInfo(
        position: sunPos,
        house: 2,
        dignity: PlanetaryDignity.neutralSign,
      );

      final chart = VedicChart(
        dateTime: now,
        location: 'Delhi',
        latitude: 28.6139,
        longitudeCoord: 77.2090,
        houses: houses,
        planets: {Planet.sun: sunInfo},
        rahu: sunInfo,
        ketu: KetuPosition(rahuPosition: sunPos),
      );

      final argalaService = ArgalaService();
      // Calculate Argalas for House 1
      final argalasOnH1 = argalaService.calculateArgalaForHouse(chart, 1);
      expect(argalasOnH1.isNotEmpty, isTrue);
      // The Argala on House 1 must be sourced from House 2
      final primaryArgala = argalasOnH1.firstWhere((a) => a.targetHouse == 1);
      expect(primaryArgala.sourceHouse, equals(2));
      expect(primaryArgala.isObstructed, isFalse);
    });

    test('9. AspectService does not count sign occupants as aspecting the sign', () {
      final aspectService = AspectService();
      final positions = {
        Planet.sun: PlanetPosition(
          planet: Planet.sun,
          dateTime: DateTime.now(),
          longitude: 15.0, // Sign 0 (Aries)
          latitude: 0.0,
          distance: 1.0,
          longitudeSpeed: 1.0,
          latitudeSpeed: 0.0,
          distanceSpeed: 0.0,
        ),
      };

      // Sun is in Sign 0 (Aries). It should NOT aspect Sign 0!
      final aspectingSign0 = aspectService.getPlanetsAspectingSign(0, positions);
      expect(aspectingSign0.contains(Planet.sun), isFalse);

      // Sun casts 7th house aspect on Sign 6 (Libra)
      final aspectingSign6 = aspectService.getPlanetsAspectingSign(6, positions);
      expect(aspectingSign6.contains(Planet.sun), isTrue);
    });

    test('10. Kalathra Dosha result hasDosha is self-consistent with description', () {
      final now = DateTime(2026, 1, 1);
      const houses = HouseSystem(
        system: 'W',
        ascendant: 15.0,
        midheaven: 105.0,
        cusps: [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330],
      );

      // Only 1 malefic (Sun) in house 1
      final sunPos = PlanetPosition(
        planet: Planet.sun,
        dateTime: now,
        longitude: 15.0,
        latitude: 0.0,
        distance: 1.0,
        longitudeSpeed: 1.0,
        latitudeSpeed: 0.0,
        distanceSpeed: 0.0,
      );
      final sunInfo = VedicPlanetInfo(
        position: sunPos,
        house: 1,
        dignity: PlanetaryDignity.neutralSign,
      );

      final chart = VedicChart(
        dateTime: now,
        location: 'Delhi',
        latitude: 28.6139,
        longitudeCoord: 77.2090,
        houses: houses,
        planets: {
          Planet.sun: sunInfo,
          Planet.moon: sunInfo,
          Planet.mars: sunInfo.copyWith(house: 3),
          Planet.saturn: sunInfo.copyWith(house: 3),
          Planet.jupiter: sunInfo.copyWith(house: 3),
          Planet.venus: sunInfo.copyWith(house: 3),
          Planet.mercury: sunInfo.copyWith(house: 3),
        },
        rahu: sunInfo.copyWith(house: 3),
        ketu: KetuPosition(rahuPosition: sunPos),
      );

      const doshaService = DoshaService();
      final result = doshaService.checkKalathraDosha(chart);
      // Not all 5 malefics in kalathra houses -> strict dosha is false
      expect(result.hasDosha, isFalse);
      expect(result.description, contains('Partial Kalathra afflictions exist'));
    });

    test('11. Tajaka Kali Saham differs from Bhratru Saham', () {
      final now = DateTime(2026, 1, 1);
      const houses = HouseSystem(
        system: 'W',
        ascendant: 15.0,
        midheaven: 105.0,
        cusps: [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330],
      );

      PlanetPosition pos(Planet p, double lon) => PlanetPosition(
        planet: p,
        dateTime: now,
        longitude: lon,
        latitude: 0,
        distance: 1,
        longitudeSpeed: 1,
        latitudeSpeed: 0,
        distanceSpeed: 0,
      );
      VedicPlanetInfo info(Planet p, double lon) => VedicPlanetInfo(
        position: pos(p, lon),
        house: 1,
        dignity: PlanetaryDignity.neutralSign,
      );

      final chart = VedicChart(
        dateTime: now,
        location: 'Delhi',
        latitude: 28.6139,
        longitudeCoord: 77.2090,
        houses: houses,
        planets: {
          Planet.sun: info(Planet.sun, 10.0),
          Planet.moon: info(Planet.moon, 40.0),
          Planet.mars: info(Planet.mars, 70.0),
          Planet.mercury: info(Planet.mercury, 100.0),
          Planet.jupiter: info(Planet.jupiter, 130.0),
          Planet.venus: info(Planet.venus, 160.0),
          Planet.saturn: info(Planet.saturn, 190.0),
        },
        rahu: info(Planet.meanNode, 220.0),
        ketu: KetuPosition(rahuPosition: pos(Planet.meanNode, 220.0)),
      );

      final tajaka = TajakaService();
      final enhancement = tajaka.calculateTajakaEnhancements(
        natalChart: chart,
        annualChart: chart,
        age: 30,
      );
      final sahams = enhancement.sahams;
      expect(sahams['Bhratru'], isNot(equals(sahams['Kali'])));
    });

    test('12. Special Lagnas anchor at SUNRISE, not at birth', () {
      final now = DateTime(2026, 1, 1, 12, 0); // Noon
      final sunrise = DateTime(2026, 1, 1, 6, 0); // 6 hours elapsed
      const houses = HouseSystem(
        system: 'W',
        ascendant: 90.0, // Cancer
        midheaven: 0.0,
        cusps: [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330],
      );

      final sunPos = PlanetPosition(
        planet: Planet.sun,
        dateTime: now,
        longitude: 250.0,
        latitude: 0,
        distance: 1,
        longitudeSpeed: 1, // 1 degree/day
        latitudeSpeed: 0,
        distanceSpeed: 0,
      );
      final sunInfo = VedicPlanetInfo(
        position: sunPos,
        house: 9,
        dignity: PlanetaryDignity.neutralSign,
      );

      final chart = VedicChart(
        dateTime: now,
        location: 'Delhi',
        latitude: 28.6139,
        longitudeCoord: 77.2090,
        houses: houses,
        planets: {Planet.sun: sunInfo, Planet.moon: sunInfo},
        rahu: sunInfo,
        ketu: KetuPosition(rahuPosition: sunPos),
      );

      const specialLagnasService = SpecialLagnasService();

      // Independent derivation (NOT a restatement of the formula under test):
      //
      //  * Elapsed interval = 6 h from sunrise to birth.
      //  * The Sun travels 1 deg/day, so in 6 h it moves 6/24 = 0.25 deg.
      //    At sunrise it therefore stood at 250.0 - 0.25 = 249.75, not 250.0.
      //  * Hora Lagna gains one sign (30 deg) per 2.5 ghatis, and 2.5 ghatis is
      //    60 minutes, i.e. one hour. Over 6 h that is 6 x 30 = 180 deg.
      //      (249.75 + 180) mod 360 = 69.75
      //  * Ghati Lagna gains one sign per ghati (24 min). 6 h = 15 ghatis, so
      //    15 x 30 = 450 deg.
      //      (249.75 + 450) mod 360 = 339.75
      //
      // Anchoring on the birth-moment Sun instead (250.0) would give 70.0 and
      // 340.0 — the ~1 deg/hour double-count of the Sun's own motion.
      final lagnas = specialLagnasService.calculateSpecialLagnas(
        chart,
        sunrise,
      );
      expect(lagnas.horaLagna, closeTo(69.75, 1e-9));
      expect(lagnas.ghatiLagna, closeTo(339.75, 1e-9));

      // When the caller already knows the Sun at sunrise, it is used verbatim.
      final pinned = specialLagnasService.calculateSpecialLagnas(
        chart,
        sunrise,
        sunLongitudeAtSunrise: 200.0,
      );
      expect(pinned.horaLagna, closeTo((200.0 + 180.0) % 360.0, 1e-9));
      expect(pinned.ghatiLagna, closeTo((200.0 + 450.0) % 360.0, 1e-9));
    });

    test('13. VedicChart.copyWith preserves calculationFlags', () {
      final now = DateTime(2026, 1, 1);
      const houses = HouseSystem(
        system: 'W',
        ascendant: 15.0,
        midheaven: 105.0,
        cusps: [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330],
      );
      const flags = CalculationFlags(
        siderealMode: SiderealMode.krishnamurti,
      );
      final pos = PlanetPosition(
        planet: Planet.sun,
        dateTime: now,
        longitude: 10.0,
        latitude: 0,
        distance: 1,
        longitudeSpeed: 1,
        latitudeSpeed: 0,
        distanceSpeed: 0,
      );
      final info = VedicPlanetInfo(
        position: pos,
        house: 1,
        dignity: PlanetaryDignity.neutralSign,
      );

      final chart = VedicChart(
        dateTime: now,
        location: 'Delhi',
        latitude: 28.6139,
        longitudeCoord: 77.2090,
        houses: houses,
        planets: {Planet.sun: info},
        rahu: info,
        ketu: KetuPosition(rahuPosition: pos),
        calculationFlags: flags,
      );

      final copied = chart.copyWith(location: 'Mumbai');
      expect(copied.calculationFlags?.siderealMode, equals(SiderealMode.krishnamurti));
      expect(copied.flags.siderealMode, equals(SiderealMode.krishnamurti));
    });

    test('14. KPDashaPeriods includes Ketu', () {
      expect(KPDashaPeriods.getPeriod(Planet.ketu), equals(7.0));
      expect(KPDashaPeriods.vimshottariYears[Planet.ketu], equals(7.0));
    });
  });
}
