import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:smartchef/models/recipe_model.dart';
import 'package:smartchef/models/user_model.dart';
import 'package:smartchef/screens/add_recipe_screen.dart';
import 'package:smartchef/screens/auth/login_screen.dart';
import 'package:smartchef/screens/recipe_detail_screen.dart';
import 'package:smartchef/services/auth_service.dart';
import 'package:smartchef/services/recipe_service.dart';
import 'package:smartchef/services/storage_service.dart';
import 'package:smartchef/widgets/recipe_card.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isUpdatingProfile = false;
  UserModel? _user;
  List<RecipeModel> _favoriteRecipes = [];
  List<RecipeModel> _myRecipes = [];
  File? _newProfileImage;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final recipeService = Provider.of<RecipeService>(context, listen: false);

      final user = await authService.getCurrentUserData();

      if (user != null) {
        final favorites =
            await recipeService.getFavoriteRecipes(user.favorites);
        final myRecipes = await recipeService.getUserRecipes(user.myRecipes);

        if (mounted) {
          setState(() {
            _user = user;
            _favoriteRecipes = favorites;
            _myRecipes = myRecipes;
            _nameController.text = user.displayName;
            _isLoading = false;
          });
        }
      } else {
        // Handle not logged in case
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => LoginScreen()),
          );
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickProfileImage() async {
    final ImagePicker imagePicker = ImagePicker();
    final XFile? image = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _newProfileImage = File(image.path);
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_user == null) return;

    setState(() {
      _isUpdatingProfile = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final storageService =
          Provider.of<StorageService>(context, listen: false);

      String? photoUrl;
      if (_newProfileImage != null) {
        photoUrl = await storageService.uploadProfileImage(_newProfileImage!);
      }

      await authService.updateUserProfile(
        displayName: _nameController.text.trim(),
        photoUrl: photoUrl,
      );

      // Reload user data
      await _loadUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      print('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingProfile = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildProfileContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddRecipeScreen()),
          ).then((_) => _loadUserData());
        },
        child: Icon(Icons.add),
        tooltip: 'Add Recipe',
      ),
    );
  }

  Widget _buildProfileContent() {
    return Column(
      children: [
        // Profile Header
        _buildProfileHeader(),

        SizedBox(height: 16),

        // Tab Bar
        TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          labelColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
          tabs: [
            Tab(text: 'My Recipes'),
            Tab(text: 'Favorites'),
          ],
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMyRecipesTab(),
              _buildFavoritesTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Profile Image
          GestureDetector(
            onTap: _pickProfileImage,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: _newProfileImage != null
                      ? FileImage(_newProfileImage!)
                      : _user?.photoUrl != null
                          ? NetworkImage(_user!.photoUrl!)
                          : null,
                  child: _newProfileImage == null && _user?.photoUrl == null
                      ? Text(
                          _user?.displayName.substring(0, 1).toUpperCase() ??
                              'U',
                          style: TextStyle(fontSize: 32),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Name Field
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
          ),

          SizedBox(height: 16),

          // Email (read-only)
          Text(
            _user?.email ?? '',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),

          SizedBox(height: 16),

          // Update Profile Button
          ElevatedButton(
            onPressed: _isUpdatingProfile ? null : _updateProfile,
            child: _isUpdatingProfile
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('Update Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRecipesTab() {
    if (_myRecipes.isEmpty) {
      return _buildEmptyState(
        'You have not created any recipes yet',
        'Tap the + button to add your first recipe',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _myRecipes.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Stack(
            children: [
              RecipeCard(recipe: _myRecipes[index], showAuthor: false),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white.withOpacity(0.8),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.blue,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddRecipeScreen(
                                editRecipe: _myRecipes[index],
                              ),
                            ),
                          ).then((_) => _loadUserData());
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white.withOpacity(0.8),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.delete,
                          size: 16,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          _showDeleteConfirmation(_myRecipes[index]);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFavoritesTab() {
    if (_favoriteRecipes.isEmpty) {
      return _buildEmptyState(
        'You have no favorite recipes yet',
        'Tap the heart icon on recipes to add them to favorites',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _favoriteRecipes.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Stack(
            children: [
              RecipeCard(recipe: _favoriteRecipes[index]),
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white.withOpacity(0.8),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.favorite,
                      size: 16,
                      color: Colors.red,
                    ),
                    onPressed: () {
                      _removeFromFavorites(_favoriteRecipes[index].id);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(RecipeModel recipe) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Recipe'),
        content: Text(
            'Are you sure you want to delete "${recipe.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRecipe(recipe.id);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecipe(String recipeId) async {
    try {
      final recipeService = Provider.of<RecipeService>(context, listen: false);
      final success = await recipeService.deleteRecipe(recipeId);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recipe deleted successfully')),
        );
        _loadUserData();
      }
    } catch (e) {
      print('Error deleting recipe: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting recipe: $e')),
        );
      }
    }
  }

  Future<void> _removeFromFavorites(String recipeId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.removeFromFavorites(recipeId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed from favorites')),
        );
        _loadUserData();
      }
    } catch (e) {
      print('Error removing from favorites: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing from favorites: $e')),
        );
      }
    }
  }
}
