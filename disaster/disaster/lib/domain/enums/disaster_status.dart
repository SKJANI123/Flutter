/// Lifecycle of a disaster event.
enum DisasterStatus {
  active('active'),
  resolved('resolved'),
  expired('expired');

  const DisasterStatus(this.code);
  final String code;

  static DisasterStatus fromCode(String? code) {
    for (final s in DisasterStatus.values) {
      if (s.code == code?.toLowerCase()) return s;
    }
    return DisasterStatus.active;
  }
}

/// Origin of the data so simulator and production data are never mixed.
enum DataProvider {
  server('server'),
  simulator('simulator'),
  local('local');

  const DataProvider(this.value);
  final String value;

  static DataProvider fromValue(String? v) {
    for (final p in DataProvider.values) {
      if (p.value == v) return p;
    }
    return DataProvider.server;
  }
}
