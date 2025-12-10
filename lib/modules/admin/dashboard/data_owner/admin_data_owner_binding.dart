import 'package:get/get.dart';
import 'package:utp_flutter/modules/admin/dashboard/data_owner/admin_data_owner_viewmodel.dart';

class AdminDataOwnerBinding extends Bindings {
  @override
  void dependencies() {
    // Mendaftarkan ViewModel AdminDataOwnerViewModel
    Get.put(AdminDataOwnerViewModel());
  }
}
