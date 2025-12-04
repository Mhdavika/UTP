import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'chat_room_page.dart';
import 'package:utp_flutter/app_session.dart';

class PesanPage extends StatelessWidget {
  const PesanPage({super.key});

  // (list dummy lama tidak dipakai lagi)

  @override
  Widget build(BuildContext context) {
    final userId = AppSession.userDocId;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // FILTER BUTTON (UI saja)
              Row(
                children: [
                  _filterButton("Semua", selected: true),
                  const SizedBox(width: 8),
                  _filterButton("Belum dibaca"),
                  const SizedBox(width: 8),
                  _filterButton("Selesai"),
                ],
              ),

              const SizedBox(height: 25),

              Expanded(
                child: userId == null
                    ? const Center(
                        child: Text('Silakan login untuk melihat pesan'),
                      )
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('chats')
                            .where('user_id', isEqualTo: userId)
                            .orderBy('last_timestamp', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Terjadi kesalahan: ${snapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Center(
                              child: Text('Belum ada percakapan'),
                            );
                          }

                          final chatDocs = snapshot.data!.docs;

                          return ListView.builder(
                            itemCount: chatDocs.length,
                            itemBuilder: (context, index) {
                              final chatDoc = chatDocs[index];
                              final data = chatDoc.data();

                              final String villaId =
                                  (data['villa_id'] ?? '').toString();
                              final String ownerId =
                                  (data['owner_id'] ?? '').toString();
                              final String lastMessage =
                                  (data['last_message'] ?? '').toString();

                              // Ambil nama villa dari koleksi "villas"
                              return FutureBuilder<
                                  DocumentSnapshot<Map<String, dynamic>>>(
                                future: FirebaseFirestore.instance
                                    .collection('villas')
                                    .doc(villaId)
                                    .get(),
                                builder: (context, villaSnap) {
                                  String name = 'Chat Villa';
                                  if (villaSnap.hasData &&
                                      villaSnap.data!.exists) {
                                    final villa = villaSnap.data!.data()!;
                                    name = (villa['name'] ?? 'Chat Villa')
                                        .toString();
                                  }

                                  final message = lastMessage.isEmpty
                                      ? 'Tap untuk membuka chat'
                                      : lastMessage;

                                  // unread belum kita hitung, jadi 0 dulu
                                  return _chatTile(
                                    context,
                                    name,
                                    message,
                                    0,
                                    villaId,
                                    ownerId,
                                    userId,
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

  // ==== UI item chat ====
  Widget _chatTile(
    BuildContext context,
    String name,
    String message,
    int unread,
    String villaId,
    String ownerId,
    String userId,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomPage(
              key: ValueKey('$userId-$villaId-$ownerId'),
              villaId: villaId,
              ownerId: ownerId,
              userId: userId,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'C',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.black54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            if (unread > 0)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unread.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==== UI filter button (dummy) ====
  Widget _filterButton(String text, {bool selected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? Colors.black : Colors.grey[300],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}
