import '../models/calculation_flags.dart';
import '../models/geographic_location.dart';
import '../models/panchanga.dart';
import '../models/planet.dart';
import '../models/planet_position.dart';
import 'ephemeris_service.dart';

/// Service for calculating Panchanga (five limbs) elements.
///
/// The Panchanga consists of:
/// - Tithi: Lunar phase (30 divisions based on Sun-Moon distance)
/// - Yoga: 27 combinations of Sun and Moon longitudes
/// - Karana: Half-tithi (60 divisions)
/// - Vara: Weekday with planetary day lord
class PanchangaService {

  PanchangaService(this._ephemerisService);
  final EphemerisService _ephemerisService;

  /// Calculates complete Panchanga for a given date and location.
  ///
  /// [dateTime] - The date and time for calculation
  /// [location] - The geographic location
  ///
  /// Returns a [Panchanga] with all five elements calculated.
  Future<Panchanga> calculatePanchanga({
    required DateTime dateTime,
    required GeographicLocation location,
  }) async {
    final flags = CalculationFlags.defaultFlags();

    // Calculate Sun and Moon positions
    final sunPos = await _ephemerisService.calculatePlanetPosition(
      planet: Planet.sun,
      dateTime: dateTime,
      location: location,
      flags: flags,
    );

    final moonPos = await _ephemerisService.calculatePlanetPosition(
      planet: Planet.moon,
      dateTime: dateTime,
      location: location,
      flags: flags,
    );

    // Calculate Tithi
    final tithi = _calculateTithi(sunPos, moonPos);

    // Calculate Yoga
    final yoga = _calculateYoga(sunPos, moonPos);

    // Calculate Karana
    final karana = _calculateKarana(sunPos, moonPos);

    // Calculate Vara
    final vara = _calculateVara(dateTime);

    // Calculate sunrise and sunset (approximate for now)
    final (sunrise, sunset) = await _calculateSunriseSunset(
      dateTime: dateTime,
      location: location,
    );

    return Panchanga(
      dateTime: dateTime,
      location: '${location.latitude}, ${location.longitude}',
      tithi: tithi,
      yoga: yoga,
      karana: karana,
      vara: vara,
      sunrise: sunrise,
      sunset: sunset,
    );
  }

  /// Calculates the Tithi (lunar phase).
  ///
  /// Tithi is determined by the angular distance between Sun and Moon,
  /// divided into 30 equal parts of 12° each.
  TithiInfo _calculateTithi(PlanetPosition sunPos, PlanetPosition moonPos) {
    // Calculate lunar elongation (Moon - Sun)
    var elongation = moonPos.longitude - sunPos.longitude;
    if (elongation < 0) elongation += 360;

    // Each tithi is 12 degrees
    const tithiDegrees = 12.0;

    // Calculate tithi number (1-30)
    final tithiNumber = (elongation / tithiDegrees).floor() + 1;
    final elapsed = (elongation % tithiDegrees) / tithiDegrees;

    // Determine paksha
    final paksha = Paksha.fromTithiNumber(tithiNumber);

    // Get tithi name
    final nameIndex = (tithiNumber - 1) % 15;
    final name = TithiInfo.tithiNames[nameIndex];

    return TithiInfo(
      number: tithiNumber,
      name: name,
      paksha: paksha,
      elapsed: elapsed,
    );
  }

  /// Calculates the Yoga.
  ///
  /// Yoga is determined by the sum of Sun and Moon longitudes,
  /// divided into 27 equal parts.
  YogaInfo _calculateYoga(PlanetPosition sunPos, PlanetPosition moonPos) {
    // Calculate sum of longitudes
    var sum = sunPos.longitude + moonPos.longitude;
    sum = sum % 360;

    // Each yoga is 13°20' (360/27)
    const yogaDegrees = 360.0 / 27;

    // Calculate yoga number (1-27)
    final yogaNumber = (sum / yogaDegrees).floor() + 1;
    final elapsed = (sum % yogaDegrees) / yogaDegrees;

    // Get yoga name
    final nameIndex = yogaNumber - 1;
    final name = YogaInfo.yogaNames[nameIndex];

    return YogaInfo(
      number: yogaNumber,
      name: name,
      elapsed: elapsed,
    );
  }

  /// Calculates the Karana.
  ///
  /// Karana is half of a tithi. There are 60 karanas total,
  /// with 7 fixed karanas repeating and 4 variable karanas.
  KaranaInfo _calculateKarana(PlanetPosition sunPos, PlanetPosition moonPos) {
    // Calculate lunar elongation (Moon - Sun)
    var elongation = moonPos.longitude - sunPos.longitude;
    if (elongation < 0) elongation += 360;

    // Each karana is 6 degrees (half tithi)
    const karanaDegrees = 6.0;

    // Calculate karana number (1-60)
    final karanaNumber = (elongation / karanaDegrees).floor() + 1;
    final elapsed = (elongation % karanaDegrees) / karanaDegrees;

    // Determine karana name
    String name;
    bool isFixed;

    // First tithi (0-12°) has fixed karanas at beginning
    if (karanaNumber <= 7) {
      // First 7 karanas: Bava, Balava, Kaulava, Taitila, Garaja, Vanija, Vishti
      name = KaranaInfo.fixedKaranaNames[karanaNumber - 1];
      isFixed = true;
    } else if (karanaNumber == 57) {
      name = KaranaInfo.variableKaranaNames[0]; // Shakuni
      isFixed = false;
    } else if (karanaNumber == 58) {
      name = KaranaInfo.variableKaranaNames[1]; // Chatushpada
      isFixed = false;
    } else if (karanaNumber == 59) {
      name = KaranaInfo.variableKaranaNames[2]; // Naga
      isFixed = false;
    } else if (karanaNumber == 60) {
      name = KaranaInfo.variableKaranaNames[3]; // Kimstughna
      isFixed = false;
    } else {
      // Repeating fixed karanas
      final fixedIndex = (karanaNumber - 8) % 7;
      name = KaranaInfo.fixedKaranaNames[fixedIndex];
      isFixed = true;
    }

    return KaranaInfo(
      number: karanaNumber,
      name: name,
      isFixed: isFixed,
      elapsed: elapsed,
    );
  }

  /// Calculates the Vara (weekday with planetary lord).
  VaraInfo _calculateVara(DateTime dateTime) {
    // Get weekday (0 = Sunday, 6 = Saturday)
    final weekday = dateTime.weekday % 7;

    return VaraInfo(
      weekday: weekday,
      name: VaraInfo.weekdayNames[weekday],
      rulingPlanet: VaraInfo.getRulingPlanet(weekday),
    );
  }

  /// Calculates high-precision sunrise and sunset times using Swiss Ephemeris.
  ///
  /// Uses swe_rise_trans function for professional-grade accuracy, which accounts for:
  /// - Geographic latitude and longitude
  /// - Atmospheric refraction
  /// - Altitude of the location
  /// - Sun's disc size
  ///
  /// Returns (sunrise, sunset) times in local timezone.
  Future<(DateTime, DateTime)> _calculateSunriseSunset({
    required DateTime dateTime,
    required GeographicLocation location,
  }) async {
    try {
      // Use high-precision calculation from Swiss Ephemeris
      final (sunrise, sunset) = await _ephemerisService.getSunriseSunset(
        date: dateTime,
        location: location,
      );

      // Fallback to approximation if precise calculation fails
      // (e.g., in polar regions where sun may not rise/set)
      if (sunrise == null || sunset == null) {
        return _calculateApproximateSunriseSunset(
          dateTime: dateTime,
          location: location,
        );
      }

      // Convert UTC results to local timezone
      final localSunrise = sunrise.toLocal();
      final localSunset = sunset.toLocal();

      return (localSunrise, localSunset);
    } catch (e) {
      // If high-precision calculation fails, fall back to approximation
      return _calculateApproximateSunriseSunset(
        dateTime: dateTime,
        location: location,
      );
    }
  }

  /// Fallback approximate sunrise/sunset calculation.
  ///
  /// Used when Swiss Ephemeris calculation fails (e.g., polar regions).
  Future<(DateTime, DateTime)> _calculateApproximateSunriseSunset({
    required DateTime dateTime,
    required GeographicLocation location,
  }) async {
    final baseDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    // Approximate sunrise/sunset based on latitude
    final latitudeAbs = location.latitude.abs();

    // Base sunrise/sunset times (approximate for equator)
    var sunriseHour = 6.0;
    var sunsetHour = 18.0;

    // Adjust for latitude (rough approximation)
    if (latitudeAbs > 23.5) {
      final season = _getSeason(dateTime, location.latitude);
      if (season > 0) {
        // Summer
        sunriseHour -= 1.0;
        sunsetHour += 1.0;
      } else {
        // Winter
        sunriseHour += 1.0;
        sunsetHour -= 1.0;
      }
    }

    // Adjust for longitude (timezone offset approximation)
    final timezoneOffset = dateTime.timeZoneOffset.inHours;
    final longitudeOffset = location.longitude / 15.0;
    final localTimeCorrection = longitudeOffset - timezoneOffset;

    sunriseHour += localTimeCorrection;
    sunsetHour += localTimeCorrection;

    final sunrise = baseDate.add(Duration(
      hours: sunriseHour.floor(),
      minutes: ((sunriseHour % 1) * 60).round(),
    ));

    final sunset = baseDate.add(Duration(
      hours: sunsetHour.floor(),
      minutes: ((sunsetHour % 1) * 60).round(),
    ));

    return (sunrise, sunset);
  }

  /// Determines season (-1 = winter, 0 = spring/fall, 1 = summer)
  int _getSeason(DateTime date, double latitude) {
    final month = date.month;
    final isNorthernHemisphere = latitude >= 0;

    if (month >= 3 && month <= 5) {
      return isNorthernHemisphere ? 0 : 0; // Spring
    } else if (month >= 6 && month <= 8) {
      return isNorthernHemisphere ? 1 : -1; // Summer
    } else if (month >= 9 && month <= 11) {
      return isNorthernHemisphere ? 0 : 0; // Fall
    } else {
      return isNorthernHemisphere ? -1 : 1; // Winter
    }
  }

  /// Gets the Tithi for a specific date.
  Future<TithiInfo> getTithi({
    required DateTime dateTime,
    required GeographicLocation location,
  }) async {
    final flags = CalculationFlags.defaultFlags();

    final sunPos = await _ephemerisService.calculatePlanetPosition(
      planet: Planet.sun,
      dateTime: dateTime,
      location: location,
      flags: flags,
    );

    final moonPos = await _ephemerisService.calculatePlanetPosition(
      planet: Planet.moon,
      dateTime: dateTime,
      location: location,
      flags: flags,
    );

    return _calculateTithi(sunPos, moonPos);
  }

  /// Gets the Yoga for a specific date.
  Future<YogaInfo> getYoga({
    required DateTime dateTime,
    required GeographicLocation location,
  }) async {
    final flags = CalculationFlags.defaultFlags();

    final sunPos = await _ephemerisService.calculatePlanetPosition(
      planet: Planet.sun,
      dateTime: dateTime,
      location: location,
      flags: flags,
    );

    final moonPos = await _ephemerisService.calculatePlanetPosition(
      planet: Planet.moon,
      dateTime: dateTime,
      location: location,
      flags: flags,
    );

    return _calculateYoga(sunPos, moonPos);
  }

  /// Gets the Karana for a specific date.
  Future<KaranaInfo> getKarana({
    required DateTime dateTime,
    required GeographicLocation location,
  }) async {
    final flags = CalculationFlags.defaultFlags();

    final sunPos = await _ephemerisService.calculatePlanetPosition(
      planet: Planet.sun,
      dateTime: dateTime,
      location: location,
      flags: flags,
    );

    final moonPos = await _ephemerisService.calculatePlanetPosition(
      planet: Planet.moon,
      dateTime: dateTime,
      location: location,
      flags: flags,
    );

    return _calculateKarana(sunPos, moonPos);
  }

  /// Gets the Vara (weekday lord) for a specific date.
  VaraInfo getVara(DateTime dateTime) {
    return _calculateVara(dateTime);
  }
}
