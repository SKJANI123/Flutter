/// A locally-registered device/user row.
class UserProfile {
  const UserProfile({
    required this.id,
    this.name,
    this.deviceId,
    this.isRegistered = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? name;
  final String? deviceId;
  final bool isRegistered;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile copyWith({
    String? name,
    String? deviceId,
    bool? isRegistered,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      deviceId: deviceId ?? this.deviceId,
      isRegistered: isRegistered ?? this.isRegistered,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
