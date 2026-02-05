import '../models/divisional_chart_type.dart';
import '../models/planet.dart';
import '../models/vedic_chart.dart';
import 'divisional_chart_service.dart';

/// Service for calculating Shadbala (Six-fold Strength) of planets.
///
/// Shadbala consists of six types of strength:
/// 1. Sthana Bala (Positional Strength)
/// 2. Dig Bala (Directional Strength)
/// 3. Kala Bala (Temporal Strength)
/// 4. Chesta Bala (Motional Strength)
/// 5. Naisargika Bala (Natural Strength)
/// 6. Drik Bala (Aspectual Strength)
class ShadbalaService {
  final DivisionalChartService _divisionalChartService =
      DivisionalChartService();

  /// Calculates complete Shadbala for all planets in a chart.
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
    final sthanaBala = _calculateSthanaBala(planet, planetInfo, chart);

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

  double _calculateSthanaBala(
      Planet planet, VedicPlanetInfo planetInfo, VedicChart chart) {
    var strength = 0.0;

    // 1. Precise Uchcha Bala (Exaltation Strength)
    strength += _calculateUchchaBala(planet, planetInfo.position.longitude);

    // 2. Saptavargaja Bala (Seven-fold divisional dignity)
    strength += _calculateSaptavargajaBala(planet, chart);

    // 3. Ojayugmarasyamsa Bala (Odd/Even sign and Navamsa)
    strength += _calculateOjayugmarasyamsaBala(
        planet, planetInfo.position.longitude, chart);

    // 4. Drekkana Bala
    strength += _calculateDrekkanaBala(planet, planetInfo.position.longitude);

    // 5. Kendra Bala (House placement)
    strength += _calculateKendraBala(planetInfo.house);

    return strength;
  }

  /// Calculates precise Uchcha Bala (Exaltation Strength).
  double _calculateUchchaBala(Planet planet, double longitude) {
    final deepExaltation = _deepExaltationPoints[planet];
    if (deepExaltation == null) return 0.0;

    final deepDebilitation = (deepExaltation + 180) % 360;
    final elongation = (longitude - deepDebilitation + 360) % 360;
    return (elongation > 180 ? (360 - elongation) : elongation) / 180.0 * 60.0;
  }

  /// Calculates Saptavargaja Bala (Strength in 7 divisional charts).
  double _calculateSaptavargajaBala(Planet planet, VedicChart rashiChart) {
    if (Planet.lunarNodes.contains(planet)) return 0.0;

    final charts = [
      DivisionalChartType.d1,
      DivisionalChartType.d2,
      DivisionalChartType.d3,
      DivisionalChartType.d7,
      DivisionalChartType.d9,
      DivisionalChartType.d12,
      DivisionalChartType.d30,
    ];

    var totalStrength = 0.0;
    for (final type in charts) {
      final vargaChart =
          _divisionalChartService.calculateDivisionalChart(rashiChart, type);
      final info = vargaChart.getPlanet(planet);
      if (info == null) continue;

      totalStrength += _getSaptavargajaScore(info.dignity);
    }

    return totalStrength;
  }

  double _getSaptavargajaScore(PlanetaryDignity dignity) {
    return switch (dignity) {
      PlanetaryDignity.moolaTrikona => 45.0,
      PlanetaryDignity.ownSign => 30.0,
      PlanetaryDignity.greatFriend => 22.5,
      PlanetaryDignity.friendSign => 15.0,
      PlanetaryDignity.neutralSign => 7.5,
      PlanetaryDignity.enemySign => 3.75,
      PlanetaryDignity.greatEnemy => 1.875,
      PlanetaryDignity.exalted => 60.0,
      PlanetaryDignity.debilitated => 0.0,
    };
  }

  double _calculateOjayugmarasyamsaBala(
      Planet planet, double rashiLong, VedicChart rashiChart) {
    final rashiSignIndex = (rashiLong / 30).floor() % 12;
    final rashiIsOdd = (rashiSignIndex + 1) % 2 != 0;

    final navamsaChart = _divisionalChartService.calculateDivisionalChart(
        rashiChart, DivisionalChartType.d9);
    final navamsaInfo = navamsaChart.getPlanet(planet);
    if (navamsaInfo == null) return 0.0;

    final navamsaSignIndex = (navamsaInfo.longitude / 30).floor() % 12;
    final navamsaIsOdd = (navamsaSignIndex + 1) % 2 != 0;

    final isFemale = [Planet.moon, Planet.venus].contains(planet);
    final isMale = [Planet.sun, Planet.mars, Planet.jupiter].contains(planet);

    var strength = 0.0;
    if (isMale) {
      if (rashiIsOdd) strength += 15.0;
      if (navamsaIsOdd) strength += 15.0;
    } else if (isFemale) {
      if (!rashiIsOdd) strength += 15.0;
      if (!navamsaIsOdd) strength += 15.0;
    }

    return strength;
  }

  double _calculateDrekkanaBala(Planet planet, double longitude) {
    final degInSign = longitude % 30;
    final decanate = (degInSign / 10).floor(); // 0, 1, 2

    final isMale = [Planet.sun, Planet.mars, Planet.jupiter].contains(planet);
    final isFemale = [Planet.moon, Planet.venus].contains(planet);
    final isNeutral = [Planet.mercury, Planet.saturn].contains(planet);

    if (isMale && decanate == 0) return 15.0;
    if (isNeutral && decanate == 1) return 15.0;
    if (isFemale && decanate == 2) return 15.0;

    return 0.0;
  }

  double _calculateKendraBala(int house) {
    if (_kendraHouses.contains(house)) return 60.0;
    if ([2, 5, 8, 11].contains(house)) return 30.0;
    return 15.0;
  }

  double _calculateDigBala(Planet planet, VedicPlanetInfo planetInfo) {
    final house = planetInfo.house;
    final optimalHouse = switch (planet) {
      Planet.sun || Planet.mars => 10,
      Planet.saturn => 7,
      Planet.moon || Planet.venus => 4,
      Planet.mercury || Planet.jupiter => 1,
      _ => 1,
    };

    var distance = (house - optimalHouse).abs();
    if (distance > 6) distance = 12 - distance;
    final strength = 60.0 * (1.0 - (distance / 6.0));
    return strength.clamp(0.0, 60.0);
  }

  double _calculateKalaBala(
      Planet planet, VedicPlanetInfo planetInfo, VedicChart chart) {
    var strength = 0.0;
    strength += _calculateNatonnataBala(planet, chart);
    strength += _calculatePakshaBala(planet, planetInfo, chart);
    strength += _calculateTribhagaBala(planet, chart);
    strength += _calculateVMDHBala(planet, chart);
    strength += _calculateAyanaBala(planet, planetInfo.position.longitude);
    return strength;
  }

  double _calculateNatonnataBala(Planet planet, VedicChart chart) {
    final sunHouse = chart.getPlanet(Planet.sun)?.house ?? 1;
    final isDay = sunHouse > 6;
    final isDayPowerful =
        [Planet.sun, Planet.jupiter, Planet.saturn].contains(planet);
    final isNightPowerful =
        [Planet.moon, Planet.mars, Planet.venus].contains(planet);

    if (planet == Planet.mercury) return 60.0;
    if (isDay) {
      return isDayPowerful ? 60.0 : 0.0;
    } else {
      return isNightPowerful ? 60.0 : 0.0;
    }
  }

  double _calculatePakshaBala(
      Planet planet, VedicPlanetInfo planetInfo, VedicChart chart) {
    final sunInfo = chart.getPlanet(Planet.sun);
    final moonInfo = chart.getPlanet(Planet.moon);
    if (sunInfo == null || moonInfo == null) return 0.0;

    var elongation = (moonInfo.longitude - sunInfo.longitude + 360) % 360;

    if (planet == Planet.moon) {
      var pakshaStrength = elongation > 180 ? (360 - elongation) : elongation;
      return (pakshaStrength / 180.0) * 60.0;
    }

    final isBenefic = [Planet.jupiter, Planet.venus].contains(planet);
    final isMalefic = [Planet.sun, Planet.mars, Planet.saturn].contains(planet);

    if (isBenefic) {
      return (elongation / 360.0) * 60.0;
    } else if (isMalefic) {
      return ((360 - elongation) / 360.0) * 60.0;
    }

    return 30.0;
  }

  double _calculateTribhagaBala(Planet planet, VedicChart chart) {
    return 0.0; // Placeholder
  }

  double _calculateAyanaBala(Planet planet, double longitude) {
    final value = (longitude - 270).abs();
    return (value / 360.0) * 60.0;
  }

  double _calculateVMDHBala(Planet planet, VedicChart chart) {
    return 0.0; // Placeholder
  }

  double _calculateChestaBala(Planet planet, VedicPlanetInfo planetInfo) {
    if (planet == Planet.sun || planet == Planet.moon) return 0.0;
    final speed = planetInfo.position.longitudeSpeed;
    if (speed < 0) return 60.0;
    final avgSpeed = _averageSpeeds[planet] ?? 1.0;
    var ratio = (speed / avgSpeed).clamp(0.0, 1.0);
    return ratio * 60.0;
  }

  double _calculateNaisargikaBala(Planet planet) {
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

  double _calculateDrikBala(
      Planet planet, VedicPlanetInfo planetInfo, VedicChart chart) {
    var netDrishti = 0.0;
    for (final otherPlanet in Planet.traditionalPlanets) {
      if (otherPlanet == planet) continue;
      final otherInfo = chart.getPlanet(otherPlanet);
      if (otherInfo == null) continue;

      final drishtiValue = _getDrishtiValue(
          otherPlanet, otherInfo.longitude, planetInfo.longitude);
      final isBenefic = [Planet.jupiter, Planet.venus].contains(otherPlanet);
      final isMalefic =
          [Planet.sun, Planet.mars, Planet.saturn].contains(otherPlanet);

      if (isBenefic || otherPlanet == Planet.mercury) {
        netDrishti += drishtiValue / 4.0;
      } else if (isMalefic) {
        netDrishti -= drishtiValue / 4.0;
      }
    }
    return netDrishti;
  }

  double _getDrishtiValue(Planet aspecting, double long1, double long2) {
    var diff = (long2 - long1 + 360) % 360;
    final houseDiff = (diff / 30).floor() + 1;
    if (aspecting == Planet.mars && (houseDiff == 4 || houseDiff == 8))
      return 60.0;
    if (aspecting == Planet.jupiter && (houseDiff == 5 || houseDiff == 9))
      return 60.0;
    if (aspecting == Planet.saturn && (houseDiff == 3 || houseDiff == 10))
      return 60.0;
    if (houseDiff == 7) return 60.0;
    if ([4, 8].contains(houseDiff)) return 45.0;
    if ([5, 9].contains(houseDiff)) return 30.0;
    if ([3, 10].contains(houseDiff)) return 15.0;
    return 0.0;
  }

  ShadbalaStrength _getStrengthCategory(double totalBala) {
    if (totalBala >= 380) return ShadbalaStrength.veryStrong;
    if (totalBala >= 330) return ShadbalaStrength.strong;
    if (totalBala >= 280) return ShadbalaStrength.moderate;
    if (totalBala >= 230) return ShadbalaStrength.weak;
    return ShadbalaStrength.veryWeak;
  }

  static const _averageSpeeds = {
    Planet.mars: 0.524,
    Planet.mercury: 1.383,
    Planet.jupiter: 0.083,
    Planet.venus: 1.2,
    Planet.saturn: 0.033,
  };

  static const _kendraHouses = [1, 4, 7, 10];

  static const _deepExaltationPoints = {
    Planet.sun: 10.0,
    Planet.moon: 33.0,
    Planet.mars: 298.0,
    Planet.mercury: 165.0,
    Planet.jupiter: 95.0,
    Planet.venus: 357.0,
    Planet.saturn: 200.0,
  };
}

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

  bool get isStrong => totalBala >= 330;
  bool get isWeak => totalBala < 280;
  double get rupas => totalBala / 60.0;

  @override
  String toString() {
    return '${planet.displayName}: ${totalBala.toStringAsFixed(1)} (${strengthCategory.name})';
  }
}

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
