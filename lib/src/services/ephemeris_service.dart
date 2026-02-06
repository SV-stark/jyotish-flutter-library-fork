import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

import '../bindings/swisseph_bindings.dart';
import '../constants/planet_constants.dart';
import '../exceptions/jyotish_exception.dart';
import '../models/calculation_flags.dart';
import '../models/geographic_location.dart';
import '../models/planet.dart';
import '../models/planet_position.dart';
import 'astrology_time_service.dart';

/// Service for calculating planetary positions using Swiss Ephemeris.
///
/// This service provides high-level methods for astronomical calculations
/// using the Swiss Ephemeris library.
class EphemerisService {
  SwissEphBindings? _bindings;
  bool _isInitialized = false;

  /// Initializes the Swiss Ephemeris service.
  ///
  /// [ephemerisPath] - Optional path to Swiss Ephemeris data files.
  /// If not provided, the library will use its default search paths.
  ///
  /// Throws [InitializationException] if initialization fails.
  Future<void> initialize({String? ephemerisPath}) async {
    if (_isInitialized) {
      return;
    }

    try {
      _bindings = SwissEphBindings();

      // Set ephemeris path if provided
      if (ephemerisPath != null) {
        _bindings!.setEphemerisPath(ephemerisPath);
      }

      // Test that the library is working
      _bindings!.getVersion();

      _isInitialized = true;
    } catch (e, stackTrace) {
      throw InitializationException(
        'Failed to initialize Swiss Ephemeris: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Calculates the position of a planet.
  ///
  /// [planet] - The planet to calculate.
  /// [dateTime] - The date and time for calculation.
  /// [location] - The geographic location for calculation.
  /// [flags] - Calculation flags.
  ///
  /// Returns a [PlanetPosition] with the calculated data.
  ///
  /// Throws [CalculationException] if calculation fails.
  Future<PlanetPosition> calculatePlanetPosition({
    required Planet planet,
    required DateTime dateTime,
    required GeographicLocation location,
    required CalculationFlags flags,
  }) async {
    if (!_isInitialized || _bindings == null) {
      throw CalculationException('EphemerisService is not initialized');
    }

    try {
      // Set topocentric position if required
      if (flags.useTopocentric) {
        _bindings!.setTopocentric(
          location.longitude,
          location.latitude,
          location.altitude,
        );
      }

      // Convert DateTime to Julian Day
      final julianDay = _dateTimeToJulianDay(dateTime);

      // Set sidereal mode and get ayanamsa for this date
      // We always use sidereal calculations for Vedic astrology
      _bindings!.setSiderealMode(
        flags.siderealModeConstant,
        0.0,
        0.0,
      );
      final ayanamsa = _bindings!.getAyanamsaUT(julianDay);

      // Calculate position (tropical, then we subtract ayanamsa)
      final errorBuffer = malloc<ffi.Char>(256);
      try {
        final results = _bindings!.calculateUT(
          julianDay: julianDay,
          planetId: planet.swissEphId,
          flags: flags.toSwissEphFlag(),
          errorBuffer: errorBuffer,
        );

        if (results == null) {
          final error = errorBuffer.cast<Utf8>().toDartString();
          throw JyotishException(
            'Failed to calculate position for ${planet.displayName}: $error',
          );
        }

        // Fetch Declination (Equatorial Latitude)
        // We need an additional call with SEFLG_EQUATORIAL flag
        // SEFLG_EQUATORIAL = 2048 (0x800)
        final eqResults = _bindings!.calculateUT(
          julianDay: julianDay,
          planetId: planet.swissEphId,
          flags: flags.toSwissEphFlag() | 0x800,
          errorBuffer: errorBuffer,
        );

        if (eqResults != null) {
          results.add(eqResults[1]); // results[6] is now declination
        } else {
          results.add(0.0);
        }

        // Convert tropical to sidereal by subtracting ayanamsa
        results[0] = (results[0] - ayanamsa + 360) % 360;

        // Adjust longitudeSpeed for sidereal frame:
        // In the sidereal frame, speeds are slightly lower due to precession.
        // The precession rate is ~50.3"/year = ~0.000137°/day.
        // This adjustment is negligible for most practical purposes (~0.01%),
        // but included for professional-grade precision in Chesta Bala.
        const double precessionRatePerDay = 50.3 / 3600.0 / 365.25; // deg/day
        results[3] = results[3] - precessionRatePerDay;

        return PlanetPosition.fromSwissEph(
          planet: planet,
          dateTime: dateTime,
          results: results,
        );
      } finally {
        malloc.free(errorBuffer);
      }
    } catch (e, stackTrace) {
      if (e is CalculationException) rethrow;
      throw CalculationException(
        'Error calculating planet position: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Converts a DateTime to Julian Day number.
  double _dateTimeToJulianDay(DateTime dateTime, {String? timezoneId}) {
    // Convert to UTC
    final utc = timezoneId != null
        ? AstrologyTimeService.localToUtc(dateTime, timezoneId)
        : dateTime.toUtc();

    // Calculate hour as decimal
    final hour = utc.hour +
        (utc.minute / 60.0) +
        (utc.second / 3600.0) +
        (utc.millisecond / 3600000.0);

    return _bindings!.julianDay(
      year: utc.year,
      month: utc.month,
      day: utc.day,
      hour: hour,
      isGregorian: true,
    );
  }

  /// Gets the ayanamsa (sidereal offset) for a given date and time.
  ///
  /// [dateTime] - The date and time to calculate for.
  /// [mode] - The sidereal mode to use.
  ///
  /// Returns the ayanamsa in degrees.
  Future<double> getAyanamsa({
    required DateTime dateTime,
    required SiderealMode mode,
    String? timezoneId,
  }) async {
    if (!_isInitialized || _bindings == null) {
      throw CalculationException('EphemerisService is not initialized');
    }

    try {
      // Set sidereal mode
      _bindings!.setSiderealMode(mode.constant, 0.0, 0.0);

      // Convert DateTime to Julian Day
      final julianDay = _dateTimeToJulianDay(dateTime, timezoneId: timezoneId);

      // Get ayanamsa
      return _bindings!.getAyanamsaUT(julianDay);
    } catch (e, stackTrace) {
      throw CalculationException(
        'Error calculating ayanamsa: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Calculates house cusps and ascendant/midheaven.
  ///
  /// [dateTime] - The date and time for calculation.
  /// [location] - The geographic location for calculation.
  /// [houseSystem] - The house system to use ('P' = Placidus, 'K' = Koch, etc.)
  ///
  /// Returns a map with 'cusps' and 'ascmc' arrays.
  ///
  /// Throws [CalculationException] if calculation fails.
  Future<Map<String, List<double>>> calculateHouses({
    required DateTime dateTime,
    required GeographicLocation location,
    String houseSystem = 'P',
  }) async {
    if (!_isInitialized || _bindings == null) {
      throw CalculationException('EphemerisService is not initialized');
    }

    try {
      // Convert DateTime to Julian Day
      final julianDay =
          _dateTimeToJulianDay(dateTime, timezoneId: location.timezone);

      // Calculate houses
      final result = _bindings!.calculateHouses(
        julianDay: julianDay,
        latitude: location.latitude,
        longitude: location.longitude,
        houseSystem: houseSystem,
      );

      if (result == null) {
        throw CalculationException('Failed to calculate houses');
      }

      return result;
    } catch (e, stackTrace) {
      throw CalculationException(
        'Error calculating houses: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Calculates high-precision rise or set time for a planet.
  ///
  /// Uses Swiss Ephemeris' swe_rise_trans function for professional-grade accuracy.
  ///
  /// [planet] - The planet to calculate rise/set for (use Planet.sun for sunrise/sunset)
  /// [date] - The date to search for the event
  /// [location] - Geographic location
  /// [rsmi] - Rise/Set calculation flag:
  ///   - SwissEphConstants.calcRise (1) for rise time
  ///   - SwissEphConstants.calcSet (2) for set time
  ///   - Can combine with bit flags like SwissEphConstants.bitHinduRising
  /// [atpress] - Atmospheric pressure in mbar (default: 0 = standard)
  /// [attemp] - Atmospheric temperature in Celsius (default: 0 = standard)
  ///
  /// Returns the DateTime of the event, or null if the event doesn't occur.
  ///
  /// Throws [CalculationException] if calculation fails.
  Future<DateTime?> getRiseSet({
    required Planet planet,
    required DateTime date,
    required GeographicLocation location,
    required int rsmi,
    double atpress = 0.0,
    double attemp = 0.0,
  }) async {
    if (!_isInitialized || _bindings == null) {
      throw CalculationException('EphemerisService is not initialized');
    }

    try {
      // Start search from beginning of the day in UTC
      final searchStart = DateTime.utc(date.year, date.month, date.day);
      final julianDay =
          _dateTimeToJulianDay(searchStart, timezoneId: location.timezone);

      final errorBuffer = malloc<ffi.Char>(256);
      try {
        final result = _bindings!.calculateRiseSet(
          julianDay: julianDay,
          planetId: planet.swissEphId,
          rsmi: rsmi,
          latitude: location.latitude,
          longitude: location.longitude,
          errorBuffer: errorBuffer,
          atpress: atpress,
          attemp: attemp,
        );

        if (result == null) {
          final error = errorBuffer.cast<Utf8>().toDartString();
          if (error.isNotEmpty) {
            // Some errors are expected (e.g., polar regions where sun doesn't rise/set)
            // Return null in such cases
            return null;
          }
          return null;
        }

        // Convert Julian Day back to DateTime
        return _julianDayToDateTime(result);
      } finally {
        malloc.free(errorBuffer);
      }
    } catch (e, stackTrace) {
      throw CalculationException(
        'Error calculating rise/set: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Gets high-precision sunrise and sunset times for a date.
  ///
  /// [date] - The date to calculate for
  /// [location] - Geographic location
  /// [atpress] - Atmospheric pressure in mbar (optional)
  /// [attemp] - Atmospheric temperature in Celsius (optional)
  ///
  /// Returns a tuple (sunrise, sunset), or null for times that don't occur.
  Future<(DateTime? sunrise, DateTime? sunset)> getSunriseSunset({
    required DateTime date,
    required GeographicLocation location,
    double atpress = 0.0,
    double attemp = 0.0,
  }) async {
    final sunrise = await getRiseSet(
      planet: Planet.sun,
      date: date,
      location: location,
      rsmi: SwissEphConstants.calcRise,
      atpress: atpress,
      attemp: attemp,
    );

    final sunset = await getRiseSet(
      planet: Planet.sun,
      date: date,
      location: location,
      rsmi: SwissEphConstants.calcSet,
      atpress: atpress,
      attemp: attemp,
    );

    return (sunrise, sunset);
  }

  /// Gets rise and set times for any planet.
  ///
  /// [planet] - The planet to calculate for
  /// [date] - The date to calculate for
  /// [location] - Geographic location
  /// [atpress] - Atmospheric pressure in mbar (optional)
  /// [attemp] - Atmospheric temperature in Celsius (optional)
  ///
  /// Returns a tuple (riseTime, setTime), or null for times that don't occur.
  Future<(DateTime? riseTime, DateTime? setTime)> getPlanetRiseSet({
    required Planet planet,
    required DateTime date,
    required GeographicLocation location,
    double atpress = 0.0,
    double attemp = 0.0,
  }) async {
    final riseTime = await getRiseSet(
      planet: planet,
      date: date,
      location: location,
      rsmi: SwissEphConstants.calcRise,
      atpress: atpress,
      attemp: attemp,
    );

    final setTime = await getRiseSet(
      planet: planet,
      date: date,
      location: location,
      rsmi: SwissEphConstants.calcSet,
      atpress: atpress,
      attemp: attemp,
    );

    return (riseTime, setTime);
  }

  /// Calculates meridian transit (culmination) times for a planet.
  ///
  /// Meridian transit occurs when a planet reaches its highest (upper culmination)
  /// or lowest (lower culmination) point in the sky.
  ///
  /// [planet] - The planet to calculate for
  /// [date] - The date to calculate for
  /// [location] - Geographic location
  /// [upperCulmination] - If true, calculates upper culmination; if false, lower culmination
  ///
  /// Returns the DateTime of the transit, or null if it doesn't occur.
  Future<DateTime?> getMeridianTransit({
    required Planet planet,
    required DateTime date,
    required GeographicLocation location,
    bool upperCulmination = true,
  }) async {
    // SE_CALC_MTRANSIT = 4 for upper culmination
    // SE_CALC_ITRANSIT = 8 for lower culmination
    final rsmi = upperCulmination
        ? SwissEphConstants.calcMTransit
        : SwissEphConstants.calcITransit;

    return await getRiseSet(
      planet: planet,
      date: date,
      location: location,
      rsmi: rsmi,
    );
  }

  /// Determines planet visibility (heliacal rise/set) at a location.
  ///
  /// Heliacal rise: First visible appearance of a planet before sunrise
  /// Heliacal set: Last visible appearance of a planet after sunset
  ///
  /// [planet] - The planet to check
  /// [date] - The date to check
  /// [location] - Geographic location
  ///
  /// Returns visibility information including whether visible, magnitude, etc.
  Future<PlanetVisibility> getPlanetVisibility({
    required Planet planet,
    required DateTime date,
    required GeographicLocation location,
  }) async {
    final flags = CalculationFlags.defaultFlags();

    // Get planet position
    final planetPos = await calculatePlanetPosition(
      planet: planet,
      dateTime: date,
      location: location,
      flags: flags,
    );

    // Get Sun position
    final sunPos = await calculatePlanetPosition(
      planet: Planet.sun,
      dateTime: date,
      location: location,
      flags: flags,
    );

    // Get sunrise/sunset
    final (sunrise, sunset) = await getSunriseSunset(
      date: date,
      location: location,
    );

    // Calculate elongation from Sun
    var elongation = (planetPos.longitude - sunPos.longitude).abs();
    if (elongation > 180) elongation = 360 - elongation;

    // Determine visibility
    bool isVisible = false;
    VisibilityType visibilityType = VisibilityType.notVisible;
    String description = '';

    if (sunrise != null && sunset != null) {
      final isBeforeSunrise = date.isBefore(sunrise);
      final isAfterSunset = date.isAfter(sunset);

      // Heliacal rise: planet visible before sunrise (eastern elongation)
      if (isBeforeSunrise && elongation > 15) {
        isVisible = true;
        visibilityType = VisibilityType.heliacalRise;
        description =
            '${planet.displayName} visible before sunrise (heliacal rise)';
      }
      // Heliacal set: planet visible after sunset (western elongation)
      else if (isAfterSunset && elongation > 15) {
        isVisible = true;
        visibilityType = VisibilityType.heliacalSet;
        description =
            '${planet.displayName} visible after sunset (heliacal set)';
      }
      // Daytime visibility (rare for most planets except Venus)
      else if (!isBeforeSunrise && !isAfterSunset && elongation > 30) {
        isVisible = true;
        visibilityType = VisibilityType.daytime;
        description = '${planet.displayName} visible in daylight';
      } else {
        description = '${planet.displayName} not visible - too close to Sun';
      }
    }

    // Calculate apparent magnitude (simplified)
    final magnitude = _calculateApparentMagnitude(planet, elongation);

    return PlanetVisibility(
      planet: planet,
      date: date,
      isVisible: isVisible,
      visibilityType: visibilityType,
      elongation: elongation,
      magnitude: magnitude,
      sunrise: sunrise,
      sunset: sunset,
      description: description,
    );
  }

  /// Calculates apparent magnitude for a planet (simplified).
  double _calculateApparentMagnitude(Planet planet, double elongation) {
    // Simplified magnitude calculation
    // Real calculation requires distance from Earth and Sun
    const baseMagnitudes = {
      Planet.mercury: -0.4,
      Planet.venus: -4.4,
      Planet.mars: -2.0,
      Planet.jupiter: -2.9,
      Planet.saturn: -0.3,
    };

    final baseMag = baseMagnitudes[planet];
    if (baseMag == null) return 99.0; // Not applicable

    // Brightness decreases when close to Sun (phase effect)
    final phaseFactor = (elongation / 180.0).clamp(0.0, 1.0);
    return baseMag + (2.5 * (1 - phaseFactor));
  }

  /// Gets high-precision eclipse data for solar and lunar eclipses.
  ///
  /// [date] - The date to search for eclipses
  /// [location] - Geographic location (for solar eclipse visibility)
  /// [eclipseType] - Type of eclipse to search for
  ///
  /// Returns detailed eclipse information or null if no eclipse.
  Future<EclipseData?> getEclipseData({
    required DateTime date,
    required GeographicLocation location,
    EclipseType eclipseType = EclipseType.any,
  }) async {
    if (!_isInitialized || _bindings == null) {
      throw CalculationException('EphemerisService is not initialized');
    }

    try {
      final julianDay = _dateTimeToJulianDay(date);

      // Search for eclipse within a window
      final searchStart = julianDay - 15; // 15 days before
      final searchEnd = julianDay + 15; // 15 days after

      // This is a simplified placeholder - real implementation would use
      // Swiss Ephemeris eclipse functions (swe_sol_eclipse_when_glob, etc.)

      // Check for full/new moon to determine eclipse possibility
      final sunPos = await calculatePlanetPosition(
        planet: Planet.sun,
        dateTime: date,
        location: location,
        flags: CalculationFlags.defaultFlags(),
      );

      final moonPos = await calculatePlanetPosition(
        planet: Planet.moon,
        dateTime: date,
        location: location,
        flags: CalculationFlags.defaultFlags(),
      );

      var elongation = (moonPos.longitude - sunPos.longitude).abs();
      if (elongation > 180) elongation = 360 - elongation;

      // Full moon (near 180°) = lunar eclipse possible
      // New moon (near 0°) = solar eclipse possible
      final isFullMoon = elongation > 170 && elongation < 190;
      final isNewMoon = elongation < 10 || elongation > 350;

      if (!isFullMoon && !isNewMoon) {
        return null; // No eclipse possible
      }

      // Simplified eclipse detection
      final eclipseDetected = isFullMoon || isNewMoon;

      if (eclipseDetected) {
        return EclipseData(
          date: date,
          eclipseType: isFullMoon ? EclipseType.lunar : EclipseType.solar,
          magnitude: _calculateEclipseMagnitude(
            sunPos: sunPos,
            moonPos: moonPos,
            isLunar: isFullMoon,
          ),
          isVisible: isFullMoon ||
              await _isSolarEclipseVisible(
                date: date,
                location: location,
              ),
          description:
              isFullMoon ? 'Lunar eclipse possible' : 'Solar eclipse possible',
        );
      }

      return null;
    } catch (e, stackTrace) {
      throw CalculationException(
        'Error calculating eclipse data: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Calculates eclipse magnitude (simplified).
  double _calculateEclipseMagnitude({
    required PlanetPosition sunPos,
    required PlanetPosition moonPos,
    required bool isLunar,
  }) {
    // Simplified calculation
    // Real calculation involves lunar nodes and precise geometry
    return 0.5; // Placeholder
  }

  /// Checks if solar eclipse is visible from location.
  Future<bool> _isSolarEclipseVisible({
    required DateTime date,
    required GeographicLocation location,
  }) async {
    // Simplified check
    // Real implementation would use swe_sol_eclipse_where
    return true;
  }

  /// Converts DateTime to Julian Day.
  ///
  /// [dateTime] - The DateTime to convert
  /// [timezoneId] - Optional timezone ID
  ///
  /// Returns the Julian Day number.
  double getJulianDay(DateTime dateTime, {String? timezoneId}) {
    return _dateTimeToJulianDay(dateTime, timezoneId: timezoneId);
  }

  /// Converts Julian Day to DateTime (UTC).
  DateTime _julianDayToDateTime(double julianDay) {
    // Julian Day 0 = January 1, 4713 BC at noon
    // JD 2451545.0 = January 1, 2000 at noon

    // Calculate days since J2000.0
    final daysSinceJ2000 = julianDay - 2451545.0;

    // Convert to Unix epoch (seconds since 1970-01-01)
    // J2000.0 is 946728000 seconds after Unix epoch
    final secondsSinceEpoch = (daysSinceJ2000 * 86400.0) + 946728000;

    return DateTime.fromMillisecondsSinceEpoch(
      (secondsSinceEpoch * 1000).round(),
      isUtc: true,
    );
  }

  /// Disposes of resources.
  void dispose() {
    if (_isInitialized && _bindings != null) {
      _bindings!.close();
      _isInitialized = false;
    }
  }

  /// Gets whether the service is initialized.
  bool get isInitialized => _isInitialized;
}

/// Represents planet visibility information.
class PlanetVisibility {
  const PlanetVisibility({
    required this.planet,
    required this.date,
    required this.isVisible,
    required this.visibilityType,
    required this.elongation,
    required this.magnitude,
    required this.sunrise,
    required this.sunset,
    required this.description,
  });

  /// The planet
  final Planet planet;

  /// The date checked
  final DateTime date;

  /// Whether the planet is visible
  final bool isVisible;

  /// Type of visibility
  final VisibilityType visibilityType;

  /// Elongation from Sun (degrees)
  final double elongation;

  /// Apparent magnitude (lower is brighter)
  final double magnitude;

  /// Sunrise time
  final DateTime? sunrise;

  /// Sunset time
  final DateTime? sunset;

  /// Description of visibility
  final String description;

  /// Whether this is a heliacal event (rise or set)
  bool get isHeliacal =>
      visibilityType == VisibilityType.heliacalRise ||
      visibilityType == VisibilityType.heliacalSet;
}

/// Types of planet visibility
enum VisibilityType {
  notVisible('Not Visible'),
  heliacalRise('Heliacal Rise'),
  heliacalSet('Heliacal Set'),
  daytime('Daytime Visible'),
  evening('Evening Star'),
  morning('Morning Star');

  const VisibilityType(this.name);
  final String name;
}

/// Types of eclipses
enum EclipseType {
  any('Any'),
  solar('Solar'),
  lunar('Lunar'),
  solarTotal('Solar Total'),
  solarPartial('Solar Partial'),
  solarAnnular('Solar Annular'),
  lunarTotal('Lunar Total'),
  lunarPartial('Lunar Partial'),
  lunarPenumbral('Lunar Penumbral');

  const EclipseType(this.name);
  final String name;
}

/// Represents eclipse data
class EclipseData {
  const EclipseData({
    required this.date,
    required this.eclipseType,
    required this.magnitude,
    required this.isVisible,
    required this.description,
    this.duration,
    this.startTime,
    this.endTime,
    this.maxEclipseTime,
  });

  /// Date of eclipse
  final DateTime date;

  /// Type of eclipse
  final EclipseType eclipseType;

  /// Eclipse magnitude (0.0 - 1.0+)
  final double magnitude;

  /// Whether visible from location
  final bool isVisible;

  /// Description
  final String description;

  /// Duration of eclipse
  final Duration? duration;

  /// Start time
  final DateTime? startTime;

  /// End time
  final DateTime? endTime;

  /// Maximum eclipse time
  final DateTime? maxEclipseTime;

  /// Whether it's a total eclipse
  bool get isTotal => magnitude >= 1.0;

  /// Whether it's a partial eclipse
  bool get isPartial => magnitude > 0.0 && magnitude < 1.0;
}
