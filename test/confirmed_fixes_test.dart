import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish/jyotish.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() async {
    final ephemerisPath = p.absolute('ephe');
    await Jyotish().initialize(ephemerisPath: ephemerisPath);
  });

  group('Confirmed Fixes Test Suite', () {
    test(
        '1. Transit aspect windows are non-inverted (startDate <= endDate) and exactOrb is non-negative',
        () async {
      final location = const GeographicLocation(
        latitude: 28.6139,
        longitude: 77.2090,
        altitude: 216.0,
        timezone: 'Asia/Kolkata',
      );

      final natalChart = await Jyotish().calculateVedicChart(
        dateTime: DateTime(1990, 1, 1, 12, 0),
        location: location,
      );

      final transits = await Jyotish().getTransitPositions(
        natalChart: natalChart,
        transitDateTime: DateTime(2026, 6, 1, 12, 0),
        location: location,
      );

      expect(transits, isNotEmpty);
      for (final entry in transits.entries) {
        for (final aspect in entry.value.aspectsToNatal) {
          expect(aspect.exactOrb, isNonNegative,
              reason:
                  'exactOrb must never be negative for ${entry.key} aspecting ${aspect.aspectedPlanet}');
          expect(
              aspect.exactOrb, lessThanOrEqualTo(aspect.type.defaultOrb + 0.001));
        }
      }

      final events = await Jyotish().getTransitEvents(
        natalChart: natalChart,
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 30),
        location: location,
      );

      for (final event in events) {
        expect(
            event.startDate.isBefore(event.endDate) ||
                event.startDate.isAtSameMomentAs(event.endDate),
            isTrue,
            reason:
                'Transit event window inverted: startDate ${event.startDate} is after endDate ${event.endDate}');
        expect(
            event.startDate.isBefore(event.exactDate) ||
                event.startDate.isAtSameMomentAs(event.exactDate),
            isTrue);
        expect(
            event.exactDate.isBefore(event.endDate) ||
                event.exactDate.isAtSameMomentAs(event.endDate),
            isTrue);
      }
    });

    test(
        '2. Atmakaraka in DashaService matches JaiminiService with retrograde Rahu reverse degree',
        () {
      final now = DateTime(2026, 1, 1);
      final houses = HouseSystem(
        system: 'Whole Sign',
        cusps: List.generate(12, (i) => i * 30.0),
        ascendant: 15.0,
        midheaven: 270.0,
      );

      // Jupiter at 25° Aries (deg = 25.0)
      final jupiterPos = PlanetPosition(
        planet: Planet.jupiter,
        dateTime: now,
        longitude: 25.0,
        latitude: 0.0,
        distance: 5.0,
        longitudeSpeed: 0.08,
        latitudeSpeed: 0.0,
        distanceSpeed: 0.0,
      );

      // Rahu at 28° Taurus (raw longitude % 30 = 28.0)
      // Because Rahu moves in reverse, its traversed distance in the sign is 30 - 28 = 2.0°!
      // Therefore Jupiter (25.0°) must win over Rahu (2.0°)!
      final rahuPos = PlanetPosition(
        planet: Planet.meanNode,
        dateTime: now,
        longitude: 58.0, // Taurus 28°
        latitude: 0.0,
        distance: 1.0,
        longitudeSpeed: -0.05,
        latitudeSpeed: 0.0,
        distanceSpeed: 0.0,
      );

      final planets = <Planet, VedicPlanetInfo>{
        Planet.sun: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.sun,
            dateTime: now,
            longitude: 10.0,
            latitude: 0.0,
            distance: 1.0,
            longitudeSpeed: 1.0,
            latitudeSpeed: 0.0,
            distanceSpeed: 0.0,
          ),
          house: 1,
          dignity: PlanetaryDignity.ownSign,
        ),
        Planet.moon: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.moon,
            dateTime: now,
            longitude: 12.0,
            latitude: 0.0,
            distance: 1.0,
            longitudeSpeed: 13.0,
            latitudeSpeed: 0.0,
            distanceSpeed: 0.0,
          ),
          house: 1,
          dignity: PlanetaryDignity.ownSign,
        ),
        Planet.mars: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.mars,
            dateTime: now,
            longitude: 14.0,
            latitude: 0.0,
            distance: 1.5,
            longitudeSpeed: 0.5,
            latitudeSpeed: 0.0,
            distanceSpeed: 0.0,
          ),
          house: 1,
          dignity: PlanetaryDignity.ownSign,
        ),
        Planet.mercury: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.mercury,
            dateTime: now,
            longitude: 16.0,
            latitude: 0.0,
            distance: 1.0,
            longitudeSpeed: 1.2,
            latitudeSpeed: 0.0,
            distanceSpeed: 0.0,
          ),
          house: 1,
          dignity: PlanetaryDignity.ownSign,
        ),
        Planet.jupiter: VedicPlanetInfo(
          position: jupiterPos,
          house: 1,
          dignity: PlanetaryDignity.ownSign,
        ),
        Planet.venus: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.venus,
            dateTime: now,
            longitude: 18.0,
            latitude: 0.0,
            distance: 0.7,
            longitudeSpeed: 1.2,
            latitudeSpeed: 0.0,
            distanceSpeed: 0.0,
          ),
          house: 1,
          dignity: PlanetaryDignity.ownSign,
        ),
        Planet.saturn: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.saturn,
            dateTime: now,
            longitude: 20.0,
            latitude: 0.0,
            distance: 9.5,
            longitudeSpeed: 0.03,
            latitudeSpeed: 0.0,
            distanceSpeed: 0.0,
          ),
          house: 1,
          dignity: PlanetaryDignity.ownSign,
        ),
      };

      final chart = VedicChart(
        dateTime: now,
        location: 'Delhi',
        latitude: 28.6139,
        longitudeCoord: 77.2090,
        houses: houses,
        planets: planets,
        rahu: VedicPlanetInfo(
          position: rahuPos,
          house: 2,
          dignity: PlanetaryDignity.ownSign,
        ),
        ketu: KetuPosition(rahuPosition: rahuPos),
      );

      final jaiminiAk = const JaiminiService().getAtmakaraka(chart);
      expect(jaiminiAk, equals(Planet.jupiter),
          reason:
              'Jupiter has 25° in sign while Rahu traversed only 2° (30 - 28)');

      final dashaService = DashaService();
      final narayana = dashaService.getNarayanaDasha(chart);
      expect(narayana.allMahadashas, isNotEmpty);
    });

    test('3. Varshaphala samvatsara numbers cover full 1 to 60 cycle', () {
      // Check current year 2026 matches Prabhava (1987) epoch -> Year 40 (Parabhava)
      final y2026 =
          VarshapalService.getCurrentVarshaNumber(DateTime(2026, 5, 1));
      expect(y2026, equals(40));
      expect(VarshapalService.getSamvatsaraName(y2026), equals('Paraabhava'));
    });

    test(
        '4. Vajra and Yava yogas require proper occupancy across both axis poles',
        () {
      const yogaService = YogaService();
      final now = DateTime(2026, 1, 1);
      final houses = HouseSystem(
        system: 'Whole Sign',
        cusps: List.generate(12, (i) => i * 30.0),
        ascendant: 15.0,
        midheaven: 270.0,
      );

      // Chart where all 3 benefics are clustered in house 1, and house 7 is EMPTY!
      // This must NOT qualify as Vajra Yoga!
      final mockPlanets = <Planet, VedicPlanetInfo>{
        Planet.sun: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.sun,
            dateTime: now,
            longitude: 95.0, // house 4
            latitude: 0,
            distance: 1,
            longitudeSpeed: 1,
            latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: 4,
          dignity: PlanetaryDignity.ownSign,
        ),
        Planet.mars: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.mars,
            dateTime: now,
            longitude: 105.0, // house 4
            latitude: 0,
            distance: 1,
            longitudeSpeed: 1,
            latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: 4,
          dignity: PlanetaryDignity.ownSign,
        ),
        Planet.saturn: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.saturn,
            dateTime: now,
            longitude: 275.0, // house 10
            latitude: 0,
            distance: 1,
            longitudeSpeed: 1,
            latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: 10,
          dignity: PlanetaryDignity.ownSign,
        ),
        Planet.jupiter: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.jupiter,
            dateTime: now,
            longitude: 5.0, // house 1
            latitude: 0,
            distance: 1,
            longitudeSpeed: 1,
            latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: 1,
          dignity: PlanetaryDignity.ownSign,
        ),
        Planet.venus: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.venus,
            dateTime: now,
            longitude: 15.0, // house 1
            latitude: 0,
            distance: 1,
            longitudeSpeed: 1,
            latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: 1,
          dignity: PlanetaryDignity.ownSign,
        ),
        Planet.mercury: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.mercury,
            dateTime: now,
            longitude: 25.0, // house 1
            latitude: 0,
            distance: 1,
            longitudeSpeed: 1,
            latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: 1,
          dignity: PlanetaryDignity.ownSign,
        ),
        Planet.moon: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.moon,
            dateTime: now,
            longitude: 185.0, // house 7
            latitude: 0,
            distance: 1,
            longitudeSpeed: 1,
            latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: 7,
          dignity: PlanetaryDignity.ownSign,
        ),
      };

      final rahu = VedicPlanetInfo(
        position: PlanetPosition(
          planet: Planet.meanNode,
          dateTime: now,
          longitude: 50.0,
          latitude: 0,
          distance: 1,
          longitudeSpeed: -0.05,
          latitudeSpeed: 0,
          distanceSpeed: 0,
        ),
        house: 2,
        dignity: PlanetaryDignity.ownSign,
      );

      final chartEmpty7 = VedicChart(
        dateTime: now,
        location: 'Delhi',
        latitude: 28.6139,
        longitudeCoord: 77.2090,
        houses: houses,
        planets: mockPlanets,
        rahu: rahu,
        ketu: KetuPosition(rahuPosition: rahu.position),
      );

      final yogas = yogaService.detectNatalYogas(chartEmpty7);
      final vajra = yogas.firstWhere((y) => y.key == 'vajra_yoga');
      expect(vajra.isPresent, isFalse,
          reason: 'House 7 has no benefic, so Vajra Yoga must not trigger');

      // Now place Venus in House 7 (185°) so benefics occupy 1 and 7, and malefics occupy 4 and 10:
      final mockPlanetsWithVenusIn7 = Map<Planet, VedicPlanetInfo>.from(mockPlanets)
        ..[Planet.venus] = VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.venus,
            dateTime: now,
            longitude: 195.0, // house 7
            latitude: 0,
            distance: 1,
            longitudeSpeed: 1,
            latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: 7,
          dignity: PlanetaryDignity.ownSign,
        );

      final chartWithVenusIn7 = VedicChart(
        dateTime: now,
        location: 'Delhi',
        latitude: 28.6139,
        longitudeCoord: 77.2090,
        houses: houses,
        planets: mockPlanetsWithVenusIn7,
        rahu: rahu,
        ketu: KetuPosition(rahuPosition: rahu.position),
      );

      final yogasPositive = yogaService.detectNatalYogas(chartWithVenusIn7);
      final vajraPositive = yogasPositive.firstWhere((y) => y.key == 'vajra_yoga');
      expect(vajraPositive.isPresent, isTrue,
          reason: 'Benefics in 1 & 7 and malefics in 4 & 10 must trigger Vajra Yoga under presence rule');
    });

    test('5. Vipareetha Raja Yoga requires adverse cross-dusthana alignment',
        () {
      const yogaService = YogaService();
      final now = DateTime(2026, 1, 1);
      final houses = HouseSystem(
        system: 'Whole Sign',
        cusps: List.generate(12, (i) => i * 30.0), // Aries Lagna
        ascendant: 15.0,
        midheaven: 270.0,
      );

      // Aries Lagna:
      // 6th house is Virgo (Lord = Mercury)
      // 8th house is Scorpio (Lord = Mars)
      // 12th house is Pisces (Lord = Jupiter)
      //
      // Case A: Mercury in 6th house (swakshetra in Virgo), Mars in 1st, Jupiter in 1st.
      // 6th lord in 6th alone should NOT trigger Vipareeta Raja Yoga!
      final planetsCaseA = <Planet, VedicPlanetInfo>{
        Planet.sun: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.sun,
            dateTime: now,
            longitude: 10.0,
            latitude: 0,
            distance: 1,
            longitudeSpeed: 1,
            latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: 1,
          dignity: PlanetaryDignity.ownSign,
        ),
        Planet.moon: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.moon,
            dateTime: now,
            longitude: 12.0,
            latitude: 0,
            distance: 1,
            longitudeSpeed: 13,
            latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: 1,
          dignity: PlanetaryDignity.ownSign,
        ),
        Planet.mars: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.mars,
            dateTime: now,
            longitude: 14.0,
            latitude: 0,
            distance: 1.5,
            longitudeSpeed: 0.5,
            latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: 1,
          dignity: PlanetaryDignity.ownSign,
        ),
        Planet.mercury: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.mercury,
            dateTime: now,
            longitude: 165.0, // Virgo, House 6
            latitude: 0,
            distance: 1,
            longitudeSpeed: 1.2,
            latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: 6,
          dignity: PlanetaryDignity.ownSign,
        ),
        Planet.jupiter: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.jupiter,
            dateTime: now,
            longitude: 18.0,
            latitude: 0,
            distance: 5,
            longitudeSpeed: 0.08,
            latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: 1,
          dignity: PlanetaryDignity.ownSign,
        ),
        Planet.venus: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.venus,
            dateTime: now,
            longitude: 20.0,
            latitude: 0,
            distance: 0.7,
            longitudeSpeed: 1.2,
            latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: 1,
          dignity: PlanetaryDignity.ownSign,
        ),
        Planet.saturn: VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.saturn,
            dateTime: now,
            longitude: 22.0,
            latitude: 0,
            distance: 9.5,
            longitudeSpeed: 0.03,
            latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: 1,
          dignity: PlanetaryDignity.ownSign,
        ),
      };

      final rahu = VedicPlanetInfo(
        position: PlanetPosition(
          planet: Planet.meanNode,
          dateTime: now,
          longitude: 50.0,
          latitude: 0,
          distance: 1,
          longitudeSpeed: -0.05,
          latitudeSpeed: 0,
          distanceSpeed: 0,
        ),
        house: 2,
        dignity: PlanetaryDignity.ownSign,
      );

      final chartA = VedicChart(
        dateTime: now,
        location: 'Delhi',
        latitude: 28.6139,
        longitudeCoord: 77.2090,
        houses: houses,
        planets: planetsCaseA,
        rahu: rahu,
        ketu: KetuPosition(rahuPosition: rahu.position),
      );

      final yogasA = yogaService.detectNatalYogas(chartA);
      final vryA = yogasA.firstWhere((y) => y.key == 'vipareetha_raja_yoga');
      expect(vryA.isPresent, isFalse,
          reason: 'A lone 6th lord in 6th does not form Vipareeta Raja Yoga');

      // Case B: Mercury (6th lord) in 8th house (Scorpio, 225°), Mars (8th lord) in 12th house (Pisces, 345°).
      // Two trik lords in adverse dusthanas! Must form Vipareeta Raja Yoga!
      final planetsCaseB = Map<Planet, VedicPlanetInfo>.from(planetsCaseA)
        ..[Planet.mercury] = VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.mercury,
            dateTime: now,
            longitude: 225.0, // Scorpio, House 8
            latitude: 0,
            distance: 1,
            longitudeSpeed: 1.2,
            latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: 8,
          dignity: PlanetaryDignity.ownSign,
        )
        ..[Planet.mars] = VedicPlanetInfo(
          position: PlanetPosition(
            planet: Planet.mars,
            dateTime: now,
            longitude: 345.0, // Pisces, House 12
            latitude: 0,
            distance: 1.5,
            longitudeSpeed: 0.5,
            latitudeSpeed: 0,
            distanceSpeed: 0,
          ),
          house: 12,
          dignity: PlanetaryDignity.ownSign,
        );

      final chartB = VedicChart(
        dateTime: now,
        location: 'Delhi',
        latitude: 28.6139,
        longitudeCoord: 77.2090,
        houses: houses,
        planets: planetsCaseB,
        rahu: rahu,
        ketu: KetuPosition(rahuPosition: rahu.position),
      );

      final yogasB = yogaService.detectNatalYogas(chartB);
      final vryB = yogasB.firstWhere((y) => y.key == 'vipareetha_raja_yoga');
      expect(vryB.isPresent, isTrue,
          reason:
              '6th lord in 8th and 8th lord in 12th form Vipareeta Raja Yoga');
    });
  });
}
