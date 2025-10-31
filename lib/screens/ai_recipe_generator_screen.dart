import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartchef/models/recipe_model.dart';
import 'package:smartchef/screens/recipe_detail_screen.dart';
import 'package:smartchef/services/auth_service.dart';
import 'package:smartchef/services/gemini_service.dart';
import 'package:smartchef/services/recipe_service.dart';

class AIRecipeGeneratorScreen extends StatefulWidget {
  @override
  _AIRecipeGeneratorScreenState createState() =>
      _AIRecipeGeneratorScreenState();
}

class _AIRecipeGeneratorScreenState extends State<AIRecipeGeneratorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ingredientsController = TextEditingController();
  final List<String> _ingredientList = [];
  bool _isGenerating = false;
  String _loadingMessage = 'Creating your recipe...';
  bool _dialogShowing = false;

  @override
  void dispose() {
    _ingredientsController.dispose();
    super.dispose();
  }

  void _addIngredient() {
    final ingredient = _ingredientsController.text.trim();
    if (ingredient.isNotEmpty) {
      setState(() {
        _ingredientList.add(ingredient);
        _ingredientsController.clear();
      });
    }
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredientList.removeAt(index);
    });
  }

  Future<void> _generateRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    if (_ingredientList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add at least one ingredient')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _loadingMessage = 'Creating your recipe...';
      _dialogShowing = true;
    });

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(_loadingMessage),
                SizedBox(height: 8),
                Text(
                  'Our AI chef is working on your custom recipe',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        });
      },
    );

    try {
      // 1. Generate recipe from ingredients
      setState(() => _loadingMessage = 'Generating recipe...');
      final geminiService = GeminiService();
      final recipeData =
          await geminiService.generateRecipeFromIngredients(_ingredientList);

      if (!_isValidRecipe(recipeData)) {
        throw Exception(
            'The AI generated an incomplete recipe. Please try again.');
      }

      // 2. Generate image description
      setState(() => _loadingMessage = 'Generating image...');
      final imageDescription = await geminiService.generateImageDescription(
          recipeData['title'] as String,
          (recipeData['ingredients'] as List).cast<String>());

      // 3. Save recipe to Firebase
      setState(() => _loadingMessage = 'Saving your recipe...');
      final authService = Provider.of<AuthService>(context, listen: false);
      final recipeService = Provider.of<RecipeService>(context, listen: false);
      final user = await authService.getCurrentUserData();

      if (user == null) throw Exception('User not authenticated');

      final newRecipe = RecipeModel(
        id: '', // Will be set by Firestore
        title: recipeData['title'] ?? 'AI Generated Recipe',
        description: recipeData['description'] ??
            'An AI-generated recipe with your ingredients.',
        imageUrl:
            'https://source.unsplash.com/featured/?${Uri.encodeComponent(imageDescription)}',
        authorId: user.uid,
        authorName: user.displayName ?? 'Anonymous',
        ingredients: List<String>.from(recipeData['ingredients'] ?? []),
        instructions: List<String>.from(recipeData['instructions'] ?? []),
        nutritionInfo:
            Map<String, dynamic>.from(recipeData['nutritionInfo'] ?? {}),
        prepTimeMinutes: recipeData['prepTimeMinutes'] ?? 20,
        cookTimeMinutes: recipeData['cookTimeMinutes'] ?? 30,
        tags: List<String>.from([...recipeData['tags'] ?? [], 'ai-generated']),
        servings: recipeData['servings'] ?? 2,
        createdAt: DateTime.now(),
      );

      final recipeId = await recipeService.addRecipe(newRecipe);
      if (recipeId == null) throw Exception('Failed to save recipe');

      // Close dialog and navigate
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailScreen(recipeId: recipeId),
          ),
        );
      }
    } catch (e) {
      print('Error generating recipe: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Try Again',
              onPressed: _generateRecipe,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _dialogShowing = false;
        });
      }
    }
  }

  bool _isValidRecipe(Map<String, dynamic> recipeData) {
    return recipeData.containsKey('title') &&
        recipeData.containsKey('ingredients') &&
        recipeData.containsKey('instructions') &&
        recipeData['ingredients'] is List &&
        recipeData['instructions'] is List &&
        (recipeData['ingredients'] as List).isNotEmpty &&
        (recipeData['instructions'] as List).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Recipe Generator'),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Let our AI chef create a custom recipe for you!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Add ingredients you have or want to use, and we\'ll generate a delicious recipe.',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 24),
              // Add ingredient input
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ingredientsController,
                      decoration: InputDecoration(
                        labelText: 'Add Ingredient',
                        hintText: 'e.g., chicken, rice, broccoli',
                        border: OutlineInputBorder(),
                      ),
                      onFieldSubmitted: (_) => _addIngredient(),
                    ),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _addIngredient,
                    child: Text('Add'),
                  ),
                ],
              ),
              SizedBox(height: 16),
              // Ingredient list
              Expanded(
                child: _ingredientList.isEmpty
                    ? Center(
                        child: Text(
                          'Add some ingredients to get started',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : Card(
                        elevation: 2,
                        child: ListView.separated(
                          padding: EdgeInsets.all(16),
                          itemCount: _ingredientList.length,
                          separatorBuilder: (context, index) => Divider(),
                          itemBuilder: (context, index) {
                            return ListTile(
                              dense: true,
                              leading: Icon(Icons.restaurant,
                                  color: Theme.of(context).primaryColor),
                              title: Text(_ingredientList[index]),
                              trailing: IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeIngredient(index),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              SizedBox(height: 16),
              // Generate button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateRecipe,
                  icon: Icon(Icons.auto_awesome),
                  label: Text(
                    'Generate Recipe',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'You can also generate recipes with specific dish names, cooking styles, or dietary preferences',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
