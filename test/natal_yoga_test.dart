import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish/jyotish.dart';

void main() {
  group('Natal Yoga Detection Tests', () {
    test('Detects Nipuna and Gaja Kesari Yogas', () {
      final now = DateTime.now();

      // Create a mock HouseSystem (Whole Sign)
      // Ascendant at 0 Aries (Longitude = 0.0)
      final houses = HouseSystem(
        system: 'Whole Sign',
        cusps: List.generate(12, (i) => i * 30.0),
        ascendant: 15.0, // Ascendant in Aries
        midheaven: 270.0,
      );

      // Create mock planets
      // Sun at 10 Aries (House 1, Sign Index 0)
      final sunPos = PlanetPosition(
        planet: Planet.sun,
        dateTime: now,
        longitude: 10.0,
        latitude: 0.0,
        distance: 1.0,
        longitudeSpeed: 1.0,
        latitudeSpeed: 0.0,
        distanceSpeed: 0.0,
      );
      final sunInfo = VedicPlanetInfo(
        position: sunPos,
        house: 1,
        dignity: PlanetaryDignity.exalted, // Sun exalted in Aries
      );

      // Mercury at 15 Aries (House 1, Sign Index 0)
      final mercPos = PlanetPosition(
        planet: Planet.mercury,
        dateTime: now,
        longitude: 15.0,
        latitude: 0.0,
        distance: 1.0,
        longitudeSpeed: 1.2,
        latitudeSpeed: 0.0,
        distanceSpeed: 0.0,
      );
      final mercInfo = VedicPlanetInfo(
        position: mercPos,
        house: 1,
        dignity: PlanetaryDignity.friendSign,
      );

      // Moon at 10 Taurus (House 2, Sign Index 1)
      final moonPos = PlanetPosition(
        planet: Planet.moon,
        dateTime: now,
        longitude: 40.0,
        latitude: 0.0,
        distance: 1.0,
        longitudeSpeed: 13.0,
        latitudeSpeed: 0.0,
        distanceSpeed: 0.0,
      );
      final moonInfo = VedicPlanetInfo(
        position: moonPos,
        house: 2,
        dignity: PlanetaryDignity.exalted, // Moon exalted in Taurus
      );

      // Jupiter at 15 Leo (House 5, Sign Index 4)
      final jupPos = PlanetPosition(
        planet: Planet.jupiter,
        dateTime: now,
        longitude: 135.0,
        latitude: 0.0,
        distance: 5.0,
        longitudeSpeed: 0.08,
        latitudeSpeed: 0.0,
        distanceSpeed: 0.0,
      );
      final jupInfo = VedicPlanetInfo(
        position: jupPos,
        house:
            5, // 4 houses away from Moon (House 2), i.e., in Kendra from Moon (4th position)
        dignity: PlanetaryDignity.friendSign,
      );

      // Mars at 15 Scorpio (House 8, Sign Index 7)
      final marsPos = PlanetPosition(
        planet: Planet.mars,
        dateTime: now,
        longitude: 225.0,
        latitude: 0.0,
        distance: 1.5,
        longitudeSpeed: 0.5,
        latitudeSpeed: 0.0,
        distanceSpeed: 0.0,
      );
      final marsInfo = VedicPlanetInfo(
        position: marsPos,
        house: 8,
        dignity: PlanetaryDignity.ownSign,
      );

      // Saturn at 15 Libra (House 7, Sign Index 6) - Kendra from Lagna (House 7)
      final satPos = PlanetPosition(
        planet: Planet.saturn,
        dateTime: now,
        longitude: 195.0,
        latitude: 0.0,
        distance: 9.5,
        longitudeSpeed: 0.03,
        latitudeSpeed: 0.0,
        distanceSpeed: 0.0,
      );
      final satInfo = VedicPlanetInfo(
        position: satPos,
        house: 7, // House 7
        dignity: PlanetaryDignity.exalted, // Saturn exalted in Libra
      );

      // Venus at 15 Capricorn (House 10, Sign Index 9) - Kendra from Lagna (House 10)
      final venPos = PlanetPosition(
        planet: Planet.venus,
        dateTime: now,
        longitude: 285.0,
        latitude: 0.0,
        distance: 0.7,
        longitudeSpeed: 1.2,
        latitudeSpeed: 0.0,
        distanceSpeed: 0.0,
      );
      final venInfo = VedicPlanetInfo(
        position: venPos,
        house: 10,
        dignity: PlanetaryDignity.friendSign,
      );

      // Rahu/Ketu mock positions
      final rahuPos = PlanetPosition(
        planet: Planet.meanNode,
        dateTime: now,
        longitude: 90.0,
        latitude: 0.0,
        distance: 1.0,
        longitudeSpeed: -0.05,
        latitudeSpeed: 0.0,
        distanceSpeed: 0.0,
      );
      final rahuInfo = VedicPlanetInfo(
        position: rahuPos,
        house: 4,
        dignity: PlanetaryDignity.ownSign,
      );

      final ketu = KetuPosition(rahuPosition: rahuPos);

      // Build planets map
      final planets = <Planet, VedicPlanetInfo>{
        Planet.sun: sunInfo,
        Planet.moon: moonInfo,
        Planet.mercury: mercInfo,
        Planet.venus: venInfo,
        Planet.mars: marsInfo,
        Planet.jupiter: jupInfo,
        Planet.saturn: satInfo,
      };

      final chart = VedicChart(
        dateTime: now,
        location: 'Delhi',
        latitude: 28.6139,
        longitudeCoord: 77.2090,
        houses: houses,
        planets: planets,
        rahu: rahuInfo,
        ketu: ketu,
      );

      // Run yoga service
      const yogaService = YogaService();
      final detected = yogaService.detectNatalYogas(chart);

      // Print detected yogas for debugging
      // ignore: avoid_print
      print(
        'Detected Yogas count: ${detected.where((y) => y.isPresent).length}',
      );
      for (final y in detected.where((y) => y.isPresent)) {
        // ignore: avoid_print
        print('- ${y.name} (${y.key}): ${y.explanation}');
      }

      // Assertions
      final nipuna = detected.firstWhere((y) => y.key == 'nipuna_yoga');
      expect(nipuna.isPresent, isTrue);

      // Jupiter is in a Kendra from the Moon (house 5 from the Moon in house 2),
      // satisfying Gaja-Kesari condition (1). But no benefic conjoins or aspects
      // Jupiter's house, so conditions (2) and (3) fail and the yoga must NOT be
      // reported. Before the fix, only condition (1) was checked and this chart
      // was wrongly reported as a full Gajakesari Yoga.
      final gajaKesari = detected.firstWhere(
        (y) => y.key == 'gaja_kesari_yoga',
      );
      expect(
        gajaKesari.isPresent,
        isFalse,
        reason: 'Jupiter in Kendra from Moon without benefic support is not '
            'Gaja-Kesari Yoga',
      );

      final sasa = detected.firstWhere((y) => y.key == 'sasa_yoga');
      expect(
        sasa.isPresent,
        isTrue,
      ); // Saturn exalted in Libra & in 7th Kendra house from Lagna

      final vesi = detected.firstWhere((y) => y.key == 'vesi_yoga');
      expect(
        vesi.isPresent,
        isFalse,
      ); // Absent because only the Moon is in the 2nd from Sun (excludes Moon)

      final sunapha = detected.firstWhere((y) => y.key == 'sunaphaa_yoga');
      expect(
        sunapha.isPresent,
        isFalse,
      ); // No planets in 2nd from Moon (Gemini - House 3 is empty of traditional planets)
    });

    test('Gaja-Kesari Yoga requires a benefic to support Jupiter', () {
      final now = DateTime.now();

      // Whole-sign chart, Ascendant at 15 Aries.
      final houses = HouseSystem(
        system: 'Whole Sign',
        cusps: List.generate(12, (i) => i * 30.0),
        ascendant: 15.0,
        midheaven: 270.0,
      );

      VedicPlanetInfo info(
        Planet planet,
        double longitude,
        int house,
        PlanetaryDignity dignity,
      ) {
        return VedicPlanetInfo(
          position: PlanetPosition(
            planet: planet,
            dateTime: now,
            longitude: longitude,
            latitude: 0.0,
            distance: 1.0,
            longitudeSpeed: 0.1,
            latitudeSpeed: 0.0,
            distanceSpeed: 0.0,
          ),
          house: house,
          dignity: dignity,
        );
      }

      // Moon in Taurus (house 2); Jupiter in Leo (house 5) is in a Kendra from
      // the Moon. Mercury — a natural benefic — is conjunct Jupiter, and Jupiter
      // is in a friendly sign and uncombust, so all three conditions hold.
      final planets = <Planet, VedicPlanetInfo>{
        Planet.sun: info(Planet.sun, 10.0, 1, PlanetaryDignity.exalted),
        Planet.moon: info(Planet.moon, 40.0, 2, PlanetaryDignity.exalted),
        Planet.mercury: info(
          Planet.mercury,
          136.0,
          5,
          PlanetaryDignity.neutralSign,
        ),
        Planet.venus: info(Planet.venus, 285.0, 10, PlanetaryDignity.friendSign),
        Planet.mars: info(Planet.mars, 225.0, 8, PlanetaryDignity.ownSign),
        Planet.jupiter: info(
          Planet.jupiter,
          135.0,
          5,
          PlanetaryDignity.friendSign,
        ),
        Planet.saturn: info(Planet.saturn, 195.0, 7, PlanetaryDignity.exalted),
      };

      final rahuPos = PlanetPosition(
        planet: Planet.meanNode,
        dateTime: now,
        longitude: 90.0,
        latitude: 0.0,
        distance: 1.0,
        longitudeSpeed: -0.05,
        latitudeSpeed: 0.0,
        distanceSpeed: 0.0,
      );
      final rahuInfo = VedicPlanetInfo(
        position: rahuPos,
        house: 4,
        dignity: PlanetaryDignity.neutralSign,
      );
      final ketu = KetuPosition(rahuPosition: rahuPos);

      final chart = VedicChart(
        dateTime: now,
        location: 'Delhi',
        latitude: 28.6139,
        longitudeCoord: 77.2090,
        houses: houses,
        planets: planets,
        rahu: rahuInfo,
        ketu: ketu,
      );

      const yogaService = YogaService();
      final detected = yogaService.detectNatalYogas(chart);
      final gajaKesari = detected.firstWhere(
        (y) => y.key == 'gaja_kesari_yoga',
      );
      expect(gajaKesari.isPresent, isTrue);
      expect(gajaKesari.explanation, contains('benefic'));
    });
  });
}
