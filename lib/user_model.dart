class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String email;
  final String role; // 'MC' | 'BC' | 'SBC'
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    this.createdAt,
  });

  String get roleLabel {
    switch (role) {
      case 'MC':  return 'Manager Consultant';
      case 'SBC': return 'Senior Business Consultant';
      case 'BC':  return 'Business Consultant';
      default:    return role;
    }
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      uid:   docId,
      name:  map['name']  ?? map['fullName'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      role:  map['role']  ?? 'BC',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name':  name,
      'phone': phone,
      'email': email,
      'role':  role,
    };
  }
}