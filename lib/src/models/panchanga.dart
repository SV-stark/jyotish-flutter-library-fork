import '../models/planet.dart';

/// Represents the five limbs (Panchanga) of a day in Vedic astrology.
/// Panchanga consists of Tithi, Yoga, Karana, Vara (weekday), and Nakshatra.
class Panchanga {
  const Panchanga({
    required this.dateTime,
    required this.location,
    required this.tithi,
    required this.yoga,
    required this.karana,
    required this.vara,
    required this.sunrise,
    required this.sunset,
  });

  /// Date and time for which the Panchanga was calculated
  final DateTime dateTime;

  /// Location information
  final String location;

  /// Tithi (lunar phase)
  final TithiInfo tithi;

  /// Yoga (27 lunar-solar combinations)
  final YogaInfo yoga;

  /// Karana (half-tithi, 60 total)
  final KaranaInfo karana;

  /// Vara (weekday/planetary day lord)
  final VaraInfo vara;

  /// Sunrise time
  final DateTime sunrise;

  /// Sunset time
  final DateTime sunset;

  /// Gets whether it's daytime
  bool get isDaytime {
    final now = dateTime;
    return now.isAfter(sunrise) && now.isBefore(sunset);
  }

  /// Gets the day length in hours
  double get dayLengthHours {
    return sunset.difference(sunrise).inMinutes / 60.0;
  }

  /// Formatted string representation
  @override
  String toString() {
    return 'Panchanga(${dateTime.toIso8601String()}): '
        '${tithi.name} (${tithi.paksha}), '
        '${yoga.name}, ${karana.name}, ${vara.name}';
  }
}

/// Tithi information
class TithiInfo {
  const TithiInfo({
    required this.number,
    required this.name,
    required this.paksha,
    required this.elapsed,
  });

  /// Tithi number (1-30)
  final int number;

  /// Tithi name
  final String name;

  /// Paksha (lunar fortnight)
  final Paksha paksha;

  /// Elapsed portion of the tithi (0.0 - 1.0)
  final double elapsed;

  /// Remaining portion of the tithi (0.0 - 1.0)
  double get remaining => 1.0 - elapsed;

  /// Whether the tithi is complete (> 0.9)
  bool get isComplete => elapsed > 0.9;

  static const List<String> tithiNames = [
    'Pratipada',
    'Dwitiya',
    'Tritiya',
    'Chaturthi',
    'Panchami',
    'Shashthi',
    'Saptami',
    'Ashtami',
    'Navami',
    'Dashami',
    'Ekadashi',
    'Dwadashi',
    'Trayodashi',
    'Chaturdashi',
    'Purnima/Amavasya',
  ];
}

/// Lunar fortnight (Paksha)
enum Paksha {
  shukla('Shukla Paksha', 'Waxing Moon'),
  krishna('Krishna Paksha', 'Waning Moon');

  const Paksha(this.sanskrit, this.description);

  final String sanskrit;
  final String description;

  /// Gets paksha from tithi number (1-15 = Shukla, 16-30 = Krishna)
  static Paksha fromTithiNumber(int tithiNumber) {
    return tithiNumber <= 15 ? Paksha.shukla : Paksha.krishna;
  }
}

/// Yoga information
class YogaInfo {
  const YogaInfo({
    required this.number,
    required this.name,
    required this.elapsed,
  });

  /// Yoga number (1-27)
  final int number;

  /// Yoga name
  final String name;

  /// Elapsed portion of the yoga (0.0 - 1.0)
  final double elapsed;

  /// Remaining portion of the yoga (0.0 - 1.0)
  double get remaining => 1.0 - elapsed;

  static const List<String> yogaNames = [
    'Vishkumbha',
    'Priti',
    'Ayushman',
    'Saubhagya',
    'Shobhana',
    'Atiganda',
    'Sukarma',
    'Dhriti',
    'Shula',
    'Ganda',
    'Vriddhi',
    'Dhruva',
    'Vyaghata',
    'Harshana',
    'Vajra',
    'Siddhi',
    'Vyatipata',
    'Variyana',
    'Parigha',
    'Shiva',
    'Siddha',
    'Sadhyaya',
    'Shubha',
    'Shukla',
    'Brahma',
    'Indra',
    'Vaidhriti',
  ];

  /// Gets the yoga nature (benefic or malefic)
  YogaNature get nature {
    final maleficYogas = [
      6,
      9,
      10,
      13,
      17,
      27
    ]; // Atiganda, Shula, Ganda, Vyaghata, Vyatipata, Vaidhriti
    return maleficYogas.contains(number)
        ? YogaNature.malefic
        : YogaNature.benefic;
  }
}

/// Yoga nature
enum YogaNature {
  benefic('Benefic', true),
  malefic('Malefic', false);

  const YogaNature(this.name, this.isAuspicious);

  final String name;
  final bool isAuspicious;
}

/// Karana information
class KaranaInfo {
  const KaranaInfo({
    required this.number,
    required this.name,
    required this.isFixed,
    required this.elapsed,
  });

  /// Karana number (1-60, repeating pattern)
  final int number;

  /// Karana name
  final String name;

  /// Whether it's a fixed karana (first 7) or variable
  final bool isFixed;

  /// Elapsed portion of the karana (0.0 - 1.0)
  final double elapsed;

  static const List<String> fixedKaranaNames = [
    'Bava',
    'Balava',
    'Kaulava',
    'Taitila',
    'Garaja',
    'Vanija',
    'Vishti',
  ];

  static const List<String> variableKaranaNames = [
    'Shakuni',
    'Chatushpada',
    'Naga',
    'Kimstughna',
  ];

  /// Gets the karana nature
  KaranaNature get nature {
    if (name == 'Vishti') return KaranaNature.malefic;
    if (isFixed) return KaranaNature.benefic;
    return KaranaNature.mixed;
  }
}

/// Karana nature
enum KaranaNature {
  benefic('Benefic', true),
  malefic('Malefic', false),
  mixed('Mixed', null);

  const KaranaNature(this.name, this.isAuspicious);

  final String name;
  final bool? isAuspicious;
}

/// Vara (weekday/planetary day) information
class VaraInfo {
  const VaraInfo({
    required this.weekday,
    required this.name,
    required this.rulingPlanet,
  });

  /// Weekday number (0 = Sunday, 1 = Monday, etc.)
  final int weekday;

  /// Weekday name
  final String name;

  /// Ruling planet of the day
  final Planet rulingPlanet;

  static const List<String> weekdayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  /// Gets the planet ruling the weekday
  static Planet getRulingPlanet(int weekday) {
    switch (weekday) {
      case 0:
        return Planet.sun;
      case 1:
        return Planet.moon;
      case 2:
        return Planet.mars;
      case 3:
        return Planet.mercury;
      case 4:
        return Planet.jupiter;
      case 5:
        return Planet.venus;
      case 6:
        return Planet.saturn;
      default:
        throw ArgumentError('Invalid weekday: $weekday');
    }
  }

  /// Gets the Hora lord for a specific hour of the day.
  ///
  /// The Hora cycle follows the sequence: Sun, Venus, Mercury, Moon, Saturn,
  /// Jupiter, Mars. The first Hora of the day (at sunrise) is ruled by the
  /// lord of the weekday.
  ///
  /// [hourOfDay] - The zero-based hour index since sunrise (0-23).
  Planet getHoraLord(int hourOfDay) {
    // Hora cycle: Sun, Venus, Mercury, Moon, Saturn, Jupiter, Mars (repeat)
    final horaOrder = [
      Planet.sun,
      Planet.venus,
      Planet.mercury,
      Planet.moon,
      Planet.saturn,
      Planet.jupiter,
      Planet.mars,
    ];

    // Find the starting index based on the weekday
    int startIndex;
    switch (weekday) {
      case 0: // Sunday
        startIndex = 0; // Sun
        break;
      case 1: // Monday
        startIndex = 3; // Moon
        break;
      case 2: // Tuesday
        startIndex = 6; // Mars
        break;
      case 3: // Wednesday
        startIndex = 2; // Mercury
        break;
      case 4: // Thursday
        startIndex = 5; // Jupiter
        break;
      case 5: // Friday
        startIndex = 1; // Venus
        break;
      case 6: // Saturday
        startIndex = 4; // Saturn
        break;
      default:
        startIndex = 0;
    }

    return horaOrder[(startIndex + hourOfDay) % 7];
  }
}
