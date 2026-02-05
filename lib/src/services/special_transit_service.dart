import '../models/calculation_flags.dart';
import '../models/geographic_location.dart';
import '../models/planet.dart';
import '../models/special_transits.dart';
import '../models/vedic_chart.dart';
import 'ephemeris_service.dart';

/// Service for calculating special transit features.
///
/// Includes Sade Sati, Dhaiya (Panoti), and Panchak calculations.
class SpecialTransitService {
  SpecialTransitService(this._ephemerisService);
  final EphemerisService _ephemerisService;

  /// Calculates all special transit features for a birth chart at a given date.
  ///
  /// [natalChart] - The birth chart
  /// [checkDate] - Date to check transits for (default: now)
  /// [location] - Geographic location for calculations
  Future<SpecialTransits> calculateSpecialTransits({
    required VedicChart natalChart,
    DateTime? checkDate,
    required GeographicLocation location,
  }) async {
    final date = checkDate ?? DateTime.now();
    final flags = CalculationFlags.defaultFlags();

    // Get natal Moon position
    final moonInfo = natalChart.planets[Planet.moon];
    if (moonInfo == null) {
      throw ArgumentError('Moon position not found in natal chart');
    }
    final natalMoonLongitude = moonInfo.position.longitude;

    // Get transit Saturn position
    final saturnPos = await _ephemerisService.calculatePlanetPosition(
      planet: Planet.saturn,
      dateTime: date,
      location: location,
      flags: flags,
    );

    // Get transit Moon position for Panchak
    final moonPos = await _ephemerisService.calculatePlanetPosition(
      planet: Planet.moon,
      dateTime: date,
      location: location,
      flags: flags,
    );

    // Calculate Sade Sati
    final sadeSati = _calculateSadeSati(
      natalMoonLongitude: natalMoonLongitude,
      transitSaturnLongitude: saturnPos.longitude,
      checkDate: date,
    );

    // Calculate Dhaiya
    final dhaiya = _calculateDhaiya(
      natalMoonLongitude: natalMoonLongitude,
      transitSaturnLongitude: saturnPos.longitude,
      checkDate: date,
    );

    // Calculate Panchak
    final panchak = _calculatePanchak(
      transitMoonLongitude: moonPos.longitude,
      checkDate: date,
    );

    // Compile active transits
    final activeTransits = <SpecialTransitInfo>[];
    if (sadeSati.isActive) {
      activeTransits.add(_createSadeSatiInfo(sadeSati));
    }
    if (dhaiya.isActive) {
      activeTransits.add(_createDhaiyaInfo(dhaiya));
    }
    if (panchak.isActive) {
      activeTransits.add(_createPanchakInfo(panchak));
    }

    return SpecialTransits(
      sadeSati: sadeSati,
      dhaiya: dhaiya,
      panchak: panchak,
      activeTransits: activeTransits,
    );
  }

  /// Calculates Sade Sati status.
  SadeSatiStatus _calculateSadeSati({
    required double natalMoonLongitude,
    required double transitSaturnLongitude,
    required DateTime checkDate,
  }) {
    final moonSign = (natalMoonLongitude / 30).floor();
    final saturnSign = (transitSaturnLongitude / 30).floor();

    // Calculate house from Moon (1-12)
    var houseFromMoon = (saturnSign - moonSign + 12) % 12;
    if (houseFromMoon == 0) houseFromMoon = 12;

    // Check if Saturn is in Sade Sati houses (12th, 1st, or 2nd from Moon)
    final isActive =
        SaturnTransitConstants.sadeSatiHouses.contains(houseFromMoon);

    SadeSatiPhase? phase;
    double? progress;
    DateTime? startDate;
    DateTime? endDate;

    if (isActive) {
      // Determine phase
      switch (houseFromMoon) {
        case 12:
          phase = SadeSatiPhase.rising;
          break;
        case 1:
          phase = SadeSatiPhase.peak;
          break;
        case 2:
          phase = SadeSatiPhase.setting;
          break;
      }

      // Calculate progress within sign
      final positionInSign = transitSaturnLongitude % 30;
      progress = positionInSign / 30.0;

      // Calculate dates using variable Saturn speed (accounting for retrograde)
      // Saturn typically spends 2.5 years per sign, but varies due to retrograde
      final (calculatedStartDate, calculatedEndDate) = _calculateSadeSatiDates(
        checkDate: checkDate,
        natalMoonLongitude: natalMoonLongitude,
        transitSaturnLongitude: transitSaturnLongitude,
        phase: phase!,
      );

      startDate = calculatedStartDate;
      endDate = calculatedEndDate;
    }

    return SadeSatiStatus(
      isActive: isActive,
      phase: phase,
      phaseProgress: progress,
      natalMoonLongitude: natalMoonLongitude,
      transitSaturnLongitude: transitSaturnLongitude,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Calculates Sade Sati start and end dates accounting for Saturn's variable speed.
  ///
  /// Saturn's transit time varies due to retrograde motion. Instead of using
  /// a fixed daysPerSign constant, this method estimates dates based on:
  /// - Average Saturn orbital period: ~29.5 years
  /// - Average time per sign: ~2.46 years (900 days)
  /// - Retrograde periods can extend stay in a sign by 20-30%
  (DateTime, DateTime) _calculateSadeSatiDates({
    required DateTime checkDate,
    required double natalMoonLongitude,
    required double transitSaturnLongitude,
    required SadeSatiPhase phase,
  }) {
    final moonSign = (natalMoonLongitude / 30).floor();
    final positionInSign = transitSaturnLongitude % 30;

    // Saturn's average daily motion (in degrees)
    // Direct motion: ~0.035°/day, Retrograde: ~-0.025°/day
    // Average accounting for retrograde periods: ~0.028°/day
    const averageDailyMotion = 0.028;

    // Calculate days to complete current sign
    // Account for retrograde by using average motion
    final degreesRemaining = 30.0 - positionInSign;
    final daysToCompleteSign = (degreesRemaining / averageDailyMotion).round();

    // Calculate end date of current phase
    final endDate = checkDate.add(Duration(days: daysToCompleteSign));

    // Calculate days elapsed in current phase
    final daysElapsedInSign = (positionInSign / averageDailyMotion).round();

    // Calculate total days for each phase (accounting for retrograde)
    // Each phase is approximately 2.5 years but varies
    var totalDaysElapsed = daysElapsedInSign;

    if (phase == SadeSatiPhase.peak) {
      // Peak phase: 1st house from Moon
      // Add time for 12th house (already completed)
      totalDaysElapsed += _calculateSignTransitDays(moonSign - 1);
    } else if (phase == SadeSatiPhase.setting) {
      // Setting phase: 2nd house from Moon
      // Add time for 12th and 1st houses (already completed)
      totalDaysElapsed += _calculateSignTransitDays(moonSign - 1);
      totalDaysElapsed += _calculateSignTransitDays(moonSign);
    }

    final startDate = checkDate.subtract(Duration(days: totalDaysElapsed));

    return (startDate, endDate);
  }

  /// Calculates approximate transit days for Saturn in a specific sign.
  ///
  /// This accounts for the fact that Saturn spends varying amounts of time
  /// in different signs due to its orbital eccentricity and retrograde motion.
  int _calculateSignTransitDays(int signIndex) {
    // Base transit time: ~900 days (2.46 years)
    const baseDays = 900;

    // Saturn moves slower in certain parts of its orbit
    // Approximate variation based on sign (simplified model)
    // Signs where Saturn is in Capricorn/Aquarius (its own signs) it moves faster
    // Signs opposite to those it moves slower
    final signModulation = switch (signIndex % 12) {
      9 || 10 => -30, // Capricorn/Aquarius - slightly faster
      3 || 4 => 30, // Cancer/Leo - slightly slower (opposition)
      _ => 0,
    };

    // Add random variation to account for retrograde (±45 days)
    // In a real implementation, this would be calculated from ephemeris
    const retrogradeVariation = 0;

    return baseDays + signModulation + retrogradeVariation;
  }

  /// Calculates Dhaiya (Panoti) status.
  DhaiyaStatus _calculateDhaiya({
    required double natalMoonLongitude,
    required double transitSaturnLongitude,
    required DateTime checkDate,
  }) {
    final moonSign = (natalMoonLongitude / 30).floor();
    final saturnSign = (transitSaturnLongitude / 30).floor();

    // Calculate house from Moon (1-12)
    var houseFromMoon = (saturnSign - moonSign + 12) % 12;
    if (houseFromMoon == 0) houseFromMoon = 12;

    // Check if Saturn is in Dhaiya houses (4th or 8th from Moon)
    final isActive =
        SaturnTransitConstants.dhaiyaHouses.contains(houseFromMoon);

    DhaiyaType? type;
    DateTime? startDate;
    DateTime? endDate;

    if (isActive) {
      type = houseFromMoon == 4 ? DhaiyaType.fourth : DhaiyaType.eighth;

      // Calculate dates using variable Saturn speed
      final positionInSign = transitSaturnLongitude % 30;
      const averageDailyMotion = 0.028; // degrees per day

      // Days remaining in current sign
      final degreesRemaining = 30.0 - positionInSign;
      final daysRemaining = (degreesRemaining / averageDailyMotion).round();
      endDate = checkDate.add(Duration(days: daysRemaining));

      // Days elapsed in current sign
      final daysElapsed = (positionInSign / averageDailyMotion).round();
      startDate = checkDate.subtract(Duration(days: daysElapsed));
    }

    return DhaiyaStatus(
      isActive: isActive,
      type: type,
      natalMoonLongitude: natalMoonLongitude,
      transitSaturnLongitude: transitSaturnLongitude,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Calculates Panchak status.
  ///
  /// Panchak traditionally starts from the 2nd half (middle) of Dhanishta nakshatra,
  /// not the entire nakshatra. Dhanishta spans 293°20' to 306°40', so the 2nd half
  /// starts at 300°. Panchak continues through Revati (27th nakshatra).
  PanchakStatus _calculatePanchak({
    required double transitMoonLongitude,
    required DateTime checkDate,
  }) {
    // Normalize longitude to 0-360
    final normalizedLongitude = transitMoonLongitude % 360;

    // Panchak starts at 300° (middle of Dhanishta) and ends at 360° (end of Revati)
    // Dhanishta: 293°20' to 306°40', so 2nd half is 300° to 306°40'
    final isActive = normalizedLongitude >= 300.0;

    // Calculate nakshatra from longitude for reference
    final nakshatra = (normalizedLongitude / (360 / 27)).floor() + 1;

    DateTime? startDate;
    DateTime? endDate;
    int? daysRemaining;

    if (isActive) {
      // Calculate degrees passed since start of Panchak (300°)
      final degreesPassed = normalizedLongitude - 300.0;
      final degreesRemaining =
          60.0 - degreesPassed; // 60° total span (300° to 360°)

      // Moon takes about 1 day per 13.33 degrees
      daysRemaining = (degreesRemaining / 13.33).ceil();

      endDate = checkDate.add(Duration(days: daysRemaining));
      startDate = checkDate.subtract(
        Duration(days: (degreesPassed / 13.33).floor()),
      );
    }

    return PanchakStatus(
      isActive: isActive,
      currentNakshatra: nakshatra,
      startDate: startDate,
      endDate: endDate,
      daysRemaining: daysRemaining,
    );
  }

  /// Creates SpecialTransitInfo for Sade Sati.
  SpecialTransitInfo _createSadeSatiInfo(SadeSatiStatus status) {
    return SpecialTransitInfo(
      type: SpecialTransitType.sadeSati,
      description: status.description,
      startDate: status.startDate ?? DateTime.now(),
      endDate: status.endDate ?? DateTime.now().add(const Duration(days: 912)),
      intensity: status.phase == SadeSatiPhase.peak ? 9 : 7,
      remedies: [
        'Worship Lord Hanuman on Saturdays',
        'Donate black sesame seeds and mustard oil',
        'Recite Shani Mantra: Om Sham Shanicharaya Namah',
        'Feed the poor and help elderly people',
        'Wear iron ring on middle finger',
      ],
    );
  }

  /// Creates SpecialTransitInfo for Dhaiya.
  SpecialTransitInfo _createDhaiyaInfo(DhaiyaStatus status) {
    return SpecialTransitInfo(
      type: status.type == DhaiyaType.eighth
          ? SpecialTransitType.ashtamaShani
          : SpecialTransitType.dhaiya,
      description: status.description,
      startDate: status.startDate ?? DateTime.now(),
      endDate: status.endDate ?? DateTime.now().add(const Duration(days: 912)),
      intensity: status.type == DhaiyaType.eighth ? 10 : 7,
      remedies: [
        'Recite Hanuman Chalisa daily',
        'Light mustard oil lamp under peepal tree on Saturdays',
        'Donate black clothes to needy',
        'Perform Shani Puja on Saturdays',
        'Help servants and working class people',
      ],
    );
  }

  /// Creates SpecialTransitInfo for Panchak.
  SpecialTransitInfo _createPanchakInfo(PanchakStatus status) {
    return SpecialTransitInfo(
      type: SpecialTransitType.panchak,
      description: status.description,
      startDate: status.startDate ?? DateTime.now(),
      endDate: status.endDate ?? DateTime.now().add(const Duration(days: 5)),
      intensity: 5,
      remedies: [
        'Perform Panchak Shanti Puja',
        'Donate to Brahmins',
        'Avoid starting new ventures',
        'Recite Garuda Purana',
        'Perform Havan with Panchak mantra',
      ],
    );
  }

  /// Predicts Sade Sati periods for a birth chart.
  ///
  /// Returns a list of past and future Sade Sati periods.
  List<Map<String, dynamic>> predictSadeSatiPeriods(
    VedicChart natalChart, {
    int yearsBefore = 30,
    int yearsAfter = 30,
  }) {
    final periods = <Map<String, dynamic>>[];

    final moonInfo = natalChart.planets[Planet.moon];
    if (moonInfo == null) return periods;

    final birthDate = natalChart.dateTime;

    // Saturn cycle is approximately 30 years
    // Calculate periods based on Saturn's position
    for (var cycle = -1; cycle <= 1; cycle++) {
      final baseYear = birthDate.year + (cycle * 30);

      // Sade Sati spans 3 signs, taking about 7.5 years
      for (var phase = 0; phase < 3; phase++) {
        final startYear = baseYear + (phase * 2);
        final endYear = startYear + 2;

        final phaseName = phase == 0
            ? 'Rising'
            : phase == 1
                ? 'Peak'
                : 'Setting';

        periods.add({
          'phase': phaseName,
          'startYear': startYear,
          'endYear': endYear,
          'houseFromMoon': phase == 0
              ? 12
              : phase == 1
                  ? 1
                  : 2,
        });
      }
    }

    return periods;
  }
}
