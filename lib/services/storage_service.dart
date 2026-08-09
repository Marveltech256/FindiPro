import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

/// A service dedicated to handling file uploads and compression with Firebase Storage.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Compresses the given image file to reduce its size before uploading.
  Future<File> compressImage(File file) async {
    // Temporary safe implementation
    return file;
  }

  /// Uploads a file to the specified path in Firebase Storage and returns the download URL.
  Future<String> uploadFile(String path, File file) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw Exception('Error uploading file: ${e.message}');
    }
  }
}