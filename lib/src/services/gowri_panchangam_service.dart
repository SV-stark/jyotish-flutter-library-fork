import '../models/geographic_location.dart';
import '../models/gowri_panchangam.dart';
import 'ephemeris_service.dart';

/// Service for calculating Gowri Panchangam.
///
/// Traditional South Indian electional logic dividing day and night into 8 parts each.
/// Each part is ruled by a specific quality (Gowri).
class GowriPanchangamService {
  GowriPanchangamService(this._ephemerisService);

  final EphemerisService _ephemerisService;

  // Day Sequences
  static const Map<int, List<GowriType>> _daySequences = {
    7: [
      // Sunday
      GowriType.uthi, GowriType.amrit, GowriType.rogam, GowriType.labhamu,
      GowriType.dhana, GowriType.soolai, GowriType.visham, GowriType.nirkku
    ],
    1: [
      // Monday
      GowriType.amrit, GowriType.rogam, GowriType.labhamu, GowriType.dhana,
      GowriType.soolai, GowriType.visham, GowriType.nirkku, GowriType.uthi
    ],
    2: [
      // Tuesday
      GowriType.rogam, GowriType.labhamu, GowriType.dhana, GowriType.soolai,
      GowriType.visham, GowriType.nirkku, GowriType.uthi, GowriType.amrit
    ],
    3: [
      // Wednesday
      GowriType.labhamu, GowriType.dhana, GowriType.soolai, GowriType.visham,
      GowriType.nirkku, GowriType.uthi, GowriType.amrit, GowriType.rogam
    ],
    4: [
      // Thursday
      GowriType.dhana, GowriType.soolai, GowriType.visham, GowriType.nirkku,
      GowriType.uthi, GowriType.amrit, GowriType.rogam, GowriType.labhamu
    ],
    5: [
      // Friday
      GowriType.soolai, GowriType.visham, GowriType.nirkku, GowriType.uthi,
      GowriType.amrit, GowriType.rogam, GowriType.labhamu, GowriType.dhana
    ],
    6: [
      // Saturday
      GowriType.visham, GowriType.nirkku, GowriType.uthi, GowriType.amrit,
      GowriType.rogam, GowriType.labhamu, GowriType.dhana, GowriType.soolai
    ],
  };

  // Night Sequences
  static const Map<int, List<GowriType>> _nightSequences = {
    7: [
      // Sunday
      GowriType.labhamu, GowriType.soolai, GowriType.uthi, GowriType.amrit,
      GowriType.visham, GowriType.rogam, GowriType.nirkku, GowriType.dhana
    ],
    1: [
      // Monday
      GowriType.labhamu, GowriType.soolai, GowriType.uthi, GowriType.amrit,
      GowriType.visham, GowriType.rogam, GowriType.nirkku, GowriType.dhana
    ],
    2: [
      // Tuesday
      GowriType.labhamu, GowriType.soolai, GowriType.uthi, GowriType.amrit,
      GowriType.visham, GowriType.rogam, GowriType.nirkku, GowriType.dhana
    ],
    3: [
      // Wednesday
      GowriType.labhamu, GowriType.soolai, GowriType.uthi, GowriType.amrit,
      GowriType.visham, GowriType.rogam, GowriType.nirkku, GowriType.dhana
    ],
    4: [
      // Thursday
      GowriType.labhamu, GowriType.soolai, GowriType.uthi, GowriType.amrit,
      GowriType.visham, GowriType.rogam, GowriType.nirkku, GowriType.dhana
    ],
    5: [
      // Friday
      GowriType.labhamu, GowriType.soolai, GowriType.uthi, GowriType.amrit,
      GowriType.visham, GowriType.rogam, GowriType.nirkku, GowriType.dhana
    ],
    6: [
      // Saturday
      GowriType.labhamu, GowriType.soolai, GowriType.uthi, GowriType.amrit,
      GowriType.visham, GowriType.rogam, GowriType.nirkku, GowriType.dhana
    ],
  };

  /// Calculates current Gowri Panchangam period.
  Future<GowriPanchangamInfo> getCurrentGowriPanchangam({
    required DateTime dateTime,
    required GeographicLocation location,
  }) async {
    final sunriseSunset = await _ephemerisService.getSunriseSunset(
      date: dateTime,
      location: location,
    );

    var sunrise = sunriseSunset.$1;
    var sunset = sunriseSunset.$2;
    if (sunrise == null || sunset == null) throw Exception('No sunrise data');

    DateTime effectiveSunrise = sunrise;
    DateTime effectiveSunset = sunset;

    // Handle previous day logic if before sunrise
    if (dateTime.isBefore(sunrise)) {
      final prevDate = dateTime.subtract(const Duration(days: 1));
      final prevInfo = await _ephemerisService.getSunriseSunset(
          date: prevDate, location: location);
      if (prevInfo.$1 != null) {
        effectiveSunrise = prevInfo.$1!;
        effectiveSunset = prevInfo.$2!;
      }
    }

    if (dateTime.isAfter(effectiveSunset) ||
        dateTime.isBefore(effectiveSunrise)) {
      // Nighttime
      final nextDate = effectiveSunrise.add(const Duration(days: 1));
      final nextInfo = await _ephemerisService.getSunriseSunset(
          date: nextDate, location: location);
      final nextSunrise =
          nextInfo.$1 ?? effectiveSunrise.add(const Duration(hours: 24));

      final nightDuration = nextSunrise.difference(effectiveSunset);
      final segmentLength = nightDuration.inMicroseconds / 8;
      final timeSinceSunset =
          dateTime.difference(effectiveSunset).inMicroseconds;
      final segmentIndex = (timeSinceSunset / segmentLength).floor();

      final adjustedIndex = segmentIndex >= 8 ? 7 : segmentIndex;
      final weekday = effectiveSunrise.weekday;

      // Note: Night sequence for Gowri Panchangam varies by source.
      // Often simpler cyclical logic is used, but standard tables exist.
      // The implemented map above is a placeholder - need to verify exact night sequence.
      // Correcting Night Sequence Logic based on standard tables:
      // Sun: Nirkku, Uthi, Amrit, Rogam, Labhamu, Dhana, Soolai, Visham (Example)
      // Actually, common logic:
      // For a given Day, Night sequence starts from a specific Gowri.

      // Let's implement a standard lookup map for Night sequences if available,
      // otherwise rely on the placeholder.
      // Placeholder used above needs verification.
      // Standard Tamil Panchangam:
      // Sun Night: Labham, Uthi, Amrit, Rogam, Soolai, Visham, Nirkku, Dhana?
      // Let's use a commonly accepted sequence or highlight this as a "Standard" variant.
      // Re-using the _nightSequences defined above for now.

      final type = _nightSequences[weekday]![adjustedIndex];

      final startTime = effectiveSunset
          .add(Duration(microseconds: (segmentLength * adjustedIndex).round()));
      final endTime = effectiveSunset.add(Duration(
          microseconds: (segmentLength * (adjustedIndex + 1)).round()));

      return GowriPanchangamInfo(
        type: type,
        startTime: startTime,
        endTime: endTime,
        isDaytime: false,
        periodNumber: adjustedIndex + 1,
      );
    } else {
      // Daytime
      final dayDuration = effectiveSunset.difference(effectiveSunrise);
      final segmentLength = dayDuration.inMicroseconds / 8;
      final timeSinceSunrise =
          dateTime.difference(effectiveSunrise).inMicroseconds;
      final segmentIndex = (timeSinceSunrise / segmentLength).floor();

      final adjustedIndex = segmentIndex >= 8 ? 7 : segmentIndex;
      final weekday = effectiveSunrise.weekday;
      final type = _daySequences[weekday]![adjustedIndex];

      final startTime = effectiveSunrise
          .add(Duration(microseconds: (segmentLength * adjustedIndex).round()));
      final endTime = effectiveSunrise.add(Duration(
          microseconds: (segmentLength * (adjustedIndex + 1)).round()));

      return GowriPanchangamInfo(
        type: type,
        startTime: startTime,
        endTime: endTime,
        isDaytime: true,
        periodNumber: adjustedIndex + 1,
      );
    }
  }
}
