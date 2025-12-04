// lib/pages/chatbot_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final List<_Message> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages.add(
      const _Message(
        fromBot: true,
        text:
            'Halo! Aku Chatbot Villa.\nSilakan pilih salah satu pertanyaan di bawah, nanti aku jawab 😊',
      ),
    );
  }

  void _sendQuestion(String question, String answer) {
    setState(() {
      _messages.add(_Message(fromBot: false, text: question));
      _messages.add(_Message(fromBot: true, text: answer));
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatRef = FirebaseFirestore.instance
        // PASTIKAN nama koleksi persis seperti ini
        .collection('chatbot')
        // order optional, tapi enak kalau tiap dokumen punya field "order" (Number)
        .orderBy('order', descending: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatbot'),
      ),
      body: Column(
        children: [
          // area chat
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final align =
                      msg.fromBot ? Alignment.centerLeft : Alignment.centerRight;
                  final bg = msg.fromBot ? Colors.white : Colors.black;
                  final color = msg.fromBot ? Colors.black : Colors.white;

                  return Align(
                    alignment: align,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        msg.text,
                        style: TextStyle(color: color, fontSize: 14),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const Divider(height: 1),

          // daftar pertanyaan di bawah
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pertanyaan yang bisa dipilih:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: chatRef.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 36,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return const Text(
                        'Belum ada daftar pertanyaan.\nIsi koleksi "chatbot" di Firestore.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      );
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final question =
                              (data['question'] ?? '').toString().trim();
                          final answer =
                              (data['answer'] ?? '').toString().trim();

                          if (question.isEmpty || answer.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.black),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: () => _sendQuestion(question, answer),
                              child: Text(
                                question,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final bool fromBot;
  final String text;

  const _Message({
    required this.fromBot,
    required this.text,
  });
}
