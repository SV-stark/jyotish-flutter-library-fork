/// Represents the different Divisional Charts (Varga) in Vedic Astrology.
enum DivisionalChartType {
  /// D1 - Rashi (Root/Body)
  d1('D1', 'Rashi', 'Body', 1),

  /// D2 - Hora (Wealth/Family)
  d2('D2', 'Hora', 'Wealth', 2),

  /// D3 - Drekkana (Siblings/Courage)
  d3('D3', 'Drekkana', 'Siblings', 3),

  /// D4 - Chaturthamsa (Fortune/Assets)
  d4('D4', 'Chaturthamsa', 'Assets', 4),

  /// D7 - Saptamsa (Children/Progeny)
  d7('D7', 'Saptamsa', 'Children', 7),

  /// D9 - Navamsa (Spouse/Dharma)
  d9('D9', 'Navamsa', 'Spouse', 9),

  /// D10 - Dasamsa (Career/Profession)
  d10('D10', 'Dasamsa', 'Career', 10),

  /// D12 - Dwadasamsa (Parents)
  d12('D12', 'Dwadasamsa', 'Parents', 12),

  /// D16 - Shodasamsa (Vehicles/Happiness)
  d16('D16', 'Shodasamsa', 'Vehicles', 16),

  /// D20 - Vimsamsa (Spiritual Progress)
  d20('D20', 'Vimsamsa', 'Spirituality', 20),

  /// D24 - Chaturvimshamsha (Education/Knowledge)
  d24('D24', 'Chaturvimshamsha', 'Education', 24),

  /// D27 - Saptavimsamsa (Strengths/Weaknesses)
  d27('D27', 'Saptavimsamsa', 'Strength', 27),

  /// D30 - Trimsamsa (Misfortunes/Evil effects)
  d30('D30', 'Trimsamsa', 'Misfortunes', 30),

  /// D40 - Khavedamsa (Auspicious/Inauspicious effects)
  d40('D40', 'Khavedamsa', 'Auspiciousness', 40),

  /// D45 - Akshavedamsa (Character/Integrity)
  d45('D45', 'Akshavedamsa', 'Character', 45),

  /// D60 - Shashtiamsa (Past Life/Karma)
  d60('D60', 'Shashtiamsa', 'Past Life', 60),

  /// D249 - 249 Subdivisions (Micro-Level Analysis)
  d249('D249', '249 Subdivisions', 'Micro Analysis', 249);

  const DivisionalChartType(
      this.code, this.name, this.significance, this.divisions);

  final String code;
  final String name;
  final String significance;
  final int divisions;
}
