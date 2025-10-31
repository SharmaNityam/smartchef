import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartchef/models/recipe_model.dart';
import 'package:smartchef/models/user_model.dart';
import 'package:smartchef/screens/ai_recipe_generator_screen.dart';
import 'package:smartchef/screens/profile_screen.dart';
import 'package:smartchef/screens/scan_screen.dart';
import 'package:smartchef/screens/search_screen.dart';
import 'package:smartchef/services/auth_service.dart';
import 'package:smartchef/services/recipe_service.dart';
import 'package:smartchef/widgets/recipe_card.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  List<RecipeModel> _trendingRecipes = [];
  List<RecipeModel> _recentRecipes = [];
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final recipeService = Provider.of<RecipeService>(context, listen: false);

    try {
      final user = await authService.getCurrentUserData();
      final trending = await recipeService.getTrendingRecipes();
      final recent = await recipeService.getRecentRecipes();

      if (mounted) {
        setState(() {
          _currentUser = user;
          _trendingRecipes = trending;
          _recentRecipes = recent;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading home data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SmartChef'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.auto_awesome),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => AIRecipeGeneratorScreen()),
              );
            },
            tooltip: 'AI Recipe Generator',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            // Navigate to scan screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ScanScreen()),
            );
          } else if (index == 2) {
            // Navigate to profile screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfileScreen()),
            );
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AIRecipeGeneratorScreen()),
          );
        },
        child: Icon(Icons.auto_awesome),
        tooltip: 'Generate Recipe with AI',
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome message
              Text(
                'Hello, ${_currentUser?.displayName ?? 'Chef'}!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 8),

              Text(
                'What would you like to cook today?',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),

              SizedBox(height: 24),

              // AI Recipe Generator Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.0),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => AIRecipeGeneratorScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 40,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Recipe Generator',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Create custom recipes with ingredients you have',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 24),

              // Trending recipes section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Trending Recipes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchScreen(
                            initialQuery: '',
                            filterType: 'trending',
                          ),
                        ),
                      );
                    },
                    child: Text('See All'),
                  ),
                ],
              ),

              SizedBox(height: 8),

              _trendingRecipes.isEmpty
                  ? _buildEmptyState('No trending recipes available')
                  : SizedBox(
                      height: 300,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _trendingRecipes.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 250,
                            margin: EdgeInsets.only(right: 16),
                            child: RecipeCard(
                              recipe: _trendingRecipes[index],
                            ),
                          );
                        },
                      ),
                    ),

              SizedBox(height: 24),

              // Recent recipes section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Recipes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchScreen(
                            initialQuery: '',
                            filterType: 'recent',
                          ),
                        ),
                      );
                    },
                    child: Text('See All'),
                  ),
                ],
              ),

              SizedBox(height: 8),

              _recentRecipes.isEmpty
                  ? _buildEmptyState('No recent recipes available')
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount:
                          _recentRecipes.length > 5 ? 5 : _recentRecipes.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: RecipeCard(
                            recipe: _recentRecipes[index],
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant,
            size: 50,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
