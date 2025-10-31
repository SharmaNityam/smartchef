import 'package:flutter/material.dart';
import 'package:smartchef/models/recipe_model.dart';
import 'package:smartchef/screens/recipe_detail_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class RecipeCard extends StatelessWidget {
  final RecipeModel recipe;
  final bool showAuthor;

  const RecipeCard({
    Key? key,
    required this.recipe,
    this.showAuthor = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailScreen(recipeId: recipe.id),
          ),
        );
      },
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe Image
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                recipe.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.restaurant,
                      size: 60,
                      color: Colors.grey[600],
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipe Title
                  Text(
                    recipe.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 4),

                  // Recipe Description
                  Text(
                    recipe.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[300]
                          : Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 8),

                  // Recipe Stats
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[300]
                            : Colors.grey[600],
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${recipe.prepTimeMinutes + recipe.cookTimeMinutes} min',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[300]
                              : Colors.grey[600],
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(
                        Icons.restaurant_outlined,
                        size: 16,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[300]
                            : Colors.grey[600],
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${recipe.servings} servings',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[300]
                              : Colors.grey[600],
                        ),
                      ),
                      Spacer(),
                      Icon(
                        Icons.favorite,
                        size: 16,
                        color: Colors.red,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${recipe.likeCount}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[300]
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),

                  if (showAuthor) ...[
                    SizedBox(height: 8),

                    // Author & Time
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          child: Text(
                            recipe.authorName[0].toUpperCase(),
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'by ${recipe.authorName}',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[300]
                                    : Colors.grey[600],
                          ),
                        ),
                        Spacer(),
                        Text(
                          timeago.format(recipe.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[300]
                                    : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
