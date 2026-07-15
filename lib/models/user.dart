/// يمثل بيانات المندوب المسجّل دخوله، مطابق لشكل $_SESSION['user']
/// في auth.php: {id, full_name, username, role}
class AppUser {
  final int id;
  final String fullName;
  final String username;
  final String role;

  AppUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: int.parse(json['id'].toString()),
      fullName: json['full_name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
    );
  }
}
