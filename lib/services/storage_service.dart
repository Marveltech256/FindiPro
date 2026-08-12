import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<File> prepareImage(File file) async {
    final bytes = await file.length();
    if (bytes <= 2 * 1024 * 1024) return file;

    final dir = await getTemporaryDirectory();
    final target = p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      target,
      quality: 82,
      minWidth: 1600,
      minHeight: 1600,
      format: CompressFormat.jpeg,
    );
    if (result == null) throw Exception('Unable to compress image.');
    return File(result.path);
  }

  Future<String> uploadImage({required File file, required String path}) async {
    final prepared = await prepareImage(file);
    final ref = _storage.ref().child(path);
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    await ref.putFile(prepared, metadata);
    return ref.getDownloadURL();
  }

  Future<void> deleteImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return;
    try {
      await _storage.refFromURL(imageUrl).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}
