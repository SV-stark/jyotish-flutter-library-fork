import 'package:jyotish/src/models/vedic_chart.dart';
import 'package:jyotish/src/models/planet.dart';
import 'package:jyotish/src/models/special_lagnas.dart';

/// Service for calculating special time-proportionate and mathematical lagnas.
class SpecialLagnasService {
  const SpecialLagnasService();

  /// Calculates Hora Lagna, Ghati Lagna, and Sree Lagna for a birth chart given the sunrise time.
  SpecialLagnas calculateSpecialLagnas(VedicChart chart, DateTime sunrise) {
    final ascendant = chart.ascendant;
    final birthTime = chart.dateTime;
    final sunLong = chart.getPlanet(Planet.sun)?.longitude ?? 0.0;

    // Calculate elapsed time in hours from sunrise to birth time.
    var elapsedMs = birthTime.difference(sunrise).inMilliseconds;
    if (elapsedMs < 0) {
      // If birth is before today's sunrise, adjust by 24 hours
      elapsedMs += const Duration(days: 1).inMilliseconds;
    }
    final elapsedHours = elapsedMs / (1000 * 60 * 60);

    // 1. Hora Lagna (HL): 2.5 ghatis (1 hour = 60 minutes) per sign (30 degrees).
    // Anchored at Sun's longitude at sunrise/birth per BPHS Ch. 5.
    final horaLagna = (sunLong + elapsedHours * 30.0) % 360.0;

    // 2. Ghati Lagna (GL): 1 ghati (0.4 hours = 24 minutes) per sign (30 degrees).
    // Anchored at Sun's longitude per BPHS Ch. 5.
    final ghatiLagna = (sunLong + (elapsedHours / 0.4) * 30.0) % 360.0;

    // 3. Sree Lagna (SL): Point of Lakshmi based on Moon's nakshatra fraction added to Ascendant.
    final moonInfo = chart.getPlanet(Planet.moon);
    final double moonLong = moonInfo?.longitude ?? 0.0;
    const nakshatraSpan = 360.0 / 27.0; // 13.333333 degrees
    final posInNakshatra = moonLong % nakshatraSpan;
    final fraction = posInNakshatra / nakshatraSpan;
    final sreeLagna = (ascendant + fraction * 360.0) % 360.0;

    return SpecialLagnas(
      horaLagna: horaLagna,
      ghatiLagna: ghatiLagna,
      sreeLagna: sreeLagna,
    );
  }
}
