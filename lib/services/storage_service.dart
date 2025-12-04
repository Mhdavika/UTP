import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class StorageService {
  static final _client = SupaBaseClient.client;
  static const bucket = 'profile'; // kamu sudah punya folder "profile"

  /// Upload image to Supabase Storage
  static Future<String?> uploadProfileImage(String userId, File file) async {
    try {
      final filePath = "user_$userId.jpg";

      await _client.storage.from(bucket).upload(
        filePath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      // Get public URL
      final url = _client.storage.from(bucket).getPublicUrl(filePath);
      return url;
    } catch (e) {
      print("Upload error: $e");
      return null;
    }
  }
}
