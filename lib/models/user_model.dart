class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final List<String> favorites;
  final List<String> myRecipes;
  final String createdAt;
  final bool isAnonymous;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.favorites,
    required this.myRecipes,
    required this.createdAt,
    this.isAnonymous = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    try {
      return UserModel(
        uid: json['uid']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        displayName: json['displayName']?.toString() ?? 'User',
        photoUrl: json['photoUrl']?.toString(),
        favorites: List<String>.from(
            json['favorites']?.map((e) => e.toString()) ?? []),
        myRecipes: List<String>.from(
            json['myRecipes']?.map((e) => e.toString()) ?? []),
        createdAt:
            json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
        isAnonymous: json['isAnonymous'] ?? false,
      );
    } catch (e) {
      print('Error parsing UserModel: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'favorites': favorites,
      'myRecipes': myRecipes,
      'createdAt': createdAt,
      'isAnonymous': isAnonymous,
    };
  }
}
