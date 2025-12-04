import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utp_flutter/app_session.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController nameController = TextEditingController(
    text: AppSession.name ?? "",
  );
  final TextEditingController emailController = TextEditingController(
    text: AppSession.email ?? "",
  );
  final TextEditingController passwordController = TextEditingController(
    text: "",
  );

  bool isLoading = false;
  Uint8List? _imageBytes; // gambar baru yang dipilih

  // ==========================
  // PILIH GAMBAR DARI GALERI
  // ==========================
  Future<void> pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memilih gambar: $e')));
    }
  }

  // ==========================
  // UPLOAD FOTO KE SUPABASE
  // ==========================
  Future<String?> uploadImage(String userId) async {
    if (_imageBytes == null) return null;

    try {
      final client = Supabase.instance.client;

      // path file di bucket "profile"
      final String path = 'profile_images/$userId.jpg';

      final String resultPath = await client.storage
          .from('profile')
          .uploadBinary(
            path,
            _imageBytes!,
            fileOptions: const FileOptions(
              upsert: true, // timpa file lama kalau ada
              contentType: 'image/jpeg',
            ),
          );

      debugPrint('Supabase upload result path: $resultPath');

      // ambil URL publik
      final String publicUrl = client.storage
          .from('profile')
          .getPublicUrl(path);

      debugPrint('Supabase public URL: $publicUrl');

      return publicUrl;
    } catch (e) {
      debugPrint('Upload profile error: $e');
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal upload foto: $e')));
      return null;
    }
  }

  // ==========================
  // SIMPAN PROFIL
  // ==========================
  Future<void> saveProfile() async {
    setState(() => isLoading = true);

    try {
      final userId = AppSession.userDocId;
      if (userId == null) {
        throw "Session user tidak ditemukan. Silakan login ulang.";
      }

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);

      final updatedName = nameController.text.trim();
      final updatedEmail = emailController.text.trim();
      final updatedPassword = passwordController.text.trim();

      // Upload foto ke Supabase kalau ada
      final profileUrl = await uploadImage(userId);

      final Map<String, dynamic> updateData = {
        'name': updatedName,
        'email': updatedEmail,
      };

      if (updatedPassword.isNotEmpty) {
        updateData['password'] = updatedPassword;
      }

      if (profileUrl != null) {
        updateData['profile_img'] = profileUrl;
      }

      debugPrint('Update Firestore users/$userId with: $updateData');

      await userRef.update(updateData);

      // update session lokal
      AppSession.name = updatedName;
      AppSession.email = updatedEmail;
      if (profileUrl != null) {
        AppSession.profileImg = profileUrl;
      }

      if (!mounted) return;

      setState(() => isLoading = false);

      // balik ke halaman profil
      Navigator.pop(context);

      // info sukses
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui')),
      );
    } catch (e) {
      debugPrint('Save profile error: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan profil: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatarImage;

    if (_imageBytes != null) {
      // preview foto baru
      avatarImage = MemoryImage(_imageBytes!);
    } else if (AppSession.profileImg != null &&
        AppSession.profileImg!.isNotEmpty) {
      // foto lama dari URL Supabase (tersimpan di Firestore)
      avatarImage = NetworkImage(AppSession.profileImg!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profil"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // FOTO PROFIL
            Center(
              child: GestureDetector(
                onTap: pickImage,
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? const Icon(Icons.camera_alt, size: 40)
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 25),

            // NAMA
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Nama",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // EMAIL
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // PASSWORD BARU (OPSIONAL)
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password Baru (opsional)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            // TOMBOL SIMPAN
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Simpan",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
