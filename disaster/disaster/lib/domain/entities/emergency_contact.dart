class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    this.relationship,
    this.isPrimary = false,
    this.isVerified = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String? relationship;
  final bool isPrimary;
  final bool isVerified;
  final DateTime? createdAt;

  EmergencyContact copyWith({
    String? name,
    String? phone,
    String? relationship,
    bool? isPrimary,
    bool? isVerified,
  }) {
    return EmergencyContact(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt,
    );
  }
}
