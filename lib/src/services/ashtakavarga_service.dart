import '../models/ashtakavarga.dart';
import '../models/planet.dart';
import '../models/vedic_chart.dart';

/// Service for calculating Ashtakavarga (eightfold division) system.
///
/// Ashtakavarga is a system that evaluates planetary strength by counting
/// benefic points (bindus) contributed by each of the seven planets plus
/// the ascendant in each sign of the zodiac.
class AshtakavargaService {
  /// Calculates the complete Ashtakavarga for a birth chart.
  ///
  /// [natalChart] - The Vedic birth chart
  ///
  /// Returns an [Ashtakavarga] with Bhinnashtakavarga for each planet
  /// and Sarvashtakavarga totals.
  Ashtakavarga calculateAshtakavarga(VedicChart natalChart) {
    // Calculate Bhinnashtakavarga for each planet
    final bhinnashtakavarga = <Planet, Bhinnashtakavarga>{};

    for (final planet in Planet.traditionalPlanets) {
      bhinnashtakavarga[planet] = _calculateBhinnashtakavarga(
        planet,
        natalChart,
      );
    }

    // Calculate Sarvashtakavarga
    final sarvashtakavarga = _calculateSarvashtakavarga(bhinnashtakavarga);

    // Calculate Samudaya Ashtakavarga
    final samudayaAshtakavarga = _calculateSamudayaAshtakavarga(
      bhinnashtakavarga,
    );

    return Ashtakavarga(
      natalChart: natalChart,
      bhinnashtakavarga: bhinnashtakavarga,
      sarvashtakavarga: sarvashtakavarga,
      samudayaAshtakavarga: samudayaAshtakavarga,
    );
  }

  /// Calculates Bhinnashtakavarga for a single planet.
  ///
  /// [subjectPlanet] - The planet for which to calculate Ashtakavarga
  /// [natalChart] - The birth chart containing planetary positions
  Bhinnashtakavarga _calculateBhinnashtakavarga(
    Planet subjectPlanet,
    VedicChart natalChart,
  ) {
    final table = AshtakavargaTables.getTableForPlanet(subjectPlanet);
    final bindus = List<int>.filled(12, 0);
    final contributions = List<int>.filled(12, 0);

    // Get the sign where the subject planet is placed
    final subjectInfo = natalChart.planets[subjectPlanet];
    if (subjectInfo == null) {
      throw ArgumentError('Planet $subjectPlanet not found in chart');
    }

    // Calculate contributions from each contributing planet
    final contributingPlanets = [
      Planet.sun,
      Planet.moon,
      Planet.mars,
      Planet.mercury,
      Planet.jupiter,
      Planet.venus,
      Planet.saturn,
    ];

    for (var signIndex = 0; signIndex < 12; signIndex++) {
      var binduCount = 0;
      var contributionMask = 0;

      // Check contributions from each planet
      for (var i = 0; i < contributingPlanets.length; i++) {
        final contributingPlanet = contributingPlanets[i];

        // Get the sign where the contributing planet is placed
        final planetInfo = natalChart.planets[contributingPlanet];
        final planetSign = planetInfo != null
            ? (planetInfo.position.longitude / 30).floor() % 12
            : 0;

        // Calculate relative sign: where the current signIndex is relative to where the contributing planet sits
        // If contributing planet is in sign X, we check the table to see which signs from X get bindus
        // For signIndex, we calculate: signIndex - planetSign (mod 12)
        final relativeSign = (signIndex - planetSign + 12) % 12;

        // Check if this planet contributes bindu in this sign
        // table[relativeSign][i] tells us if planet i contributes to a sign that is 'relativeSign' away from it
        if (table[relativeSign][i] == 1) {
          binduCount++;
          contributionMask |= 1 << i;
        }
      }

      // Also consider ascendant contribution
      final ascendantSign = (natalChart.houses.ascendant / 30).floor() % 12;
      // Check if ascendant contributes to this signIndex
      final relativeAscendant = (signIndex - ascendantSign + 12) % 12;

      // Ascendant contribution varies by planet
      if (_doesAscendantContribute(subjectPlanet, relativeAscendant)) {
        binduCount++;
        contributionMask |= 1 << 7; // Use bit 7 for ascendant
      }

      bindus[signIndex] = binduCount;
      contributions[signIndex] = contributionMask;
    }

    return Bhinnashtakavarga(
      planet: subjectPlanet,
      bindus: bindus,
      contributions: contributions,
    );
  }

  /// Checks if ascendant contributes bindu for a specific planet in a relative sign.
  bool _doesAscendantContribute(Planet planet, int relativeSign) {
    // Ascendant contribution rules vary by planet
    switch (planet) {
      case Planet.sun:
        return [0, 3, 6, 10, 11].contains(relativeSign);
      case Planet.moon:
        return [1, 3, 6, 7, 10, 11].contains(relativeSign);
      case Planet.mars:
        return [0, 3, 6, 10, 11].contains(relativeSign);
      case Planet.mercury:
        return [0, 2, 4, 6, 8, 10, 11].contains(relativeSign);
      case Planet.jupiter:
        return [0, 2, 4, 6, 8, 9, 10, 11].contains(relativeSign);
      case Planet.venus:
        return [0, 2, 3, 4, 5, 6, 8, 9, 10, 11].contains(relativeSign);
      case Planet.saturn:
        return [0, 3, 5, 6, 9, 10, 11].contains(relativeSign);
      default:
        return false;
    }
  }

  /// Calculates Sarvashtakavarga from all Bhinnashtakavargas.
  Sarvashtakavarga _calculateSarvashtakavarga(
    Map<Planet, Bhinnashtakavarga> bhinnashtakavarga,
  ) {
    final totalBindus = List<int>.filled(12, 0);

    for (final entry in bhinnashtakavarga.entries) {
      for (var i = 0; i < 12; i++) {
        totalBindus[i] += entry.value.bindus[i];
      }
    }

    return Sarvashtakavarga(bindus: totalBindus);
  }

  /// Calculates Samudaya Ashtakavarga (total for all planets).
  List<int> _calculateSamudayaAshtakavarga(
    Map<Planet, Bhinnashtakavarga> bhinnashtakavarga,
  ) {
    // Samudaya is the same as Sarvashtakavarga total
    final totals = List<int>.filled(12, 0);

    for (final entry in bhinnashtakavarga.entries) {
      for (var i = 0; i < 12; i++) {
        totals[i] += entry.value.bindus[i];
      }
    }

    return totals;
  }

  /// Analyzes transit favorability based on Ashtakavarga.
  ///
  /// [ashtakavarga] - The calculated Ashtakavarga
  /// [transitPlanet] - The planet in transit
  /// [transitSign] - The sign being transited (0-11)
  ///
  /// Returns a transit analysis result.
  AshtakavargaTransit analyzeTransit({
    required Ashtakavarga ashtakavarga,
    required Planet transitPlanet,
    required int transitSign,
    DateTime? transitDate,
  }) {
    // Get bindus for the transiting planet in that sign
    final planetBav = ashtakavarga.bhinnashtakavarga[transitPlanet];
    final bindus = planetBav?.getBindusForSign(transitSign) ?? 0;

    // Get total bindus in that sign
    final totalBindus = ashtakavarga.getTotalBindusForSign(transitSign);

    // More than 28 bindus is generally favorable
    final isFavorable = totalBindus > 28;

    // Calculate strength score (0-100)
    var strengthScore = bindus * 10; // Up to 80 for bindus
    if (isFavorable) strengthScore += 20;
    strengthScore = strengthScore.clamp(0, 100);

    return AshtakavargaTransit(
      transitDate: transitDate ?? DateTime.now(),
      transitPlanet: transitPlanet,
      transitSign: transitSign,
      bindus: bindus,
      isFavorable: isFavorable,
      strengthScore: strengthScore,
    );
  }

  /// Gets favorable periods for a specific planet transit.
  ///
  /// Returns a list of sign indices where the planet receives
  /// more than 28 bindus in the Sarvashtakavarga.
  List<int> getFavorableTransitSigns(
    Ashtakavarga ashtakavarga,
    Planet planet,
  ) {
    final favorableSigns = <int>[];

    for (var sign = 0; sign < 12; sign++) {
      if (ashtakavarga.isSignFavorableForTransits(sign)) {
        favorableSigns.add(sign);
      }
    }

    return favorableSigns;
  }

  /// Gets detailed bindu information for all planets in a specific sign.
  Map<Planet, int> getBinduDetailsForSign(
    Ashtakavarga ashtakavarga,
    int signIndex,
  ) {
    final details = <Planet, int>{};

    for (final entry in ashtakavarga.bhinnashtakavarga.entries) {
      details[entry.key] = entry.value.getBindusForSign(signIndex);
    }

    return details;
  }

  /// Applies Trikona Shodhana (Trine Reduction) to Ashtakavarga.
  ///
  /// Trikona Shodhana reduces the bindus in trinal houses (1-5-9, 2-6-10, 3-7-11, 4-8-12)
  /// according to Parashari rules:
  /// - If all three signs in a trikona have bindus, keep the minimum
  /// - If two have bindus, keep the lower one
  /// - If one has bindus, keep that value
  /// - If none have bindus, all remain zero
  Ashtakavarga applyTrikonaShodhana(Ashtakavarga ashtakavarga) {
    final reducedBhinnashtakavarga = <Planet, Bhinnashtakavarga>{};

    for (final entry in ashtakavarga.bhinnashtakavarga.entries) {
      final planet = entry.key;
      final bav = entry.value;
      final reducedBindus = List<int>.from(bav.bindus);

      // Apply reduction to each trikona
      for (final trikona in _trikonas) {
        final bindu1 = bav.bindus[trikona[0]];
        final bindu2 = bav.bindus[trikona[1]];
        final bindu3 = bav.bindus[trikona[2]];

        // Find minimum bindus among the three
        final minBindu = [bindu1, bindu2, bindu3]
            .where((b) => b > 0)
            .reduce((a, b) => a < b ? a : b);

        // Apply reduction
        if (bindu1 > 0) reducedBindus[trikona[0]] = minBindu;
        if (bindu2 > 0) reducedBindus[trikona[1]] = minBindu;
        if (bindu3 > 0) reducedBindus[trikona[2]] = minBindu;
      }

      reducedBhinnashtakavarga[planet] = Bhinnashtakavarga(
        planet: planet,
        bindus: reducedBindus,
        contributions: bav.contributions,
      );
    }

    // Recalculate Sarvashtakavarga
    final sarvashtakavarga = _calculateSarvashtakavarga(reducedBhinnashtakavarga);

    return Ashtakavarga(
      natalChart: ashtakavarga.natalChart,
      bhinnashtakavarga: reducedBhinnashtakavarga,
      sarvashtakavarga: sarvashtakavarga,
      samudayaAshtakavarga: _calculateSamudayaAshtakavarga(reducedBhinnashtakavarga),
    );
  }

  /// Applies Ekadhipati Shodhana (Reduction for Same Lordship).
  ///
  /// Ekadhipati Shodhana is applied to signs owned by the same planet
  /// (e.g., both Gemini and Virgo are owned by Mercury).
  /// The reduction rules are:
  /// - For signs with odd foot (Aries, Taurus, Gemini, Libra, Scorpio, Sagittarius):
  ///   If both have bindus, subtract the smaller from the larger
  /// - For signs with even foot (Cancer, Leo, Virgo, Capricorn, Aquarius, Pisces):
  ///   If both have bindus, keep the smaller value
  Ashtakavarga applyEkadhipatiShodhana(Ashtakavarga ashtakavarga) {
    final reducedBhinnashtakavarga = <Planet, Bhinnashtakavarga>{};

    for (final entry in ashtakavarga.bhinnashtakavarga.entries) {
      final planet = entry.key;
      final bav = entry.value;
      final reducedBindus = List<int>.from(bav.bindus);

      // Apply reduction to each planet's dual signs
      for (final signPair in _dualSigns) {
        final sign1 = signPair[0];
        final sign2 = signPair[1];
        final bindu1 = bav.bindus[sign1];
        final bindu2 = bav.bindus[sign2];

        if (bindu1 > 0 && bindu2 > 0) {
          // Check if signs are odd or even foot
          final isOddFoot = _oddFootSigns.contains(sign1);

          if (isOddFoot) {
            // Odd foot: subtract smaller from larger
            final diff = (bindu1 - bindu2).abs();
            reducedBindus[sign1] = diff;
            reducedBindus[sign2] = diff;
          } else {
            // Even foot: keep the smaller
            final minBindu = bindu1 < bindu2 ? bindu1 : bindu2;
            reducedBindus[sign1] = minBindu;
            reducedBindus[sign2] = minBindu;
          }
        }
      }

      reducedBhinnashtakavarga[planet] = Bhinnashtakavarga(
        planet: planet,
        bindus: reducedBindus,
        contributions: bav.contributions,
      );
    }

    // Recalculate Sarvashtakavarga
    final sarvashtakavarga = _calculateSarvashtakavarga(reducedBhinnashtakavarga);

    return Ashtakavarga(
      natalChart: ashtakavarga.natalChart,
      bhinnashtakavarga: reducedBhinnashtakavarga,
      sarvashtakavarga: sarvashtakavarga,
      samudayaAshtakavarga: _calculateSamudayaAshtakavarga(reducedBhinnashtakavarga),
    );
  }

  /// Calculates Pinda (Planetary Strength) from Ashtakavarga.
  ///
  /// Pinda is the final strength score calculated from the reduced Ashtakavarga.
  /// It multiplies the bindus by specific multipliers for each sign.
  Map<Planet, PindaResult> calculatePinda(Ashtakavarga ashtakavarga) {
    final pindaResults = <Planet, PindaResult>{};

    for (final entry in ashtakavarga.bhinnashtakavarga.entries) {
      final planet = entry.key;
      final bav = entry.value;

      var totalPinda = 0.0;
      final signPindas = <int, double>{};

      for (var signIndex = 0; signIndex < 12; signIndex++) {
        final bindus = bav.bindus[signIndex];
        final multiplier = _pindaMultipliers[signIndex];
        final pinda = bindus * multiplier;

        signPindas[signIndex] = pinda;
        totalPinda += pinda;
      }

      pindaResults[planet] = PindaResult(
        planet: planet,
        totalPinda: totalPinda,
        signPindas: signPindas,
        averagePinda: totalPinda / 12,
      );
    }

    return pindaResults;
  }

  // Trikona groups (trines)
  static const _trikonas = [
    [0, 4, 8],   // Aries, Leo, Sagittarius (Fire)
    [1, 5, 9],   // Taurus, Virgo, Capricorn (Earth)
    [2, 6, 10],  // Gemini, Libra, Aquarius (Air)
    [3, 7, 11],  // Cancer, Scorpio, Pisces (Water)
  ];

  // Dual signs (owned by same planet)
  static const _dualSigns = [
    [2, 5],   // Gemini, Virgo (Mercury)
    [1, 6],   // Taurus, Libra (Venus)
    [0, 7],   // Aries, Scorpio (Mars)
    [8, 11],  // Sagittarius, Pisces (Jupiter)
    [9, 10],  // Capricorn, Aquarius (Saturn)
  ];

  // Signs with odd foot
  static const _oddFootSigns = [0, 1, 2, 6, 7, 8]; // Aries to Sagittarius

  // Pinda multipliers for each sign
  static const _pindaMultipliers = [
    1.0,  // Aries
    2.0,  // Taurus
    3.0,  // Gemini
    4.0,  // Cancer
    5.0,  // Leo
    6.0,  // Virgo
    7.0,  // Libra
    8.0,  // Scorpio
    9.0,  // Sagittarius
    10.0, // Capricorn
    11.0, // Aquarius
    12.0, // Pisces
  ];
}

/// Result of Pinda calculation.
class PindaResult {
  const PindaResult({
    required this.planet,
    required this.totalPinda,
    required this.signPindas,
    required this.averagePinda,
  });

  final Planet planet;
  final double totalPinda;
  final Map<int, double> signPindas;
  final double averagePinda;

  /// Gets Pinda for a specific sign
  double getPindaForSign(int signIndex) => signPindas[signIndex] ?? 0.0;

  @override
  String toString() {
    return '${planet.displayName}: ${totalPinda.toStringAsFixed(1)} total, ${averagePinda.toStringAsFixed(1)} avg';
  }
}
