enum UserRole { member, approver, admin }

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String churchId;
  final UserRole role;
  final String? departmentId;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.churchId,
    required this.role,
    this.departmentId,
  });

  factory AppUser.fromFirestore(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      name: data['name'],
      email: data['email'],
      churchId: data['churchId'],
      role: UserRole.values.firstWhere(
        (e) => e.name == data['role'],
        orElse: () => UserRole.member,
      ),
      departmentId: data['departmentId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'churchId': churchId,
      'role': role.name,
      'departmentId': departmentId,
    };
  }
}