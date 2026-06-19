import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF059669);
  static const Color primaryDark = Color(0xFF064E3B);
  static const Color secondary = Color(0xFF10B981);
  static const Color primaryContainer = Color(0xFFD1FAE5);
  static const Color softGreen = Color(0xFFA7F3D0);
  static const Color lightGreen = Color(0xFFECFDF5);
  static const Color surface = Color(0xFFF8F9FF);
  static const Color surfaceLow = Color(0xFFF1F5F3);
  static const Color white = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF1F2937);
  static const Color greyText = Color(0xFF6B7280);
  static const Color outline = Color(0xFFE5E7EB);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF3B82F6);
  static const Color orange = Color(0xFFF59E0B);

  static const double radius = 8;
  static const double cardRadius = 16;

  static ThemeData get theme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
          primary: primary,
          secondary: secondary,
          surface: white,
          error: error,
        ).copyWith(
          primaryContainer: primaryContainer,
          onPrimaryContainer: primaryDark,
          surfaceContainerLowest: white,
          surfaceContainerLow: surfaceLow,
          outline: outline,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      fontFamily: 'PlusJakartaSans',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: darkText,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkText,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: darkText,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: darkText,
          height: 1.45,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: greyText,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: darkText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'PlusJakartaSans',
          color: darkText,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLow,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        prefixIconColor: primaryDark,
        suffixIconColor: primaryDark,
        prefixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          color: greyText,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          color: greyText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: white,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          disabledBackgroundColor: primary.withAlpha(105),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: primary),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: white,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: primaryDark),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: white,
        indicatorColor: primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: states.contains(WidgetState.selected)
                ? primaryDark
                : greyText,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(color: outline, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: primaryDark,
        contentTextStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          color: white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
    );
  }

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF047857), Color(0xFF059669), Color(0xFF10B981)],
  );

  static BoxDecoration cardDecoration({
    Color color = white,
    double borderRadius = cardRadius,
    bool bordered = false,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: bordered ? Border.all(color: outline) : null,
      boxShadow: [
        BoxShadow(
          color: primaryDark.withAlpha(10),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
