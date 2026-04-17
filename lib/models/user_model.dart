class UserModel {
  String id;
  String email;
  String role;

  UserModel({
    required this.id,
    required this.email,
    required this.role,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'role': role,
    };
  }
}