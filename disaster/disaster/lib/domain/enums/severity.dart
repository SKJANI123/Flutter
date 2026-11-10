/// Intrinsic severity of a disaster event itself (independent from the user's
/// distance). Used together with distance to compute the user [AlertLevel].
enum Severity {
  info('info', 0),
  minor('minor', 1),
  moderate('moderate', 2),
  severe('severe', 3),
  extreme('extreme', 4);

  const Severity(this.code, this.weight);
  final String code;
  final int weight;

  static Severity? fromCode(String? code) {
    if (code == null) return null;
    for (final s in Severity.values) {
      if (s.code == code.toLowerCase()) return s;
    }
    return null;
  }
}
