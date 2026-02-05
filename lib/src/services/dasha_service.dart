import '../models/dasha.dart';
import '../models/planet.dart';
import '../models/rashi.dart';
import '../models/vedic_chart.dart';

/// Service for calculating Vedic dasha periods.
///
/// Supports Vimshottari (120-year cycle) and Yogini (36-year cycle) dasha systems.
class DashaService {
  /// Vimshottari dasha sequence: Sun, Moon, Mars, Rahu, Jupiter, Saturn, Mercury, Ketu, Venus
  static const List<Planet> vimshottariSequence = [
    Planet.sun,
    Planet.moon,
    Planet.mars,
    Planet.meanNode, // Rahu
    Planet.jupiter,
    Planet.saturn,
    Planet.mercury,
    Planet.ketu,
    Planet.venus,
  ];

  /// Vimshottari dasha years for each planet
  static const Map<Planet, double> vimshottariYears = {
    Planet.sun: 6.0,
    Planet.moon: 10.0,
    Planet.mars: 7.0,
    Planet.meanNode: 18.0, // Rahu
    Planet.jupiter: 16.0,
    Planet.saturn: 19.0,
    Planet.mercury: 17.0,
    Planet.venus: 20.0,
  };

  /// Extended vimshottari sequence including Ketu separately
  static const List<_VimshottariPlanetInfo> _vimshottariPlanets = [
    _VimshottariPlanetInfo(Planet.sun, 'Sun', 6.0),
    _VimshottariPlanetInfo(Planet.moon, 'Moon', 10.0),
    _VimshottariPlanetInfo(Planet.mars, 'Mars', 7.0),
    _VimshottariPlanetInfo(Planet.meanNode, 'Rahu', 18.0),
    _VimshottariPlanetInfo(Planet.jupiter, 'Jupiter', 16.0),
    _VimshottariPlanetInfo(Planet.saturn, 'Saturn', 19.0),
    _VimshottariPlanetInfo(Planet.mercury, 'Mercury', 17.0),
    _VimshottariPlanetInfo(Planet.ketu, 'Ketu', 7.0),
    _VimshottariPlanetInfo(Planet.venus, 'Venus', 20.0),
  ];

  /// Nakshatra dasha lord indices (which _vimshottariPlanets index each nakshatra starts from)
  static const List<int> _nakshatraDashaLordIndex = [
    7, // Ashwini -> Ketu
    8, // Bharani -> Venus
    0, // Krittika -> Sun
    1, // Rohini -> Moon
    2, // Mrigashira -> Mars
    3, // Ardra -> Rahu
    4, // Punarvasu -> Jupiter
    5, // Pushya -> Saturn
    6, // Ashlesha -> Mercury
    7, // Magha -> Ketu
    8, // Purva Phalguni -> Venus
    0, // Uttara Phalguni -> Sun
    1, // Hasta -> Moon
    2, // Chitra -> Mars
    3, // Swati -> Rahu
    4, // Vishakha -> Jupiter
    5, // Anuradha -> Saturn
    6, // Jyeshtha -> Mercury
    7, // Mula -> Ketu
    8, // Purva Ashadha -> Venus
    0, // Uttara Ashadha -> Sun
    1, // Shravana -> Moon
    2, // Dhanishta -> Mars
    3, // Shatabhisha -> Rahu
    4, // Purva Bhadrapada -> Jupiter
    5, // Uttara Bhadrapada -> Saturn
    6, // Revati -> Mercury
  ];

  static const List<String> _nakshatraNames = [
    'Ashwini',
    'Bharani',
    'Krittika',
    'Rohini',
    'Mrigashira',
    'Ardra',
    'Punarvasu',
    'Pushya',
    'Ashlesha',
    'Magha',
    'Purva Phalguni',
    'Uttara Phalguni',
    'Hasta',
    'Chitra',
    'Swati',
    'Vishakha',
    'Anuradha',
    'Jyeshtha',
    'Mula',
    'Purva Ashadha',
    'Uttara Ashadha',
    'Shravana',
    'Dhanishta',
    'Shatabhisha',
    'Purva Bhadrapada',
    'Uttara Bhadrapada',
    'Revati',
  ];

  /// Calculates Vimshottari Dasha from birth details.
  ///
  /// [moonLongitude] - Moon's sidereal longitude at birth (0-360)
  /// [birthDateTime] - Birth date and time
  /// [levels] - Number of levels to calculate (1-3)
  /// [birthTimeUncertainty] - Uncertainty in birth time (minutes) for warning
  ///
  /// Returns complete Vimshottari dasha calculation.
  DashaResult calculateVimshottariDasha({
    required double moonLongitude,
    required DateTime birthDateTime,
    int levels = 3,
    int? birthTimeUncertainty,
  }) {
    // Calculate nakshatra and pada from Moon longitude
    const nakshatraWidth = 360.0 / 27; // 13.333... degrees
    final nakshatraIndex = (moonLongitude / nakshatraWidth).floor() % 27;
    final positionInNakshatra = moonLongitude % nakshatraWidth;
    final pada = (positionInNakshatra / (nakshatraWidth / 4)).floor() + 1;

    // Get birth nakshatra name
    final birthNakshatra = _nakshatraNames[nakshatraIndex];

    // Get starting dasha lord index
    final startingLordIndex = _nakshatraDashaLordIndex[nakshatraIndex];

    // Calculate balance of first dasha
    // The portion of nakshatra already traversed determines how much of the first dasha has elapsed
    final portionTraversed = positionInNakshatra / nakshatraWidth;
    final portionRemaining = 1.0 - portionTraversed;
    final firstDashaYears = _vimshottariPlanets[startingLordIndex].years;
    final balanceDays = firstDashaYears * 365.25 * portionRemaining;

    // Generate precision warning if applicable
    String? precisionWarning;
    if (birthTimeUncertainty != null && birthTimeUncertainty > 5) {
      precisionWarning =
          'Birth time uncertainty of $birthTimeUncertainty minutes may affect dasha accuracy. '
          'Moon moves approximately 0.5° per hour, which can shift nakshatra boundaries.';
    }

    // Calculate all mahadashas
    final mahadashas = _calculateMahadashas(
      birthDateTime: birthDateTime,
      startingLordIndex: startingLordIndex,
      balanceDays: balanceDays,
      levels: levels,
    );

    return DashaResult(
      type: DashaType.vimshottari,
      birthDateTime: birthDateTime,
      moonLongitude: moonLongitude,
      birthNakshatra: birthNakshatra,
      birthPada: pada,
      balanceOfFirstDasha: balanceDays,
      allMahadashas: mahadashas,
      precisionWarning: precisionWarning,
    );
  }

  /// Internal: Calculate all mahadashas with optional sub-periods.
  List<DashaPeriod> _calculateMahadashas({
    required DateTime birthDateTime,
    required int startingLordIndex,
    required double balanceDays,
    required int levels,
  }) {
    final mahadashas = <DashaPeriod>[];
    var currentDate = birthDateTime;

    // Calculate 2 full cycles (240 years) to cover any lifetime
    for (var cycle = 0; cycle < 2; cycle++) {
      for (var i = 0; i < 9; i++) {
        final lordIndex = (startingLordIndex + i) % 9;
        final planetInfo = _vimshottariPlanets[lordIndex];

        double durationDays;
        if (cycle == 0 && i == 0) {
          // First dasha uses balance
          durationDays = balanceDays;
        } else {
          durationDays = planetInfo.years * 365.25;
        }

        final endDate = currentDate.add(Duration(days: durationDays.round()));

        // Calculate sub-periods if requested
        List<DashaPeriod> subPeriods = [];
        if (levels >= 2) {
          subPeriods = _calculateAntardashas(
            mahadashaLord: planetInfo.planet,
            mahadashaStart: currentDate,
            mahadashaDays: durationDays,
            startingLordIndex: lordIndex,
            levels: levels,
          );
        }

        final mahadasha = DashaPeriod(
          lord: planetInfo.planet,
          lordName:
              planetInfo.name, // Pass custom name to distinguish Rahu/Ketu
          startDate: currentDate,
          endDate: endDate,
          duration: Duration(days: durationDays.round()),
          level: 0,
          subPeriods: subPeriods,
        );

        mahadashas.add(mahadasha);
        currentDate = endDate;
      }
    }

    return mahadashas;
  }

  /// Internal: Calculate antardashas (sub-periods) within a mahadasha.
  List<DashaPeriod> _calculateAntardashas({
    required Planet mahadashaLord,
    required DateTime mahadashaStart,
    required double mahadashaDays,
    required int startingLordIndex,
    required int levels,
  }) {
    final antardashas = <DashaPeriod>[];
    var currentDate = mahadashaStart;
    final totalDays = mahadashaDays;

    // Antardasha starts with the mahadasha lord, then proceeds in sequence
    for (var i = 0; i < 9; i++) {
      final lordIndex = (startingLordIndex + i) % 9;
      final planetInfo = _vimshottariPlanets[lordIndex];

      // Duration proportional to planet's vimshottari years
      final durationDays = totalDays * (planetInfo.years / 120.0);
      final endDate = currentDate.add(Duration(days: durationDays.round()));

      // Calculate pratyantardasha if requested
      List<DashaPeriod> subPeriods = [];
      if (levels >= 3) {
        subPeriods = _calculatePratyantardashas(
          antardashaStart: currentDate,
          antardashaDays: durationDays,
          startingLordIndex: lordIndex,
        );
      }

      final antardasha = DashaPeriod(
        lord: planetInfo.planet,
        lordName: planetInfo.name, // Pass custom name to distinguish Rahu/Ketu
        startDate: currentDate,
        endDate: endDate,
        duration: Duration(days: durationDays.round()),
        level: 1,
        subPeriods: subPeriods,
      );

      antardashas.add(antardasha);
      currentDate = endDate;
    }

    return antardashas;
  }

  /// Internal: Calculate pratyantardashas (sub-sub-periods).
  List<DashaPeriod> _calculatePratyantardashas({
    required DateTime antardashaStart,
    required double antardashaDays,
    required int startingLordIndex,
  }) {
    final pratyantardashas = <DashaPeriod>[];
    var currentDate = antardashaStart;
    final totalDays = antardashaDays;

    for (var i = 0; i < 9; i++) {
      final lordIndex = (startingLordIndex + i) % 9;
      final planetInfo = _vimshottariPlanets[lordIndex];

      final durationDays = totalDays * (planetInfo.years / 120.0);
      final endDate = currentDate.add(Duration(days: durationDays.round()));

      final pratyantardasha = DashaPeriod(
        lord: planetInfo.planet,
        lordName: planetInfo.name, // Pass custom name to distinguish Rahu/Ketu
        startDate: currentDate,
        endDate: endDate,
        duration: Duration(days: durationDays.round()),
        level: 2,
        subPeriods: const [],
      );

      pratyantardashas.add(pratyantardasha);
      currentDate = endDate;
    }

    return pratyantardashas;
  }

  /// Calculates Yogini Dasha from birth details.
  ///
  /// [moonLongitude] - Moon's sidereal longitude at birth (0-360)
  /// [birthDateTime] - Birth date and time
  /// [levels] - Number of levels to calculate (1-3)
  /// [birthTimeUncertainty] - Uncertainty in birth time (minutes) for warning
  ///
  /// Returns complete Yogini dasha calculation.
  DashaResult calculateYoginiDasha({
    required double moonLongitude,
    required DateTime birthDateTime,
    int levels = 3,
    int? birthTimeUncertainty,
  }) {
    // Calculate nakshatra from Moon longitude
    const nakshatraWidth = 360.0 / 27;
    final nakshatraIndex = (moonLongitude / nakshatraWidth).floor() % 27;
    final positionInNakshatra = moonLongitude % nakshatraWidth;
    final pada = (positionInNakshatra / (nakshatraWidth / 4)).floor() + 1;

    final birthNakshatra = _nakshatraNames[nakshatraIndex];

    // Yogini dasha uses (nakshatra + 3) mod 8 to find starting yogini
    final startingYoginiIndex = (nakshatraIndex + 3) % 8;

    // Calculate balance of first dasha
    final portionTraversed = positionInNakshatra / nakshatraWidth;
    final portionRemaining = 1.0 - portionTraversed;
    final firstDashaYears = Yogini.values[startingYoginiIndex].years;
    final balanceDays = firstDashaYears * 365.25 * portionRemaining;

    // Generate precision warning
    String? precisionWarning;
    if (birthTimeUncertainty != null && birthTimeUncertainty > 5) {
      precisionWarning =
          'Birth time uncertainty of $birthTimeUncertainty minutes may affect dasha accuracy.';
    }

    // Calculate all mahadashas
    final mahadashas = _calculateYoginiMahadashas(
      birthDateTime: birthDateTime,
      startingYoginiIndex: startingYoginiIndex,
      balanceDays: balanceDays,
      levels: levels,
    );

    return DashaResult(
      type: DashaType.yogini,
      birthDateTime: birthDateTime,
      moonLongitude: moonLongitude,
      birthNakshatra: birthNakshatra,
      birthPada: pada,
      balanceOfFirstDasha: balanceDays,
      allMahadashas: mahadashas,
      precisionWarning: precisionWarning,
    );
  }

  /// Internal: Calculate Yogini mahadashas.
  List<DashaPeriod> _calculateYoginiMahadashas({
    required DateTime birthDateTime,
    required int startingYoginiIndex,
    required double balanceDays,
    required int levels,
  }) {
    final mahadashas = <DashaPeriod>[];
    var currentDate = birthDateTime;

    // Calculate 4 full cycles (144 years)
    for (var cycle = 0; cycle < 4; cycle++) {
      for (var i = 0; i < 8; i++) {
        final yoginiIndex = (startingYoginiIndex + i) % 8;
        final yogini = Yogini.values[yoginiIndex];

        double durationDays;
        if (cycle == 0 && i == 0) {
          durationDays = balanceDays;
        } else {
          durationDays = yogini.years * 365.25;
        }

        final endDate = currentDate.add(Duration(days: durationDays.round()));

        // Calculate sub-periods if requested
        List<DashaPeriod> subPeriods = [];
        if (levels >= 2) {
          subPeriods = _calculateYoginiAntardashas(
            yogini: yogini,
            mahadashaStart: currentDate,
            mahadashaDays: durationDays,
            startingYoginiIndex: yoginiIndex,
            levels: levels,
          );
        }

        final mahadasha = DashaPeriod(
          lord: yogini.planet,
          startDate: currentDate,
          endDate: endDate,
          duration: Duration(days: durationDays.round()),
          level: 0,
          subPeriods: subPeriods,
        );

        mahadashas.add(mahadasha);
        currentDate = endDate;
      }
    }

    return mahadashas;
  }

  /// Internal: Calculate Yogini antardashas.
  List<DashaPeriod> _calculateYoginiAntardashas({
    required Yogini yogini,
    required DateTime mahadashaStart,
    required double mahadashaDays,
    required int startingYoginiIndex,
    required int levels,
  }) {
    final antardashas = <DashaPeriod>[];
    var currentDate = mahadashaStart;
    final totalDays = mahadashaDays;
    const totalYoginiYears = 36.0; // Total yogini cycle

    for (var i = 0; i < 8; i++) {
      final yoginiIndex = (startingYoginiIndex + i) % 8;
      final subYogini = Yogini.values[yoginiIndex];

      final durationDays = totalDays * (subYogini.years / totalYoginiYears);
      final endDate = currentDate.add(Duration(days: durationDays.round()));

      List<DashaPeriod> subPeriods = [];
      if (levels >= 3) {
        subPeriods = _calculateYoginiPratyantardashas(
          antardashaStart: currentDate,
          antardashaDays: durationDays,
          startingYoginiIndex: yoginiIndex,
        );
      }

      final antardasha = DashaPeriod(
        lord: subYogini.planet,
        startDate: currentDate,
        endDate: endDate,
        duration: Duration(days: durationDays.round()),
        level: 1,
        subPeriods: subPeriods,
      );

      antardashas.add(antardasha);
      currentDate = endDate;
    }

    return antardashas;
  }

  /// Internal: Calculate Yogini pratyantardashas.
  List<DashaPeriod> _calculateYoginiPratyantardashas({
    required DateTime antardashaStart,
    required double antardashaDays,
    required int startingYoginiIndex,
  }) {
    final pratyantardashas = <DashaPeriod>[];
    var currentDate = antardashaStart;
    final totalDays = antardashaDays;
    const totalYoginiYears = 36.0;

    for (var i = 0; i < 8; i++) {
      final yoginiIndex = (startingYoginiIndex + i) % 8;
      final subYogini = Yogini.values[yoginiIndex];

      final durationDays = totalDays * (subYogini.years / totalYoginiYears);
      final endDate = currentDate.add(Duration(days: durationDays.round()));

      final pratyantardasha = DashaPeriod(
        lord: subYogini.planet,
        startDate: currentDate,
        endDate: endDate,
        duration: Duration(days: durationDays.round()),
        level: 2,
        subPeriods: const [],
      );

      pratyantardashas.add(pratyantardasha);
      currentDate = endDate;
    }

    return pratyantardashas;
  }

  /// Calculates Chara Dasha from a Rashi chart.
  ///
  /// Chara Dasha is a sign-based dasha system where the sequence and duration
  /// depend on the Lagna (Ascendant) and the positions of signs and their lords.
  DashaResult calculateCharaDasha(VedicChart rashiChart, {int levels = 1}) {
    final ascendantSign = Rashi.fromLongitude(rashiChart.houses.ascendant);
    final isDirect = ascendantSign.isOdd;

    // Determine the sequence of signs
    final sequence = <Rashi>[];
    for (var i = 0; i < 12; i++) {
      final signIndex = isDirect
          ? (ascendantSign.number + i) % 12
          : (ascendantSign.number - i + 12) % 12;
      sequence.add(Rashi.fromIndex(signIndex));
    }

    final mahadashas = <DashaPeriod>[];
    var currentDate = rashiChart.dateTime;

    for (final sign in sequence) {
      final years = _calculateCharaDashaYears(sign, rashiChart);

      // Approximation: using 365.25 days per year
      final durationDays = years * 365.25;
      final endDate = currentDate.add(Duration(days: durationDays.round()));

      final mahadasha = DashaPeriod(
        rashi: sign,
        startDate: currentDate,
        endDate: endDate,
        duration: Duration(days: durationDays.round()),
        level: 0,
        subPeriods: const [], // Sub-periods for Chara Dasha can be implemented later if needed
      );

      mahadashas.add(mahadasha);
      currentDate = endDate;
    }

    return DashaResult(
      type: DashaType.chara,
      birthDateTime: rashiChart.dateTime,
      moonLongitude: rashiChart.planets[Planet.moon]?.position.longitude ?? 0,
      birthNakshatra: rashiChart.planets[Planet.moon]?.nakshatra ?? 'Unknown',
      birthPada: rashiChart.planets[Planet.moon]?.pada ?? 0,
      balanceOfFirstDasha:
          0, // Sign-based dashas typically start fully at birth
      allMahadashas: mahadashas,
    );
  }

  /// Internal: Calculate years for a sign in Chara Dasha.
  int _calculateCharaDashaYears(Rashi sign, VedicChart chart) {
    final lord = _getSignLord(sign, chart);
    final lordPos = chart.getPlanet(lord)?.position;
    if (lordPos == null) return 0;

    final lordSign = Rashi.fromLongitude(lordPos.longitude);

    int diff;
    if (sign.isOdd) {
      // Direct distance
      diff = (lordSign.number - sign.number + 12) % 12;
    } else {
      // Indirect distance
      diff = (sign.number - lordSign.number + 12) % 12;
    }

    return diff == 0 ? 12 : diff;
  }

  /// Internal: Get the primary lord of a sign (handling Scorpio/Aquarius).
  Planet _getSignLord(Rashi sign, VedicChart chart) {
    switch (sign) {
      case Rashi.aries:
      case Rashi.scorpio:
        if (sign == Rashi.scorpio) {
          // Scorpio has two lords: Mars and Ketu.
          // Simplified: Use the one that is stronger or just Mars for now.
          // Most implementations default to Mars if No planet is in Scorpio.
          return Planet.mars;
        }
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
        if (sign == Rashi.aquarius) {
          // Aquarius has two lords: Saturn and Rahu.
          return Planet.saturn;
        }
        return Planet.saturn;
    }
  }

  /// Finds the current dasha period at a given date.
  ///
  /// [dashaResult] - Previously calculated dasha result
  /// [targetDate] - Date to find the current period for
  ///
  /// Returns list of active periods (mahadasha, antardasha, pratyantardasha).
  List<DashaPeriod> getCurrentPeriods(
      DashaResult dashaResult, DateTime targetDate) {
    return dashaResult.getActivePeriodsAt(targetDate);
  }
}

/// Internal helper class for Vimshottari planet info.
class _VimshottariPlanetInfo {
  const _VimshottariPlanetInfo(this.planet, this.name, this.years);
  final Planet planet;
  final String name;
  final double years;
}
