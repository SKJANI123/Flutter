/// The user-facing safety level for a disaster given the user's distance.
enum AlertLevel {
  safe('safe', 0),
  warning('warning', 1),
  danger('danger', 2),
  critical('critical', 3);

  const AlertLevel(this.code, this.weight);
  final String code;
  final int weight;

  String get label => switch (this) {
    AlertLevel.safe => 'Safe',
    AlertLevel.warning => 'Warning',
    AlertLevel.danger => 'Danger',
    AlertLevel.critical => 'Critical',
  };

  static AlertLevel fromCode(String? code) {
    for (final l in AlertLevel.values) {
      if (l.code == code) return l;
    }
    return AlertLevel.safe;
  }

  bool get isSafe => this == AlertLevel.safe;

  bool get isActive => !isSafe;

  /// True when this level is equal to or worse than [other].
  bool atLeast(AlertLevel other) => weight >= other.weight;
}
