import 'package:flutter/material.dart';

/// Premium FinTech color palette inspired by modern trading apps.
/// Clean neutral surfaces with green/blue accents for trust and clarity.
class PremiumColors {
  // Background (ultra-clean modern slate-white)
  static const deepDark = Color(0xFFF8FAFC); // Slate 50
  static const cardBg = Color(0xFFFFFFFF); // Pure White
  static const surfaceBg = Color(0xFFF1F5F9); // Slate 100

  // Accents (curated, harmonious high-end Indigo, Cobalt, and Teal)
  static const neonTeal = Color(0xFF6366F1); // Indigo
  static const softPurple = Color(0xFF4F46E5); // Deep Indigo
  static const electricBlue = Color(0xFF3B82F6); // Vibrant Blue

  // Status Colors (modern emerald, ruby/rose, amber, and cyan)
  static const profit = Color(0xFF10B981); // Emerald Green
  static const loss = Color(0xFFF43F5E); // Rose/Red
  static const warning = Color(0xFFF59E0B); // Amber
  static const info = Color(0xFF06B6D4); // Cyan

  // Text
  static const textPrimary = Color(0xFF0F172A); // Slate 900
  static const textSecondary = Color(0xFF334155); // Slate 700
  static const textMuted = Color(0xFF64748B); // Slate 500
  static const textOnAccent = Color(0xFFFFFFFF);

  // Overlays & Dividers
  static const overlay = Color(0x1F6366F1); // 12% Indigo
  static const divider = Color(0x0F0F172A); // 6% Slate 900
  static const glassBg = Color(0xCCFFFFFF); // 80% Glass White

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF818CF8), neonTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF6366F1), softPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient profitGradient = LinearGradient(
    colors: [Color(0xFF34D399), profit],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lossGradient = LinearGradient(
    colors: [Color(0xFFFB7185), loss],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Premium Typography System
class PremiumTypography {
  // Font Families
  static const String primaryFont = 'Inter';
  static const String numericFont = 'JetBrainsMono';
  static const String headingFont = 'Satoshi';

  // Text Styles
  static const TextStyle h1 = TextStyle(
    fontFamily: headingFont,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: PremiumColors.textPrimary,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: headingFont,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: PremiumColors.textPrimary,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: primaryFont,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: PremiumColors.textPrimary,
  );

  static const TextStyle body1 = TextStyle(
    fontFamily: primaryFont,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: PremiumColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle body2 = TextStyle(
    fontFamily: primaryFont,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: PremiumColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: primaryFont,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: PremiumColors.textMuted,
  );

  // Numeric Styles (for prices, percentages)
  static const TextStyle priceSmall = TextStyle(
    fontFamily: numericFont,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: PremiumColors.textPrimary,
  );

  static const TextStyle priceMedium = TextStyle(
    fontFamily: numericFont,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: PremiumColors.textPrimary,
  );

  static const TextStyle priceLarge = TextStyle(
    fontFamily: numericFont,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: PremiumColors.textPrimary,
  );
}

/// Premium Theme Configuration
class PremiumTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: PremiumColors.deepDark,
      primaryColor: PremiumColors.neonTeal,
      colorScheme: const ColorScheme.light(
        primary: PremiumColors.neonTeal,
        secondary: PremiumColors.softPurple,
        surface: PremiumColors.cardBg,
        error: PremiumColors.loss,
        onPrimary: PremiumColors.textOnAccent,
        onSecondary: PremiumColors.textPrimary,
        onSurface: PremiumColors.textPrimary,
      ),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: PremiumTypography.h2,
        iconTheme: IconThemeData(color: PremiumColors.textPrimary),
      ),

      // Card Theme
      cardTheme: const CardThemeData(
        color: PremiumColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PremiumColors.neonTeal,
          foregroundColor: PremiumColors.textOnAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: PremiumTypography.primaryFont,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PremiumColors.cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PremiumColors.neonTeal, width: 2),
        ),
        hintStyle: const TextStyle(
          color: PremiumColors.textMuted,
          fontFamily: PremiumTypography.primaryFont,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: PremiumColors.surfaceBg,
        labelStyle: const TextStyle(
          color: PremiumColors.textPrimary,
          fontFamily: PremiumTypography.primaryFont,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: PremiumColors.divider,
        thickness: 1,
        space: 1,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: PremiumColors.cardBg,
        selectedItemColor: PremiumColors.neonTeal,
        unselectedItemColor: PremiumColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: PremiumTypography.primaryFont,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: PremiumTypography.primaryFont,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: PremiumTypography.h1,
        displayMedium: PremiumTypography.h2,
        displaySmall: PremiumTypography.h3,
        bodyLarge: PremiumTypography.body1,
        bodyMedium: PremiumTypography.body2,
        bodySmall: PremiumTypography.caption,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF090D16),
      primaryColor: const Color(0xFF10B981),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF10B981),
        secondary: Color(0xFF6366F1),
        surface: Color(0xFF111827),
        error: Color(0xFFF43F5E),
      ),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: PremiumTypography.h2,
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // Card Theme
      cardTheme: const CardThemeData(
        color: Color(0xFF111827),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: const Color(0xFF090D16),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: PremiumTypography.primaryFont,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111827),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF6B7280),
          fontFamily: PremiumTypography.primaryFont,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1F2937),
        labelStyle: const TextStyle(
          color: Colors.white,
          fontFamily: PremiumTypography.primaryFont,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: Color(0x0FFFFFFF),
        thickness: 1,
        space: 1,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF111827),
        selectedItemColor: Color(0xFF10B981),
        unselectedItemColor: Color(0xFF6B7280),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: PremiumTypography.primaryFont,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: PremiumTypography.primaryFont,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: PremiumTypography.h1,
        displayMedium: PremiumTypography.h2,
        displaySmall: PremiumTypography.h3,
        bodyLarge: PremiumTypography.body1,
        bodyMedium: PremiumTypography.body2,
        bodySmall: PremiumTypography.caption,
      ),
    );
  }
}

/// Premium UI Constants
class PremiumUI {
  // Spacing
  static const double spacingXS = 4;
  static const double spacingS = 8;
  static const double spacingM = 16;
  static const double spacingL = 24;
  static const double spacingXL = 32;

  // Border Radius
  static const double radiusS = 8;
  static const double radiusM = 12;
  static const double radiusL = 16;
  static const double radiusXL = 20;
  static const double radiusRound = 100;

  // Icon Sizes
  static const double iconS = 16;
  static const double iconM = 20;
  static const double iconL = 24;
  static const double iconXL = 32;

  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // Glassmorphism Effect
  static BoxDecoration glassCard({double blur = 10}) {
    return BoxDecoration(
      color: PremiumColors.glassBg,
      borderRadius: BorderRadius.circular(radiusXL),
      border: Border.all(color: PremiumColors.overlay, width: 1),
    );
  }

  // Soft Shadow
  static List<BoxShadow> softShadow({Color? color}) {
    return [
      BoxShadow(
        color: (color ?? PremiumColors.textPrimary).withValues(alpha: 0.08),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ];
  }
}
