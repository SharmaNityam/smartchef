class RecipeModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String authorId;
  final String authorName;
  final List<String> ingredients;
  final List<String> instructions;
  final Map<String, dynamic> nutritionInfo;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final List<String> tags;
  final int servings;
  final DateTime createdAt;
  final int viewCount;
  final int likeCount;

  RecipeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.authorId,
    required this.authorName,
    required this.ingredients,
    required this.instructions,
    required this.nutritionInfo,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.tags,
    required this.servings,
    required this.createdAt,
    this.viewCount = 0,
    this.likeCount = 0,
  });

  factory RecipeModel.fromJson(Map<String, dynamic> json) {
    return RecipeModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      authorId: json['authorId'] ?? '',
      authorName: json['authorName'] ?? '',
      ingredients: List<String>.from(json['ingredients'] ?? []),
      instructions: List<String>.from(json['instructions'] ?? []),
      nutritionInfo: Map<String, dynamic>.from(json['nutritionInfo'] ?? {}),
      prepTimeMinutes: json['prepTimeMinutes'] ?? 0,
      cookTimeMinutes: json['cookTimeMinutes'] ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      servings: json['servings'] ?? 2,
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : DateTime.now(),
      viewCount: json['viewCount'] ?? 0,
      likeCount: json['likeCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'authorId': authorId,
      'authorName': authorName,
      'ingredients': ingredients,
      'instructions': instructions,
      'nutritionInfo': nutritionInfo,
      'prepTimeMinutes': prepTimeMinutes,
      'cookTimeMinutes': cookTimeMinutes,
      'tags': tags,
      'servings': servings,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'viewCount': viewCount,
      'likeCount': likeCount,
    };
  }
}
