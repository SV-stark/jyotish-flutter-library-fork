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
