import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartchef/models/recipe_model.dart';
import 'package:smartchef/models/user_model.dart';
import 'package:smartchef/screens/ai_recipe_chat_screen.dart'; // Make sure this import is correct
import 'package:smartchef/services/auth_service.dart';
import 'package:smartchef/services/recipe_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;

  const RecipeDetailScreen({
    Key? key,
    required this.recipeId,
  }) : super(key: key);

  @override
  _RecipeDetailScreenState createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _isLoading = true;
  RecipeModel? _recipe;
  UserModel? _currentUser;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final recipeService = Provider.of<RecipeService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);

      final recipe = await recipeService.getRecipeById(widget.recipeId);
      final user = await authService.getCurrentUserData();

      if (mounted) {
        setState(() {
          _recipe = recipe;
          _currentUser = user;
          _isFavorite = user?.favorites.contains(widget.recipeId) ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading recipe: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading recipe: $e')),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentUser == null) return;

    setState(() {
      _isFavorite = !_isFavorite;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      if (_isFavorite) {
        await authService.addToFavorites(widget.recipeId);
      } else {
        await authService.removeFromFavorites(widget.recipeId);
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      if (mounted) {
        setState(() {
          _isFavorite = !_isFavorite; // Revert on error
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating favorites: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading || _recipe == null
          ? Center(child: CircularProgressIndicator())
          : _buildRecipeDetails(),
      floatingActionButton: _recipe != null
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AIRecipeChatScreen(recipe: _recipe!),
                  ),
                ).then((updatedRecipe) {
                  if (updatedRecipe != null) {
                    setState(() {
                      _recipe = updatedRecipe;
                    });
                  }
                });
              },
              child: Icon(Icons.chat),
              tooltip: 'Chat with AI Chef',
              backgroundColor: Theme.of(context).colorScheme.secondary,
            )
          : null,
    );
  }

  Widget _buildRecipeDetails() {
    return CustomScrollView(
      slivers: [
        // App Bar with Image
        SliverAppBar(
          expandedHeight: 250,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Image.network(
              _recipe!.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: Icon(
                    Icons.restaurant,
                    size: 80,
                    color: Colors.grey[600],
                  ),
                );
              },
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : Colors.white,
              ),
              onPressed: _toggleFavorite,
            ),
            IconButton(
              icon: Icon(Icons.share),
              onPressed: () {
                // Implement share functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sharing recipe...')),
                );
              },
            ),
          ],
        ),

        // Recipe Content
        SliverList(
          delegate: SliverChildListDelegate([
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipe Title
                  Text(
                    _recipe!.title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 8),

                  // Author and Date
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        child: Text(_recipe!.authorName[0].toUpperCase()),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'by ${_recipe!.authorName}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      Spacer(),
                      Text(
                        timeago.format(_recipe!.createdAt),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Recipe Info Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          Icons.timer_outlined,
                          'Prep Time',
                          '${_recipe!.prepTimeMinutes} min',
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          Icons.local_fire_department_outlined,
                          'Cook Time',
                          '${_recipe!.cookTimeMinutes} min',
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          Icons.restaurant_outlined,
                          'Servings',
                          '${_recipe!.servings}',
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Description
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 8),

                  Text(
                    _recipe!.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Ingredients
                  Text(
                    'Ingredients',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 8),

                  ..._recipe!.ingredients.map((ingredient) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: Theme.of(context).primaryColor,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ingredient,
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  SizedBox(height: 24),

                  // Instructions
                  Text(
                    'Instructions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 8),

                  ..._recipe!.instructions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final instruction = entry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Theme.of(context).primaryColor,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              instruction,
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  SizedBox(height: 24),

                  // Nutrition Information
                  Text(
                    'Nutrition Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildNutritionInfo(
                          'Calories',
                          _recipe!.nutritionInfo['calories'].toString(),
                        ),
                      ),
                      Expanded(
                        child: _buildNutritionInfo(
                          'Protein',
                          _recipe!.nutritionInfo['protein'].toString(),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: _buildNutritionInfo(
                          'Carbs',
                          _recipe!.nutritionInfo['carbs'].toString(),
                        ),
                      ),
                      Expanded(
                        child: _buildNutritionInfo(
                          'Fat',
                          _recipe!.nutritionInfo['fat'].toString(),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _recipe!.tags.map((tag) {
                      return Chip(
                        label: Text(
                          tag,
                          style: TextStyle(fontSize: 12),
                        ),
                        backgroundColor:
                            Theme.of(context).primaryColor.withOpacity(0.1),
                      );
                    }).toList(),
                  ),

                  // AI Chat button hint
                  SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap the chat button to modify this recipe with AI',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 40),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String value) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(
              icon,
              color: Theme.of(context).primaryColor,
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionInfo(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$title: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
