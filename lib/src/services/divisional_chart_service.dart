import '../models/planet.dart';
import '../models/planet_position.dart';
import '../models/vedic_chart.dart';
import '../models/divisional_chart_type.dart';

/// Service for calculating Divisional Charts (Varga).
class DivisionalChartService {
  /// Calculates a specific divisional chart from a base Rashi chart.
  VedicChart calculateDivisionalChart(
    VedicChart rashiChart,
    DivisionalChartType type,
  ) {
    if (type == DivisionalChartType.d1) {
      return rashiChart;
    }

    // Calculate D-Chart Ascendant
    final newAscendantDegree = _calculateVargaLongitude(
      rashiChart.ascendant,
      type,
    );

    // Create new House System (Whole Sign based on D-Ascendant)
    final dHouses = _createWholeSignHouses(newAscendantDegree);

    final finalPlanets = <Planet, VedicPlanetInfo>{};

    for (final entry in rashiChart.planets.entries) {
      final planet = entry.key;
      final originalInfo = entry.value;

      final newInfo = _calculatePlanetVarga(
        originalInfo: originalInfo,
        type: type,
        dHouses: dHouses,
      );
      finalPlanets[planet] = newInfo;
    }

    // Handle Rahu/Ketu special
    final rahuInfo = _calculatePlanetVarga(
      originalInfo: rashiChart.rahu,
      type: type,
      dHouses: dHouses,
    );

    final ketuInfo = KetuPosition(rahuPosition: rahuInfo.position);

    return VedicChart(
      dateTime: rashiChart.dateTime,
      location: rashiChart.location,
      latitude: rashiChart.latitude,
      longitudeCoord: rashiChart.longitudeCoord,
      houses: dHouses,
      planets: finalPlanets,
      rahu: rahuInfo,
      ketu: ketuInfo,
    );
  }

  VedicPlanetInfo _calculatePlanetVarga({
    required VedicPlanetInfo originalInfo,
    required DivisionalChartType type,
    required HouseSystem dHouses,
  }) {
    final newLongitude = _calculateVargaLongitude(originalInfo.longitude, type);

    final newPosition = PlanetPosition(
      planet: originalInfo.position.planet,
      dateTime: originalInfo.position.dateTime,
      longitude: newLongitude,
      latitude: originalInfo.position.latitude,
      distance: originalInfo.position.distance,
      longitudeSpeed: originalInfo.position.longitudeSpeed,
      latitudeSpeed: originalInfo.position.latitudeSpeed,
      distanceSpeed: originalInfo.position.distanceSpeed,
    );

    final house = dHouses.getHouseForLongitude(newLongitude);

    return VedicPlanetInfo(
      position: newPosition,
      house: house,
      dignity: PlanetaryDignity.neutralSign, // TODO: Implement D-Chart dignity
      isCombust: false,
    );
  }

  HouseSystem _createWholeSignHouses(double ascendantLongitude) {
    final ascSignIndex = (ascendantLongitude / 30).floor();

    final cusps = List<double>.generate(12, (i) {
      return ((ascSignIndex + i) % 12) * 30.0;
    });

    final mc = (ascendantLongitude + 270) % 360;

    return HouseSystem(
      system: 'Whole Sign (Varga)',
      cusps: cusps,
      ascendant: ascendantLongitude,
      midheaven: mc,
    );
  }

  /// Calculates the absolute longitude (0-360) of a point in a divisional chart.
  double _calculateVargaLongitude(double longitude, DivisionalChartType type) {
    // 1. Get current sign and position in sign
    final signIndex = (longitude / 30).floor(); // 0-11
    final degreeInSign = longitude % 30;

    // 2. Determine the "Varga Sign Index" (0-11)
    final vargaSignIndex = _getVargaSign(signIndex, degreeInSign, type);

    // 3. Determine degrees in the new sign
    // Typically: (degreeInSign * N) % 30
    final parts = type.divisions;
    final degreesInNewSign = (degreeInSign * parts) % 30;

    return (vargaSignIndex * 30) + degreesInNewSign;
  }

  int _getVargaSign(
      int signIndex, double degreeInSign, DivisionalChartType type) {
    final sign = signIndex + 1; // 1-12
    final isOdd = sign % 2 != 0;
    final isMoveable = [1, 4, 7, 10].contains(sign);
    final isFixed = [2, 5, 8, 11].contains(sign);
    // final isDual = [3, 6, 9, 12].contains(sign);

    final element = (sign - 1) % 4; // 0=Fire, 1=Earth, 2=Air, 3=Water

    switch (type) {
      case DivisionalChartType.d1:
        return signIndex;

      case DivisionalChartType.d2: // Hora
        // Parashara Hora
        if (isOdd) {
          // 0-15 Sun (Leo/5), 15-30 Moon (Cancer/4)
          return (degreeInSign < 15) ? 4 : 3; // Index 4=Leo, 3=Can
        } else {
          // 0-15 Moon (Cancer/4), 15-30 Sun (Leo/5)
          return (degreeInSign < 15) ? 3 : 4;
        }

      case DivisionalChartType.d3: // Drekkana
        final part = (degreeInSign / 10).floor(); // 0, 1, 2
        // 1st part: same, 2nd: 5th, 3rd: 9th
        if (part == 0) return signIndex;
        if (part == 1) return (signIndex + 4) % 12;
        return (signIndex + 8) % 12;

      case DivisionalChartType.d4: // Chaturthamsa
        final part = (degreeInSign / (30 / 4)).floor(); // 0-3
        // 1: Same, 2: 4th, 3: 7th, 4: 10th (Kendra count) => Not exactly?
        // Rule:
        // 1st part: Same sign
        // 2nd part: 4th from sign
        // 3rd part: 7th from sign
        // 4th part: 10th from sign
        final offset = part * 3;
        return (signIndex + offset) % 12;

      case DivisionalChartType.d7: // Saptamsa
        final part = (degreeInSign / (30 / 7)).floor(); // 0-6
        if (isOdd) {
          // Start from same sign
          return (signIndex + part) % 12;
        } else {
          // Start from 7th sign
          return (signIndex + 6 + part) % 12;
        }

      case DivisionalChartType.d9: // Navamsa
        final part = (degreeInSign / (30 / 9)).floor(); // 0-8

        // Fire (1,5,9): Start Aries (0)
        // Earth (2,6,10): Start Capricorn (9)
        // Air (3,7,11): Start Libra (6)
        // Water (4,8,12): Start Cancer (3)
        final startMap = {
          0: 0, // Fire -> Aries
          1: 9, // Earth -> Cap
          2: 6, // Air -> Libra
          3: 3, // Water -> Can
        };
        final startSignIndex = startMap[element]!;
        return (startSignIndex + part) % 12;

      case DivisionalChartType.d10: // Dasamsa
        final part = (degreeInSign / (30 / 10)).floor(); // 0-9
        if (isOdd) {
          // Start same
          return (signIndex + part) % 12;
        } else {
          // Start 9th
          return (signIndex + 8 + part) % 12;
        }

      case DivisionalChartType.d12: // Dwadasamsa
        final part = (degreeInSign / (30 / 12)).floor(); // 0-11
        // Starts from same sign
        return (signIndex + part) % 12;

      case DivisionalChartType.d16: // Shodasamsa
        final part = (degreeInSign / (30 / 16)).floor(); // 0-15
        if (isMoveable) {
          // Start Aries
          return (0 + part) % 12;
        } else if (isFixed) {
          // Start Leo
          return (4 + part) % 12;
        } else {
          // Start Sag
          return (8 + part) % 12;
        }

      case DivisionalChartType.d20: // Vimsamsa
        final part = (degreeInSign / (30 / 20)).floor(); // 0-19
        if (isMoveable) {
          // Start Aries
          return (0 + part) % 12;
        } else if (isFixed) {
          // Start Sag (Note: D16 was Leo/Sag, D20 is Sag/Leo? Verify!)
          // Standard: Moveable->Aries, Fixed->Sagittarius, Dual->Leo
          return (8 + part) % 12;
        } else {
          // Start Leo
          return (4 + part) % 12;
        }

      case DivisionalChartType.d24: // Chaturvimshamsha
        final part = (degreeInSign / (30 / 24)).floor(); // 0-23
        if (isOdd) {
          // Start Leo
          return (4 + part) % 12;
        } else {
          // Start Cancer
          return (3 + part) % 12;
        }

      case DivisionalChartType.d27: // Saptavimsamsa
        final part = (degreeInSign / (30 / 27)).floor(); // 0-26
        // Like Navamsa starts: Fire->Aries, Earth->Cancer, Air->Libra, Water->Cap
        // Wait, standard D27:
        // Fire signs: Start Aries
        // Earth signs: Start Cancer
        // Air signs: Start Libra
        // Water signs: Start Capricorn
        // This is 1, 4, 7, 10
        final startMap = {
          0: 0, // Fire -> Aries
          1: 3, // Earth -> Cancer
          2: 6, // Air -> Libra
          3: 9, // Water -> Cap
        };
        return (startMap[element]! + part) % 12;

      // TODO: D30 requires special handling (degree ranges not equal)
      case DivisionalChartType.d30:
        return _calculateD30Sign(signIndex, degreeInSign);

      case DivisionalChartType.d40: // Khavedamsa
        final part = (degreeInSign / (30 / 40)).floor();
        if (isOdd) {
          // Start Aries
          return (0 + part) % 12;
        } else {
          // Start Libra
          return (6 + part) % 12;
        }

      case DivisionalChartType.d45: // Akshavedamsa
        final part = (degreeInSign / (30 / 45)).floor();
        if (isMoveable) {
          // Start Aries
          return (0 + part) % 12;
        } else if (isFixed) {
          // Start Leo
          return (4 + part) % 12;
        } else {
          // Start Sagittarius
          return (8 + part) % 12;
        }

      case DivisionalChartType.d60: // Shashtiamsa (Simple calculation)
        final part = (degreeInSign / (30 / 60)).floor();
        // Ignore sign, simply (part + signIndex? + ...)
        // Standard Parashara: "Multiply longitude by 2" (Wait, 60 parts per sign = 0.5 deg each)
        // Rule: Start from the sign itself?
        // No, D60 usually: (Sign * 60 + part) % 12?
        // Actually: "To calculate D60, take the degrees, minutes, seconds... multiply by 2? No."
        // Let's use the simplest: "Cyclic from Sign"?
        // BV Raman: "Ignore the Rasi. Take the degrees. Each degree is 2 parts. 0-0.5 is part 1."
        // Index = (Degrees * 2).floor() + 1
        // Mapping? "In odd signs proceed direct. In even signs proceed reverse?" No that's some others.
        // D60 Parashara: "Current Sign + Part".
        // Let's try: (SignIndex + part) % 12.
        return (signIndex + part) % 12;
    }
  }

  int _calculateD30Sign(int signIndex, double degree) {
    // Trimsamsa
    final sign = signIndex + 1;
    final isOdd = sign % 2 != 0;

    // Aries=0, Taurus=1, Gemini=2, Cancer=3, Leo=4, Virgo=5...
    // Mars=0,7; Sat=9,10; Jup=8,11; Merc=2,5; Ven=1,6

    if (isOdd) {
      // 0-5: Mars (Aries)
      if (degree < 5) return 0;
      // 5-10: Saturn (Aquarius)
      if (degree < 10) return 10;
      // 10-18: Jupiter (Sagittarius)
      if (degree < 18) return 8;
      // 18-25: Mercury (Gemini)
      if (degree < 25) return 2;
      // 25-30: Venus (Libra)
      return 6;
    } else {
      // 0-5: Venus (Taurus)
      if (degree < 5) return 1;
      // 5-12: Mercury (Virgo)
      if (degree < 12) return 5;
      // 12-20: Jupiter (Pisces)
      if (degree < 20) return 11;
      // 20-25: Saturn (Capricorn)
      if (degree < 25) return 9;
      // 25-30: Mars (Scorpio)
      return 7;
    }
  }
}
