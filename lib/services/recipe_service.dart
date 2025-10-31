import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smartchef/models/recipe_model.dart';
import 'package:smartchef/services/gemini_service.dart';

class RecipeService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeminiService _geminiService = GeminiService();

  // Get trending recipes
  Future<List<RecipeModel>> getTrendingRecipes() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('recipes')
          .orderBy('viewCount', descending: true)
          .limit(10)
          .get();

      return snapshot.docs
          .map(
              (doc) => RecipeModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting trending recipes: $e');
      return [];
    }
  }

  // Get recent recipes
  Future<List<RecipeModel>> getRecentRecipes() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('recipes')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      return snapshot.docs
          .map(
              (doc) => RecipeModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting recent recipes: $e');
      return [];
    }
  }

  // Get recipe by ID
  Future<RecipeModel?> getRecipeById(String id) async {
    try {
      final DocumentSnapshot doc =
          await _firestore.collection('recipes').doc(id).get();

      if (doc.exists) {
        // Increment view count
        await _firestore.collection('recipes').doc(id).update({
          'viewCount': FieldValue.increment(1),
        });

        return RecipeModel.fromJson(doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      print('Error getting recipe by ID: $e');
    }
    return null;
  }

  // Search recipes
  Future<List<RecipeModel>> searchRecipes(String query) async {
    try {
      // Search by title
      final QuerySnapshot titleSnapshot = await _firestore
          .collection('recipes')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      // Search by tags
      final QuerySnapshot tagSnapshot = await _firestore
          .collection('recipes')
          .where('tags', arrayContains: query.toLowerCase())
          .get();

      // Combine results and remove duplicates
      final Set<String> uniqueIds = {};
      final List<RecipeModel> results = [];

      for (var doc in titleSnapshot.docs) {
        if (!uniqueIds.contains(doc.id)) {
          uniqueIds.add(doc.id);
          results.add(RecipeModel.fromJson(doc.data() as Map<String, dynamic>));
        }
      }

      for (var doc in tagSnapshot.docs) {
        if (!uniqueIds.contains(doc.id)) {
          uniqueIds.add(doc.id);
          results.add(RecipeModel.fromJson(doc.data() as Map<String, dynamic>));
        }
      }

      return results;
    } catch (e) {
      print('Error searching recipes: $e');
      return [];
    }
  }

  // Add new recipe
  Future<String?> addRecipe(RecipeModel recipe) async {
    try {
      if (_auth.currentUser == null) return null;

      final docRef = _firestore.collection('recipes').doc();
      final newRecipe = recipe.toJson();
      newRecipe['id'] = docRef.id;

      await docRef.set(newRecipe);

      // Add recipe to user's recipes
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'myRecipes': FieldValue.arrayUnion([docRef.id]),
      });

      notifyListeners();
      return docRef.id;
    } catch (e) {
      print('Error adding recipe: $e');
      return null;
    }
  }

  // Update recipe
  Future<bool> updateRecipe(RecipeModel recipe) async {
    try {
      await _firestore
          .collection('recipes')
          .doc(recipe.id)
          .update(recipe.toJson());
      notifyListeners();
      return true;
    } catch (e) {
      print('Error updating recipe: $e');
      return false;
    }
  }

  // Delete recipe
  Future<bool> deleteRecipe(String id) async {
    try {
      if (_auth.currentUser == null) return false;

      await _firestore.collection('recipes').doc(id).delete();

      // Remove recipe from user's recipes
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'myRecipes': FieldValue.arrayRemove([id]),
      });

      notifyListeners();
      return true;
    } catch (e) {
      print('Error deleting recipe: $e');
      return false;
    }
  }

  // Like recipe
  Future<bool> likeRecipe(String id) async {
    try {
      await _firestore.collection('recipes').doc(id).update({
        'likeCount': FieldValue.increment(1),
      });
      return true;
    } catch (e) {
      print('Error liking recipe: $e');
      return false;
    }
  }

  // Get user's favorite recipes
  Future<List<RecipeModel>> getFavoriteRecipes(List<String> favoriteIds) async {
    try {
      if (favoriteIds.isEmpty) return [];

      final List<RecipeModel> favoriteRecipes = [];

      // Firestore limits batched reads to 10 at a time
      for (int i = 0; i < favoriteIds.length; i += 10) {
        final end = (i + 10 < favoriteIds.length) ? i + 10 : favoriteIds.length;
        final batch = favoriteIds.sublist(i, end);

        final QuerySnapshot snapshot = await _firestore
            .collection('recipes')
            .where('id', whereIn: batch)
            .get();

        favoriteRecipes.addAll(snapshot.docs
            .map((doc) =>
                RecipeModel.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
      }

      return favoriteRecipes;
    } catch (e) {
      print('Error getting favorite recipes: $e');
      return [];
    }
  }

  // Get user's own recipes
  Future<List<RecipeModel>> getUserRecipes(List<String> recipeIds) async {
    try {
      if (recipeIds.isEmpty) return [];

      final List<RecipeModel> userRecipes = [];

      // Firestore limits batched reads to 10 at a time
      for (int i = 0; i < recipeIds.length; i += 10) {
        final end = (i + 10 < recipeIds.length) ? i + 10 : recipeIds.length;
        final batch = recipeIds.sublist(i, end);

        final QuerySnapshot snapshot = await _firestore
            .collection('recipes')
            .where('id', whereIn: batch)
            .get();

        userRecipes.addAll(snapshot.docs
            .map((doc) =>
                RecipeModel.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
      }

      return userRecipes;
    } catch (e) {
      print('Error getting user recipes: $e');
      return [];
    }
  }

  // Get recipes by ingredient
  Future<List<RecipeModel>> getRecipesByIngredient(String ingredient) async {
    try {
      // Use Gemini to find similar ingredients
      final List<String> similarIngredients =
          await _geminiService.getSimilarIngredients(ingredient);

      final List<RecipeModel> results = [];
      final Set<String> uniqueIds = {};

      for (final ing in similarIngredients) {
        final QuerySnapshot snapshot = await _firestore
            .collection('recipes')
            .where('ingredients', arrayContains: ing)
            .limit(5)
            .get();

        for (var doc in snapshot.docs) {
          if (!uniqueIds.contains(doc.id)) {
            uniqueIds.add(doc.id);
            results
                .add(RecipeModel.fromJson(doc.data() as Map<String, dynamic>));
          }
        }
      }

      return results;
    } catch (e) {
      print('Error getting recipes by ingredient: $e');
      return [];
    }
  }

  // Get recipe recommendations from food image
  Future<List<RecipeModel>> getRecipeRecommendationsFromImage(
      String imageUrl) async {
    try {
      // Use Gemini to identify food from image
      final Map<String, dynamic> foodData =
          await _geminiService.identifyFoodFromImage(imageUrl);

      final String foodName = foodData['name'] as String;
      final List<String> possibleIngredients =
          foodData['ingredients'] as List<String>;

      // Search for recipes with similar food name
      final QuerySnapshot nameSnapshot = await _firestore
          .collection('recipes')
          .where('title', isGreaterThanOrEqualTo: foodName)
          .where('title', isLessThanOrEqualTo: foodName + '\uf8ff')
          .limit(5)
          .get();

      // Add recipes with matching ingredients
      final Set<String> uniqueIds = {};
      final List<RecipeModel> results = [];

      // Add name matches
      for (var doc in nameSnapshot.docs) {
        uniqueIds.add(doc.id);
        results.add(RecipeModel.fromJson(doc.data() as Map<String, dynamic>));
      }

      // Add ingredient matches
      for (final ingredient in possibleIngredients) {
        if (results.length >= 10) break; // Limit to 10 results

        final QuerySnapshot ingredientSnapshot = await _firestore
            .collection('recipes')
            .where('ingredients', arrayContains: ingredient)
            .limit(3)
            .get();

        for (var doc in ingredientSnapshot.docs) {
          if (!uniqueIds.contains(doc.id) && results.length < 10) {
            uniqueIds.add(doc.id);
            results
                .add(RecipeModel.fromJson(doc.data() as Map<String, dynamic>));
          }
        }
      }

      return results;
    } catch (e) {
      print('Error getting recipe recommendations from image: $e');
      return [];
    }
  }
}
