import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<File?> _compressImage(File file) async {
    final XFile? result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      '${file.path}_compressed.jpg',
      quality: 70,
    );

    if (result == null) return null;

    return File(result.path);
  }

  Future<String> uploadImage({
    required File file,
    required String path,
  }) async {
    File? compressedFile = await _compressImage(file);
    if (compressedFile == null) {
      throw Exception('Image compression failed.');
    }

    final ref = _storage.ref(path);
    await ref.putFile(compressedFile);
    final downloadUrl = await ref.getDownloadURL();
    return downloadUrl;
  }

  Future<void> deleteImage(String imageUrl) async {
    if (imageUrl.isEmpty || !imageUrl.contains('firebasestorage')) return;
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        print('Failed to delete image: ${e.message}');
      }
    }
  }
}