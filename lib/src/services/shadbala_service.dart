import '../models/planet.dart';
import '../models/vedic_chart.dart';

/// Service for calculating Shadbala (Six-fold Strength) of planets.
///
/// Shadbala is a comprehensive system for evaluating planetary strength
/// in Vedic astrology. It consists of six types of strength:
/// 1. Sthana Bala (Positional Strength)
/// 2. Dig Bala (Directional Strength)
/// 3. Kala Bala (Temporal Strength)
/// 4. Chesta Bala (Motional Strength)
/// 5. Naisargika Bala (Natural Strength)
/// 6. Drik Bala (Aspectual Strength)
class ShadbalaService {
  /// Calculates complete Shadbala for all planets in a chart.
  ///
  /// [chart] - The Vedic birth chart
  /// Returns a map of planets to their Shadbala results.
  Map<Planet, ShadbalaResult> calculateShadbala(VedicChart chart) {
    final results = <Planet, ShadbalaResult>{};

    for (final entry in chart.planets.entries) {
      final planet = entry.key;
      final planetInfo = entry.value;

      results[planet] = _calculatePlanetShadbala(
        planet: planet,
        planetInfo: planetInfo,
        chart: chart,
      );
    }

    return results;
  }

  /// Calculates Shadbala for a single planet.
  ShadbalaResult _calculatePlanetShadbala({
    required Planet planet,
    required VedicPlanetInfo planetInfo,
    required VedicChart chart,
  }) {
    // 1. Sthana Bala (Positional Strength)
    final sthanaBala = _calculateSthanaBala(planet, planetInfo);

    // 2. Dig Bala (Directional Strength)
    final digBala = _calculateDigBala(planet, planetInfo);

    // 3. Kala Bala (Temporal Strength)
    final kalaBala = _calculateKalaBala(planet, planetInfo, chart);

    // 4. Chesta Bala (Motional Strength)
    final chestaBala = _calculateChestaBala(planet, planetInfo);

    // 5. Naisargika Bala (Natural Strength)
    final naisargikaBala = _calculateNaisargikaBala(planet);

    // 6. Drik Bala (Aspectual Strength)
    final drikBala = _calculateDrikBala(planet, planetInfo, chart);

    // Calculate total Shadbala
    final totalBala = sthanaBala +
        digBala +
        kalaBala +
        chestaBala +
        naisargikaBala +
        drikBala;

    // Determine strength category
    final strengthCategory = _getStrengthCategory(totalBala);

    return ShadbalaResult(
      planet: planet,
      sthanaBala: sthanaBala,
      digBala: digBala,
      kalaBala: kalaBala,
      chestaBala: chestaBala,
      naisargikaBala: naisargikaBala,
      drikBala: drikBala,
      totalBala: totalBala,
      strengthCategory: strengthCategory,
    );
  }

  /// Calculates Sthana Bala (Positional Strength).
  ///
  /// Based on:
  /// - Exaltation/Debilitation
  /// - Own sign/Moola Trikona
  /// - Friendly/Enemy signs
  /// - Placement in angles/trines
  double _calculateSthanaBala(Planet planet, VedicPlanetInfo planetInfo) {
    var strength = 0.0;

    // Base strength from dignity
    switch (planetInfo.dignity) {
      case PlanetaryDignity.exalted:
        strength += 60.0;
        break;
      case PlanetaryDignity.ownSign:
        strength += 45.0;
        break;
      case PlanetaryDignity.moolaTrikona:
        strength += 40.0;
        break;
      case PlanetaryDignity.greatFriend:
        strength += 30.0;
        break;
      case PlanetaryDignity.friendSign:
        strength += 22.5;
        break;
      case PlanetaryDignity.neutralSign:
        strength += 15.0;
        break;
      case PlanetaryDignity.enemySign:
        strength += 7.5;
        break;
      case PlanetaryDignity.greatEnemy:
        strength += 3.75;
        break;
      case PlanetaryDignity.debilitated:
        strength += 0.0;
        break;
    }

    // House placement bonus
    final house = planetInfo.house;
    if (_kendraHouses.contains(house)) {
      strength += 15.0; // Angular houses (1, 4, 7, 10)
    } else if (_trikonaHouses.contains(house)) {
      strength += 12.0; // Trinal houses (5, 9)
    } else if (_upachayaHouses.contains(house)) {
      strength += 8.0; // Growth houses (3, 6, 10, 11)
    } else if (_dusthanaHouses.contains(house)) {
      strength += 4.0; // Difficult houses (6, 8, 12)
    } else {
      strength += 6.0; // Other houses (2)
    }

    return strength.clamp(0.0, 100.0);
  }

  /// Calculates Dig Bala (Directional Strength).
  ///
  /// Planets have maximum strength in specific directions:
  /// - Sun & Mars: 10th house (South)
  /// - Saturn: 7th house (West)
  /// - Moon & Venus: 4th house (North)
  /// - Mercury & Jupiter: 1st house (East)
  double _calculateDigBala(Planet planet, VedicPlanetInfo planetInfo) {
    final house = planetInfo.house;

    // Define optimal houses for each planet
    final optimalHouse = switch (planet) {
      Planet.sun || Planet.mars => 10, // South
      Planet.saturn => 7, // West
      Planet.moon || Planet.venus => 4, // North
      Planet.mercury || Planet.jupiter => 1, // East
      _ => 1,
    };

    // Calculate distance from optimal house
    var distance = (house - optimalHouse).abs();
    if (distance > 6) distance = 12 - distance;

    // Maximum dig bala is 60 when in optimal house
    // Decreases linearly to 0 at opposite house
    final strength = 60.0 * (1.0 - (distance / 6.0));

    return strength.clamp(0.0, 60.0);
  }

  /// Calculates Kala Bala (Temporal Strength).
  ///
  /// Based on:
  /// - Day/night birth
  /// - Hora (planetary hour)
  /// - Season
  /// - Planetary year/month/day/hour
  double _calculateKalaBala(
    Planet planet,
    VedicPlanetInfo planetInfo,
    VedicChart chart,
  ) {
    var strength = 0.0;

    // Base temporal strength
    strength += 30.0;

    // Diurnal/nocturnal strength
    final isDayPlanet = [
      Planet.sun,
      Planet.jupiter,
      Planet.saturn,
    ].contains(planet);

    // Simplified: assume day birth for now
    // In full implementation, check if birth was during day or night
    if (isDayPlanet) {
      strength += 15.0;
    } else {
      strength += 10.0;
    }

    // Paksha Bala (Lunar phase strength for Moon)
    if (planet == Planet.moon) {
      // Check Moon's position relative to Sun
      final sunInfo = chart.planets[Planet.sun];
      if (sunInfo != null) {
        final moonSunDistance =
            (planetInfo.longitude - sunInfo.longitude).abs();
        // Full Moon (180°) gets maximum strength
        final pakshaStrength =
            60.0 * (1.0 - ((moonSunDistance - 180).abs() / 180));
        strength += pakshaStrength.clamp(0.0, 60.0);
      }
    }

    return strength.clamp(0.0, 100.0);
  }

  /// Calculates Chesta Bala (Motional Strength).
  ///
  /// Based on:
  /// - Retrograde motion (higher strength)
  /// - Fast/slow motion
  /// - Stationary points
  double _calculateChestaBala(Planet planet, VedicPlanetInfo planetInfo) {
    var strength = 30.0; // Base strength

    final speed = planetInfo.position.longitudeSpeed;

    // Retrograde planets get extra strength
    if (speed < 0) {
      strength += 30.0;
    }

    // Very slow or stationary planets also get strength
    if (speed.abs() < 0.1) {
      strength += 15.0;
    }

    // Normal speed bonus (simplified)
    if (speed.abs() > 0.5 && speed.abs() < 1.5) {
      strength += 10.0;
    }

    return strength.clamp(0.0, 60.0);
  }

  /// Calculates Naisargika Bala (Natural Strength).
  ///
  /// Based on the inherent brightness/size of planets.
  /// Simplified values based on traditional texts.
  double _calculateNaisargikaBala(Planet planet) {
    // Natural strength values (out of 60)
    const naturalStrengths = {
      Planet.sun: 60.0,
      Planet.moon: 51.43,
      Planet.venus: 42.85,
      Planet.jupiter: 34.28,
      Planet.mercury: 25.71,
      Planet.mars: 17.14,
      Planet.saturn: 8.57,
    };

    return naturalStrengths[planet] ?? 30.0;
  }

  /// Calculates Drik Bala (Aspectual Strength).
  ///
  /// Based on benefic/malefic aspects from other planets.
  double _calculateDrikBala(
    Planet planet,
    VedicPlanetInfo planetInfo,
    VedicChart chart,
  ) {
    var beneficAspects = 0.0;
    var maleficAspects = 0.0;

    // Benefic planets
    const benefics = [
      Planet.jupiter,
      Planet.venus,
      Planet.mercury,
      Planet.moon
    ];
    // Malefic planets
    const malefics = [Planet.saturn, Planet.mars, Planet.sun];

    for (final entry in chart.planets.entries) {
      final otherPlanet = entry.key;
      if (otherPlanet == planet) continue;

      final otherInfo = entry.value;
      final aspect =
          _calculateAspect(planetInfo.longitude, otherInfo.longitude);

      if (aspect) {
        if (benefics.contains(otherPlanet)) {
          beneficAspects += 10.0;
        } else if (malefics.contains(otherPlanet)) {
          maleficAspects += 10.0;
        }
      }
    }

    // Drik Bala = Benefic aspects - Malefic aspects
    // Range: -60 to +60
    final drikBala = beneficAspects - maleficAspects;

    // Normalize to 0-60 range
    return (drikBala + 60.0).clamp(0.0, 60.0);
  }

  /// Checks if two planets are in aspect.
  ///
  /// Simplified aspect calculation for Vedic astrology:
  /// - 7th house aspect (180°) for all planets
  /// - Special aspects for Jupiter (5, 9), Mars (4, 8), Saturn (3, 10)
  bool _calculateAspect(double longitude1, double longitude2) {
    final diff = (longitude1 - longitude2).abs();

    // 7th house aspect (180° ± 8° orb)
    if ((diff - 180).abs() < 8 || diff < 8 || diff > 352) {
      return true;
    }

    return false;
  }

  /// Gets strength category based on total Shadbala.
  ShadbalaStrength _getStrengthCategory(double totalBala) {
    if (totalBala >= 380) {
      return ShadbalaStrength.veryStrong;
    } else if (totalBala >= 330) {
      return ShadbalaStrength.strong;
    } else if (totalBala >= 280) {
      return ShadbalaStrength.moderate;
    } else if (totalBala >= 230) {
      return ShadbalaStrength.weak;
    } else {
      return ShadbalaStrength.veryWeak;
    }
  }

  // House classifications
  static const _kendraHouses = [1, 4, 7, 10];
  static const _trikonaHouses = [5, 9];
  static const _upachayaHouses = [3, 6, 10, 11];
  static const _dusthanaHouses = [6, 8, 12];
}

/// Result of Shadbala calculation for a planet.
class ShadbalaResult {
  const ShadbalaResult({
    required this.planet,
    required this.sthanaBala,
    required this.digBala,
    required this.kalaBala,
    required this.chestaBala,
    required this.naisargikaBala,
    required this.drikBala,
    required this.totalBala,
    required this.strengthCategory,
  });

  final Planet planet;
  final double sthanaBala;
  final double digBala;
  final double kalaBala;
  final double chestaBala;
  final double naisargikaBala;
  final double drikBala;
  final double totalBala;
  final ShadbalaStrength strengthCategory;

  /// Checks if planet is strong enough to give results
  bool get isStrong => totalBala >= 330;

  /// Checks if planet is weak
  bool get isWeak => totalBala < 280;

  /// Gets Rupas (1 Rupa = 60 Shashtiamsas)
  double get rupas => totalBala / 60.0;

  @override
  String toString() {
    return '${planet.displayName}: ${totalBala.toStringAsFixed(1)} (${strengthCategory.name})';
  }
}

/// Strength categories for Shadbala.
enum ShadbalaStrength {
  veryStrong('Very Strong', 'Excellent planetary influence'),
  strong('Strong', 'Good planetary influence'),
  moderate('Moderate', 'Average planetary influence'),
  weak('Weak', 'Reduced planetary influence'),
  veryWeak('Very Weak', 'Minimal planetary influence');

  const ShadbalaStrength(this.name, this.description);

  final String name;
  final String description;
}
