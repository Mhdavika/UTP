import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:utp_flutter/modules/admin/dashboard/data_owner/detail_owner/admin_owner_detail_viewmodel.dart';

class AdminOwnerDetailView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Ambil ownerId dari parameter
    final String ownerId = Get.arguments;

    // Ambil ViewModel
    final controller = Get.find<AdminOwnerDetailViewModel>();

    // Memanggil fungsi loadOwnerAndVillas untuk mengambil data owner dan villa
    controller.loadOwnerAndVillas(ownerId);

    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Owner - ${controller.owner.name}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Owner
            Text(
              controller.owner.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(controller.owner.email),
            const SizedBox(height: 4),
            Text(controller.owner.phone),
            const SizedBox(height: 16),
            const Text(
              'Villas owned by this owner:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Tampilkan daftar villa yang dimiliki oleh owner
            Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.errorMessage.value.isNotEmpty) {
                return Center(
                  child: Text(
                    'Error: ${controller.errorMessage.value}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final villas = controller.villas;

              if (villas.isEmpty) {
                return const Center(
                  child: Text('This owner has no villas.'),
                );
              }

              return Expanded(
                child: ListView.builder(
                  itemCount: villas.length,
                  itemBuilder: (ctx, index) {
                    final villa = villas[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(villa.name),
                        subtitle: Text(villa.address),
                        trailing: Text('Rp ${villa.price.toStringAsFixed(0)}'),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
