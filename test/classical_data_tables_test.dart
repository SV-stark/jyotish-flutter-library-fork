import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish/jyotish.dart'
    show
        Jyotish,
        GeographicLocation,
        Planet,
        RelationshipCalculator,
        RelationshipType;

/// Regression tests for the two data tables that have never had coverage.
///
/// Both were flagged for many rounds as wrong on the strength of remembered
/// values. Both were checked against primary sources and found correct, but
/// neither had a test, so nothing stopped a value drifting. These tests pin
/// each table to its source and record the derivation, so a future change has
/// to argue with BPHS rather than with a reviewer's memory.
void main() {
  group('Naisargika Maitri (BPHS 3.55)', () {
    /// The BPHS rule, transcribed: a planet's friends are the lords of the
    /// 2nd, 4th, 5th, 8th, 9th and 12th signs from its Moolatrikona, plus the
    /// lord of its exaltation sign. Everything else is an enemy, and a planet
    /// appearing on both lists is neutral.
    ///
    /// Deriving the table from this rule and comparing all 42 directed pairs
    /// against [RelationshipCalculator.naturalRelationships] agrees exactly,
    /// which is what these expectations encode.
    const expected = <Planet, Map<Planet, RelationshipType>>{
      Planet.sun: {
        Planet.moon: RelationshipType.friend,
        Planet.mars: RelationshipType.friend,
        Planet.jupiter: RelationshipType.friend,
        Planet.mercury: RelationshipType.neutral,
        Planet.venus: RelationshipType.enemy,
        Planet.saturn: RelationshipType.enemy,
      },
      Planet.moon: {
        Planet.sun: RelationshipType.friend,
        Planet.mercury: RelationshipType.friend,
        Planet.mars: RelationshipType.neutral,
        Planet.jupiter: RelationshipType.neutral,
        Planet.venus: RelationshipType.neutral,
        Planet.saturn: RelationshipType.neutral,
      },
      Planet.mars: {
        Planet.sun: RelationshipType.friend,
        Planet.moon: RelationshipType.friend,
        Planet.jupiter: RelationshipType.friend,
        Planet.mercury: RelationshipType.enemy,
        Planet.venus: RelationshipType.neutral,
        Planet.saturn: RelationshipType.neutral,
      },
      Planet.mercury: {
        Planet.sun: RelationshipType.friend,
        Planet.venus: RelationshipType.friend,
        Planet.moon: RelationshipType.enemy,
        Planet.mars: RelationshipType.neutral,
        Planet.jupiter: RelationshipType.neutral,
        Planet.saturn: RelationshipType.neutral,
      },
      Planet.jupiter: {
        Planet.sun: RelationshipType.friend,
        Planet.moon: RelationshipType.friend,
        Planet.mars: RelationshipType.friend,
        Planet.mercury: RelationshipType.enemy,
        Planet.venus: RelationshipType.enemy,
        Planet.saturn: RelationshipType.neutral,
      },
      Planet.venus: {
        Planet.mercury: RelationshipType.friend,
        Planet.saturn: RelationshipType.friend,
        Planet.sun: RelationshipType.enemy,
        Planet.moon: RelationshipType.enemy,
        Planet.mars: RelationshipType.neutral,
        Planet.jupiter: RelationshipType.neutral,
      },
      Planet.saturn: {
        Planet.mercury: RelationshipType.friend,
        Planet.venus: RelationshipType.friend,
        Planet.sun: RelationshipType.enemy,
        Planet.moon: RelationshipType.enemy,
        Planet.mars: RelationshipType.enemy,
        Planet.jupiter: RelationshipType.neutral,
      },
    };

    test('every directed pair matches the BPHS-derived table', () {
      final table = RelationshipCalculator.naturalRelationships;
      for (final planetEntry in expected.entries) {
        for (final otherEntry in planetEntry.value.entries) {
          expect(
            table[planetEntry.key]?[otherEntry.key],
            otherEntry.value,
            reason: '${planetEntry.key.displayName} towards '
                '${otherEntry.key.displayName}',
          );
        }
      }
    });

    test('row widths follow the table\'s own structure', () {
      final table = RelationshipCalculator.naturalRelationships;
      // Seven grahas plus the two nodes. A graha relates to the other six
      // grahas, while a node — which owns no sign — relates to all seven
      // grahas and is documented to act like Saturn (Rahu) and Mars (Ketu).
      expect(table.length, 9);
      for (final planet in Planet.traditionalPlanets) {
        expect(
          table[planet]!.length,
          6,
          reason: '${planet.displayName} should relate to the other six grahas',
        );
      }
      for (final node in [Planet.meanNode, Planet.trueNode, Planet.ketu]) {
        final row = table[node];
        if (row == null) continue;
        expect(
          row.length,
          7,
          reason: '${node.displayName} should relate to all seven grahas',
        );
      }
    });

    test('the deliberately asymmetric pairs are preserved', () {
      // The classical table is not symmetric. Mercury calls the Sun a friend
      // while the Sun calls Mercury neutral, because Mercury owns both the 2nd
      // and the 11th signs from Leo. These are the pairs most likely to be
      // "tidied" into symmetry by a well-meaning edit.
      const table = RelationshipCalculator.naturalRelationships;
      expect(table[Planet.sun]![Planet.mercury], RelationshipType.neutral);
      expect(table[Planet.mercury]![Planet.sun], RelationshipType.friend);
      // The Moon counts Mercury a friend; Mercury counts the Moon its only
      // enemy.
      expect(table[Planet.moon]![Planet.mercury], RelationshipType.friend);
      expect(table[Planet.mercury]![Planet.moon], RelationshipType.enemy);
      // Venus and Saturn are mutual friends, but Saturn lists Mars as an
      // enemy while Mars lists Saturn as neutral.
      expect(table[Planet.venus]![Planet.saturn], RelationshipType.friend);
      expect(table[Planet.saturn]![Planet.venus], RelationshipType.friend);
      expect(table[Planet.saturn]![Planet.mars], RelationshipType.enemy);
      expect(table[Planet.mars]![Planet.saturn], RelationshipType.neutral);
    });

    test('Panchadha Maitri arithmetic combines natural and temporary', () {
      // BPHS 27 / Phaladeepika 2: the five grades come from summing a
      // friend/neutral/enemy score for the natural and temporary layers.
      expect(
        RelationshipCalculator.calculateCompound(
          RelationshipType.friend,
          RelationshipType.friend,
        ),
        RelationshipType.greatFriend,
      );
      expect(
        RelationshipCalculator.calculateCompound(
          RelationshipType.enemy,
          RelationshipType.enemy,
        ),
        RelationshipType.greatEnemy,
      );
      expect(
        RelationshipCalculator.calculateCompound(
          RelationshipType.friend,
          RelationshipType.enemy,
        ),
        RelationshipType.neutral,
      );
      expect(
        RelationshipCalculator.calculateCompound(
          RelationshipType.enemy,
          RelationshipType.friend,
        ),
        RelationshipType.neutral,
      );
      expect(
        RelationshipCalculator.calculateCompound(
          RelationshipType.neutral,
          RelationshipType.friend,
        ),
        RelationshipType.friend,
      );
      expect(
        RelationshipCalculator.calculateCompound(
          RelationshipType.neutral,
          RelationshipType.enemy,
        ),
        RelationshipType.enemy,
      );
      expect(
        RelationshipCalculator.calculateCompound(
          RelationshipType.neutral,
          RelationshipType.neutral,
        ),
        RelationshipType.neutral,
      );
    });
  });

  group('Bhinnashtakavarga fixed totals', () {
    test('each planet donates its classical bindu count and the total is 337',
        () async {
      // B.V. Raman, Ashtakavarga System of Prediction, Ch. II: "The total
      // individual contribution of benefic points by any planet in any
      // horoscope will be the same respective figures as given. The sum total
      // of benefic points of all planets will be 337 for any horoscope. This
      // is constant."
      //
      // These totals are a hard checksum on the ~60 rows of house lists in
      // ashtakavarga.dart: if a row is transcribed wrong the total moves.
      const classicalTotals = <Planet, int>{
        Planet.sun: 48,
        Planet.moon: 49,
        Planet.mars: 39,
        Planet.mercury: 54,
        Planet.jupiter: 56,
        Planet.venus: 52,
        Planet.saturn: 39,
      };

      expect(
        classicalTotals.values.reduce((a, b) => a + b),
        337,
        reason: 'the seven fixed totals must sum to the Sarvashtakavarga total',
      );

      final jyotish = Jyotish();
      await jyotish.initialize();

      // Two unrelated births: the totals must be identical, because they are a
      // property of the tables and not of the chart.
      final births = [
        (
          DateTime(1995, 8, 20, 10, 30),
          const GeographicLocation(latitude: 28.6139, longitude: 77.2090)
        ),
        (
          DateTime(1975, 11, 2, 6, 45),
          const GeographicLocation(latitude: 51.5074, longitude: -0.1278)
        ),
      ];

      for (final (dateTime, location) in births) {
        final chart = await jyotish.calculateVedicChart(
          dateTime: dateTime,
          location: location,
        );
        final aav = jyotish.systems.ashtakavarga.calculateAshtakavarga(chart);

        classicalTotals.forEach((planet, expectedTotal) {
          expect(
            aav.bhinnashtakavarga[planet]!.totalBindus,
            expectedTotal,
            reason: '${planet.displayName} BAV total on $dateTime',
          );
        });

        expect(
          aav.sarvashtakavarga.bindus.reduce((a, b) => a + b),
          337,
          reason: 'Sarvashtakavarga total on $dateTime',
        );
        expect(aav.sarvashtakavarga.total, 337);
      }
    });
  });

  group('Minimum required Shadbala', () {
    test('matches BPHS 27.32-33', () async {
      // "390, 360, 300, 420, 390, 330 and 300 Virupas are the Shadbala Pindas,
      //  needed for Surya etc. to be considered strong." — BPHS 27.32-33.
      //
      // Note the Sun is 390 (6.5 rupas), NOT 300. This value and its test were
      // both flipped in the same commit once, so the suite passed either way
      // and the number was never checked against the verse. Pin it here.
      const classicalMinimum = <Planet, int>{
        Planet.sun: 390,
        Planet.moon: 360,
        Planet.mars: 300,
        Planet.mercury: 420,
        Planet.jupiter: 390,
        Planet.venus: 330,
        Planet.saturn: 300,
      };
      expect(classicalMinimum[Planet.sun], 390);
      expect(classicalMinimum[Planet.sun], isNot(300));

      final jyotish = Jyotish();
      await jyotish.initialize();
      final chart = await jyotish.calculateVedicChart(
        dateTime: DateTime(1995, 8, 20, 10, 30),
        location: const GeographicLocation(
          latitude: 28.6139,
          longitude: 77.2090,
        ),
      );
      final shadbala = await jyotish.systems.shadbala.calculateShadbala(chart);

      classicalMinimum.forEach((planet, minimum) {
        expect(
          shadbala[planet]!.minimumRequired,
          minimum.toDouble(),
          reason: '${planet.displayName} minimum required Shadbala',
        );
      });
    });
  });
}
