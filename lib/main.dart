import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Wajib dipanggil untuk inisialisasi bahasa Indonesia pada kalender/tanggal
  await initializeDateFormatting('id_ID', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keuangan Roti Bakar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark, // Kita gunakan tema gelap untuk efek Aurora
        scaffoldBackgroundColor: const Color(0xFF040D21), // Latar belakang biru sangat gelap
        textTheme: GoogleFonts.montserratTextTheme(
          ThemeData.dark().textTheme,
        ).copyWith(
          // Membuat default font menjadi lebih tebal (Semi-Bold)
          bodyLarge: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          bodyMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          titleLarge: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}