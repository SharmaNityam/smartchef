import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class StorageService extends ChangeNotifier {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Upload recipe image
  Future<String?> uploadRecipeImage(File imageFile) async {
    try {
      if (_auth.currentUser == null) return null;

      final String fileName =
          '${const Uuid().v4()}${path.extension(imageFile.path)}';
      final Reference ref =
          _storage.ref().child('recipes/${_auth.currentUser!.uid}/$fileName');

      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;

      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading recipe image: $e');
      return null;
    }
  }

  // Upload profile image
  Future<String?> uploadProfileImage(File imageFile) async {
    try {
      if (_auth.currentUser == null) return null;

      final String fileName = 'profile${path.extension(imageFile.path)}';
      final Reference ref =
          _storage.ref().child('profiles/${_auth.currentUser!.uid}/$fileName');

      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;

      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }

  // Delete recipe image
  Future<bool> deleteRecipeImage(String imageUrl) async {
    try {
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      return true;
    } catch (e) {
      print('Error deleting recipe image: $e');
      return false;
    }
  }
}
