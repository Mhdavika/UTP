import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class AdminOwnerItem {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;

  AdminOwnerItem({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
  });
}

class AdminDataOwnerViewModel extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final RxBool isLoading = false.obs;
  final RxList<AdminOwnerItem> owners = <AdminOwnerItem>[].obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadOwners(); // Memanggil loadOwners() saat inisialisasi
  }

  // -------------------------
  // LOAD OWNER LIST
  // -------------------------
  Future<void> loadOwners() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final snapshot = await _db.collection('users').where('role', isEqualTo: 'owner').get();
      print('ADMIN DATA OWNER → jumlah dokumen: ${snapshot.docs.length}');

      final List<AdminOwnerItem> items = [];

      for (final doc in snapshot.docs) {
        items.add(await _mapOwnerDoc(doc));
      }

      owners.assignAll(items);  // Memperbarui daftar owner
    } catch (e, st) {
      print('ERROR loadOwners: $e\n$st');
      errorMessage.value = e.toString();
      owners.clear();
    } finally {
      isLoading.value = false;
    }
  }

  // -------------------------
  // MAP DOCUMENT OWNER
  // -------------------------
  Future<AdminOwnerItem> _mapOwnerDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();

    final String name = (data['name'] ?? '') as String;
    final String email = (data['email'] ?? '') as String;
    final String phone = (data['phone'] ?? '') as String;
    final String role = (data['role'] ?? '') as String;

    return AdminOwnerItem(
      id: doc.id,
      name: name,
      email: email,
      phone: phone,
      role: role,
    );
  }

  // -------------------------
  // CREATE NEW OWNER
  // -------------------------
  Future<void> createOwner(String name, String email, String phone) async {
    try {
      await _db.collection('users').add({
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'owner',  // Role owner secara default
      });
    } catch (e) {
      print('Error creating owner: $e');
    }
  }

  // -------------------------
  // UPDATE OWNER
  // -------------------------
  Future<void> updateOwner(String ownerId, String name, String email, String phone) async {
    try {
      await _db.collection('users').doc(ownerId).update({
        'name': name,
        'email': email,
        'phone': phone,
      });
    } catch (e) {
      print('Error updating owner: $e');
    }
  }

  // -------------------------
  // DELETE OWNER
  // -------------------------
  Future<void> deleteOwner(String ownerId) async {
    try {
      await _db.collection('users').doc(ownerId).delete();
    } catch (e) {
      print('Error deleting owner: $e');
    }
  }
}
