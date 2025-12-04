import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomPage extends StatefulWidget {
  final String villaId;
  final String ownerId;
  final String userId;

  const ChatRoomPage({
    super.key,
    required this.villaId,
    required this.ownerId,
    required this.userId,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController messageController = TextEditingController();

  DocumentReference<Map<String, dynamic>>? _chatDoc;
  CollectionReference<Map<String, dynamic>>? _messagesRef;

  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _loadOrCreateChat();
  }

  /// Cari chat yang sudah pernah ada, kalau belum ada buat baru.
  Future<void> _loadOrCreateChat() async {
    try {
      // 1. CARI CHAT LAMA
      final q = await FirebaseFirestore.instance
          .collection('chats')
          .where('user_id', isEqualTo: widget.userId)
          .where('owner_id', isEqualTo: widget.ownerId)
          .where('villa_id', isEqualTo: widget.villaId)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        // Pakai chat yang sudah ada → riwayat pesan langsung terbaca
        _chatDoc = q.docs.first.reference;
      } else {
        // 2. BELUM ADA CHAT → BUAT BARU DENGAN ID GABUNGAN
        final String newChatId =
            '${widget.userId}_${widget.ownerId}_${widget.villaId}';

        _chatDoc =
            FirebaseFirestore.instance.collection('chats').doc(newChatId);

        await _chatDoc!.set({
          'villa_id': widget.villaId,
          'owner_id': widget.ownerId,
          'user_id': widget.userId,
          'last_message': '',
          'last_timestamp': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      _messagesRef = _chatDoc!.collection('messages');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal inisialisasi chat: $e')),
      );
    }

    if (!mounted) return;
    setState(() {
      _initializing = false;
    });
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing || _messagesRef == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Chat Pemilik"),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat Pemilik"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // LIST CHAT
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messagesRef!
                  .orderBy("timestamp", descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Terjadi kesalahan: ${snapshot.error}",
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Belum ada chat"));
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i].data();
                    final String text = (msg['text'] ?? '').toString();
                    final String senderId =
                        (msg['sender_id'] ?? '').toString();

                    final bool isMe = senderId == widget.userId;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 12),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.black : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // INPUT AREA
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.black12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        hintText: "Tulis pesan...",
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: sendMessage,
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> sendMessage() async {
    final msgText = messageController.text.trim();
    if (msgText.isEmpty) return;

    messageController.clear();

    if (_chatDoc == null || _messagesRef == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat belum siap, coba lagi.')),
      );
      return;
    }

    final msg = <String, dynamic>{
      'sender_id': widget.userId,
      'text': msgText,
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      // SIMPAN PESAN
      await _messagesRef!.add(msg);

      // UPDATE DOKUMEN CHAT UTAMA
      await _chatDoc!.set({
        'villa_id': widget.villaId,
        'owner_id': widget.ownerId,
        'user_id': widget.userId,
        'last_message': msgText,
        'last_timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal mengirim pesan: $e")),
      );
    }
  }
}
