import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:utp_flutter/app_session.dart';
import 'package:utp_flutter/main.dart';
import 'package:utp_flutter/pages/register_page.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailOrPhoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  Future<void> _login() async {
    final input = emailOrPhoneController.text.trim();
    final password = passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = "Email/nomor dan password wajib diisi";
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      QuerySnapshot<Map<String, dynamic>> snap;

      // Jika mengandung "@", berarti login pakai email
      if (input.contains("@")) {
        snap = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: input)
            .limit(1)
            .get();
      } else {
        // Login menggunakan nomor telepon
        String phone = input;
        if (phone.startsWith("0")) phone = phone.substring(1);

        snap = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get();
      }

      if (snap.docs.isEmpty) {
        setState(() {
          errorMessage = "Akun tidak ditemukan";
        });
      } else {
        final doc = snap.docs.first;
        final data = doc.data();

        final String passwordDb = (data['password'] ?? '').toString();

        // cek password
        if (passwordDb == password) {
          // ambil phone dari database
          final String phoneFromDb = (data['phone'] ?? '').toString();

          // simpan session (AppSession-mu yang lama, TANPA diubah)
          final ok = await AppSession.saveUser(phoneFromDb);

          if (!ok) {
            setState(() {
              errorMessage = "Gagal menyimpan sesi pengguna";
            });
          } else {
            if (!mounted) return;

            // Masuk ke halaman utama (dengan Navigasi Bottom)
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainPage()),
            );
          }
        } else {
          setState(() {
            errorMessage = "Password salah";
          });
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = "Terjadi kesalahan: $e";
      });
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        // agar tidak overflow di layar kecil
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              const Text(
                "Masuk ke Akun Anda",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 30),

              // Email / Phone
              TextField(
                controller: emailOrPhoneController,
                decoration: const InputDecoration(
                  labelText: "Email atau Nomor Telepon",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              // Password
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              if (errorMessage != null)
                Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),

              const SizedBox(height: 20),

              // Tombol Login
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: isLoading ? null : _login,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Login", style: TextStyle(fontSize: 16)),
                ),
              ),

              const SizedBox(height: 18),

              // Tombol ke Register
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Belum punya akun? "),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterPage(),
                        ),
                      );
                    },
                    child: const Text("Daftar"),
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
