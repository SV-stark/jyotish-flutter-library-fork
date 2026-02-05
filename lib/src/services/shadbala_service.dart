import '../models/divisional_chart_type.dart';
import '../models/planet.dart';
import '../models/vedic_chart.dart';
import '../models/geographic_location.dart';
import 'divisional_chart_service.dart';
import 'ephemeris_service.dart';

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
  ShadbalaService(this._ephemerisService);
  final EphemerisService _ephemerisService;
  final DivisionalChartService _divisionalChartService =
      DivisionalChartService();

  /// Calculates complete Shadbala for all planets in a chart.
  Future<Map<Planet, ShadbalaResult>> calculateShadbala(
      VedicChart chart) async {
    final results = <Planet, ShadbalaResult>{};

    for (final entry in chart.planets.entries) {
      final planet = entry.key;
      final planetInfo = entry.value;

      results[planet] = await _calculatePlanetShadbala(
        planet: planet,
        planetInfo: planetInfo,
        chart: chart,
      );
    }

    return results;
  }

  /// Calculates Shadbala for a single planet.
  Future<ShadbalaResult> _calculatePlanetShadbala({
    required Planet planet,
    required VedicPlanetInfo planetInfo,
    required VedicChart chart,
  }) async {
    // 1. Sthana Bala (Positional Strength)
    final sthanaBala = _calculateSthanaBala(planet, planetInfo, chart);

    // 2. Dig Bala (Directional Strength)
    final digBala = _calculateDigBala(planet, planetInfo);

    // 3. Kala Bala (Temporal Strength)
    final kalaBala = await _calculateKalaBala(planet, planetInfo, chart);

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

  Future<double> _calculateKalaBala(
      Planet planet, VedicPlanetInfo planetInfo, VedicChart chart) async {
    var strength = 0.0;
    strength += _calculateNatonnataBala(planet, chart);
    strength += _calculatePakshaBala(planet, planetInfo, chart);
    strength += await _calculateTribhagaBala(planet, chart);
    strength += await _calculateVMDHBala(planet, chart);
    strength += _calculateAyanaBala(
        planet, planetInfo.position.longitude, planetInfo.position.declination);
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

  Future<double> _calculateTribhagaBala(Planet planet, VedicChart chart) async {
    // Mercury always gets 60 points
    if (planet == Planet.mercury) return 60.0;

    // Assignment:
    // Day (Sunrise-Sunset): 1st 1/3 Jupiter, 2nd 1/3 Sun, 3rd 1/3 Saturn
    // Night (Sunset-Sunrise): 1st 1/3 Moon, 2nd 1/3 Venus, 3rd 1/3 Mars

    final date = chart.dateTime;
    final location = GeographicLocation(
      latitude: chart.latitude,
      longitude: chart.longitudeCoord,
      altitude: 0,
    );

    final sunriseSunset = await _ephemerisService.getSunriseSunset(
        date: date, location: location);
    final sunrise = sunriseSunset.$1;
    final sunset = sunriseSunset.$2;

    if (sunrise == null || sunset == null) return 0.0;

    final birthTime = chart.dateTime.toUtc();
    final isDay = birthTime.isAfter(sunrise) && birthTime.isBefore(sunset);

    if (isDay) {
      final dayDuration = sunset.difference(sunrise).inSeconds;
      final partDuration = dayDuration / 3;
      final secondsSinceSunrise = birthTime.difference(sunrise).inSeconds;
      final partIndex =
          (secondsSinceSunrise / partDuration).floor().clamp(0, 2);

      final lords = [Planet.jupiter, Planet.sun, Planet.saturn];
      return planet == lords[partIndex] ? 60.0 : 0.0;
    } else {
      // Find previous sunset and next sunrise for accurate night division
      final prevDate = date.subtract(const Duration(days: 1));
      final prevSunriseSunset = await _ephemerisService.getSunriseSunset(
          date: prevDate, location: location);
      final prevSunset = prevSunriseSunset.$2;

      final nextDate = date.add(const Duration(days: 1));
      final nextSunriseSunset = await _ephemerisService.getSunriseSunset(
          date: nextDate, location: location);
      final nextSunrise = nextSunriseSunset.$1;

      // Determine which night segment we are in
      DateTime nightStart;
      DateTime nightEnd;

      if (birthTime.isAfter(sunset)) {
        nightStart = sunset;
        nightEnd = nextSunrise ?? sunset.add(const Duration(hours: 12));
      } else {
        nightStart = prevSunset ?? sunrise.subtract(const Duration(hours: 12));
        nightEnd = sunrise;
      }

      final nightDuration = nightEnd.difference(nightStart).inSeconds;
      final partDuration = nightDuration / 3;
      final secondsSinceNightStart = birthTime.difference(nightStart).inSeconds;
      final partIndex =
          (secondsSinceNightStart / partDuration).floor().clamp(0, 2);

      final lords = [Planet.moon, Planet.venus, Planet.mars];
      return planet == lords[partIndex] ? 60.0 : 0.0;
    }
  }

  double _calculateAyanaBala(Planet planet, double longitude, double decl) {
    // Ayana Bala = 60 * (24 +/- Declination) / 48
    // For Sun, Mars, Jupiter, Venus: + for North (positive), - for South (negative)
    // For Moon, Saturn: - for North, + for South
    // For Mercury: Always plus (absolute)

    final absDecl = decl.abs();

    if ([Planet.sun, Planet.mars, Planet.jupiter, Planet.venus]
        .contains(planet)) {
      return (24 + decl) / 48 * 60;
    } else if ([Planet.moon, Planet.saturn].contains(planet)) {
      return (24 - decl) / 48 * 60;
    } else {
      // Mercury
      return (24 + absDecl) / 48 * 60;
    }
  }

  /// Calculates VMDH Bala (Vara-Maasa-Varsha-Hora Bala).
  /// 
  /// Total: 150 virupas (60 Rupas)
  /// - Vara Bala: 45 virupas (Weekday lord)
  /// - Maasa Bala: 30 virupas (Month lord)
  /// - Varsha Bala: 15 virupas (Year lord)
  /// - Hora Bala: 60 virupas (Planetary hour lord)
  Future<double> _calculateVMDHBala(Planet planet, VedicChart chart) async {
    var totalStrength = 0.0;
    
    // 1. Vara Bala (45 virupas) - Weekday lord
    totalStrength += _calculateVaraBala(planet, chart.dateTime);
    
    // 2. Maasa Bala (30 virupas) - Month lord
    totalStrength += _calculateMaasaBala(planet, chart.dateTime);
    
    // 3. Varsha Bala (15 virupas) - Year lord
    totalStrength += _calculateVarshaBala(planet, chart.dateTime);
    
    // 4. Hora Bala (60 virupas) - Planetary hour lord
    totalStrength += await _calculateHoraBala(planet, chart);
    
    return totalStrength;
  }

  /// Vara Bala: 45 virupas for the weekday lord.
  /// Weekday: Sun (1), Mon (2), Tue (3), Wed (4), Thu (5), Fri (6), Sat (7)
  double _calculateVaraBala(Planet planet, DateTime dateTime) {
    final weekday = dateTime.weekday; // 1 (Mon) - 7 (Sun)
    final varaLord = switch (weekday) {
      7 => Planet.sun,    // Sunday
      1 => Planet.moon,   // Monday
      2 => Planet.mars,   // Tuesday
      3 => Planet.mercury, // Wednesday
      4 => Planet.jupiter, // Thursday
      5 => Planet.venus,  // Friday
      6 => Planet.saturn, // Saturday
      _ => Planet.sun,
    };

    return planet == varaLord ? 45.0 : 0.0;
  }

  /// Maasa Bala: 30 virupas for the month lord.
  /// Based on the Hindu lunar month (Maasa).
  /// In absence of full lunar calendar calculation, we use an approximation
  /// based on the approximate solar month position.
  double _calculateMaasaBala(Planet planet, DateTime dateTime) {
    // Solar month lords (approximation for sidereal calculations)
    // This follows the traditional assignment where months are ruled by planets
    // based on the Sun's position in the zodiac
    final monthLord = _getMonthLord(dateTime);
    return planet == monthLord ? 30.0 : 0.0;
  }

  /// Gets the lord of the current month based on traditional Vedic calendar.
  /// The month is determined by which nakshatra the Moon is in at sunrise
  /// on the full moon day, but for practical calculations we use an approximation.
  Planet _getMonthLord(DateTime dateTime) {
    // Approximate month lord based on solar month
    // Traditional: Chaitra (Jupiter), Vaishakha (Venus), Jyeshtha (Mercury),
    // Ashadha (Saturn), Shravana (Saturn), Bhadrapada (Jupiter),
    // Ashwin (Mars), Kartik (Moon), Agrahayana (Venus),
    // Pausha (Mercury), Magha (Jupiter), Phalguna (Sun)
    
    // Simplified: Use solar longitude approximation
    // Sun's position roughly determines the month
    final month = dateTime.month;
    
    // Traditional month lords (approximate mapping)
    return switch (month) {
      1 => Planet.jupiter,  // January (approx Chaitra) - Jupiter
      2 => Planet.venus,    // February (approx Vaishakha) - Venus
      3 => Planet.mercury,  // March (approx Jyeshtha) - Mercury
      4 => Planet.saturn,   // April (approx Ashadha) - Saturn
      5 => Planet.saturn,   // May (approx Shravana) - Saturn
      6 => Planet.jupiter,  // June (approx Bhadrapada) - Jupiter
      7 => Planet.mars,     // July (approx Ashwin) - Mars
      8 => Planet.moon,     // August (approx Kartik) - Moon
      9 => Planet.venus,    // September (approx Agrahayana) - Venus
      10 => Planet.mercury, // October (approx Pausha) - Mercury
      11 => Planet.jupiter, // November (approx Magha) - Jupiter
      12 => Planet.sun,     // December (approx Phalguna) - Sun
      _ => Planet.sun,
    };
  }

  /// Varsha Bala: 15 virupas for the year lord.
  /// Based on the 60-year Jovian cycle (Samvatsara).
  /// Each year in the 60-year cycle has a specific lord.
  double _calculateVarshaBala(Planet planet, DateTime dateTime) {
    final yearLord = _getYearLord(dateTime.year);
    return planet == yearLord ? 15.0 : 0.0;
  }

  /// Gets the lord of the year based on the 60-year Jovian cycle.
  /// The cycle repeats every 60 years, with each year ruled by a planet.
  Planet _getYearLord(int year) {
    // The 60-year cycle starts from year 1 (Prabhava) in the Julian calendar
    // We use a simplified calculation based on the year number
    // The 60-year cycle assigns lords in a specific sequence
    
    // Reference year: 1987 was Prabhava (Jupiter)
    final cyclePosition = (year - 1987) % 60;
    
    // The 60-year cycle lords (simplified - in reality more complex)
    // Following the Samvatsara system, years are ruled by planets in sequence
    // This is an approximation for Shadbala calculation
    final yearLords = [
      Planet.jupiter, Planet.jupiter, Planet.mars, Planet.mars, Planet.sun,
      Planet.sun, Planet.mercury, Planet.mercury, Planet.saturn, Planet.saturn,
      Planet.jupiter, Planet.jupiter, Planet.mars, Planet.mars, Planet.sun,
      Planet.sun, Planet.mercury, Planet.mercury, Planet.saturn, Planet.saturn,
      Planet.jupiter, Planet.jupiter, Planet.mars, Planet.mars, Planet.sun,
      Planet.sun, Planet.mercury, Planet.mercury, Planet.saturn, Planet.saturn,
      Planet.jupiter, Planet.jupiter, Planet.mars, Planet.mars, Planet.sun,
      Planet.sun, Planet.mercury, Planet.mercury, Planet.saturn, Planet.saturn,
      Planet.jupiter, Planet.jupiter, Planet.mars, Planet.mars, Planet.sun,
      Planet.sun, Planet.mercury, Planet.mercury, Planet.saturn, Planet.saturn,
      Planet.jupiter, Planet.jupiter, Planet.mars, Planet.mars, Planet.sun,
      Planet.sun, Planet.mercury, Planet.mercury, Planet.saturn, Planet.saturn,
    ];
    
    return yearLords[cyclePosition.abs() % 60];
  }

  /// Hora Bala: 60 virupas for the current Hora (planetary hour) lord.
  /// Each day is divided into 24 Horas (12 daytime + 12 nighttime).
  Future<double> _calculateHoraBala(Planet planet, VedicChart chart) async {
    final location = GeographicLocation(
      latitude: chart.latitude,
      longitude: chart.longitudeCoord,
      altitude: 0,
    );

    // Get sunrise and sunset for accurate Hora calculation
    final sunriseSunset = await _ephemerisService.getSunriseSunset(
        date: chart.dateTime, location: location);
    
    if (sunriseSunset.$1 == null || sunriseSunset.$2 == null) {
      // If sunrise/sunset unavailable, return 0
      return 0.0;
    }

    final horaLord = _getHoraLord(
      chart.dateTime,
      sunriseSunset.$1!,
      sunriseSunset.$2!,
    );

    return planet == horaLord ? 60.0 : 0.0;
  }

  /// Calculates the Hora (planetary hour) lord for a given time.
  /// 
  /// Each day has 24 Horas:
  /// - 12 daytime Horas (from sunrise to sunset)
  /// - 12 nighttime Horas (from sunset to next sunrise)
  /// 
  /// The sequence of lords follows the Chaldean order:
  /// Sun -> Venus -> Mercury -> Moon -> Saturn -> Jupiter -> Mars -> Sun...
  Planet _getHoraLord(DateTime dateTime, DateTime sunrise, DateTime sunset) {
    // Determine if it's day or night
    final birthTime = dateTime.toUtc();
    final isDay = birthTime.isAfter(sunrise) && birthTime.isBefore(sunset);

    // Get weekday (0 = Sunday, 1 = Monday, etc.)
    final weekday = dateTime.weekday % 7;

    // Hora lords sequence: Sun, Venus, Mercury, Moon, Saturn, Jupiter, Mars
    const horaSequence = [
      Planet.sun,
      Planet.venus,
      Planet.mercury,
      Planet.moon,
      Planet.saturn,
      Planet.jupiter,
      Planet.mars,
    ];

    // First Hora of each day is ruled by the day lord
    final dayStartLords = [
      Planet.sun,    // Sunday
      Planet.moon,   // Monday
      Planet.mars,   // Tuesday
      Planet.mercury, // Wednesday
      Planet.jupiter, // Thursday
      Planet.venus,  // Friday
      Planet.saturn, // Saturday
    ];

    final dayStartLord = dayStartLords[weekday];
    var startIndex = horaSequence.indexOf(dayStartLord);

    if (isDay) {
      // Daytime: Calculate which Hora we're in
      final dayDuration = sunset.difference(sunrise);
      final horaDuration = dayDuration.inSeconds / 12;
      final secondsSinceSunrise = birthTime.difference(sunrise).inSeconds;
      final horaIndex = (secondsSinceSunrise / horaDuration).floor();

      return horaSequence[(startIndex + horaIndex) % 7];
    } else {
      // Nighttime: Night starts with 5th lord from day start
      startIndex = (startIndex + 4) % 7;

      // Calculate night duration and Hora
      final nextSunrise = sunrise.add(const Duration(days: 1));
      DateTime nightStart;
      DateTime nightEnd;

      if (birthTime.isAfter(sunset)) {
        nightStart = sunset;
        nightEnd = nextSunrise;
      } else {
        // Before sunrise - use previous sunset
        nightStart = sunrise.subtract(const Duration(hours: 12));
        nightEnd = sunrise;
      }

      final nightDuration = nightEnd.difference(nightStart);
      final horaDuration = nightDuration.inSeconds / 12;
      final secondsSinceNightStart = birthTime.difference(nightStart).inSeconds;
      final horaIndex = (secondsSinceNightStart / horaDuration).floor();

      return horaSequence[(startIndex + horaIndex) % 7];
    }
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

  /// Calculates Drik Bala (Aspectual Strength) using professional 60-virupa system.
  ///
  /// Drik Bala measures the aspectual influence on a planet.
  /// Benefic aspects add strength, malefic aspects subtract strength.
  /// Total virupas range from -60 to +60.
  double _calculateDrikBala(
      Planet planet, VedicPlanetInfo planetInfo, VedicChart chart) {
    var netVirupas = 0.0;

    for (final otherPlanet in Planet.traditionalPlanets) {
      if (otherPlanet == planet) continue;
      final otherInfo = chart.getPlanet(otherPlanet);
      if (otherInfo == null) continue;

      // Calculate full professional aspect strength (0-60 virupas)
      final aspectStrength = _calculateProfessionalAspectStrength(
        aspecting: otherPlanet,
        aspectingLong: otherInfo.longitude,
        aspectedLong: planetInfo.longitude,
      );

      // Apply aspect based on benefic/malefic nature
      final aspectValue = _applyAspectNature(otherPlanet, aspectStrength);
      netVirupas += aspectValue;
    }

    // Clamp to valid range (-60 to +60 virupas)
    return netVirupas.clamp(-60.0, 60.0);
  }

  /// Applies aspect nature (benefic adds, malefic subtracts).
  /// 
  /// Benefic planets: Jupiter, Venus, Mercury, Moon
  /// Malefic planets: Sun, Mars, Saturn
  /// Aspect strength is divided by 4 as per Parashara
  double _applyAspectNature(Planet aspectingPlanet, double aspectStrength) {
    // Determine planet nature
    final isBenefic = [
      Planet.jupiter,
      Planet.venus,
      Planet.mercury,
      Planet.moon,
    ].contains(aspectingPlanet);

    final isMalefic = [
      Planet.sun,
      Planet.mars,
      Planet.saturn,
    ].contains(aspectingPlanet);

    // Apply Parashara's rule: divide by 4
    final virupas = aspectStrength / 4.0;

    if (isBenefic) {
      return virupas; // Benefic aspects add strength
    } else if (isMalefic) {
      return -virupas; // Malefic aspects subtract strength
    }

    return 0.0;
  }

  /// Calculates professional aspect strength using 60-virupa mathematical system.
  ///
  /// Uses precise interpolation based on Parasharic rules:
  /// - Full aspects: 60 virupas
  /// - 3/4 aspects: 45 virupas
  /// - 1/2 aspects: 30 virupas
  /// - 1/4 aspects: 15 virupas
  /// - No aspect: 0 virupas
  /// 
  /// All planets have full 7th aspect (180°).
  /// Mars has special aspects on 4th (90°) and 8th (210°).
  /// Jupiter has special aspects on 5th (120°) and 9th (240°).
  /// Saturn has special aspects on 3rd (60°) and 10th (270°).
  double _calculateProfessionalAspectStrength({
    required Planet aspecting,
    required double aspectingLong,
    required double aspectedLong,
  }) {
    final diff = (aspectedLong - aspectingLong + 360) % 360;
    var maxStrength = 0.0;

    // Check all applicable aspects for this planet
    final aspects = _getPlanetAspects(aspecting);

    for (final aspectAngle in aspects) {
      final aspectDiff = (diff - aspectAngle + 360) % 360;
      final orb = aspectDiff > 180 ? 360 - aspectDiff : aspectDiff;

      // Calculate virupa strength based on orb
      final strength = _calculateVirupaFromOrb(orb, aspecting, aspectAngle);

      if (strength > maxStrength) {
        maxStrength = strength;
      }
    }

    return maxStrength;
  }

  /// Gets all aspect angles for a planet.
  List<double> _getPlanetAspects(Planet planet) {
    // All planets have 7th aspect (180°)
    final aspects = <double>[180.0];

    // Special aspects
    switch (planet) {
      case Planet.mars:
        aspects.addAll([90.0, 210.0]); // 4th and 8th
      case Planet.jupiter:
        aspects.addAll([120.0, 240.0]); // 5th and 9th
      case Planet.saturn:
        aspects.addAll([60.0, 270.0]); // 3rd and 10th
      default:
        break;
    }

    return aspects;
  }

  /// Calculates virupa strength (0-60) from aspect orb using professional interpolation.
  ///
  /// Traditional 60-virupa system:
  /// - 0° orb: 60 virupas (full strength)
  /// - 30° orb: 45 virupas (3/4 strength)
  /// - 60° orb: 30 virupas (1/2 strength)
  /// - 90° orb: 15 virupas (1/4 strength)
  /// - 120° orb: 0 virupas (no strength)
  ///
  /// Uses mathematical interpolation for precise calculation.
  double _calculateVirupaFromOrb(double orb, Planet planet, double aspectAngle) {
    // Normalize orb to 0-180 range
    final normalizedOrb = orb.abs();

    // Maximum orb allowance varies by aspect type
    final maxOrb = _getMaxOrbForAspect(planet, aspectAngle);

    if (normalizedOrb >= maxOrb) {
      return 0.0; // Outside orb limit
    }

    // Professional 60-virupa interpolation formula
    // Based on Parashara's principles: strength decreases quadratically with orb
    final orbRatio = normalizedOrb / maxOrb;
    
    // Use cosine interpolation for smooth strength curve
    // At orb=0: strength=60, at orb=max: strength=0
    final strength = 60.0 * ((1 + cos(orbRatio * pi)) / 2);

    return strength;
  }

  /// Gets maximum orb allowance for different aspect types.
  double _getMaxOrbForAspect(Planet planet, double aspectAngle) {
    // Full aspects (7th house) get 30° orb for all planets
    if (aspectAngle == 180.0) {
      return 30.0;
    }

    // Special aspects get 15° orb
    if ([90.0, 210.0, 120.0, 240.0, 60.0, 270.0].contains(aspectAngle)) {
      return 15.0;
    }

    return 30.0;
  }

  // Cosine function for interpolation
  double cos(double radians) {
    return cosInternal(radians);
  }

  double cosInternal(double x) {
    // Taylor series approximation for cosine
    x = x % (2 * 3.14159265358979323846);
    double result = 1.0;
    double term = 1.0;
    double x2 = x * x;
    
    for (int i = 1; i <= 10; i++) {
      term *= -x2 / ((2 * i - 1) * (2 * i));
      result += term;
    }
    
    return result;
  }

  /// Pi constant
  static const double pi = 3.14159265358979323846;

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
