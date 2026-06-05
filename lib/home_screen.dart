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
  
  // Nilai default, tapi sekarang akan disimpan dinamis ke database
  final int defaultRentFee = 17000;
  final int defaultSalaryFee = 40000;
  final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  // Variabel untuk menyimpan tanggal yang sedang dilihat
  DateTime selectedDate = DateTime.now();
  Stream<QuerySnapshot>? _transactionsStream;
  String _lastCycleKey = "";

  // LOGIKA BARU: Siklus Bulanan Dimulai Setiap Tanggal 4
  String get currentCycleKey {
    if (selectedDate.day >= 4) {
      return "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}";
    } else {
      DateTime prevMonth = DateTime(selectedDate.year, selectedDate.month - 1, 1);
      return "${prevMonth.year}-${prevMonth.month.toString().padLeft(2, '0')}";
    }
  }

  // Menampilkan Teks Periode (Contoh: 4 Jun - 3 Jul 2026)
  String get periodText {
    DateTime start;
    DateTime end;
    if (selectedDate.day >= 4) {
      start = DateTime(selectedDate.year, selectedDate.month, 4);
      end = DateTime(selectedDate.year, selectedDate.month + 1, 3);
    } else {
      start = DateTime(selectedDate.year, selectedDate.month - 1, 4);
      end = DateTime(selectedDate.year, selectedDate.month, 3);
    }
    return "${DateFormat('d MMM', 'id_ID').format(start)} - ${DateFormat('d MMM yyyy', 'id_ID').format(end)}";
  }
  
  String get currentDateKey => "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

  @override
  void initState() {
    super.initState();
    _setupStream(); 
  }

  void _setupStream() {
    _lastCycleKey = currentCycleKey;
    _transactionsStream = _firestore
        .collection('transactions')
        .where('monthKey', isEqualTo: _lastCycleKey)
        .snapshots();
  }

  void changeDate(int days) {
    DateTime newDate = selectedDate.add(Duration(days: days));
    DateTime now = DateTime.now();
    
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime dateToCheck = DateTime(newDate.year, newDate.month, newDate.day);
    DateTime startDate = DateTime(2026, 6, 4); // Batas Hari Pertama Jualan
    
    if (dateToCheck.isAfter(today)) return;
    
    if (dateToCheck.isBefore(startDate)) {
      _showSuccessSnackBar("Data sebelum 4 Juni 2026 tidak tersedia (Hari pertama buka).", Icons.info_outline, Colors.blue);
      return;
    }

    setState(() {
      selectedDate = newDate;
      if (currentCycleKey != _lastCycleKey) {
        _setupStream();
      }
    });
  }

  void _showSuccessSnackBar(String message, IconData icon, Color color) {
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

  // --- FITUR BARU: TAMPILAN DETAIL TRANSAKSI ---
  void _showDetailSheet(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    bool isIncome = data['type'] == 'income';
    
    // Format Waktu Transaksi
    String timeString = "";
    if (data['timestamp'] != null) {
      DateTime ts = (data['timestamp'] as Timestamp).toDate();
      timeString = DateFormat('EEEE, d MMMM yyyy - HH:mm', 'id_ID').format(ts);
    }

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
                Icon(isIncome ? Icons.trending_up : Icons.receipt_long, color: isIncome ? const Color(0xFF32D74B) : const Color(0xFFFF453A), size: 28),
                const SizedBox(width: 12),
                Text(isIncome ? "Detail Pemasukan" : "Detail Pengeluaran", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 24),
            
            // Keterangan Penuh
            const Text("Keterangan", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              isIncome ? "Hasil Jualan Harian" : "${data['note']}",
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
            ),
            const SizedBox(height: 16),
            
            // Waktu
            const Text("Waktu Input", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            Text(timeString.isNotEmpty ? timeString : "Waktu tidak diketahui", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),

            // Rincian Angka
            if (isIncome) ...[
              _buildDetailRow("Uang Kotor (Masuk)", formatCurrency.format(data['gross']), Colors.white),
              const SizedBox(height: 8),
              _buildDetailRow("Potongan Sewa", "- ${formatCurrency.format(data.containsKey('rent') ? data['rent'] : defaultRentFee)}", Colors.orange),
              const SizedBox(height: 8),
              _buildDetailRow("Potongan Gaji", "- ${formatCurrency.format(data.containsKey('salary') ? data['salary'] : defaultSalaryFee)}", Colors.orange),
              const SizedBox(height: 12),
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              _buildDetailRow("Duit Sendiri (Bersih)", formatCurrency.format(data['net']), const Color(0xFF32D74B), isBold: true),
            ] else ...[
              _buildDetailRow("Total Pengeluaran", formatCurrency.format(data['amount']), const Color(0xFFFF453A), isBold: true),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Widget Bantuan untuk Rincian Angka di Detail
  Widget _buildDetailRow(String label, String value, Color valueColor, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.white70, fontSize: isBold ? 16 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(color: valueColor, fontSize: isBold ? 18 : 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showInputIncomeSheet() {
    final TextEditingController incomeController = TextEditingController();
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
              controller: incomeController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: "Total Uang Masuk Kotor (Rp)",
                hintText: "Contoh: 187000",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontWeight: FontWeight.normal),
                labelStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                prefixIcon: const Icon(Icons.payments_outlined, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),
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
                      fillColor: Colors.white.withOpacity(0.05),
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
                      fillColor: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "*Anda bisa mengedit potongan jika gaji/sewa hari ini berbeda.",
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
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
                  if (incomeController.text.isNotEmpty) {
                    int gross = int.parse(incomeController.text);
                    int rent = rentController.text.isNotEmpty ? int.parse(rentController.text) : 0;
                    int salary = salaryController.text.isNotEmpty ? int.parse(salaryController.text) : 0;
                    
                    int net = gross - (rent + salary);
                    
                    await _firestore.collection('transactions').add({
                      'type': 'income',
                      'gross': gross,
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
            Text("Catat Pengeluaran:\n$displayDate", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Keterangan (Cth: Beli Roti, Plastik, dll)",
                labelStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
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
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontWeight: FontWeight.normal),
                labelStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                prefixIcon: const Icon(Icons.money_off, color: Colors.white70),
              ),
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
                    await _firestore.collection('transactions').add({
                      'type': 'expense',
                      'note': nameController.text,
                      'amount': int.parse(amountController.text),
                      'monthKey': currentCycleKey,
                      'dateKey': currentDateKey,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      _showSuccessSnackBar("Pengeluaran berhasil disimpan!", Icons.check_circle, const Color(0xFFFF453A));
                    }
                  }
                },
                child: const Text("Simpan Pengeluaran", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
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
                if (data['type'] == 'income') {
                  _showEditIncomeSheet(doc);
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
    final TextEditingController incomeController = TextEditingController(text: data['gross'].toString());
    
    int savedRent = data.containsKey('rent') ? data['rent'] : defaultRentFee;
    int savedSalary = data.containsKey('salary') ? data['salary'] : defaultSalaryFee;
    
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
              controller: incomeController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: "Total Uang Masuk Kotor (Rp)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                prefixIcon: const Icon(Icons.payments_outlined, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),
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
                      fillColor: Colors.white.withOpacity(0.05),
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
                      fillColor: Colors.white.withOpacity(0.05),
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
                  if (incomeController.text.isNotEmpty) {
                    int gross = int.parse(incomeController.text);
                    int rent = rentController.text.isNotEmpty ? int.parse(rentController.text) : 0;
                    int salary = salaryController.text.isNotEmpty ? int.parse(salaryController.text) : 0;
                    
                    int net = gross - (rent + salary);
                    
                    await doc.reference.update({
                      'gross': gross,
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
            const Text("Edit Pengeluaran", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Keterangan",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
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
                fillColor: Colors.white.withOpacity(0.1),
                prefixIcon: const Icon(Icons.money_off, color: Colors.white70),
              ),
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
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 10))
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
        title: const Text("Roti Bakar Amang - Sultan adam", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
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
                int monthlyGross = 0; // TAMBAHAN: Variabel Uang Kotor Sebulan
                int dailyGross = 0;
                int dailyNet = 0;
                int dailyExpense = 0;
                int fixedCostCollected = 0;
                List<DocumentSnapshot> dailyDocs = [];

                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final bool isExpense = data['type'] == 'expense';
                  
                  if (isExpense) {
                    monthlyNet -= (data['amount'] as num).toInt();
                  } else {
                    monthlyNet += (data['net'] as num).toInt();
                    monthlyGross += (data['gross'] as num).toInt(); // TAMBAHAN: Menghitung uang kotor periode ini
                    
                    int savedRent = data.containsKey('rent') ? (data['rent'] as num).toInt() : defaultRentFee;
                    int savedSalary = data.containsKey('salary') ? (data['salary'] as num).toInt() : defaultSalaryFee;
                    
                    fixedCostCollected += (savedRent + savedSalary);
                  }

                  if (data['dateKey'] == currentDateKey) {
                    dailyDocs.add(doc);
                    if (isExpense) {
                      dailyExpense += (data['amount'] as num).toInt();
                      dailyNet -= (data['amount'] as num).toInt();
                    } else {
                      dailyGross += (data['gross'] as num).toInt();
                      dailyNet += (data['net'] as num).toInt();
                    }
                  }
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  children: [
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text("DUIT BERSIH PERIODE INI", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
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
                          // --- TAMBAHAN: Chip Uang Kotor Bulanan ---
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9F0A).withOpacity(0.15),
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
                          // --- SELESAI TAMBAHAN ---
                          const SizedBox(height: 12),
                          Text(periodText, style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- KARTU TARGET BULANAN ---
                    _buildGlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Target Sewa & Gaji (Siklus 4)", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(
                                fixedCostCollected >= 1700000 ? "Tercapai! 🎉" : "${((fixedCostCollected / 1700000) * 100).toStringAsFixed(1)}%",
                                style: TextStyle(
                                  color: fixedCostCollected >= 1700000 ? const Color(0xFF32D74B) : const Color(0xFFFF9F0A),
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
                              value: (fixedCostCollected / 1700000) > 1.0 ? 1.0 : (fixedCostCollected / 1700000),
                              minHeight: 8,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                fixedCostCollected >= 1700000 ? const Color(0xFF32D74B) : const Color(0xFFFF9F0A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(formatCurrency.format(fixedCostCollected), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                              Text("/ Rp1.700.000", style: const TextStyle(color: Colors.white54, fontSize: 13)),
                            ],
                          ),
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
                          icon: Icon(Icons.arrow_forward_ios, color: isToday ? Colors.white.withOpacity(0.2) : Colors.white, size: 20)
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildGlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              const Text("Jualan Kotor", style: TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(height: 8),
                              Text(formatCurrency.format(dailyGross), style: const TextStyle(color: Color(0xFFFF9F0A), fontWeight: FontWeight.w800, fontSize: 15)),
                            ],
                          ),
                          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
                          Column(
                            children: [
                              const Text("Duit Sendiri", style: TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(height: 8),
                              Text(formatCurrency.format(dailyNet), style: const TextStyle(color: Color(0xFF32D74B), fontWeight: FontWeight.w800, fontSize: 15)),
                            ],
                          ),
                          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
                          Column(
                            children: [
                              const Text("Pengeluaran", style: TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(height: 8),
                              Text(formatCurrency.format(dailyExpense), style: const TextStyle(color: Color(0xFFFF453A), fontWeight: FontWeight.w800, fontSize: 15)),
                            ],
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
                          Text("Ketuk riwayat untuk rincian", style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    dailyDocs.isEmpty ? 
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 30), 
                          child: Column(
                            children: [
                              Icon(Icons.hourglass_empty, size: 40, color: Colors.white.withOpacity(0.3)),
                              const SizedBox(height: 12),
                              Text("Tidak ada jualan/pengeluaran.", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
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
                          bool isIncome = data['type'] == 'income';
                          
                          int savedRent = data.containsKey('rent') ? (data['rent'] as num).toInt() : defaultRentFee;
                          int savedSalary = data.containsKey('salary') ? (data['salary'] as num).toInt() : defaultSalaryFee;
                          int totalPotongan = savedRent + savedSalary;
                          
                          // InkWell digunakan agar kotak riwayat bisa disentuh/ditekan
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showDetailSheet(doc), // Membuka pop-up rincian detail
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05), 
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withOpacity(0.05))
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isIncome ? const Color(0xFF32D74B).withOpacity(0.15) : const Color(0xFFFF453A).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          isIncome ? Icons.trending_up : Icons.receipt_long_outlined,
                                          color: isIncome ? const Color(0xFF32D74B) : const Color(0xFFFF453A),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isIncome ? "Hasil Jualan" : "${data['note']}", 
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                              maxLines: 2, // Membatasi teks agar tidak merusak layout
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            if (isIncome) Text("Dipotong ${formatCurrency.format(totalPotongan)}", style: const TextStyle(fontSize: 11, color: Colors.white54)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isIncome ? "+${formatCurrency.format(data['gross'])}" : "-${formatCurrency.format(data['amount'])}",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900, 
                                          fontSize: 15,
                                          color: isIncome ? const Color(0xFF32D74B) : const Color(0xFFFF453A)
                                        ),
                                      ),
                                      const SizedBox(width: 4),
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
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
      ),
    );
  }
}