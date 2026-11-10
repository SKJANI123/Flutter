/// The type of an environmental disaster (alerts are per event).
enum DisasterType {
  earthquake('earthquake', 'earthquake'),
  flood('flood', 'flood'),
  cyclone('cyclone', 'cyclone'),
  tsunami('tsunami', 'tsunami'),
  landslide('landslide', 'landslide'),
  wildfire('wildfire', 'wildfire'),
  heavyRain('heavy_rain', 'heavy_rain'),
  lightning('lightning', 'lightning'),
  storm('storm', 'storm'),
  extremeHeat('extreme_heat', 'extreme_heat'),
  volcano('volcano', 'volcano');

  const DisasterType(this.code, this.id);

  /// Canonical lowercase snake_case code used by the API.
  final String code;

  /// The value stored in the database.
  final String id;

  /// Human readable title-case label.
  String get label => switch (this) {
    DisasterType.earthquake => 'Earthquake',
    DisasterType.flood => 'Flood',
    DisasterType.cyclone => 'Cyclone',
    DisasterType.tsunami => 'Tsunami',
    DisasterType.landslide => 'Landslide',
    DisasterType.wildfire => 'Wildfire',
    DisasterType.heavyRain => 'Heavy Rain',
    DisasterType.lightning => 'Lightning',
    DisasterType.storm => 'Storm',
    DisasterType.extremeHeat => 'Extreme Heat',
    DisasterType.volcano => 'Volcano',
  };

  static DisasterType? fromCode(String? code) {
    if (code == null) return null;
    for (final t in DisasterType.values) {
      if (t.code == code.toLowerCase() || t.id == code.toLowerCase()) {
        return t;
      }
    }
    return null;
  }
}
