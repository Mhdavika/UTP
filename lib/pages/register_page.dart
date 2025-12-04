import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:utp_flutter/app_session.dart';
import 'package:utp_flutter/main.dart'; // untuk MainPage

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  Future<void> _register() async {
    String name = nameController.text.trim();
    String phone = phoneController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (name.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = "Semua field wajib diisi.";
      });
      return;
    }

    // Normalisasi nomor: hapus 0 depan (08123 → 8123)
    if (phone.startsWith("0")) {
      phone = phone.substring(1);
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final usersRef = FirebaseFirestore.instance.collection('users');

      // cek email sudah dipakai atau belum
      final emailSnap = await usersRef
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (emailSnap.docs.isNotEmpty) {
        setState(() {
          errorMessage = "Email sudah terdaftar.";
          isLoading = false;
        });
        return;
      }

      // cek nomor HP sudah dipakai atau belum
      final phoneSnap = await usersRef
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (phoneSnap.docs.isNotEmpty) {
        setState(() {
          errorMessage = "Nomor telepon sudah terdaftar.";
          isLoading = false;
        });
        return;
      }

      // SIMPAN USER BARU (HARUS SESUAI DENGAN RULES)
      await usersRef.add({
        'name': name,
        'phone': phone,
        'email': email,
        'password': password, // saran: nanti pakai hash
        'role': 'user', // ⬅ SELALU USER
        'profile_img': '', // bisa diisi URL nanti
        'created_at': FieldValue.serverTimestamp(),
      });

      // AUTO-LOGIN: simpan session berdasarkan phone
      await AppSession.saveUser(phone);

      if (!mounted) return;

      // Masuk ke MainPage (yang punya bottom navigation)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainPage()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        errorMessage = "Terjadi kesalahan: $e";
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Daftar Akun")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Nama lengkap",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Nomor Telepon",
                hintText: "Contoh: 0812345678",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (errorMessage != null)
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _register,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Daftar"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
