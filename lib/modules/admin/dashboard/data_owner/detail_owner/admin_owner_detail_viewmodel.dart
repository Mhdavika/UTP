import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class AdminVillaItem {
  final String id;
  final String name;
  final String address;
  final double price;
  final String ownerId;

  AdminVillaItem({
    required this.id,
    required this.name,
    required this.address,
    required this.price,
    required this.ownerId,
  });
}

class AdminOwnerDetailViewModel extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final RxBool isLoading = false.obs;
  final RxList<AdminVillaItem> villas = <AdminVillaItem>[].obs;
  final RxString errorMessage = ''.obs;
  
  late AdminOwnerItem owner;  // Instance for the selected owner

  // Load owner data by ID
  Future<void> loadOwnerAndVillas(String ownerId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Fetch owner data based on ownerId
      final ownerDoc = await _db.collection('users').doc(ownerId).get();
      if (ownerDoc.exists) {
        final ownerData = ownerDoc.data()!;
        owner = AdminOwnerItem(
          id: ownerDoc.id,
          name: ownerData['name'],
          email: ownerData['email'],
          phone: ownerData['phone'],
          role: ownerData['role'],
        );
      }

      // Fetch villas owned by the owner
      final snapshot = await _db.collection('villas').where('owner_id', isEqualTo: ownerId).get();
      final List<AdminVillaItem> items = [];

      for (final doc in snapshot.docs) {
        items.add(await _mapVillaDoc(doc));
      }

      villas.assignAll(items);  // Assign villas to observable list
    } catch (e, st) {
      print('ERROR loading owner and villas: $e\n$st');
      errorMessage.value = e.toString();
      villas.clear();
    } finally {
      isLoading.value = false;
    }
  }

  // Map document to AdminVillaItem
  Future<AdminVillaItem> _mapVillaDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();

    return AdminVillaItem(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      price: data['price']?.toDouble() ?? 0.0,
      ownerId: data['owner_id'] ?? '',
    );
  }
}

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
