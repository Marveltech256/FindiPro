import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';

class StorageService {
  SupabaseClient get _supabase => SupabaseConfig.client;

  /// Compresses the image if necessary with a fallback to the original file.
  Future<File> prepareImage(File file) async {
    try {
      final bytes = await file.length();
      if (bytes <= 1.5 * 1024 * 1024) return file;

      final dir = await getTemporaryDirectory();
      final target = p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        target,
        quality: 85,
        minWidth: 1600,
        minHeight: 1600,
        format: CompressFormat.jpeg,
      );
      if (result != null) {
        return File(result.path);
      }
    } catch (e) {
      debugPrint('>>> [StorageService.prepareImage] Compression note (using original file): $e');
    }
    return file;
  }

  /// Reusable upload function for avatars.
  /// Uploads to Supabase Storage bucket "avatars" with a unique timestamped path:
  /// {firebaseUid}/profile_{timestamp}.jpg
  Future<String> uploadAvatar({
    required String uid,
    required File file,
    String bucket = 'avatars',
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = p.extension(file.path).replaceAll('.', '').toLowerCase();
    final fileExt = (ext.isEmpty || ext == 'jpg' || ext == 'jpeg') ? 'jpg' : ext;
    final filePath = '$uid/profile_$timestamp.$fileExt';

    return uploadImage(file: file, path: filePath, bucket: bucket, uid: uid);
  }

  /// Uploads a profile image specifically for an authenticated user to Supabase Storage.
  Future<String> uploadProfileImage({
    required String uid,
    required File file,
    String folder = '',
    String bucket = 'avatars',
  }) async {
    return uploadAvatar(uid: uid, file: file, bucket: bucket);
  }

  /// Uploads any image file to Supabase Storage using uploadBinary and returns the public URL.
  Future<String> uploadImage({
    required File file,
    required String path,
    String bucket = 'avatars',
    String? uid,
  }) async {
    final prepared = await prepareImage(file);
    final fileBytes = await prepared.readAsBytes();
    return uploadBytes(
      bytes: fileBytes,
      path: path,
      bucket: bucket,
      uid: uid,
    );
  }

  /// Uploads raw bytes to Supabase Storage using uploadBinary and returns the public URL.
  Future<String> uploadBytes({
    required Uint8List bytes,
    required String path,
    String bucket = 'avatars',
    String? uid,
  }) async {
    final sanitizedPath = path.startsWith('/') ? path.substring(1) : path;
    final ext = p.extension(sanitizedPath).toLowerCase();
    final contentType = ext == '.png' ? 'image/png' : 'image/jpeg';

    debugPrint('========== AVATAR UPLOAD ==========');
    debugPrint('Avatar path: $sanitizedPath');
    debugPrint('Firebase UID: ${uid ?? "N/A"}');
    debugPrint('Supabase authenticated user: ${_supabase.auth.currentUser?.id}');
    debugPrint('Bucket: $bucket');
    debugPrint('File size: ${bytes.length} bytes');
    debugPrint('Content Type: $contentType');
    debugPrint('====================================');

    try {
      // Use uploadBinary for robust file handling in Flutter with upsert: true
      await _supabase.storage
          .from(bucket)
          .uploadBinary(
            sanitizedPath,
            bytes,
            fileOptions: FileOptions(
              upsert: true, // Crucial to prevent collision/permission errors on overwrite
              contentType: contentType,
            ),
          );

      // Get the public URL safely after upload
      final publicUrl = _supabase.storage
          .from(bucket)
          .getPublicUrl(sanitizedPath);

      debugPrint('========== AVATAR UPLOAD SUCCESS ==========');
      debugPrint('Generated Public URL: $publicUrl');
      debugPrint('===========================================');
      return publicUrl;
    } on StorageException catch (e) {
      debugPrint('========== AVATAR UPLOAD ERROR ==========');
      debugPrint('Error: $e');
      debugPrint('Runtime type: ${e.runtimeType}');
      debugPrint('Message: ${e.message}');
      debugPrint('Status Code: ${e.statusCode}');
      debugPrint('Error: ${e.error}');
      debugPrint('=========================================');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('========== AVATAR UPLOAD ERROR ==========');
      debugPrint('Error: $e');
      debugPrint('Runtime type: ${e.runtimeType}');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('=========================================');
      rethrow;
    }
  }

  /// Generates a signed URL for private objects.
  Future<String> getSignedUrl(String path, {String bucket = 'avatars', int expiresIn = 3600}) async {
    final sanitizedPath = path.startsWith('/') ? path.substring(1) : path;
    return _supabase.storage.from(bucket).createSignedUrl(sanitizedPath, expiresIn);
  }

  /// Gets a public URL for an object.
  String getPublicUrl(String path, {String bucket = 'avatars'}) {
    final sanitizedPath = path.startsWith('/') ? path.substring(1) : path;
    return _supabase.storage.from(bucket).getPublicUrl(sanitizedPath);
  }

  /// Deletes an image from Supabase Storage.
  Future<void> deleteImage(String? imageUrlOrPath, {String bucket = 'avatars'}) async {
    if (imageUrlOrPath == null || imageUrlOrPath.isEmpty) return;

    try {
      String objectPath = imageUrlOrPath;
      if (imageUrlOrPath.contains('supabase.co/storage')) {
        final uri = Uri.parse(imageUrlOrPath);
        final segments = uri.pathSegments;
        final publicIndex = segments.indexOf('public');
        if (publicIndex != -1 && publicIndex + 2 < segments.length) {
          final bucketName = segments[publicIndex + 1];
          objectPath = segments.sublist(publicIndex + 2).join('/');
          await _supabase.storage.from(bucketName).remove([objectPath]);
          return;
        }
      }
      await _supabase.storage.from(bucket).remove([objectPath]);
    } catch (e) {
      debugPrint('Supabase Storage delete error: $e');
    }
  }
}
