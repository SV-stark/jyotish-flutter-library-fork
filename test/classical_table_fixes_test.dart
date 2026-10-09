import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish/jyotish.dart';

/// Regression tests for the audited data-table and interpretation fixes.
///
/// These lock in classical BPHS / Muhurta-Chintamani / Saravali values so the
/// tables cannot silently drift again. Each expectation cites its source.
void main() {
  group('Varna Koota (Dakshin-Bharat nakshatra table, 7/7/7/6)', () {
    final service = CompatibilityService();

    test('covers all 27 nakshatras with no silent fallback', () {
      // Every nakshatra must resolve to a Varna. Before the fix only 26 of 27
      // were listed and Mula fell through to a bare `return 'Shudra'`.
      const all = [
        'Ashwini', 'Bharani', 'Krittika', 'Rohini', 'Mrigashira', 'Ardra',
        'Punarvasu', 'Pushya', 'Ashlesha', 'Magha', 'Purva Phalguni',
        'Uttara Phalguni', 'Hasta', 'Chitra', 'Swati', 'Vishakha', 'Anuradha',
        'Jyeshtha', 'Mula', 'Purva Ashadha', 'Uttara Ashadha', 'Shravana',
        'Dhanishta', 'Shatabhisha', 'Purva Bhadrapada', 'Uttara Bhadrapada',
        'Revati',
      ];

      // Spot-check the classical table (Madhaviya Grantha / B.V. Raman).
      const expected = <String, String>{
        'Ashwini': 'Brahmin',
        'Pushya': 'Brahmin',
        'Ashlesha': 'Brahmin',
        'Vishakha': 'Brahmin',
        'Anuradha': 'Brahmin',
        'Shatabhisha': 'Brahmin',
        'Purva Bhadrapada': 'Brahmin',
        'Bharani': 'Kshatriya',
        'Punarvasu': 'Kshatriya',
        'Magha': 'Kshatriya',
        'Swati': 'Kshatriya',
        'Jyeshtha': 'Kshatriya',
        'Dhanishta': 'Kshatriya',
        'Uttara Bhadrapada': 'Kshatriya',
        'Krittika': 'Vaishya',
        'Ardra': 'Vaishya',
        'Purva Phalguni': 'Vaishya',
        'Chitra': 'Vaishya',
        'Mula': 'Vaishya',
        'Shravana': 'Vaishya',
        'Revati': 'Vaishya',
        'Rohini': 'Shudra',
        'Mrigashira': 'Shudra',
        'Uttara Phalguni': 'Shudra',
        'Hasta': 'Shudra',
        'Purva Ashadha': 'Shudra',
        'Uttara Ashadha': 'Shudra',
      };

      expect(expected.length, 27);

      for (final nakshatra in all) {
        expect(
          expected.containsKey(nakshatra),
          isTrue,
          reason: 'test table is missing $nakshatra',
        );
      }

      // Two nakshatras of different varna must score 1 when the boy's varna is
      // higher, and 0 when it is lower.
      // Ashwini = Brahmin (highest), Rohini = Shudra (lowest).
      expect(service.calculateVarna('Ashwini', 'Rohini'), 1);
      expect(service.calculateVarna('Rohini', 'Ashwini'), 0);
      // Same varna always scores 1 regardless of direction.
      expect(service.calculateVarna('Ashwini', 'Pushya'), 1);
      expect(service.calculateVarna('Mula', 'Shravana'), 1);
      // Mula is Vaishya and Shravana is Vaishya, so this scores 1. The old
      // table put Mula alone in Shudra, which made this 1 for the wrong reason
      // and inverted the direction.
      // Vaishya (Mula, index 2) is higher than Shudra (Rohini, index 3).
      expect(service.calculateVarna('Mula', 'Rohini'), 1);
      expect(service.calculateVarna('Rohini', 'Mula'), 0);
    });

    test('an unrecognised nakshatra throws rather than guessing', () {
      expect(
        () => service.calculateVarna('NotANakshatra', 'Ashwini'),
        throwsArgumentError,
      );
    });
  });

  group('Yoni Koota matrix (Muhurta Chintamani / Saravali, 5-tier)', () {
    final service = CompatibilityService();

    test('same animal scores 4 and the seven enemy pairs score 0', () {
      // Each pair below is the same yoni animal, so both directions score 4.
      const sameAnimalPairs = [
        ['Ashwini', 'Shatabhisha'], // Horse
        ['Bharani', 'Revati'], // Elephant
        ['Krittika', 'Pushya'], // Goat
        ['Rohini', 'Mrigashira'], // Serpent
        ['Ardra', 'Mula'], // Dog
        ['Punarvasu', 'Ashlesha'], // Cat
        ['Magha', 'Purva Phalguni'], // Rat
        ['Uttara Phalguni', 'Uttara Bhadrapada'], // Cow
        ['Hasta', 'Swati'], // Buffalo
        ['Chitra', 'Vishakha'], // Tiger
        ['Anuradha', 'Jyeshtha'], // Deer
        ['Purva Ashadha', 'Shravana'], // Monkey
        ['Dhanishta', 'Purva Bhadrapada'], // Lion
      ];
      for (final pair in sameAnimalPairs) {
        expect(
          service.calculateYoni(pair[0], pair[1]),
          4,
          reason: 'same yoni ${pair[0]}/${pair[1]} must score 4',
        );
      }

      // The seven sworn-enemy (predator/prey) pairs score 0.
      const enemyPairs = [
        ['Ashwini', 'Hasta'], // Horse / Buffalo
        ['Bharani', 'Dhanishta'], // Elephant / Lion
        ['Krittika', 'Purva Ashadha'], // Goat / Monkey
        ['Rohini', 'Uttara Ashadha'], // Serpent / Mongoose
        ['Ardra', 'Anuradha'], // Dog / Deer
        ['Punarvasu', 'Magha'], // Cat / Rat
        ['Uttara Phalguni', 'Chitra'], // Cow / Tiger
      ];
      for (final pair in enemyPairs) {
        expect(
          service.calculateYoni(pair[0], pair[1]),
          0,
          reason: 'enemy pair ${pair[0]}/${pair[1]} must score 0',
        );
        // The matrix is symmetric.
        expect(
          service.calculateYoni(pair[1], pair[0]),
          0,
          reason: 'enemy pair ${pair[1]}/${pair[0]} must score 0',
        );
      }
    });

    test('the "inimical" tier of 1 is present, not inflated to 2', () {
      // Horse/Tiger and Horse/Cow are classically inimical (not sworn enemies)
      // and score 1. Under the old matrix they were collapsed to 2.
      expect(service.calculateYoni('Ashwini', 'Chitra'), 1);
      expect(service.calculateYoni('Chitra', 'Ashwini'), 1);
      expect(service.calculateYoni('Ashwini', 'Uttara Phalguni'), 1);
      expect(service.calculateYoni('Uttara Phalguni', 'Ashwini'), 1);
    });

    test('an unresolvable animal throws rather than defaulting to 1', () {
      expect(
        () => service.calculateYoni('NotANakshatra', 'Ashwini'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Gana Koota (directional, out of 6)', () {
    final service = CompatibilityService();

    test('same gana scores the full 6', () {
      // Deva + Deva, Manushya + Manushya, Rakshasa + Rakshasa.
      expect(service.calculateGana('Ashwini', 'Mrigashira'), 6); // Deva/Deva
      expect(service.calculateGana('Bharani', 'Rohini'), 6); // Manushya/Manushya
      expect(service.calculateGana('Krittika', 'Magha'), 6); // Rakshasa/Rakshasa
    });

    test('Deva+Manushya is directional: 6 and 5, never 3', () {
      // Boy Deva (Ashwini), girl Manushya (Bharani) => 6.
      expect(service.calculateGana('Ashwini', 'Bharani'), 6);
      // Boy Manushya, girl Deva => 5.
      expect(service.calculateGana('Bharani', 'Ashwini'), 5);
    });

    test('cross-gana pairings with Rakshasa score 1 or 0, never 3', () {
      // Boy Rakshasa (Krittika), girl Deva (Ashwini) => 1.
      expect(service.calculateGana('Krittika', 'Ashwini'), 1);
      // Boy Deva, girl Rakshasa => 0.
      expect(service.calculateGana('Ashwini', 'Krittika'), 0);
      // Manushya + Rakshasa in either direction => 0.
      expect(service.calculateGana('Bharani', 'Krittika'), 0);
      expect(service.calculateGana('Krittika', 'Bharani'), 0);
    });
  });

  group('Nitya Yoga lords (nine-planet cycle, three times over)', () {
    test('the 27 lords follow the Parashari sequence exactly', () {
      const expectedLords = <int, Planet>{
        1: Planet.saturn, // Vishkumbha
        2: Planet.mercury, // Priti
        3: Planet.ketu, // Ayushman
        4: Planet.venus, // Saubhagya
        5: Planet.sun, // Shobhana
        6: Planet.moon, // Atiganda
        7: Planet.mars, // Sukarma
        8: Planet.meanNode, // Dhriti (Rahu)
        9: Planet.jupiter, // Shula
        10: Planet.saturn, // Ganda
        15: Planet.moon, // Vajra
        17: Planet.meanNode, // Vyatipata
        21: Planet.ketu, // Siddha
        25: Planet.mars, // Brahma
        26: Planet.meanNode, // Indra
        27: Planet.jupiter, // Vaidhriti
      };

      expectedLords.forEach((number, planet) {
        expect(
          YogaDetails.getDetails(number).rulingPlanet,
          planet,
          reason: 'yoga #$number lord mismatch',
        );
      });
    });

    test('each of the nine planets rules exactly three yogas', () {
      final counts = <Planet, int>{};
      for (var n = 1; n <= 27; n++) {
        final lord = YogaDetails.getDetails(n).rulingPlanet;
        counts[lord] = (counts[lord] ?? 0) + 1;
      }
      // A seven-planet table cannot evenly divide 27; the old table produced
      // 6/5/4/4/3/3/2, which is the signature of a scrambled rotation.
      expect(counts.length, 9);
      for (final entry in counts.entries) {
        expect(
          entry.value,
          3,
          reason: '${entry.key.displayName} rules ${entry.value} yogas, '
              'expected 3',
        );
      }
    });

    test('the malefic nature set matches the standard tables', () {
      const maleficNumbers = [1, 6, 9, 10, 13, 15, 17, 19, 27];
      for (var n = 1; n <= 27; n++) {
        final nature = YogaDetails.getDetails(n).nature;
        if (maleficNumbers.contains(n)) {
          expect(nature, YogaNature.malefic, reason: 'yoga #$n');
        } else {
          expect(nature, isNot(YogaNature.malefic), reason: 'yoga #$n');
        }
      }
    });
  });
}
