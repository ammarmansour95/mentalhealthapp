import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Therapeutic Green-to-Blue Color Palette
  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color primaryTealLight = Color(0xFF14B8A6);
  static const Color primaryTealDark = Color(0xFF0F766E);
  
  static const Color oceanAzure = Color(0xFF0284C7); // Calming deep ocean blue
  static const Color softCyan = Color(0xFF0EA5E9);    // Soft sky cyan
  static const Color iceBlue = Color(0xFFE0F2FE);     // Gentle ice blue tint
  
  static const Color sageGreen = Color(0xFF10B981);   // Healing sage / emerald green
  static const Color sageGreenLight = Color(0xFFD1FAE5);
  static const Color healingMint = Color(0xFF14B8A6);
  
  static const Color slateNavy = Color(0xFF0F172A);
  static const Color slateDark = Color(0xFF1E293B);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateLight = Color(0xFFF1F5F9);
  
  // Minimal alert for cancellations / severe clinical triage
  static const Color alertRose = Color(0xFFF43F5E);
  static const Color alertRoseLight = Color(0xFFFFE4E6);
  
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: primaryTeal,
      secondary: oceanAzure,
      surface: surfaceWhite,
      error: alertRose,
    ),
    scaffoldBackgroundColor: backgroundLight,
    textTheme: GoogleFonts.cairoTextTheme().apply(
      bodyColor: slateNavy,
      displayColor: slateNavy,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceWhite,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: slateNavy),
      titleTextStyle: TextStyle(
        color: slateNavy,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceWhite,
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: slateLight, width: 1),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primaryTeal,
      inactiveTrackColor: primaryTeal.withOpacity(0.15),
      thumbColor: primaryTeal,
      overlayColor: primaryTeal.withOpacity(0.12),
      trackHeight: 6,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceWhite,
      elevation: 6,
      selectedItemColor: primaryTeal,
      unselectedItemColor: slateMuted,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      unselectedLabelStyle: TextStyle(fontSize: 11),
      type: BottomNavigationBarType.fixed,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceWhite,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: primaryTeal, width: 1.8),
      ),
    ),
  );
}
