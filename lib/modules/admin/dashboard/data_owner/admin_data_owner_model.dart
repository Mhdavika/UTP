class DataOwner {
  final String name;
  final String email;
  final String phone;
  final String role;
  final String ownerId;

  DataOwner({
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.ownerId,
  });

  // Membuat instance DataOwner dari Firestore document
  factory DataOwner.fromFirestore(Map<String, dynamic> data) {
    return DataOwner(
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? '',
      ownerId: data['owner_id'] ?? '',
    );
  }
}
