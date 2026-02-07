import '../models/bhava_bala.dart';
import '../models/planet.dart';
import '../models/rashi.dart';
import '../models/vedic_chart.dart';
import 'shadbala_service.dart';

/// Service for calculating Bhava Bala (House Strength).
class BhavaBalaService {
  BhavaBalaService(this._shadbalaService);
  final ShadbalaService _shadbalaService;

  /// Calculates Bhava Bala for all 12 houses.
  Future<Map<int, BhavaBalaResult>> calculateBhavaBala(VedicChart chart) async {
    final results = <int, BhavaBalaResult>{};

    // First, get Shadbala for all planets (needed for Bhava Adhipati Bala)
    final planetShadbala = await _shadbalaService.calculateShadbala(chart);

    for (var h = 1; h <= 12; h++) {
      // 1. Bhava Adhipati Bala (Shadbala of the house lord)
      final lord = _getHouseLord(chart, h);
      final lordBala = planetShadbala[lord]?.totalBala ?? 0.0;

      // 2. Bhava Dig Bala
      final digBala = _calculateBhavaDigBala(h, chart.ascendant);

      // 3. Bhava Drishti Bala (Simplified)
      final drishtiBala = _calculateBhavaDrishtiBala(h, chart);

      final totalBala = lordBala + digBala + drishtiBala;

      results[h] = BhavaBalaResult(
        houseNumber: h,
        strength: totalBala,
        lordStrength: lordBala,
        digBala: digBala,
        aspectStrength: drishtiBala,
        category: _getBhavaStrengthCategory(totalBala),
      );
    }

    return results;
  }

  BhavaStrengthCategory _getBhavaStrengthCategory(double strength) {
    if (strength >= 90) return BhavaStrengthCategory.veryStrong;
    if (strength >= 70) return BhavaStrengthCategory.strong;
    if (strength >= 50) return BhavaStrengthCategory.moderate;
    if (strength >= 30) return BhavaStrengthCategory.weak;
    return BhavaStrengthCategory.veryWeak;
  }

  Planet _getHouseLord(VedicChart chart, int houseNumber) {
    // Determine sign of the house
    final ascLong = chart.ascendant;
    final lagnaSign = Rashi.fromLongitude(ascLong);
    final houseSignIndex = (lagnaSign.index + houseNumber - 1) % 12;
    final rashi = Rashi.values[houseSignIndex];

    switch (rashi) {
      case Rashi.aries:
      case Rashi.scorpio:
        return Planet.mars;
      case Rashi.taurus:
      case Rashi.libra:
        return Planet.venus;
      case Rashi.gemini:
      case Rashi.virgo:
        return Planet.mercury;
      case Rashi.cancer:
        return Planet.moon;
      case Rashi.leo:
        return Planet.sun;
      case Rashi.sagittarius:
      case Rashi.pisces:
        return Planet.jupiter;
      case Rashi.capricorn:
      case Rashi.aquarius:
        return Planet.saturn;
    }
  }

  double _calculateBhavaDigBala(int house, double ascendantDegree) {
    // Standard Dig Bala for houses:
    // 4th house: 60 virupas
    // 10th house: 0 or low? Actually, specific planets get Dig Bala in houses.
    // For BHAVA Dig Bala (Bhava Bala specifically):
    // 1st, 4th, 7th, 10th (Kendras) get strength.
    // However, some systems use:
    // House 4, 5, 6, 7, 8, 9 (South) vs others.
    // Simplified standard for Bhava Bala:
    if ([1, 4, 7, 10].contains(house)) return 60.0;
    if ([2, 5, 8, 11].contains(house)) return 30.0;
    return 15.0;
  }

  double _calculateBhavaDrishtiBala(int house, VedicChart chart) {
    // Simplified: Benefic planets in/aspecting house add strength, malefics subtract.
    // This is often a complex calculation involving Drik Bala.
    // For now, return a placeholder base strength.
    return 30.0;
  }
}
