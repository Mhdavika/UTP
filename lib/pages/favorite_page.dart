import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:utp_flutter/app_session.dart';

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritPageState();
}

class _FavoritPageState extends State<FavoritePage> {
  bool isEditMode = false;

  /// Referensi ke subcollection favorites: users/{userDocId}/favorites
  CollectionReference<Map<String, dynamic>> _favoritesRef() {
    final userId = AppSession.userDocId;
    if (userId == null) {
      throw Exception('User belum login / session belum dimuat');
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('favorites');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// HEADER + BUTTON EDIT
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Favorit",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  // Tombol Edit / Selesai
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        isEditMode = !isEditMode;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isEditMode ? "Selesai" : "Edit",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// LIST / GRID FAVORIT DARI FIRESTORE
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _favoritesRef()
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Terjadi kesalahan: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('Belum ada villa favorit'),
                      );
                    }

                    final favDocs = snapshot.data!.docs;

                    return GridView.builder(
                      itemCount: favDocs.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.8,
                      ),
                      itemBuilder: (context, index) {
                        final favDoc = favDocs[index];
                        final favData = favDoc.data();

                        // Ambil villaId dari field, kalau kosong pakai docId
                        final villaId =
                            (favData['villaId'] ?? favDoc.id).toString();

                        // Ambil data villa dari koleksi "villas"
                        return FutureBuilder<
                            DocumentSnapshot<Map<String, dynamic>>>(
                          future: FirebaseFirestore.instance
                              .collection('villas')
                              .doc(villaId)
                              .get(),
                          builder: (context, villaSnap) {
                            String villaName = 'Villa tidak ditemukan';
                            String villaLocation = '';

                            if (villaSnap.hasData && villaSnap.data!.exists) {
                              final villaData = villaSnap.data!.data()!;
                              villaName =
                                  (villaData['name'] ?? 'Tanpa Nama').toString();
                              villaLocation =
                                  (villaData['location'] ?? '-').toString();
                            }

                            return Stack(
                              children: [
                                /// CARD
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Expanded(
                                        child: Center(
                                          child: Icon(Icons.home, size: 40),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        villaName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        villaLocation,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),

                                /// TAP UNTUK DETAIL (opsional)
                                Positioned.fill(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        // TODO: Navigasi ke DetailPage kalau mau
                                      },
                                    ),
                                  ),
                                ),

                                /// ICON DELETE (X) PALING ATAS
                                if (isEditMode)
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: () {
                                        // Jangan pakai await + ScaffoldMessenger langsung
                                        favDoc.reference
                                            .delete()
                                            .catchError((e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Gagal menghapus favorit: $e'),
                                            ),
                                          );
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child:
                                            const Icon(Icons.close, size: 16),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
