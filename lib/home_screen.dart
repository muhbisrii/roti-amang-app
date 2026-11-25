import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Potongan sewa dinamis: Bulan pertama 17rb, Bulan selanjutnya 23rb bulat
  int get defaultRentFee => _cycleIndex == 0 ? 17000 : 23000; 
  final int defaultSalaryFee = 40000;
  final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  DateTime selectedDate = DateTime.now();
  Stream<QuerySnapshot>? _transactionsStream;
  
  // Menggunakan index siklus untuk memantau perubahan halaman
  int _lastCycleIndex = -1;
  
  // Status Mode Pemilik (Admin)
  bool isOwner = false;

  // --- LOGIKA: SIKLUS CUSTOM (Bulan 1 Fix, Bulan 2 Mulai 6 Juli) ---
  final DateTime projectStartDate = DateTime(2026, 6, 4);
  final DateTime cycle2StartDate = DateTime(2026, 7, 6); // Tanggal awal bulan ke-2

  int get _cycleIndex {
    DateTime justDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    if (justDate.isBefore(cycle2StartDate)) {
      return 0; // Bulan 1 (4 Jun - 5 Jul)
    }
    // Mulai dari 6 Juli, siklus dihitung per 30 hari
    int diff = justDate.difference(cycle2StartDate).inDays;
    return 1 + (diff ~/ 30);
  }

  // Tetap dipertahankan untuk penulisan data agar konsisten
  String get currentCycleKey {
    DateTime mappedMonth = DateTime(2026, 6 + _cycleIndex, 1);
    return "${mappedMonth.year}-${mappedMonth.month.toString().padLeft(2, '0')}";
  }

  DateTime get cycleStartDate {
    if (_cycleIndex == 0) return projectStartDate;
    return cycle2StartDate.add(Duration(days: (_cycleIndex - 1) * 30));
  }

  DateTime get cycleEndDate {
    if (_cycleIndex == 0) return cycle2StartDate.subtract(const Duration(days: 1)); // Berakhir 5 Juli
    return cycleStartDate.add(const Duration(days: 29));
  }

  String get periodText {
    return "${DateFormat('d MMM', 'id_ID').format(cycleStartDate)} - ${DateFormat('d MMM yyyy', 'id_ID').format(cycleEndDate)}";
  }
  
  String get currentDateKey => "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

  @override
  void initState() {
    super.initState();
    // Memastikan waktu jam tidak mengganggu hitungan hari
    DateTime now = DateTime.now();
    selectedDate = DateTime(now.year, now.month, now.day);
    _setupStream(); 
  }

  void _setupStream() {
    _lastCycleIndex = _cycleIndex;
    
    // FORMAT TANGGAL PENCARIAN (Batas Awal & Akhir Siklus)
    String startKey = "${cycleStartDate.year}-${cycleStartDate.month.toString().padLeft(2, '0')}-${cycleStartDate.day.toString().padLeft(2, '0')}";
    String endKey = "${cycleEndDate.year}-${cycleEndDate.month.toString().padLeft(2, '0')}-${cycleEndDate.day.toString().padLeft(2, '0')}";

    // Pencarian sekarang murni menggunakan filter rentang tanggal (dateKey)
    // agar sisa data dari tanggal 4-5 juli tidak ikut terbawa ke siklus bulan kedua.
    _transactionsStream = _firestore
        .collection('transactions')
        .where('dateKey', isGreaterThanOrEqualTo: startKey)
        .where('dateKey', isLessThanOrEqualTo: endKey)
        .snapshots();
  }

  void changeDate(int days) {
    DateTime newDate = selectedDate.add(Duration(days: days));
    DateTime now = DateTime.now();
    
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime dateToCheck = DateTime(newDate.year, newDate.month, newDate.day);
    
    if (dateToCheck.isAfter(today)) return;
    
    if (dateToCheck.isBefore(projectStartDate)) {
      _showSuccessSnackBar("Data sebelum 4 Juni 2026 tidak tersedia.", Icons.info_outline, Colors.blue);
      return;
    }

    setState(() {
      selectedDate = newDate;
      if (_cycleIndex != _lastCycleIndex) {
        _setupStream();
      }
    });
  }

  void _showSuccessSnackBar(String message, IconData icon, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(0xFF2C2C2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showOwnerUnlockDialog() {
    final TextEditingController pinController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mode Pemilik', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isOwner ? 'Anda saat ini berada di Mode Pemilik. Ingin mengunci kembali aplikasi?' : 'Masukkan PIN rahasia untuk membuka akses input dan edit data.', 
              style: const TextStyle(color: Colors.white70, fontSize: 13)
            ),
            const SizedBox(height: 16),
            if (!isOwner)
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 8),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: "****",
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (isOwner) {
                setState(() => isOwner = false);
                Navigator.pop(context);
                _showSuccessSnackBar("Aplikasi berhasil dikunci", Icons.lock, Colors.orange);
              } else {
                if (pinController.text == "110204") {
                  setState(() => isOwner = true);
                  Navigator.pop(context);
                  _showSuccessSnackBar("Akses Pemilik Dibuka!", Icons.lock_open, const Color(0xFF32D74B));
                } else {
                  Navigator.pop(context);
                  _showSuccessSnackBar("PIN Salah!", Icons.error, const Color(0xFFFF453A));
                }
              }
            },
            child: Text(isOwner ? 'Kunci Aplikasi' : 'Buka Akses', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isBold ? Colors.white : Colors.white70, fontSize: isBold ? 16 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(color: valueColor, fontSize: isBold ? 18 : 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showDetailSheet(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    String type = data['type'] ?? 'income';
    bool isIncome = type == 'income';
    bool isAdvance = type == 'salary_advance';
    bool isHoliday = type == 'holiday';
    bool isExpense = type == 'expense';
    bool isPersonalFund = isExpense && (data['isPersonalFund'] == true);
    
    String timeString = "";
    if (data['timestamp'] != null) {
      DateTime ts = (data['timestamp'] as Timestamp).toDate();
      timeString = DateFormat('EEEE, d MMMM yyyy - HH:mm', 'id_ID').format(ts);
    }
    
    int holidayRent = data.containsKey('rent') ? (data['rent'] as num).toInt() : 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  isIncome ? Icons.trending_up : (isAdvance ? Icons.request_quote : (isHoliday ? Icons.event_busy : Icons.receipt_long)), 
                  color: isIncome ? const Color(0xFF32D74B) : (isAdvance ? Colors.orangeAccent : (isHoliday ? Colors.lightBlueAccent : (isPersonalFund ? Colors.amberAccent : const Color(0xFFFF453A)))), 
                  size: 28
                ),
                const SizedBox(width: 12),
                Text(
                  isIncome ? "Detail Pemasukan" : (isAdvance ? "Detail Gaji / Kasbon" : (isHoliday ? "Detail Hari Libur" : (isPersonalFund ? "Pengeluaran (Duit Pribadi)" : "Detail Pengeluaran"))), 
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            const Text("Keterangan", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              isIncome ? "Hasil Jualan Harian" : "${data['note']}",
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
            ),
            const SizedBox(height: 16),
            
            const Text("Waktu Input", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            Text(timeString.isNotEmpty ? timeString : "Waktu tidak diketahui", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),

            if (isIncome) ...[
              _buildDetailRow("Uang Kotor (Total)", formatCurrency.format(data['gross']), Colors.white, isBold: true),
              const SizedBox(height: 4),
              if (data.containsKey('cash') || !data.containsKey('qris')) 
                _buildDetailRow("  • Tunai (Cash Laci)", formatCurrency.format(data.containsKey('cash') ? data['cash'] : data['gross']), Colors.white70),
              if (data.containsKey('qris') && data['qris'] > 0)
                _buildDetailRow("  • QRIS / Bank / GoFood", formatCurrency.format(data['qris']), Colors.white70),
              const SizedBox(height: 16),

              _buildDetailRow("Potongan Sewa", "- ${formatCurrency.format(data.containsKey('rent') ? data['rent'] : defaultRentFee)}", Colors.orange),
              const SizedBox(height: 8),
              _buildDetailRow("Potongan Gaji", "- ${formatCurrency.format(data.containsKey('salary') ? data['salary'] : defaultSalaryFee)}", Colors.orange),
              const SizedBox(height: 12),
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              _buildDetailRow("Duit Sendiri (Bersih)", formatCurrency.format(data['net']), const Color(0xFF32D74B), isBold: true),
            ] else if (isAdvance) ...[
              _buildDetailRow("Total Gaji Diambil", formatCurrency.format(data['amount']), Colors.orangeAccent, isBold: true),
              const SizedBox(height: 8),
              _buildDetailRow("Diambil dari", data['paymentMethod'] == 'bank' ? "Bank (QRIS)" : "Laci (Cash)", Colors.white70),
            ] else if (isHoliday) ...[
              _buildDetailRow("Status Hari", "LIBUR (Tidak Jaga)", Colors.lightBlueAccent, isBold: true),
              const SizedBox(height: 8),
              _buildDetailRow("Dampak Gaji Bulanan", "- Rp40.000 (Target Berkurang)", Colors.orangeAccent),
              const SizedBox(height: 8),
              _buildDetailRow("Potong Sewa dari Duit Bersih", holidayRent > 0 ? "- ${formatCurrency.format(holidayRent)}" : "Rp0 (Data Lama)", holidayRent > 0 ? const Color(0xFFFF453A) : Colors.white70),
            ] else ...[
              _buildDetailRow("Total Pengeluaran", formatCurrency.format(data['amount']), isPersonalFund ? Colors.amberAccent : const Color(0xFFFF453A), isBold: true),
              const SizedBox(height: 8),
              _buildDetailRow("Sumber Dana", isPersonalFund ? "Duit Pribadi Sendiri (Aman)" : (data['paymentMethod'] == 'bank' ? "Bank (QRIS Usaha)" : "Laci (Cash Usaha)"), Colors.white70),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showInputHolidayDialog() {
    String displayDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(selectedDate);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.event_busy, color: Colors.lightBlueAccent),
            SizedBox(width: 10),
            Text('Setel Hari Libur?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Tanggal $displayDate akan diset sebagai HARI LIBUR.\n\nLogika Sistem:\n• Target gaji otomatis berkurang Rp40.000.\n• Duit Bersih dipotong ${formatCurrency.format(defaultRentFee)} untuk bayar sewa (Uang fisik di laci tidak berubah).',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await _firestore.collection('transactions').add({
                'type': 'holiday',
                'note': 'Pegawai Libur / Tidak Jualan',
                'amount': 0,
                'rent': defaultRentFee, 
                'monthKey': currentCycleKey,
                'dateKey': currentDateKey,
                'timestamp': FieldValue.serverTimestamp(),
              });
              if (mounted) {
                Navigator.pop(context);
                _showSuccessSnackBar("Hari libur dicatat. Sewa ${formatCurrency.format(defaultRentFee)} dipotong dari Duit Bersih.", Icons.event_busy, Colors.lightBlueAccent);
              }
            },
            child: const Text('Ya, Setel Libur', style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showInputSalaryAdvanceSheet() {
    final TextEditingController nameController = TextEditingController(text: "Kasbon Gaji Harian");
    final TextEditingController amountController = TextEditingController();
    String displayDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(selectedDate);
    String paymentMethod = 'cash'; 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Ambil Gaji / Kasbon:\n$displayDate", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Keterangan",
                    labelStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    prefixIcon: const Icon(Icons.badge, color: Colors.orangeAccent),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: "Total Gaji Diambil (Rp)",
                    hintText: "Contoh: 50000",
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontWeight: FontWeight.normal),
                    labelStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    prefixIcon: const Icon(Icons.request_quote, color: Colors.orangeAccent),
                  ),
                ),
                
                const SizedBox(height: 20),
                const Text("Ambil Uang Dari:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => paymentMethod = 'cash'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: paymentMethod == 'cash' ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: paymentMethod == 'cash' ? Colors.greenAccent : Colors.transparent),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.money, color: paymentMethod == 'cash' ? Colors.greenAccent : Colors.white54, size: 18),
                              const SizedBox(width: 8),
                              Text("Laci (Cash)", style: TextStyle(color: paymentMethod == 'cash' ? Colors.greenAccent : Colors.white54, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => paymentMethod = 'bank'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: paymentMethod == 'bank' ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: paymentMethod == 'bank' ? Colors.blueAccent : Colors.transparent),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_wallet, color: paymentMethod == 'bank' ? Colors.blueAccent : Colors.white54, size: 18),
                              const SizedBox(width: 8),
                              Text("Bank (QRIS)", style: TextStyle(color: paymentMethod == 'bank' ? Colors.blueAccent : Colors.white54, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      if (nameController.text.isNotEmpty && amountController.text.isNotEmpty) {
                        await _firestore.collection('transactions').add({
                          'type': 'salary_advance',
                          'note': nameController.text,
                          'amount': int.parse(amountController.text),
                          'paymentMethod': paymentMethod, 
                          'monthKey': currentCycleKey,
                          'dateKey': currentDateKey,
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                        if (mounted) {
                          Navigator.pop(context);
                          _showSuccessSnackBar("Kasbon berhasil dicatat! Target menurun otomatis.", Icons.check_circle, Colors.orangeAccent);
                        }
                      }
                    },
                    child: const Text("Simpan Data Gaji", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        }
      ),
    );
  }

  void _showInputIncomeSheet() {
    final TextEditingController cashController = TextEditingController();
    final TextEditingController qrisController = TextEditingController();
    final TextEditingController rentController = TextEditingController(text: defaultRentFee.toString());
    final TextEditingController salaryController = TextEditingController(text: defaultSalaryFee.toString());
    String displayDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(selectedDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Input Jualan untuk:\n$displayDate", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),
            
            TextField(
              controller: cashController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: "Uang Tunai / Cash (Rp)",
                hintText: "Contoh: 100000",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontWeight: FontWeight.normal),
                labelStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                prefixIcon: const Icon(Icons.payments_outlined, color: Colors.greenAccent),
              ),
            ),
            const SizedBox(height: 12),
            
            TextField(
              controller: qrisController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: "QRIS / Bank / GoFood (Rp)", 
                hintText: "Contoh: 87000 (Kosongkan jika tidak ada)",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontWeight: FontWeight.normal),
                labelStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                prefixIcon: const Icon(Icons.account_balance_wallet, color: Colors.blueAccent),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: rentController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: "Potongan Sewa",
                      labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: salaryController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: "Potongan Gaji",
                      labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  int cash = cashController.text.isNotEmpty ? int.parse(cashController.text) : 0;
                  int qris = qrisController.text.isNotEmpty ? int.parse(qrisController.text) : 0;
                  int gross = cash + qris;

                  if (gross > 0) {
                    int rent = rentController.text.isNotEmpty ? int.parse(rentController.text) : 0;
                    int salary = salaryController.text.isNotEmpty ? int.parse(salaryController.text) : 0;
                    int net = gross - (rent + salary);
                    
                    await _firestore.collection('transactions').add({
                      'type': 'income',
                      'gross': gross,
                      'cash': cash,
                      'qris': qris,
                      'rent': rent,
                      'salary': salary,
                      'net': net,
                      'monthKey': currentCycleKey,
                      'dateKey': currentDateKey,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    
                    if (mounted) {
                      Navigator.pop(context);
                      _showSuccessSnackBar("Data jualan berhasil disimpan!", Icons.check_circle, const Color(0xFF32D74B));
                    }
                  }
                },
                child: const Text("Simpan Data Jualan", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showInputExpenseSheet() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    String displayDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(selectedDate);
    String paymentMethod = 'cash'; 
    bool isPersonalFund = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Catat Pengeluaran:\n$displayDate", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Keterangan (Cth: Beli Roti, Selai, dll)",
                    labelStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    prefixIcon: const Icon(Icons.receipt_long_outlined, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: "Total Pengeluaran (Rp)",
                    hintText: "Contoh: 50000",
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontWeight: FontWeight.normal),
                    labelStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    prefixIcon: const Icon(Icons.money_off, color: Colors.white70),
                  ),
                ),
                
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SwitchListTile(
                    title: const Text("Pakai Duit Pribadi?", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Uang kas toko/laci/bank tidak akan terpotong", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    value: isPersonalFund,
                    activeColor: Colors.amberAccent,
                    onChanged: (bool value) {
                      setModalState(() {
                        isPersonalFund = value;
                      });
                    },
                  ),
                ),

                if (!isPersonalFund) ...[
                  const SizedBox(height: 20),
                  const Text("Ambil Uang Dari:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => paymentMethod = 'cash'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: paymentMethod == 'cash' ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: paymentMethod == 'cash' ? Colors.greenAccent : Colors.transparent),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.money, color: paymentMethod == 'cash' ? Colors.greenAccent : Colors.white54, size: 18),
                                const SizedBox(width: 8),
                                Text("Laci (Cash)", style: TextStyle(color: paymentMethod == 'cash' ? Colors.greenAccent : Colors.white54, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => paymentMethod = 'bank'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: paymentMethod == 'bank' ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: paymentMethod == 'bank' ? Colors.blueAccent : Colors.transparent),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.account_balance_wallet, color: paymentMethod == 'bank' ? Colors.blueAccent : Colors.white54, size: 18),
                                const SizedBox(width: 8),
                                Text("Bank (QRIS)", style: TextStyle(color: paymentMethod == 'bank' ? Colors.blueAccent : Colors.white54, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPersonalFund ? Colors.amberAccent : const Color(0xFFFF3B30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      if (nameController.text.isNotEmpty && amountController.text.isNotEmpty) {
                        await _firestore.collection('transactions').add({
                          'type': 'expense',
                          'note': nameController.text,
                          'amount': int.parse(amountController.text),
                          'paymentMethod': isPersonalFund ? 'personal' : paymentMethod, 
                          'isPersonalFund': isPersonalFund,
                          'monthKey': currentCycleKey,
                          'dateKey': currentDateKey,
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                        if (mounted) {
                          Navigator.pop(context);
                          _showSuccessSnackBar("Pengeluaran berhasil disimpan!", Icons.check_circle, isPersonalFund ? Colors.amber : const Color(0xFFFF453A));
                        }
                      }
                    },
                    child: Text(
                      isPersonalFund ? "Simpan Catatan Pribadi" : "Simpan Pengeluaran", 
                      style: TextStyle(color: isPersonalFund ? Colors.black : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        }
      ),
    );
  }

  void _showOptionsSheet(DocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text('Edit Data', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context); 
                final data = doc.data() as Map<String, dynamic>;
                String type = data['type'] ?? 'income';
                if (type == 'income') {
                  _showEditIncomeSheet(doc);
                } else if (type == 'salary_advance') {
                  _showEditSalaryAdvanceSheet(doc);
                } else if (type == 'holiday') {
                  _showSuccessSnackBar("Hari libur tidak perlu diedit, silakan hapus jika salah input.", Icons.info_outline, Colors.orange);
                } else {
                  _showEditExpenseSheet(doc);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Color(0xFFFF453A)),
              title: const Text('Hapus Data', style: TextStyle(color: Color(0xFFFF453A), fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context); 
                _confirmDelete(doc);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text('Hapus Data?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Data ini akan dihapus permanen. Total pendapatan dan target bulanan akan disesuaikan otomatis.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await doc.reference.delete();
              if (mounted) {
                Navigator.pop(context);
                _showSuccessSnackBar("Data berhasil dihapus!", Icons.delete_outline, const Color(0xFFFF453A));
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Color(0xFFFF453A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditIncomeSheet(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    int savedCash = data.containsKey('cash') ? data['cash'] : data['gross'];
    int savedQris = data.containsKey('qris') ? data['qris'] : 0;
    int savedRent = data.containsKey('rent') ? data['rent'] : defaultRentFee;
    int savedSalary = data.containsKey('salary') ? data['salary'] : defaultSalaryFee;

    final TextEditingController cashController = TextEditingController(text: savedCash > 0 ? savedCash.toString() : "");
    final TextEditingController qrisController = TextEditingController(text: savedQris > 0 ? savedQris.toString() : "");
    final TextEditingController rentController = TextEditingController(text: savedRent.toString());
    final TextEditingController salaryController = TextEditingController(text: savedSalary.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Edit Data Jualan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),
            
            TextField(
              controller: cashController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: "Uang Tunai / Cash (Rp)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                prefixIcon: const Icon(Icons.payments_outlined, color: Colors.greenAccent),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qrisController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: "QRIS / Bank / GoFood (Rp)", 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                prefixIcon: const Icon(Icons.account_balance_wallet, color: Colors.blueAccent),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: rentController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: "Potongan Sewa",
                      labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: salaryController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: "Potongan Gaji",
                      labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  int cash = cashController.text.isNotEmpty ? int.parse(cashController.text) : 0;
                  int qris = qrisController.text.isNotEmpty ? int.parse(qrisController.text) : 0;
                  int gross = cash + qris;

                  if (gross > 0) {
                    int rent = rentController.text.isNotEmpty ? int.parse(rentController.text) : 0;
                    int salary = salaryController.text.isNotEmpty ? int.parse(salaryController.text) : 0;
                    int net = gross - (rent + salary);
                    
                    await doc.reference.update({
                      'gross': gross,
                      'cash': cash,
                      'qris': qris,
                      'rent': rent,
                      'salary': salary,
                      'net': net,
                    });
                    
                    if (mounted) {
                      Navigator.pop(context);
                      _showSuccessSnackBar("Perubahan jualan disimpan!", Icons.edit_note, Colors.blue);
                    }
                  }
                },
                child: const Text("Simpan Perubahan", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showEditExpenseSheet(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final TextEditingController nameController = TextEditingController(text: data['note']);
    final TextEditingController amountController = TextEditingController(text: data['amount'].toString());
    String paymentMethod = data.containsKey('paymentMethod') ? data['paymentMethod'] : 'cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Edit Pengeluaran", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Keterangan",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    prefixIcon: const Icon(Icons.receipt_long_outlined, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: "Total Pengeluaran (Rp)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    prefixIcon: const Icon(Icons.money_off, color: Colors.white70),
                  ),
                ),
                
                const SizedBox(height: 20),
                const Text("Ambil Uang Dari:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => paymentMethod = 'cash'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: paymentMethod == 'cash' ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: paymentMethod == 'cash' ? Colors.greenAccent : Colors.transparent),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.money, color: paymentMethod == 'cash' ? Colors.greenAccent : Colors.white54, size: 18),
                              const SizedBox(width: 8),
                              Text("Laci (Cash)", style: TextStyle(color: paymentMethod == 'cash' ? Colors.greenAccent : Colors.white54, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => paymentMethod = 'bank'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: paymentMethod == 'bank' ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: paymentMethod == 'bank' ? Colors.blueAccent : Colors.transparent),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_wallet, color: paymentMethod == 'bank' ? Colors.blueAccent : Colors.white54, size: 18),
                              const SizedBox(width: 8),
                              Text("Bank (QRIS)", style: TextStyle(color: paymentMethod == 'bank' ? Colors.blueAccent : Colors.white54, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      if (nameController.text.isNotEmpty && amountController.text.isNotEmpty) {
                        await doc.reference.update({
                          'note': nameController.text,
                          'amount': int.parse(amountController.text),
                          'paymentMethod': paymentMethod, 
                        });
                        if (mounted) {
                          Navigator.pop(context);
                          _showSuccessSnackBar("Perubahan pengeluaran disimpan!", Icons.edit_note, Colors.blue);
                        }
                      }
                    },
                    child: const Text("Simpan Perubahan", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        }
      ),
    );
  }

  void _showEditSalaryAdvanceSheet(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final TextEditingController nameController = TextEditingController(text: data['note']);
    final TextEditingController amountController = TextEditingController(text: data['amount'].toString());
    String paymentMethod = data.containsKey('paymentMethod') ? data['paymentMethod'] : 'cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Edit Kasbon Gaji", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Keterangan",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    prefixIcon: const Icon(Icons.badge, color: Colors.orangeAccent),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: "Total Gaji Diambil (Rp)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    prefixIcon: const Icon(Icons.request_quote, color: Colors.orangeAccent),
                  ),
                ),
                
                const SizedBox(height: 20),
                const Text("Ambil Uang Dari:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => paymentMethod = 'cash'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: paymentMethod == 'cash' ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: paymentMethod == 'cash' ? Colors.greenAccent : Colors.transparent),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.money, color: paymentMethod == 'cash' ? Colors.greenAccent : Colors.white54, size: 18),
                              const SizedBox(width: 8),
                              Text("Laci (Cash)", style: TextStyle(color: paymentMethod == 'cash' ? Colors.greenAccent : Colors.white54, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => paymentMethod = 'bank'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: paymentMethod == 'bank' ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: paymentMethod == 'bank' ? Colors.blueAccent : Colors.transparent),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_wallet, color: paymentMethod == 'bank' ? Colors.blueAccent : Colors.white54, size: 18),
                              const SizedBox(width: 8),
                              Text("Bank (QRIS)", style: TextStyle(color: paymentMethod == 'bank' ? Colors.blueAccent : Colors.white54, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      if (nameController.text.isNotEmpty && amountController.text.isNotEmpty) {
                        await doc.reference.update({
                          'note': nameController.text,
                          'amount': int.parse(amountController.text),
                          'paymentMethod': paymentMethod, 
                        });
                        if (mounted) {
                          Navigator.pop(context);
                          _showSuccessSnackBar("Perubahan kasbon disimpan!", Icons.edit_note, Colors.blue);
                        }
                      }
                    },
                    child: const Text("Simpan Perubahan", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 10))
        ]
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    bool isToday = selectedDate.year == now.year && selectedDate.month == now.month && selectedDate.day == now.day;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: GestureDetector(
          onLongPress: _showOwnerUnlockDialog,
          child: const Text("Roti Bakar Amang - Sultan adam", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned(
            top: -50, left: -100,
            child: Container(
              width: 300, height: 300,
              decoration: const BoxDecoration(color: Color(0xFF1E3A8A), shape: BoxShape.circle),
            ),
          ),
          Positioned(
            top: 200, right: -150,
            child: Container(
              width: 350, height: 350,
              decoration: const BoxDecoration(color: Color(0xFF4C1D95), shape: BoxShape.circle),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.transparent),
          ),
          
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: _transactionsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text("Gagal memuat data: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                    )
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }

                List<DocumentSnapshot> docs = snapshot.data?.docs.toList() ?? [];
                
                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = (aData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final bTime = (bData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                  return bTime.compareTo(aTime);
                });
                
                int monthlyNet = 0;
                int monthlyGross = 0;
                int monthlyCash = 0;
                int monthlyQris = 0;

                int dailyGross = 0;
                int dailyNet = 0;
                int dailyExpense = 0;
                int dailyCash = 0;
                int dailyQris = 0; 
                
                int rentCollected = 0;
                int salaryCollected = 0;
                int totalKasbon = 0; 
                int totalHoliday = 0; 
                List<DocumentSnapshot> dailyDocs = [];

                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final String type = data['type'] ?? 'income';
                  
                  if (type == 'expense') {
                    int expenseAmount = (data['amount'] as num).toInt();
                    bool isPersonal = data['isPersonalFund'] ?? false;

                    if (!isPersonal) {
                      monthlyNet -= expenseAmount; 
                      String method = data.containsKey('paymentMethod') ? data['paymentMethod'] : 'cash';
                      if (method == 'bank') {
                        monthlyQris -= expenseAmount;
                      } else {
                        monthlyCash -= expenseAmount;
                      }
                    }

                    if (data['dateKey'] == currentDateKey) {
                      dailyDocs.add(doc);
                      dailyExpense += expenseAmount; 
                      
                      if (!isPersonal) {
                        dailyNet -= expenseAmount;
                        String method = data.containsKey('paymentMethod') ? data['paymentMethod'] : 'cash';
                        if (method == 'bank') {
                          dailyQris -= expenseAmount;
                        } else {
                          dailyCash -= expenseAmount;
                        }
                      }
                    }
                  } 
                  else if (type == 'salary_advance') {
                    int advanceAmount = (data['amount'] as num).toInt();
                    totalKasbon += advanceAmount; 
                    
                    String method = data.containsKey('paymentMethod') ? data['paymentMethod'] : 'cash';
                    if (method == 'bank') {
                      monthlyQris -= advanceAmount;
                    } else {
                      monthlyCash -= advanceAmount;
                    }

                    if (data['dateKey'] == currentDateKey) {
                      dailyDocs.add(doc);
                      dailyExpense += advanceAmount; 
                      if (method == 'bank') {
                        dailyQris -= advanceAmount;
                      } else {
                        dailyCash -= advanceAmount;
                      }
                    }
                  } 
                  else if (type == 'holiday') {
                    totalHoliday += 1; 
                    int holidayRent = data.containsKey('rent') ? (data['rent'] as num).toInt() : 0;
                    
                    monthlyNet -= holidayRent;
                    rentCollected += holidayRent;

                    if (data['dateKey'] == currentDateKey) {
                      dailyDocs.add(doc);
                      dailyNet -= holidayRent;
                    }
                  }
                  else {
                    monthlyNet += (data['net'] as num).toInt();
                    monthlyGross += (data['gross'] as num).toInt(); 
                    
                    int c = data.containsKey('cash') ? (data['cash'] as num).toInt() : (data['gross'] as num).toInt();
                    int q = data.containsKey('qris') ? (data['qris'] as num).toInt() : 0;
                    monthlyCash += c;
                    monthlyQris += q;
                    
                    int savedRent = data.containsKey('rent') ? (data['rent'] as num).toInt() : defaultRentFee;
                    int savedSalary = data.containsKey('salary') ? (data['salary'] as num).toInt() : defaultSalaryFee;
                    
                    rentCollected += savedRent;
                    salaryCollected += savedSalary;

                    if (data['dateKey'] == currentDateKey) {
                      dailyDocs.add(doc);
                      dailyGross += (data['gross'] as num).toInt();
                      dailyNet += (data['net'] as num).toInt();
                      
                      int dc = data.containsKey('cash') ? (data['cash'] as num).toInt() : (data['gross'] as num).toInt();
                      int dq = data.containsKey('qris') ? (data['qris'] as num).toInt() : 0;
                      dailyCash += dc;
                      dailyQris += dq;
                    }
                  }
                }

                // --- LOGIKA TARGET TERPISAH (OTOMATIS BERUBAH) ---
                int rentTarget = _cycleIndex == 0 ? 500000 : 700000; 
                double rentProgress = rentTarget > 0 ? (rentCollected / rentTarget) : 1.0;
                if (rentProgress > 1.0) rentProgress = 1.0;

                int baseSalaryTarget = 30 * defaultSalaryFee; 
                int currentSalaryTarget = baseSalaryTarget - totalKasbon - (totalHoliday * defaultSalaryFee);
                if (currentSalaryTarget < 0) currentSalaryTarget = 0;
                
                double salaryProgress = currentSalaryTarget > 0 ? (salaryCollected / currentSalaryTarget) : 1.0;
                if (salaryProgress > 1.0) salaryProgress = 1.0;

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  children: [
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text("DUIT BERSIH PERIODE INI", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          const SizedBox(height: 8),
                          Text(
                            formatCurrency.format(monthlyNet), 
                            style: TextStyle(
                              color: monthlyNet >= 0 ? Colors.white : const Color(0xFFFF453A), 
                              fontSize: 38, 
                              fontWeight: FontWeight.w900, 
                              letterSpacing: -1
                            )
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9F0A).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.payments_outlined, color: Color(0xFFFF9F0A), size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  "Kotor: ${formatCurrency.format(monthlyGross)}",
                                  style: const TextStyle(color: Color(0xFFFF9F0A), fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.money, color: Colors.greenAccent, size: 12),
                                    const SizedBox(width: 4),
                                    Text("Laci: ${formatCurrency.format(monthlyCash)}", style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.account_balance_wallet, color: Colors.blueAccent, size: 12),
                                    const SizedBox(width: 4),
                                    Text("Bank: ${formatCurrency.format(monthlyQris)}", style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          Text(periodText, style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildGlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Target Sewa Lapak", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(
                                rentCollected >= rentTarget ? "Tercapai! 🎉" : "${((rentCollected / rentTarget) * 100).toStringAsFixed(1)}%",
                                style: TextStyle(
                                  color: rentCollected >= rentTarget ? const Color(0xFF32D74B) : const Color(0xFFFF9F0A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: rentProgress,
                              minHeight: 8,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                rentCollected >= rentTarget ? const Color(0xFF32D74B) : const Color(0xFFFF9F0A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(formatCurrency.format(rentCollected), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                              Text("/ ${formatCurrency.format(rentTarget)}", style: const TextStyle(color: Colors.white54, fontSize: 13)), 
                            ],
                          ),
                          
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(color: Colors.white24, height: 1),
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Target Gaji Pegawai", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(
                                salaryCollected >= currentSalaryTarget ? "Tercapai! 🎉" : "${((salaryCollected / currentSalaryTarget) * 100).toStringAsFixed(1)}%",
                                style: TextStyle(
                                  color: salaryCollected >= currentSalaryTarget ? const Color(0xFF32D74B) : const Color(0xFFFF9F0A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: salaryProgress,
                              minHeight: 8,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                salaryCollected >= currentSalaryTarget ? const Color(0xFF32D74B) : const Color(0xFFFF9F0A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(formatCurrency.format(salaryCollected), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                              Text("/ ${formatCurrency.format(currentSalaryTarget)}", style: const TextStyle(color: Colors.white54, fontSize: 13)), 
                            ],
                          ),
                          if (totalHoliday > 0 || totalKasbon > 0) ...[
                            const SizedBox(height: 8),
                            if (totalHoliday > 0)
                              Text("* Target Gaji dikurangi ${totalHoliday}x Libur (-${formatCurrency.format(totalHoliday * defaultSalaryFee)})", style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.w500)),
                            if (totalKasbon > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text("* Target Gaji dikurangi Kasbon (-${formatCurrency.format(totalKasbon)})", style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.w500)),
                              ),
                          ]
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => changeDate(-1), 
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20)
                        ),
                        Column(
                          children: [
                            const Text("Rincian Harian", style: TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              isToday ? "Hari Ini" : DateFormat('EEEE, d MMM', 'id_ID').format(selectedDate), 
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: isToday ? null : () => changeDate(1), 
                          icon: Icon(Icons.arrow_forward_ios, color: isToday ? Colors.white.withValues(alpha: 0.2) : Colors.white, size: 20)
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildGlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  const Text("Jualan Kotor", style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  const SizedBox(height: 8),
                                  Text(formatCurrency.format(dailyGross), style: const TextStyle(color: Color(0xFFFF9F0A), fontWeight: FontWeight.w800, fontSize: 15)),
                                ],
                              ),
                              Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.2)),
                              Column(
                                children: [
                                  const Text("Perubahan Kas", style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  const SizedBox(height: 8),
                                  Text(
                                    dailyNet >= 0 ? "+${formatCurrency.format(dailyNet)}" : formatCurrency.format(dailyNet), 
                                    style: TextStyle(color: dailyNet >= 0 ? const Color(0xFF32D74B) : const Color(0xFFFF453A), fontWeight: FontWeight.w800, fontSize: 15)
                                  ),
                                ],
                              ),
                              Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.2)),
                              Column(
                                children: [
                                  const Text("Pengeluaran", style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  const SizedBox(height: 8),
                                  Text(formatCurrency.format(dailyExpense), style: const TextStyle(color: Color(0xFFFF453A), fontWeight: FontWeight.w800, fontSize: 15)),
                                ],
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.money, color: Colors.greenAccent, size: 16),
                                    const SizedBox(width: 6),
                                    Text("Laci: ${formatCurrency.format(dailyCash)}", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Container(width: 1, height: 16, color: Colors.white.withValues(alpha: 0.2)),
                                Row(
                                  children: [
                                    const Icon(Icons.account_balance_wallet, color: Colors.blueAccent, size: 16), 
                                    const SizedBox(width: 6),
                                    Text("Bank: ${formatCurrency.format(dailyQris)}", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)), 
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Riwayat Tanggal Ini", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        if (dailyDocs.isNotEmpty)
                          Text("Ketuk riwayat untuk rincian", style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    dailyDocs.isEmpty ? 
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 30), 
                          child: Column(
                            children: [
                              Icon(Icons.hourglass_empty, size: 40, color: Colors.white.withValues(alpha: 0.3)),
                              const SizedBox(height: 12),
                              Text("Tidak ada jualan/pengeluaran.", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                            ],
                          )
                        )
                      ) 
                      : 
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: dailyDocs.length,
                        itemBuilder: (context, index) {
                          var doc = dailyDocs[index];
                          var data = doc.data() as Map<String, dynamic>;
                          String type = data['type'] ?? 'income';
                          bool isIncome = type == 'income';
                          bool isAdvance = type == 'salary_advance';
                          bool isHoliday = type == 'holiday';
                          bool isPersonal = data['isPersonalFund'] ?? false;
                          
                          int savedRent = data.containsKey('rent') ? (data['rent'] as num).toInt() : defaultRentFee;
                          int savedSalary = data.containsKey('salary') ? (data['salary'] as num).toInt() : defaultSalaryFee;
                          int totalPotongan = savedRent + savedSalary;
                          
                          int holidayRent = data.containsKey('rent') ? (data['rent'] as num).toInt() : 0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showDetailSheet(doc),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05), 
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.05))
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isIncome ? const Color(0xFF32D74B).withValues(alpha: 0.15) : (isAdvance ? Colors.orangeAccent.withValues(alpha: 0.15) : (isHoliday ? Colors.lightBlueAccent.withValues(alpha: 0.15) : (isPersonal ? Colors.amberAccent.withValues(alpha: 0.15) : const Color(0xFFFF453A).withValues(alpha: 0.15)))),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          isIncome ? Icons.trending_up : (isAdvance ? Icons.request_quote : (isHoliday ? Icons.event_busy : Icons.receipt_long_outlined)),
                                          color: isIncome ? const Color(0xFF32D74B) : (isAdvance ? Colors.orangeAccent : (isHoliday ? Colors.lightBlueAccent : (isPersonal ? Colors.amberAccent : const Color(0xFFFF453A)))),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isIncome ? "Hasil Jualan" : (isAdvance ? "Kasbon: ${data['note']}" : (isHoliday ? "Hari Libur Toko" : "${data['note']}")), 
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                              maxLines: 2, 
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            if (isIncome) Text("Dipotong ${formatCurrency.format(totalPotongan)}", style: const TextStyle(fontSize: 11, color: Colors.white54)),
                                            if (isHoliday) Text("Dipotong Sewa ${formatCurrency.format(holidayRent)}", style: const TextStyle(fontSize: 11, color: Colors.orangeAccent)),
                                            if (isPersonal) const Text("Dana Pribadi (Tidak Potong Saldo Usaha)", style: TextStyle(fontSize: 11, color: Colors.amberAccent)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isIncome ? "+${formatCurrency.format(data['gross'])}" : (isHoliday ? "-${formatCurrency.format(holidayRent)}" : "-${formatCurrency.format(data['amount'])}"),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900, 
                                          fontSize: 15,
                                          color: isIncome ? const Color(0xFF32D74B) : (isHoliday ? const Color(0xFFFF453A) : (isAdvance ? Colors.orangeAccent : (isPersonal ? Colors.amberAccent : const Color(0xFFFF453A))))
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      if (isOwner)
                                        IconButton(
                                          icon: const Icon(Icons.more_vert, color: Colors.white54, size: 22),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _showOptionsSheet(doc),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 100), 
                  ],
                );
              }
            ),
          ),
        ],
      ),
      floatingActionButton: isOwner 
      ? Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: "btn_holiday",
              backgroundColor: const Color(0xFF1C1C1E),
              elevation: 8,
              onPressed: _showInputHolidayDialog,
              child: const Icon(Icons.event_busy, color: Colors.lightBlueAccent),
            ),
            const SizedBox(height: 16),
            FloatingActionButton(
              heroTag: "btn_kasbon",
              backgroundColor: const Color(0xFF1C1C1E),
              elevation: 8,
              onPressed: _showInputSalaryAdvanceSheet,
              child: const Icon(Icons.request_quote, color: Colors.orangeAccent),
            ),
            const SizedBox(height: 16),
            FloatingActionButton(
              heroTag: "btn_expense",
              backgroundColor: const Color(0xFF1C1C1E),
              elevation: 8,
              onPressed: _showInputExpenseSheet,
              child: const Icon(Icons.remove_circle_outline, color: Color(0xFFFF453A)),
            ),
            const SizedBox(height: 16),
            FloatingActionButton.extended(
              heroTag: "btn_income",
              backgroundColor: Colors.white,
              elevation: 10,
              onPressed: _showInputIncomeSheet,
              icon: const Icon(Icons.add, color: Colors.black, size: 24),
              label: const Text("Input Jualan", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
            ),
          ],
        )
      : null, 
    );
  }
}