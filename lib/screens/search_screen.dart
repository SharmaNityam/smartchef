// screens/search_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartchef/models/recipe_model.dart';
import 'package:smartchef/screens/recipe_detail_screen.dart';
import 'package:smartchef/services/auth_service.dart';
import 'package:smartchef/services/gemini_service.dart';
import 'package:smartchef/services/recipe_service.dart';
import 'package:smartchef/widgets/recipe_card.dart';

class SearchScreen extends StatefulWidget {
  final String initialQuery;
  final String? filterType;

  const SearchScreen({
    Key? key,
    this.initialQuery = '',
    this.filterType,
  }) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<RecipeModel> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  bool _isGeneratingRecipe = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;

    if (widget.filterType != null || widget.initialQuery.isNotEmpty) {
      _performSearch();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final recipeService = Provider.of<RecipeService>(context, listen: false);
      List<RecipeModel> results = [];

      if (widget.filterType == 'trending') {
        results = await recipeService.getTrendingRecipes();
      } else if (widget.filterType == 'recent') {
        results = await recipeService.getRecentRecipes();
      } else if (query.isNotEmpty) {
        results = await recipeService.searchRecipes(query);
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error searching recipes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _generateRecipeWithAI(String dishName) async {
    setState(() {
      _isGeneratingRecipe = true;
    });

    try {
      final recipeService = Provider.of<RecipeService>(context, listen: false);
      final geminiService = GeminiService(); // Or get this from provider

      // Show generating recipe dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Creating your recipe...'),
                  SizedBox(height: 8),
                  Text(
                    'Our AI chef is cooking up a special recipe for "$dishName"',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        );
      }

      // Get recipe details from Gemini
      final recipeData =
          await geminiService.generateRecipeFromIngredients([dishName]);

      // Convert to a RecipeModel
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.getCurrentUserData();

      if (user != null) {
        final newRecipe = RecipeModel(
          id: '', // Will be set by Firestore
          title: recipeData['title'] ?? 'AI Generated $dishName Recipe',
          description: recipeData['description'] ??
              'An AI-generated recipe based on your search.',
          imageUrl:
              'https://via.placeholder.com/500?text=AI+Generated+Recipe', // Placeholder until we implement proper image generation
          authorId: user.uid,
          authorName: user.displayName,
          ingredients: List<String>.from(recipeData['ingredients'] ?? []),
          instructions: List<String>.from(recipeData['instructions'] ?? []),
          nutritionInfo:
              Map<String, dynamic>.from(recipeData['nutritionInfo'] ?? {}),
          prepTimeMinutes: recipeData['prepTimeMinutes'] ?? 20,
          cookTimeMinutes: recipeData['cookTimeMinutes'] ?? 30,
          tags:
              List<String>.from([...recipeData['tags'] ?? [], 'ai-generated']),
          servings: recipeData['servings'] ?? 2,
          createdAt: DateTime.now(),
        );

        // Close the dialog
        if (mounted) {
          Navigator.pop(context);
        }

        // Save to Firestore
        final recipeId = await recipeService.addRecipe(newRecipe);

        if (recipeId != null && mounted) {
          // Navigate to the recipe detail
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeDetailScreen(recipeId: recipeId),
            ),
          );
        } else {
          throw Exception('Failed to save the generated recipe');
        }
      }
    } catch (e) {
      print('Error generating recipe with AI: $e');

      // Close the dialog if it's open
      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating recipe: $e'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingRecipe = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.filterType == 'trending'
            ? Text('Trending Recipes')
            : widget.filterType == 'recent'
                ? Text('Recent Recipes')
                : Text('Search Recipes'),
      ),
      body: Column(
        children: [
          // Search Bar
          if (widget.filterType == null) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search recipes, ingredients, or tags...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (_) => _performSearch(),
                    ),
                  ),
                  SizedBox(width: 12),
                  IconButton(
                    onPressed: _isLoading || _searchController.text.isEmpty
                        ? null
                        : _performSearch,
                    icon: Icon(Icons.search),
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
            ),
          ],

          // Results
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _hasSearched && _searchResults.isEmpty
                    ? _buildEmptyState()
                    : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: RecipeCard(
            recipe: _searchResults[index],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final query = _searchController.text.trim();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),

          SizedBox(height: 16),

          Text(
            'No recipes found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),

          SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              widget.filterType == null
                  ? 'No results for "$query"'
                  : widget.filterType == 'trending'
                      ? 'No trending recipes available at the moment'
                      : 'No recent recipes available at the moment',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Only show the AI generation button when it's a regular search
          if (widget.filterType == null && query.isNotEmpty) ...[
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isGeneratingRecipe
                  ? null
                  : () => _generateRecipeWithAI(query),
              icon: Icon(Icons.auto_awesome),
              label: Text('Generate Recipe with AI'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                backgroundColor: Theme.of(context).colorScheme.secondary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Let our AI chef create a custom recipe for you',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
