// lib/services/user_collections.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:utp_flutter/app_session.dart';

class UserCollections {
  /// Ambil ID user yang lagi login dari AppSession
  static String get _uid {
    final uid = AppSession.userDocId;
    if (uid == null) {
      throw Exception('User belum login atau session belum dimuat');
    }
    return uid;
  }

  /// users/{userDocId}/favorites
  static CollectionReference<Map<String, dynamic>> favorites() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('favorites');
  }

  /// ============================================================
  /// =============== 3. FUNGSI FAVORIT (PENTING) ================
  /// ============================================================

  /// CEK apakah villa sudah jadi favorit user
  /// Stream<bool> yang akan otomatis update saat data berubah
  static Stream<bool> isFavoriteStream(String villaId) {
    return favorites()
        .doc(villaId) // docId = villaId
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  /// TAMBAH atau HAPUS favorit
  static Future<void> toggleFavorite(String villaId) async {
    final docRef = favorites().doc(villaId);

    final snapshot = await docRef.get();

    if (snapshot.exists) {
      // Jika sudah favorit → hapus
      await docRef.delete();
    } else {
      // Jika belum → tambahkan
      await docRef.set({
        'villaId': villaId, // simpan id villa
        'createdAt': FieldValue.serverTimestamp(), // buat sorting
      });
    }
  }
}
