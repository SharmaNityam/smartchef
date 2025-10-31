import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smartchef/models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> _getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          return UserModel.fromJson(Map<String, dynamic>.from(data));
        }
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Existing signOut method
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      notifyListeners();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // Existing updateUserProfile method
  Future<void> updateUserProfile({
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      if (_auth.currentUser != null) {
        await _auth.currentUser!.updateDisplayName(displayName);

        if (photoUrl != null) {
          await _auth.currentUser!.updatePhotoURL(photoUrl);
        }

        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .update({
          'displayName': displayName,
          if (photoUrl != null) 'photoUrl': photoUrl,
        });

        notifyListeners();
      }
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // Existing addToFavorites method
  Future<void> addToFavorites(String recipeId) async {
    try {
      if (_auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .update({
          'favorites': FieldValue.arrayUnion([recipeId]),
        });
        notifyListeners();
      }
    } catch (e) {
      print('Error adding to favorites: $e');
      rethrow;
    }
  }

  // Existing removeFromFavorites method
  Future<void> removeFromFavorites(String recipeId) async {
    try {
      if (_auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .update({
          'favorites': FieldValue.arrayRemove([recipeId]),
        });
        notifyListeners();
      }
    } catch (e) {
      print('Error removing from favorites: $e');
      rethrow;
    }
  }

  // Existing addToMyRecipes method
  Future<void> addToMyRecipes(String recipeId) async {
    try {
      if (_auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .update({
          'myRecipes': FieldValue.arrayUnion([recipeId]),
        });
        notifyListeners();
      }
    } catch (e) {
      print('Error adding to my recipes: $e');
      rethrow;
    }
  }

  Future<UserModel?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;

      if (user != null) {
        final userData = {
          'uid': user.uid,
          'email': '',
          'displayName': 'Guest User',
          'photoUrl': null,
          'favorites': [],
          'myRecipes': [],
          'createdAt': DateTime.now().toIso8601String(),
          'isAnonymous': true,
        };

        await _firestore.collection('users').doc(user.uid).set(userData);
        return UserModel.fromJson(userData);
      }
      return null;
    } catch (e) {
      print('Error signing in anonymously: $e');
      rethrow;
    }
  }

  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();
        if (userDoc.exists) {
          return UserModel.fromJson(_convertFirestoreDoc(userDoc));
        }
      }
      return null;
    } catch (e) {
      print('Error signing in with email: $e');
      rethrow;
    }
  }

  Future<UserModel?> registerWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(displayName);
        return await _handleUserAuthSuccess(
          userCredential.user,
          displayName: displayName,
        );
      }
      return null;
    } catch (e) {
      print('Error in registerWithEmail: $e');
      rethrow;
    }
  }

  Future<UserModel?> _handleUserAuthSuccess(
    User? user, {
    String? displayName,
  }) async {
    if (user == null) return null;

    try {
      final userData = _createBasicUserData(
        uid: user.uid,
        email: user.email,
        displayName: displayName ?? user.displayName,
        photoUrl: user.photoURL,
        isAnonymous: user.isAnonymous,
      );

      await _firestore.collection('users').doc(user.uid).set(userData);
      return _safeConvertToUserModel(userData);
    } catch (e) {
      print('Error in _handleUserAuthSuccess: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _createBasicUserData({
    required String uid,
    String? email,
    String? displayName,
    String? photoUrl,
    bool isAnonymous = false,
  }) {
    return {
      'uid': uid,
      'email': email ?? '',
      'displayName': displayName ?? (isAnonymous ? 'Guest User' : 'New User'),
      'photoUrl': photoUrl,
      'favorites': FieldValue.arrayUnion([]),
      'myRecipes': FieldValue.arrayUnion([]),
      'createdAt': FieldValue.serverTimestamp(),
      'isAnonymous': isAnonymous,
    };
  }

  UserModel? _safeConvertToUserModel(Map<String, dynamic> data) {
    try {
      // Ensure all list fields are properly initialized
      final safeData = Map<String, dynamic>.from(data)
        ..['favorites'] = List<String>.from(data['favorites'] ?? [])
        ..['myRecipes'] = List<String>.from(data['myRecipes'] ?? []);

      return UserModel.fromJson(safeData);
    } catch (e) {
      print('Error converting to UserModel: $e');
      return null;
    }
  }

  Future<UserModel?> getCurrentUserData() async {
    if (_auth.currentUser == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();
      if (doc.exists) {
        return _safeConvertToUserModel(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error in getCurrentUserData: $e');
      return null;
    }
  }

  Map<String, dynamic> _convertFirestoreDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    // Convert any FieldValue objects to their actual values
    return {
      'uid': data['uid'] ?? doc.id,
      'email': data['email'] ?? '',
      'displayName': data['displayName'] ?? 'User',
      'photoUrl': data['photoUrl'],
      'favorites': _convertFieldValueToList(data['favorites']),
      'myRecipes': _convertFieldValueToList(data['myRecipes']),
      'createdAt': data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate().toIso8601String()
          : data['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      'isAnonymous': data['isAnonymous'] ?? false,
    };
  }

  List<String> _convertFieldValueToList(dynamic value) {
    if (value == null) return [];
    if (value is List) return List<String>.from(value);
    if (value is FieldValue)
      return []; // FieldValue can't be converted directly
    return [];
  }
}
