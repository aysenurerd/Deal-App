import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';

void main() => runApp(const DealApp());

class DealApp extends StatelessWidget {
  const DealApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Deal App',
      theme: ThemeData.dark().copyWith(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1C1C1E), // Premium koyu arka plan
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFDD835), // Sarı/Altın vurgu rengi
          secondary: Color(0xFFFDD835),
          surface: Color(0xFF2C2C2E), // Kart yüzey rengi
          onSurface: Colors.white,
          onPrimary: Color(0xFF1C1C1E), // Sarı üzerine koyu yazı
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.dark().textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
        ).copyWith(
          headlineLarge: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 32,
            color: Colors.white,
          ),
          headlineMedium: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
          titleLarge: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1C1C1E),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1C1C1E),
          selectedItemColor: Color(0xFFFDD835), // Sarı seçili ikon
          unselectedItemColor: Colors.grey, // Gri seçili olmayan ikon
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
