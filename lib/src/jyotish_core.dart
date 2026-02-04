import 'models/geographic_location.dart';
import 'models/planet.dart';
import 'models/planet_position.dart';
import 'models/calculation_flags.dart';
import 'models/vedic_chart.dart';
import 'models/aspect.dart';
import 'models/transit.dart';
import 'models/dasha.dart';
import 'services/ephemeris_service.dart';
import 'services/vedic_chart_service.dart';
import 'services/aspect_service.dart';
import 'services/transit_service.dart';
import 'services/dasha_service.dart';
import 'services/divisional_chart_service.dart';
import 'models/divisional_chart_type.dart';
import 'exceptions/jyotish_exception.dart';

/// The main entry point for the Jyotish library.
///
/// This class provides a high-level API for calculating planetary positions,
/// aspects, transits, and dashas using Swiss Ephemeris.
///
/// Example:
/// ```dart
/// final jyotish = Jyotish();
/// await jyotish.initialize();
///
/// final position = await jyotish.getPlanetPosition(
///   planet: Planet.sun,
///   dateTime: DateTime.now(),
///   location: GeographicLocation(
///     latitude: 27.7172,
///     longitude: 85.3240,
///   ),
/// );
///
/// print('Sun longitude: ${position.longitude}');
/// ```
class Jyotish {
  static Jyotish? _instance;
  EphemerisService? _ephemerisService;
  VedicChartService? _vedicChartService;
  AspectService? _aspectService;
  TransitService? _transitService;
  DashaService? _dashaService;
  DivisionalChartService? _divisionalChartService;
  bool _isInitialized = false;

  /// Creates a new instance of Jyotish.
  ///
  /// Use [initialize] to set up the Swiss Ephemeris data path before
  /// performing calculations.
  Jyotish._();

  /// Gets the singleton instance of Jyotish.
  factory Jyotish() {
    _instance ??= Jyotish._();
    return _instance!;
  }

  /// Initializes the Swiss Ephemeris library.
  ///
  /// [ephemerisPath] - Optional custom path to Swiss Ephemeris data files.
  /// If not provided, the library will look for data in the default locations.
  ///
  /// This method must be called before performing any calculations.
  ///
  /// Throws [JyotishException] if initialization fails.
  Future<void> initialize({String? ephemerisPath}) async {
    if (_isInitialized) {
      return;
    }

    try {
      _ephemerisService = EphemerisService();
      await _ephemerisService!.initialize(ephemerisPath: ephemerisPath);
      _vedicChartService = VedicChartService(_ephemerisService!);
      _aspectService = AspectService();
      _transitService = TransitService(_ephemerisService!);
      _dashaService = DashaService();
      _isInitialized = true;
    } catch (e) {
      throw JyotishException(
        'Failed to initialize Jyotish: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Calculates the position of a planet at a given date, time, and location.
  ///
  /// [planet] - The planet to calculate the position for.
  /// [dateTime] - The date and time for the calculation.
  /// [location] - The geographic location for the calculation.
  /// [flags] - Optional calculation flags for customizing the calculation.
  ///
  /// Returns a [PlanetPosition] containing the calculated position data.
  ///
  /// Throws [JyotishException] if the library is not initialized or
  /// if the calculation fails.
  Future<PlanetPosition> getPlanetPosition({
    required Planet planet,
    required DateTime dateTime,
    required GeographicLocation location,
    CalculationFlags? flags,
  }) async {
    _ensureInitialized();

    try {
      return await _ephemerisService!.calculatePlanetPosition(
        planet: planet,
        dateTime: dateTime,
        location: location,
        flags: flags ?? CalculationFlags.defaultFlags(),
      );
    } catch (e) {
      throw JyotishException(
        'Failed to calculate planet position: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Calculates positions for multiple planets at once.
  ///
  /// This is more efficient than calling [getPlanetPosition] multiple times.
  ///
  /// [planets] - List of planets to calculate positions for.
  /// [dateTime] - The date and time for the calculation.
  /// [location] - The geographic location for the calculation.
  /// [flags] - Optional calculation flags for customizing the calculation.
  ///
  /// Returns a Map of [Planet] to [PlanetPosition].
  ///
  /// Throws [JyotishException] if the library is not initialized or
  /// if any calculation fails.
  Future<Map<Planet, PlanetPosition>> getMultiplePlanetPositions({
    required List<Planet> planets,
    required DateTime dateTime,
    required GeographicLocation location,
    CalculationFlags? flags,
  }) async {
    _ensureInitialized();

    final Map<Planet, PlanetPosition> positions = {};

    for (final planet in planets) {
      positions[planet] = await getPlanetPosition(
        planet: planet,
        dateTime: dateTime,
        location: location,
        flags: flags,
      );
    }

    return positions;
  }

  /// Calculates positions for all major planets.
  ///
  /// This is a convenience method that calculates positions for:
  /// Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Uranus, Neptune, Pluto.
  ///
  /// [dateTime] - The date and time for the calculation.
  /// [location] - The geographic location for the calculation.
  /// [flags] - Optional calculation flags for customizing the calculation.
  ///
  /// Returns a Map of [Planet] to [PlanetPosition].
  Future<Map<Planet, PlanetPosition>> getAllPlanetPositions({
    required DateTime dateTime,
    required GeographicLocation location,
    CalculationFlags? flags,
  }) async {
    return getMultiplePlanetPositions(
      planets: Planet.majorPlanets,
      dateTime: dateTime,
      location: location,
      flags: flags,
    );
  }

  /// Calculates a complete Vedic astrology chart.
  ///
  /// This method provides comprehensive Vedic astrology data including:
  /// - All planetary positions in sidereal zodiac (Lahiri ayanamsa)
  /// - Rahu (North Node) and Ketu (South Node) positions
  /// - House placements for all planets
  /// - Planetary dignities (exaltation, debilitation, own sign, etc.)
  /// - Combustion status
  /// - Nakshatra and pada for all planets
  /// - Ascendant (Lagna) and house cusps
  ///
  /// [dateTime] - The date and time for the chart (usually birth time)
  /// [location] - The geographic location for the chart (usually birth place)
  /// [houseSystem] - House system to use (default: 'W' for Whole Sign)
  /// [includeOuterPlanets] - Include Uranus, Neptune, Pluto (default: false, not used in traditional Vedic astrology)
  ///
  /// Returns a [VedicChart] with complete chart information.
  ///
  /// Throws [JyotishException] if the library is not initialized or
  /// if the calculation fails.
  ///
  /// Example:
  /// ```dart
  /// final chart = await jyotish.calculateVedicChart(
  ///   dateTime: DateTime(1990, 5, 15, 14, 30),
  ///   location: GeographicLocation(latitude: 28.6139, longitude: 77.2090),
  /// );
  ///
  /// print('Ascendant: ${chart.ascendantSign}');
  /// print('Sun in house: ${chart.getPlanet(Planet.sun)?.house}');
  /// ```
  Future<VedicChart> calculateVedicChart({
    required DateTime dateTime,
    required GeographicLocation location,
    String houseSystem = 'W',
    bool includeOuterPlanets = false,
  }) async {
    _ensureInitialized();

    try {
      return await _vedicChartService!.calculateChart(
        dateTime: dateTime,
        location: location,
        houseSystem: houseSystem,
        includeOuterPlanets: includeOuterPlanets,
      );
    } catch (e) {
      throw JyotishException(
        'Failed to calculate Vedic chart: ${e.toString()}',
        originalError: e,
      );
    }
  }

  // ============================================================
  // DIVISIONAL CHART CALCULATIONS
  // ============================================================

  /// Calculates a specific Divisional Chart (Varga) from a Rashi chart.
  ///
  /// [rashiChart] - The base Rashi chart (D1) calculated using [calculateVedicChart]
  /// [type] - The type of divisional chart to calculate (e.g. [DivisionalChartType.d9])
  ///
  /// Returns a new [VedicChart] representing the divisional chart.
  /// NOTE: The 'longitude' values in the returned chart are the PROJECTED longitudes
  /// into the 0-360 zodiac. For example, if a planet is in the middle of Aries in D9,
  /// its longitude will be around 15°.
  /// The [HouseSystem] in the returned chart is typically a Whole Sign system
  /// based on the D-Chart Ascendant.
  VedicChart getDivisionalChart({
    required VedicChart rashiChart,
    required DivisionalChartType type,
  }) {
    // _ensureInitialized(); // Not needed for pure math
    if (_divisionalChartService == null) {
      _divisionalChartService = DivisionalChartService();
    }
    return _divisionalChartService!.calculateDivisionalChart(rashiChart, type);
  }

  // ============================================================
  // ASPECT CALCULATIONS
  // ============================================================

  /// Calculates all Vedic aspects between planets at a given time.
  ///
  /// Vedic aspects (Graha Drishti) include:
  /// - All planets aspect the 7th house (opposition)
  /// - Mars has special aspects on 4th and 8th houses
  /// - Jupiter has special aspects on 5th and 9th houses
  /// - Saturn has special aspects on 3rd and 10th houses
  ///
  /// [dateTime] - Date and time for the calculation
  /// [location] - Geographic location
  /// [config] - Optional aspect calculation configuration
  ///
  /// Returns a list of all aspects found.
  ///
  /// Example:
  /// ```dart
  /// final aspects = await jyotish.getAspects(
  ///   dateTime: DateTime.now(),
  ///   location: location,
  /// );
  /// for (final aspect in aspects) {
  ///   print(aspect.description);
  /// }
  /// ```
  Future<List<AspectInfo>> getAspects({
    required DateTime dateTime,
    required GeographicLocation location,
    AspectConfig config = AspectConfig.vedic,
  }) async {
    _ensureInitialized();

    try {
      final positions = await getMultiplePlanetPositions(
        planets: [...Planet.traditionalPlanets, Planet.meanNode],
        dateTime: dateTime,
        location: location,
      );

      return _aspectService!.calculateAspects(positions, config: config);
    } catch (e) {
      throw JyotishException(
        'Failed to calculate aspects: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Gets all aspects involving a specific planet.
  ///
  /// [planet] - The planet to get aspects for
  /// [dateTime] - Date and time for the calculation
  /// [location] - Geographic location
  ///
  /// Returns aspects where the planet is either aspecting or being aspected.
  Future<List<AspectInfo>> getAspectsForPlanet({
    required Planet planet,
    required DateTime dateTime,
    required GeographicLocation location,
  }) async {
    _ensureInitialized();

    try {
      final positions = await getMultiplePlanetPositions(
        planets: [...Planet.traditionalPlanets, Planet.meanNode],
        dateTime: dateTime,
        location: location,
      );

      return _aspectService!.getAspectsForPlanet(planet, positions);
    } catch (e) {
      throw JyotishException(
        'Failed to calculate aspects for planet: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Calculates aspects within a Vedic chart.
  ///
  /// [chart] - A previously calculated Vedic chart
  /// [config] - Optional aspect configuration
  ///
  /// Returns list of all aspects in the chart.
  List<AspectInfo> getChartAspects(
    VedicChart chart, {
    AspectConfig config = AspectConfig.vedic,
  }) {
    _ensureInitialized();

    final positions = <Planet, PlanetPosition>{};
    for (final entry in chart.planets.entries) {
      positions[entry.key] = entry.value.position;
    }

    return _aspectService!.calculateAspects(positions, config: config);
  }

  // ============================================================
  // TRANSIT CALCULATIONS
  // ============================================================

  /// Calculates transit positions relative to a natal chart.
  ///
  /// [natalChart] - The birth chart to compare transits against
  /// [transitDateTime] - Date/time for transit positions (default: now)
  /// [location] - Geographic location for calculations
  ///
  /// Returns a map of planets to their transit information including
  /// which natal house they're transiting and aspects to natal planets.
  ///
  /// Example:
  /// ```dart
  /// final chart = await jyotish.calculateVedicChart(...);
  /// final transits = await jyotish.getTransitPositions(
  ///   natalChart: chart,
  ///   location: location,
  /// );
  /// print('Saturn transiting house ${transits[Planet.saturn]?.transitHouse}');
  /// ```
  Future<Map<Planet, TransitInfo>> getTransitPositions({
    required VedicChart natalChart,
    DateTime? transitDateTime,
    required GeographicLocation location,
  }) async {
    _ensureInitialized();

    try {
      return await _transitService!.calculateTransits(
        natalChart: natalChart,
        transitDateTime: transitDateTime ?? DateTime.now(),
        location: location,
      );
    } catch (e) {
      throw JyotishException(
        'Failed to calculate transits: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Finds significant transit events within a date range.
  ///
  /// [natalChart] - The birth chart
  /// [startDate] - Start of the date range
  /// [endDate] - End of the date range
  /// [location] - Geographic location
  /// [planets] - Optional list of planets to track (default: all traditional + Rahu)
  ///
  /// Returns list of transit events sorted by date.
  ///
  /// Example:
  /// ```dart
  /// final events = await jyotish.getTransitEvents(
  ///   natalChart: chart,
  ///   startDate: DateTime.now(),
  ///   endDate: DateTime.now().add(Duration(days: 365)),
  ///   location: location,
  /// );
  /// for (final event in events) {
  ///   print('${event.exactDate}: ${event.description}');
  /// }
  /// ```
  Future<List<TransitEvent>> getTransitEvents({
    required VedicChart natalChart,
    required DateTime startDate,
    required DateTime endDate,
    required GeographicLocation location,
    List<Planet>? planets,
  }) async {
    _ensureInitialized();

    try {
      final config = TransitConfig(
        startDate: startDate,
        endDate: endDate,
        planets: planets,
      );

      return await _transitService!.findTransitEvents(
        natalChart: natalChart,
        config: config,
        location: location,
      );
    } catch (e) {
      throw JyotishException(
        'Failed to find transit events: ${e.toString()}',
        originalError: e,
      );
    }
  }

  // ============================================================
  // DASHA CALCULATIONS
  // ============================================================

  /// Calculates Vimshottari Dasha from a birth chart.
  ///
  /// Vimshottari is the most commonly used dasha system in Vedic astrology,
  /// with a 120-year cycle based on the Moon's nakshatra at birth.
  ///
  /// [natalChart] - The birth chart (Moon's position is used)
  /// [levels] - Number of dasha levels to calculate:
  ///   - 1 = Mahadasha only
  ///   - 2 = Mahadasha + Antardasha
  ///   - 3 = Mahadasha + Antardasha + Pratyantardasha (default)
  /// [birthTimeUncertainty] - Uncertainty in birth time (minutes) for warning
  ///
  /// Returns complete Vimshottari dasha calculation.
  ///
  /// Example:
  /// ```dart
  /// final dasha = await jyotish.getVimshottariDasha(natalChart: chart);
  /// print('Current dasha: ${dasha.getCurrentPeriodString(DateTime.now())}');
  /// print('Birth nakshatra: ${dasha.birthNakshatra}');
  /// ```
  Future<DashaResult> getVimshottariDasha({
    required VedicChart natalChart,
    int levels = 3,
    int? birthTimeUncertainty,
  }) async {
    _ensureInitialized();

    try {
      // Get Moon's position from the chart
      final moonInfo = natalChart.planets[Planet.moon];
      if (moonInfo == null) {
        throw JyotishException('Moon position not found in natal chart');
      }

      return _dashaService!.calculateVimshottariDasha(
        moonLongitude: moonInfo.position.longitude,
        birthDateTime: natalChart.dateTime,
        levels: levels,
        birthTimeUncertainty: birthTimeUncertainty,
      );
    } catch (e) {
      if (e is JyotishException) rethrow;
      throw JyotishException(
        'Failed to calculate Vimshottari dasha: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Calculates Yogini Dasha from a birth chart.
  ///
  /// Yogini is an alternate dasha system with a 36-year cycle,
  /// using 8 yoginis instead of 9 planets.
  ///
  /// [natalChart] - The birth chart (Moon's position is used)
  /// [levels] - Number of dasha levels to calculate (1-3)
  /// [birthTimeUncertainty] - Uncertainty in birth time (minutes) for warning
  ///
  /// Returns complete Yogini dasha calculation.
  Future<DashaResult> getYoginiDasha({
    required VedicChart natalChart,
    int levels = 3,
    int? birthTimeUncertainty,
  }) async {
    _ensureInitialized();

    try {
      final moonInfo = natalChart.planets[Planet.moon];
      if (moonInfo == null) {
        throw JyotishException('Moon position not found in natal chart');
      }

      return _dashaService!.calculateYoginiDasha(
        moonLongitude: moonInfo.position.longitude,
        birthDateTime: natalChart.dateTime,
        levels: levels,
        birthTimeUncertainty: birthTimeUncertainty,
      );
    } catch (e) {
      if (e is JyotishException) rethrow;
      throw JyotishException(
        'Failed to calculate Yogini dasha: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Gets the current dasha period at a specific date.
  ///
  /// [natalChart] - The birth chart
  /// [targetDate] - Date to find the current period for (default: now)
  /// [type] - Dasha system to use (default: Vimshottari)
  ///
  /// Returns list of active periods (mahadasha, antardasha, pratyantardasha).
  ///
  /// Example:
  /// ```dart
  /// final periods = await jyotish.getCurrentDasha(natalChart: chart);
  /// for (final period in periods) {
  ///   print('${period.levelName}: ${period.lord.displayName}');
  /// }
  /// ```
  Future<List<DashaPeriod>> getCurrentDasha({
    required VedicChart natalChart,
    DateTime? targetDate,
    DashaType type = DashaType.vimshottari,
  }) async {
    _ensureInitialized();

    try {
      final DashaResult result;
      if (type == DashaType.vimshottari) {
        result = await getVimshottariDasha(natalChart: natalChart);
      } else {
        result = await getYoginiDasha(natalChart: natalChart);
      }

      return result.getActivePeriodsAt(targetDate ?? DateTime.now());
    } catch (e) {
      if (e is JyotishException) rethrow;
      throw JyotishException(
        'Failed to get current dasha: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Disposes of resources used by the library.
  ///
  /// Call this method when you're done using the library to free up resources.
  void dispose() {
    _ephemerisService?.dispose();
    _isInitialized = false;
  }

  /// Ensures that the library has been initialized.
  void _ensureInitialized() {
    if (!_isInitialized || _ephemerisService == null) {
      throw JyotishException(
        'Jyotish is not initialized. Call initialize() first.',
      );
    }
  }

  /// Gets whether the library has been initialized.
  bool get isInitialized => _isInitialized;
}
