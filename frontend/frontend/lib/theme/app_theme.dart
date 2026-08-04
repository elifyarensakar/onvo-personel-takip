import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Onvo marka renkleri.
///
/// Mavi tonları logodan birebir alınmıştır (#216093). Amber, tüm
/// uygulamada tek vurgu rengi olarak kullanılır (buton, odak durumu,
/// seçili durum) — fabrika ortamında dikkat çekici ama göz yormayan
/// bir kontrast sağlar.
class AppColors {
  AppColors._();

  static const Color onvoBlue = Color(0xFF216093);
  static const Color onvoBlueDeep = Color(0xFF123249);
  static const Color onvoBlueDeeper = Color(0xFF0B2233);

  static const Color amber = Color(0xFFF0A63C);
  static const Color amberDark = Color(0xFFC97F1E);

  static const Color ink = Color(0xFF16232D);
  static const Color muted = Color(0xFF7C8A96);
  static const Color mutedLight = Color(0xFFAEB9C2);
  static const Color line = Color(0xFFE7ECEF);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceTint = Color(0xFFF4F7F9);

  static const Color error = Color(0xFFD14D3F);
  static const Color errorTint = Color(0xFFFBEBE8);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [onvoBlueDeeper, onvoBlueDeep, onvoBlue],
    stops: [0.0, 0.4, 1.0],
  );

  static const LinearGradient screenBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDFE9F0), Color(0xFFC9D7E2)],
  );
}

/// Onvo tipografi ölçeği.
///
/// Başlıklarda Space Grotesk (logo harflerindeki geometrik/köşeli
/// karaktere yakın), gövde ve form elemanlarında okunabilirliği yüksek
/// Inter kullanılır.
class AppText {
  AppText._();

  static TextStyle get eyebrow => GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
        color: AppColors.amberDark,
      );

  static TextStyle get h1 => GoogleFonts.spaceGrotesk(
        fontSize: 25,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.2,
      );

  static TextStyle get subtext => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.muted,
        height: 1.45,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );

  static TextStyle get input => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
      );

  static TextStyle get errorMsg => GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: AppColors.error,
      );

  static TextStyle get button => GoogleFonts.inter(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: const Color(0xFF2B1B04),
      );

  static TextStyle get link => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.onvoBlue,
      );

  static TextStyle get footer => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.mutedLight,
        letterSpacing: 0.2,
      );

  static TextStyle get brandTag => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.2,
        color: Colors.white.withOpacity(0.62),
      );
}

/// Uygulama genelindeki ThemeData. main.dart içinde MaterialApp'e verilir.
ThemeData buildOnvoTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.surfaceTint,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.onvoBlue,
      primary: AppColors.onvoBlue,
      secondary: AppColors.amber,
    ),
    textTheme: GoogleFonts.interTextTheme(),
    fontFamily: GoogleFonts.inter().fontFamily,
  );
}
