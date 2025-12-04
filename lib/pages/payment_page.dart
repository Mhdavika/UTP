// lib/pages/payment_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PaymentPage extends StatefulWidget {
  final String bookingId;
  final String villaName;
  final int totalPrice;
  final DateTime checkIn;
  final DateTime checkOut;

  const PaymentPage({
    super.key,
    required this.bookingId,
    required this.villaName,
    required this.totalPrice,
    required this.checkIn,
    required this.checkOut,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  /// 0 = review
  /// 1 = pilih metode
  /// 2 = detail metode (transfer / qris)
  /// 3 = upload bukti
  /// 4 = sukses
  int _step = 0;

  String _method = 'transfer'; // 'transfer' | 'qris'
  String _selectedBank = 'BCA';
  bool _saving = false;

  XFile? _proofFile; // bukti pembayaran

  final Map<String, String> _bankAccounts = {
    'BCA': '123 138 138 0130108',
    'BRI': '7777 8888 9999',
    'Mandiri': '123 000 999 888',
    'BNI': '987 654 321 000',
  };

  String get _selectedAccount => _bankAccounts[_selectedBank] ?? '-';

  String _formatRupiah(int value) => 'Rp ${value.toString()}';

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  void _goToNextStep() {
    setState(() {
      if (_step < 4) _step++;
    });
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      setState(() => _proofFile = result);
    }
  }

  /// Simpan info pembayaran ke Firestore HANYA ke dokumen bookings/{bookingId}
  /// supaya tidak perlu aturan subcollection.
  Future<void> _confirmPayment() async {
    if (_proofFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan upload bukti pembayaran terlebih dahulu.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final bookingRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId);

      await bookingRef.update({
        // status booking tetap pending, admin yang nanti mengubah jadi "paid"
        'status': 'pending',
        'payment_status': 'waiting_verification',
        'payment_method': _method,
        'bank': _method == 'transfer' ? _selectedBank : null,
        'has_payment_proof': true,
        'payment_proof_file_name': _proofFile!.name,
        'payment_proof_uploaded_at': FieldValue.serverTimestamp(),
      });

      setState(() {
        _saving = false;
        _step = 4; // sukses
      });
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengkonfirmasi pembayaran: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_step) {
      case 0:
        body = _buildReviewStep();
        break;
      case 1:
        body = _buildMethodStep();
        break;
      case 2:
        body = _method == 'transfer'
            ? _buildTransferDetailStep()
            : _buildQrisStep();
        break;
      case 3:
        body = _buildUploadProofStep();
        break;
      case 4:
        body = _buildSuccessStep();
        break;
      default:
        body = const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
        title: const Text('Detail page'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: body,
        ),
      ),
    );
  }

  // ====== STEP 0: Tinjau & lanjutkan ======
  Widget _buildReviewStep() {
    final dateText =
        '${_formatDate(widget.checkIn)}  -  ${_formatDate(widget.checkOut)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.villaName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(dateText, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(fontSize: 12)),
                        Text(
                          _formatRupiah(widget.totalPrice),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _goToNextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Pesan', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // ====== STEP 1: Pilih metode ======
  Widget _buildMethodStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tambahkan metode pembayaran',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              RadioListTile<String>(
                value: 'transfer',
                groupValue: _method,
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _method = val);
                },
                title: const Text('Transfer Bank'),
                secondary: const Icon(Icons.account_balance),
              ),
              const Divider(height: 0),
              RadioListTile<String>(
                value: 'qris',
                groupValue: _method,
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _method = val);
                },
                title: const Text('Qris'),
                secondary: const Icon(Icons.qr_code),
              ),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _goToNextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Selanjutnya',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // ====== STEP 2A: Transfer (pilih bank) ======
  Widget _buildTransferDetailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // header total
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Pembayaran', style: TextStyle(fontSize: 14)),
              Text(
                _formatRupiah(widget.totalPrice),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'Pilih bank tujuan',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),

        // pilih bank
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: _bankAccounts.keys.map((bank) {
              return RadioListTile<String>(
                value: bank,
                groupValue: _selectedBank,
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _selectedBank = val);
                },
                title: Text('Bank $bank'),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance, size: 32),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bank $_selectedBank',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No. Rekening / VA',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            _selectedAccount,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          // TODO: copy ke clipboard kalau mau
                        },
                        child: const Text('SALIN'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),

                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'Petunjuk Transfer mBanking',
                      style: TextStyle(fontSize: 13),
                    ),
                    children: const [
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '1. Buka aplikasi mBanking sesuai bank.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '2. Pilih menu transfer ke rekening / virtual account.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '3. Masukkan nomor rekening di atas dan jumlah sesuai tagihan.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'Petunjuk Transfer ATM',
                      style: TextStyle(fontSize: 13),
                    ),
                    children: const [
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '1. Masukkan kartu ATM dan PIN.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '2. Pilih menu transfer antar rekening/bank.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '3. Masukkan nomor rekening di atas dan jumlah sesuai tagihan.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _goToNextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Lanjutkan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // ====== STEP 2B: QRIS ======
  Widget _buildQrisStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Qris',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/qris_example.png', // pastikan sudah didaftarkan di pubspec.yaml
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) {
                  return const Center(
                    child: Text('QRIS CODE', style: TextStyle(fontSize: 16)),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Silakan scan QRIS di atas\nmenggunakan e-wallet / mBanking Anda.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _goToNextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Lanjutkan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // ====== STEP 3: Upload bukti (transfer & qris) ======
  Widget _buildUploadProofStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _method == 'transfer'
              ? 'Upload Bukti Transfer'
              : 'Upload Bukti Pembayaran QRIS',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Pembayaran',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              Text(
                _formatRupiah(widget.totalPrice),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Metode: ${_method == 'transfer' ? 'Transfer Bank ($_selectedBank)' : 'QRIS'}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Upload bukti pembayaran',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickProof,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400),
              color: Colors.white,
            ),
            child: Row(
              children: [
                const Icon(Icons.upload_file, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _proofFile == null
                        ? 'Pilih gambar bukti pembayaran'
                        : _proofFile!.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: _proofFile == null
                          ? Colors.grey[600]
                          : Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Format: jpg, png. Bisa berupa screenshot atau foto struk pembayaran.',
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _confirmPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Saya sudah bayar',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ),
      ],
    );
  }

  // ====== STEP 4: Sukses ======
  Widget _buildSuccessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.check_circle, color: Colors.green, size: 72),
        const SizedBox(height: 20),
        const Text(
          'Booking Berhasil',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'Terima kasih atas booking-nya.\nPembayaran kamu akan dicek oleh admin.',
          style: TextStyle(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Status akan berubah menjadi PAID\nsetelah admin memverifikasi bukti.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Kembali ke Beranda',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
