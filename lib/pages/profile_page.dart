import 'package:flutter/material.dart';
import 'package:utp_flutter/app_session.dart';

import 'edit_profile_page.dart';
import 'login_page.dart';
import 'my_bookings_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  bool get isLoggedIn => AppSession.phone != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Profil",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoggedIn ? _buildLoggedInUI(context) : _buildLoggedOutUI(context),
    );
  }

  // ===============================
  //  UI Jika BELUM LOGIN
  // ===============================
  Widget _buildLoggedOutUI(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => LoginPage()),
          );
        },
        child: const Text("Masuk / Daftar"),
      ),
    );
  }

  // ===============================
  //  UI Jika SUDAH LOGIN
  // ===============================
  Widget _buildLoggedInUI(BuildContext context) {
    final String name = AppSession.name ?? "Pengguna";
    final String email = AppSession.email ?? "-";
    final String? profileImg = AppSession.profileImg; // FOTO PROFIL

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        /// Foto Profil + Nama + Email
        Center(
          child: Column(
            children: [
              // FOTO PROFIL DARI SUPABASE
              CircleAvatar(
                radius: 55,
                backgroundColor: Colors.grey[300],
                backgroundImage: (profileImg != null && profileImg.isNotEmpty)
                    ? NetworkImage(profileImg)
                    : null,
                child: (profileImg == null || profileImg.isEmpty)
                    ? Icon(Icons.person, size: 50, color: Colors.grey[600])
                    : null,
              ),

              const SizedBox(height: 12),

              // NAMA
              Text(
                name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 4),

              // EMAIL
              Text(
                email,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        /// MENU-MENU
        _menuItem(
          Icons.shopping_bag_outlined,
          "Pesanan Saya",
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyBookingsPage()),
            );
          },
        ),

        _menuItem(Icons.favorite_border, "Favorit", () {}),
        _menuItem(Icons.settings_outlined, "Pengaturan", () {}),

        _menuItem(
          Icons.person_outline,
          "Lihat / Edit Profil",
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfilePage()),
            ).then((_) {
              // setelah kembali dari edit, refresh tampilan
              (context as Element).reassemble();
            });
          },
        ),

        _menuItem(Icons.help_outline, "Bantuan", () {}),

        const SizedBox(height: 30),

        /// LOGOUT
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[800],
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () async {
            await AppSession.clear();

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => LoginPage()),
            );
          },
          child: const Text(
            "Logout",
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ],
    );
  }

  // Widget menu DENGAN onTap
  Widget _menuItem(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, size: 28),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        trailing: const Icon(Icons.chevron_right),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: Colors.grey[200],
      ),
    );
  }
}
