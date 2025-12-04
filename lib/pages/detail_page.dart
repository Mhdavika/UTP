// lib/pages/detail_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:table_calendar/table_calendar.dart';

import 'chat_room_page.dart';
import 'payment_page.dart';
import 'package:utp_flutter/services/user_collections.dart';
import 'package:utp_flutter/app_session.dart';

class DetailPage extends StatefulWidget {
  final String villaId;
  final Map<String, dynamic> villaData;

  const DetailPage({
    super.key,
    required this.villaId,
    required this.villaData,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  // tanggal dipilih
  DateTime? _checkIn;
  DateTime? _checkOut;

  // untuk kalender
  late DateTime _focusedDay;
  late DateTime _firstDay;
  late DateTime _lastDay;
  Set<DateTime> _bookedDates = {}; // hari-hari yang SUDAH dibayar (range [checkIn, checkOut))
  bool _loadingCalendar = true;

  bool _loadingBooking = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = DateTime(now.year, now.month, now.day);
    _firstDay = DateTime(now.year, now.month, now.day);
    _lastDay = DateTime(now.year + 2, 12, 31);

    _loadBookedDates();
  }

  // ---------- UTIL ----------

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  String _formatDate(DateTime? date) {
    if (date == null) return 'Pilih tanggal';
    return '${date.day}/${date.month}/${date.year}';
  }

  int _parsePrice(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Hitung total harga berdasarkan range tanggal:
  /// - Senin–Jumat pakai weekday_price
  /// - Sabtu–Minggu pakai weekend_price
  int _calculateTotalPrice() {
    if (_checkIn == null || _checkOut == null) return 0;

    final int weekdayPrice = _parsePrice(widget.villaData['weekday_price']);
    final int weekendPrice = _parsePrice(widget.villaData['weekend_price']);

    DateTime day = _normalize(_checkIn!);
    DateTime last = _normalize(_checkOut!);

    // Kalau user pilih check-in & check-out sama → anggap 1 malam
    if (!day.isBefore(last)) {
      final bool isWeekend =
          day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
      return isWeekend ? weekendPrice : weekdayPrice;
    }

    int total = 0;

    // Hitung semua hari di [checkIn, checkOut)
    while (day.isBefore(last)) {
      final bool isWeekend =
          day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
      total += isWeekend ? weekendPrice : weekdayPrice;
      day = day.add(const Duration(days: 1));
    }

    return total;
  }

  bool _isBooked(DateTime day) {
    final d = _normalize(day);
    return _bookedDates.contains(d);
  }

  bool _isSelected(DateTime day) {
    final d = _normalize(day);
    return (_checkIn != null && _normalize(_checkIn!) == d) ||
        (_checkOut != null && _normalize(_checkOut!) == d);
  }

  bool _isInSelectedRange(DateTime day) {
    if (_checkIn == null || _checkOut == null) return false;
    final d = _normalize(day);
    final start = _normalize(_checkIn!);
    final end = _normalize(_checkOut!);
    // di tengah range, bukan ujung
    return d.isAfter(start) && d.isBefore(end);
  }

  // ---------- LOAD BOOKED DATES (status == 'paid') ----------

  Future<void> _loadBookedDates() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('villa_id', isEqualTo: widget.villaId)
          .get();

      final Set<DateTime> booked = {};

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = (data['status'] ?? '').toString();

        // hanya tandai booking yang SUDAH DIBAYAR
        if (status != 'paid') continue;

        final checkInTs = data['check_in'] as Timestamp;
        final checkOutTs = data['check_out'] as Timestamp;

        DateTime day = _normalize(checkInTs.toDate());
        final last = _normalize(checkOutTs.toDate());

        // tandai semua hari di [checkIn, last)
        while (day.isBefore(last)) {
          booked.add(day);
          day = day.add(const Duration(days: 1));
        }
      }

      setState(() {
        _bookedDates = booked;
        _loadingCalendar = false;
      });
    } catch (e) {
      setState(() => _loadingCalendar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat kalender: $e')),
      );
    }
  }

  // ---------- PILIH HARI DI KALENDER ----------

  void _onSelectDay(DateTime day) {
    final today = _normalize(DateTime.now());
    day = _normalize(day);

    // tidak boleh pilih hari lampau
    if (day.isBefore(today)) return;

    setState(() {
      // ===== CASE 1: belum punya check-in / sudah punya range lengkap → mulai baru =====
      if (_checkIn == null || (_checkIn != null && _checkOut != null)) {
        // tidak boleh mulai dari tanggal yang sudah dibooking
        if (_isBooked(day)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Tanggal ini sudah dibooking, tidak bisa untuk check-in.'),
            ),
          );
          return;
        }
        _checkIn = day;
        _checkOut = null;
        return;
      }

      // ===== CASE 2: sudah ada check-in tapi belum ada check-out =====
      if (_checkIn != null && _checkOut == null) {
        // jika klik sebelum check-in → jadikan starting baru
        if (day.isBefore(_checkIn!)) {
          if (_isBooked(day)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Tanggal ini sudah dibooking, tidak bisa untuk check-in.'),
              ),
            );
            return;
          }
          _checkIn = day;
          _checkOut = null;
          return;
        }

        // sekarang day >= _checkIn → kandidat check-out
        // cek apakah tengah-tengah range [checkIn, day) ada tanggal booked
        DateTime cursor = _normalize(_checkIn!);
        bool hasBooked = false;

        // perhatikan: pakai isBefore(day) → EXCLUSIVE di hari "day"
        // jadi checkOut boleh bersinggungan dgn booking lain di ujung
        while (cursor.isBefore(day)) {
          if (_isBooked(cursor)) {
            hasBooked = true;
            break;
          }
          cursor = cursor.add(const Duration(days: 1));
        }

        if (hasBooked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Range tanggal ini melewati tanggal yang sudah dibooking. Silakan pilih range lain.'),
            ),
          );
          return;
        }

        // kalau day sendiri booked → boleh jadi check-out (tamu keluar, tamu lain masuk di hari itu)
        _checkOut = day;
      }
    });
  }

  // ---------- CEK RANGE KE FIRESTORE (ANTI RACE-CONDITION) ----------

  Future<bool> _isDateRangeAvailable() async {
    if (_checkIn == null || _checkOut == null) return false;

    final villaId = widget.villaId;
    final checkIn = _normalize(_checkIn!);
    final checkOut = _normalize(_checkOut!);

    final snap = await FirebaseFirestore.instance
        .collection('bookings')
        .where('villa_id', isEqualTo: villaId)
        .get();

    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString();
      if (status != 'paid') continue; // hanya booking yang sudah dibayar

      final existingIn = _normalize((data['check_in'] as Timestamp).toDate());
      final existingOut = _normalize((data['check_out'] as Timestamp).toDate());

      // interval malam: [checkIn, checkOut)
      // overlap kalau existingIn < checkOut dan existingOut > checkIn
      final bool overlap =
          existingIn.isBefore(checkOut) && existingOut.isAfter(checkIn);

      if (overlap) {
        return false;
      }
    }

    return true;
  }

  // ---------- BOOKING + NAVIGASI KE PAYMENT ----------

  Future<void> _createBooking() async {
    if (_checkIn == null || _checkOut == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi tanggal check-in & check-out')),
      );
      return;
    }

    final userId = AppSession.userDocId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu')),
      );
      return;
    }

    try {
      setState(() => _loadingBooking = true);

      // cek lagi ke Firestore biar anti race-condition
      final available = await _isDateRangeAvailable();
      if (!available) {
        setState(() => _loadingBooking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tanggal ini sudah dibooking orang lain.\nSilakan pilih tanggal lain.',
            ),
          ),
        );
        _loadBookedDates();
        return;
      }

      final String ownerId = widget.villaData['owner_id'] ?? '';

      // HITUNG TOTAL HARGA BERDASARKAN WEEKDAY/WEEKEND
      final int totalPrice = _calculateTotalPrice();
      if (totalPrice <= 0) {
        setState(() => _loadingBooking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terjadi kesalahan dalam perhitungan harga.'),
          ),
        );
        return;
      }

      final bookingRef =
          await FirebaseFirestore.instance.collection('bookings').add({
        'user_id': userId,
        'villa_id': widget.villaId,
        'owner_id': ownerId,
        'villa_name': widget.villaData['name'] ?? 'Tanpa Nama',
        'villa_location': widget.villaData['location'] ?? '-',
        'status': 'pending', // akan jadi 'paid' setelah bayar
        'check_in': Timestamp.fromDate(_checkIn!),
        'check_out': Timestamp.fromDate(_checkOut!),
        'total_price': totalPrice,
        'created_at': FieldValue.serverTimestamp(),
      });

      setState(() => _loadingBooking = false);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            bookingId: bookingRef.id,
            villaName: widget.villaData['name'] ?? 'Tanpa Nama',
            totalPrice: totalPrice,
            checkIn: _checkIn!,
            checkOut: _checkOut!,
          ),
        ),
      );
    } catch (e) {
      setState(() => _loadingBooking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat booking: $e')),
      );
    }
  }

  // ---------- CHAT & MAPS ----------

  void _openChatRoom() {
    final String ownerId = widget.villaData['owner_id'] ?? '';

    if (ownerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data pemilik villa tidak tersedia')),
      );
      return;
    }

    final userId = AppSession.userDocId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          villaId: widget.villaId,
          ownerId: ownerId,
          userId: userId,
        ),
      ),
    );
  }

  Future<void> _openMaps(String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link lokasi belum tersedia')),
      );
      return;
    }

    try {
      final Uri uri = Uri.parse(url);

      final success = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka Google Maps')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi error saat membuka Maps: $e')),
      );
    }
  }

  // ---------- HELPER CELL KALENDER ----------

  Widget _buildDayCell(
    BuildContext context,
    DateTime day,
    DateTime todayNorm,
  ) {
    final d = _normalize(day);
    final isPast = d.isBefore(todayNorm);
    final isBooked = _isBooked(d);
    final isSelected = _isSelected(d);
    final inRange = _isInSelectedRange(d);

    Color bg = Colors.transparent;
    Color textColor = Colors.black;

    if (isBooked) {
      bg = Colors.red; // booked = merah
      textColor = Colors.white;
    } else if (isSelected || inRange) {
      bg = Colors.black;
      textColor = Colors.white;
    } else if (isPast) {
      textColor = Colors.grey; // tanggal lewat = abu-abu
    }

    return Center(
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: textColor,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final data = widget.villaData;

    final String name = data['name'] ?? 'Tanpa Nama';
    final String location = data['location'] ?? '-';
    final int weekdayPrice = _parsePrice(data['weekday_price']);
    final int weekendPrice = _parsePrice(data['weekend_price']);
    final String description = data['description'] ?? '';
    final String mapsLink = data['maps_link'] ?? '';

    final todayNorm = _normalize(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: _openChatRoom,
          ),
          StreamBuilder<bool>(
            stream: UserCollections.isFavoriteStream(widget.villaId),
            builder: (context, snapshot) {
              final isFav = snapshot.data ?? false;

              return IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.red : Colors.grey,
                ),
                onPressed: () async {
                  try {
                    await UserCollections.toggleFavorite(widget.villaId);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal mengubah favorit: $e')),
                    );
                  }
                },
              );
            },
          ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.black,
              ),
              onPressed: _loadingBooking ? null : _createBooking,
              child: Text(
                _loadingBooking ? 'Memproses...' : 'Pesan',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // COVER FOTO (placeholder)
            Container(
              height: 220,
              width: double.infinity,
              color: Colors.grey.shade300,
            ),

            // KONTEN PUTIH DENGAN RADIUS DI ATAS
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // NAMA + LOKASI + RATING (dummy)
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      location,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        Icon(Icons.star,
                            size: 14, color: Colors.orangeAccent),
                        SizedBox(width: 4),
                        Text(
                          '4.9 (200 ulasan)',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // HARGA WEEKDAY & WEEKEND BERDAMPINGAN (DI KIRI)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Weekday : ",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              "Rp $weekdayPrice",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              "Weekend : ",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              "Rp $weekendPrice",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // DESKRIPSI
                    const Text(
                      "Deskripsi",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description.isEmpty
                          ? "Belum ada deskripsi."
                          : description,
                      style: const TextStyle(fontSize: 14),
                    ),

                    const SizedBox(height: 16),

                    // TOMBOL LIHAT LOKASI
                    if (mapsLink.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.location_on_outlined),
                          label: const Text(
                            "Lihat di Google Maps",
                            style: TextStyle(fontSize: 14),
                          ),
                          onPressed: () => _openMaps(mapsLink),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // KALENDER
                    const Text(
                      "Tanggal Menginap",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "• Abu-abu = tanggal sudah lewat\n• Merah = tanggal sudah dibooking",
                      style: TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 12),

                    if (_loadingCalendar)
                      const Center(child: CircularProgressIndicator())
                    else
                      TableCalendar(
                        firstDay: _firstDay,
                        lastDay: _lastDay,
                        focusedDay: _focusedDay,
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                        ),
                        calendarFormat: CalendarFormat.month,
                        availableGestures: AvailableGestures.horizontalSwipe,
                        selectedDayPredicate: (day) =>
                            _isSelected(_normalize(day)),
                        onDaySelected: (selectedDay, focusedDay) {
                          _focusedDay = focusedDay;
                          _onSelectDay(selectedDay);
                        },
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                        },
                        // booked day tetap enabled, tapi dicek di _onSelectDay
                        enabledDayPredicate: (day) {
                          final d = _normalize(day);
                          if (d.isBefore(todayNorm)) return false;
                          return true;
                        },
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) =>
                              _buildDayCell(context, day, todayNorm),
                          todayBuilder: (context, day, focusedDay) =>
                              _buildDayCell(context, day, todayNorm),
                        ),
                      ),

                    const SizedBox(height: 8),
                    Text(
                      'Check-in:  ${_formatDate(_checkIn)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      'Check-out: ${_formatDate(_checkOut)}',
                      style: const TextStyle(fontSize: 13),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
