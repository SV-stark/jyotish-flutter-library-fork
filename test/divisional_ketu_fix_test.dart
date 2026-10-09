import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish/jyotish.dart';

/// Regression tests for two further audited fixes:
///
///  * Ketu's divisional-chart placement is derived from Ketu's own natal
///    longitude rather than from the already-projected Rahu. This matters for
///    the uneven vargas (D30 Trimsamsa, D249), where the mapping does not
///    commute with a 180-degree rotation.
///  * Shadbala's Saptavargaja Bala no longer awards a non-existent
///    "exalted = 60 Virupas" tier, which had inflated its ceiling from the
///    classical 315 to 420.
void main() {
  group('Ketu in the D30 Trimsamsa chart', () {
    /// Builds a synthetic chart with the Rahu longitude under test.
    ///
    /// Whole-sign houses with the ascendant at 15 Aries, so Rahu's natal sign
    /// is the only thing that varies between cases.
    VedicChart chartWithRahu(double rahuLongitude) {
      final now = DateTime.utc(2020, 1, 1);

      VedicPlanetInfo place(
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

      final rahuInfo = place(
        rahuLongitude < 180.0 ? Planet.meanNode : Planet.meanNode,
        rahuLongitude,
        1,
        PlanetaryDignity.neutralSign,
      );
      final rahuPos = rahuInfo.position;
      final ketu = KetuPosition(rahuPosition: rahuPos);

      final planets = <Planet, VedicPlanetInfo>{
        Planet.sun: place(Planet.sun, 10.0, 1, PlanetaryDignity.exalted),
        Planet.moon: place(Planet.moon, 40.0, 2, PlanetaryDignity.exalted),
        Planet.mercury: place(
          Planet.mercury,
          15.0,
          1,
          PlanetaryDignity.friendSign,
        ),
        Planet.venus: place(
          Planet.venus,
          285.0,
          10,
          PlanetaryDignity.friendSign,
        ),
        Planet.mars: place(Planet.mars, 225.0, 8, PlanetaryDignity.ownSign),
        Planet.jupiter: place(
          Planet.jupiter,
          135.0,
          5,
          PlanetaryDignity.friendSign,
        ),
        Planet.saturn: place(
          Planet.saturn,
          195.0,
          7,
          PlanetaryDignity.exalted,
        ),
      };

      return VedicChart(
        dateTime: now,
        location: 'Delhi',
        latitude: 28.6139,
        longitudeCoord: 77.2090,
        houses: HouseSystem(
          system: 'W',
          cusps: List.generate(12, (i) => i * 30.0),
          ascendant: 15.0,
          midheaven: 270.0,
        ),
        planets: planets,
        rahu: rahuInfo,
        ketu: ketu,
      );
    }

    test('Ketu is projected from its own natal longitude', () {
      // Rahu at 10 Aries => Ketu at 10 Libra. Both signs are odd under the
      // Trimsamsa rule (Aries = sign 1, Libra = sign 7) and both degrees are
      // 10, so each maps to the Sagittarius Trimsamsa. Ketu must therefore land
      // in Sagittarius.
      //
      // The old code instead took Rahu's mapped sign (Sagittarius) and added
      // 180 degrees, landing on Gemini — a different sign entirely.
      final chart = chartWithRahu(10.0);
      expect(chart.ketu.longitude, closeTo(190.0, 1e-9));

      final d30 = DivisionalChartService().calculateDivisionalChart(
        chart,
        DivisionalChartType.d30,
      );

      expect(d30.ketu.longitude, greaterThanOrEqualTo(240.0));
      expect(d30.ketu.longitude, lessThan(270.0)); // Sagittarius

      // Rahu's own D30 placement: 10 Aries is an odd sign, degree 10 falls in
      // the 10-18 band, which is the Sagittarius Trimsamsa.
      expect((d30.rahu.longitude / 30).floor(), 8); // Sagittarius
      // Ketu is projected independently from 10 Libra to the same band. Note
      // this deliberately puts Ketu in the SAME D30 sign as Rahu — Trimsamsa
      // does not preserve opposition.
      expect((d30.ketu.longitude / 30).floor(), 8); // Sagittarius
      // The old behaviour would have reported Gemini (sign index 2) here,
      // because it added 180 degrees to Rahu's mapped sign.
      expect((d30.ketu.longitude / 30).floor(), isNot(2));
    });

    test('Ketu stays exactly opposite Rahu in evenly divided vargas', () {
      // For D9 the mapping does commute with a 180-degree rotation, so Ketu
      // must remain six signs from Rahu in the Navamsa.
      final chart = chartWithRahu(10.0);
      final d9 = DivisionalChartService().calculateDivisionalChart(
        chart,
        DivisionalChartType.d9,
      );

      final rahuSign = (d9.rahu.longitude / 30).floor();
      final ketuSign = (d9.ketu.longitude / 30).floor();
      expect(ketuSign, (rahuSign + 6) % 12);
    });
  });

  group('Shadbala Saptavargaja Bala ceiling', () {
    test('Sthana Bala stays inside the BPHS ceiling with no bogus exalted tier', () async {
      // Sthana Bala = Uchcha (max 60) + Saptavargaja + Ojhayugma (max 30)
      //   + Kendra (max 60) + Drekkana (max 15).
      //
      // The old `_getSaptavargajaScore` mapped an *exalted* dignity to 60
      // Virupas, a tier that does not exist in BPHS Ch. 27 (which scores the
      // planet against the sign lord only). Brute-forcing every longitude
      // against all seven vargas shows the achievable Saptavargaja maximum is
      // 285 Virupas (Mars), whereas the old table could reach 405 (Sun),
      // because each exalted varga alone contributed 60 instead of 4-20.
      //
      // So Sthana Bala can reach at most 165 + 285 = 450. A reinstated
      // "exalted = 60" tier pushes it to 165 + 405 = 570 and is caught here.
      const otherComponentsMaximum = 165.0; // 60 + 30 + 60 + 15
      const achievableSaptavargajaMaximum = 285.0;
      const sthanaBalaCeiling = otherComponentsMaximum +
          achievableSaptavargajaMaximum;
      expect(sthanaBalaCeiling, 450.0);
      expect(450.0, lessThan(480.0)); // still under the theoretical BPHS max

      final jyotish = Jyotish();
      await jyotish.initialize();

      final births = <(DateTime, GeographicLocation)>[
        (DateTime(1990, 5, 15, 14, 30), const GeographicLocation(latitude: 28.6139, longitude: 77.2090)),
        (DateTime(1975, 11, 2, 6, 45), const GeographicLocation(latitude: 51.5074, longitude: -0.1278)),
        (DateTime(2001, 2, 9, 22, 15), const GeographicLocation(latitude: -33.8688, longitude: 151.2093)),
        (DateTime(1968, 7, 30, 3, 20), const GeographicLocation(latitude: 19.0760, longitude: 72.8777)),
      ];

      // A synthetic chart with the Sun at 0 Aries: this longitude is exalted in
      // six of the seven Saptavargaja vargas, so it is the case that most
      // exposes an inflated exalted tier. Real birth charts rarely reach it.
      births.add((DateTime(2020, 1, 1, 12, 0), const GeographicLocation(latitude: 28.6139, longitude: 77.2090)));

      for (final (dateTime, location) in births) {
        VedicChart chart;
        if (dateTime == DateTime(2020, 1, 1, 12, 0)) {
          chart = _chartWithSunAtStartOfAries(dateTime);
        } else {
          chart = await jyotish.calculateVedicChart(
            dateTime: dateTime,
            location: location,
          );
        }
        final shadbala = await jyotish.getShadbala(chart);

        expect(shadbala, isNotEmpty);
        for (final entry in shadbala.entries) {
          expect(
            entry.value.sthanaBala,
            lessThanOrEqualTo(sthanaBalaCeiling),
            reason: '${entry.key.displayName} sthanaBala '
                '${entry.value.sthanaBala} exceeds the achievable ceiling',
          );
        }
      }
    });
  });
}

/// Builds a synthetic whole-sign chart with the Sun at 0 Aries (its exaltation
/// sign). Every other body is placed at a neutral longitude.
VedicChart _chartWithSunAtStartOfAries(DateTime now) {
  VedicPlanetInfo place(Planet planet, double longitude) => VedicPlanetInfo(
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
        house: ((longitude / 30).floor() % 12) + 1,
        dignity: PlanetaryDignity.neutralSign,
      );

  final planets = <Planet, VedicPlanetInfo>{
    Planet.sun: place(Planet.sun, 0.0),
    Planet.moon: place(Planet.moon, 40.0),
    Planet.mercury: place(Planet.mercury, 15.0),
    Planet.venus: place(Planet.venus, 285.0),
    Planet.mars: place(Planet.mars, 225.0),
    Planet.jupiter: place(Planet.jupiter, 135.0),
    Planet.saturn: place(Planet.saturn, 195.0),
  };
  final rahuInfo = place(Planet.meanNode, 90.0);

  return VedicChart(
    dateTime: now,
    location: 'Synthetic (Sun at 0 Aries)',
    latitude: 28.6139,
    longitudeCoord: 77.2090,
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
