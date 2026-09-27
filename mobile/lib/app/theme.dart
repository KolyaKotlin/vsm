import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Палитра «та ВСМ: кремовые панели, дерево столика, красная ливрея.
///
/// Ориентир — интерьер вагона из датасета и фирменный красный РЖД,
/// а не тёмный «кибер»-интерфейс.
abstract final class VsmColors {
  static const background = Color(0xFFEDE6D9);
  static const surface = Color(0xFFFFFBF4);
  static const surfaceHigh = Color(0xFFF4EBE0);
  static const stroke = Color(0xFFD5C6B0);

  /// Красная полоса ливреи ВСМ / РЖД.
  static const brand = Color(0xFFC8102E);
  static const brandDim = Color(0xFF8E1022);

  /// Латунь табличек и поручней.
  static const brass = Color(0xFF9A7B4F);

  /// Шкала «лояльность пассажира» — тёплый свет салона.
  static const loyalty = Color(0xFFC4841D);

  /// Шкала «рейтинг безопасности» — зелёный сигнал.
  static const safety = Color(0xFF1F7A5C);

  static const textPrimary = Color(0xFF1A1F2C);
  static const textSecondary = Color(0xFF5C564C);
  static const textMuted = Color(0xFF8A8175);

  static const danger = Color(0xFFB42318);
  static const success = Color(0xFF1F7A5C);
  static const warning = Color(0xFFC4841D);

  /// Тёмная шапка табло / ливреи.
  static const livery = Color(0xFF1C2433);
}

abstract final class VsmSpacing {
  static const cardRadius = 12.0;
  static const chipRadius = 8.0;
  static const screenPadding = 20.0;
}

abstract final class VsmGradients {
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC8102E), Color(0xFF8E1022)],
  );

  static const livery = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2A3344), Color(0xFF1C2433)],
  );

  static const cabin = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF7F1E6), Color(0xFFEDE6D9)],
  );

  static const glass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x14FFFFFF), Color(0x05FFFFFF)],
  );

  /// Старое имя, чтобы карточки без явного градиента не ломались.
  static const speed = cabin;
}

ThemeData buildVsmTheme() {
  const scheme = ColorScheme.light(
    primary: VsmColors.brand,
    onPrimary: Colors.white,
    secondary: VsmColors.brass,
    onSecondary: Colors.white,
    surface: VsmColors.surface,
    onSurface: VsmColors.textPrimary,
    error: VsmColors.danger,
    onError: Colors.white,
  );

  final base = ThemeData.from(colorScheme: scheme, useMaterial3: true);
  final sans = GoogleFonts.ptSans;
  final serif = GoogleFonts.ptSerif;
  final textTheme = GoogleFonts.ptSansTextTheme(base.textTheme)
      .apply(
        bodyColor: VsmColors.textPrimary,
        displayColor: VsmColors.textPrimary,
      )
      .copyWith(
        displaySmall: serif(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.15,
          color: VsmColors.textPrimary,
        ),
        headlineSmall: serif(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: VsmColors.textPrimary,
        ),
        titleMedium: sans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.25,
          color: VsmColors.textPrimary,
        ),
        bodyMedium: sans(
          fontSize: 15,
          height: 1.45,
          color: VsmColors.textPrimary,
        ),
        bodySmall: sans(
          fontSize: 13,
          height: 1.4,
          color: VsmColors.textSecondary,
        ),
        labelSmall: sans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: VsmColors.textMuted,
        ),
      );

  return base.copyWith(
    scaffoldBackgroundColor: VsmColors.background,
    splashFactory: InkRipple.splashFactory,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: VsmColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: sans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: VsmColors.textPrimary,
      ),
      iconTheme: const IconThemeData(color: VsmColors.textPrimary),
    ),
    cardTheme: CardThemeData(
      color: VsmColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VsmSpacing.cardRadius),
        side: const BorderSide(color: VsmColors.stroke),
      ),
    ),
    dividerTheme: const DividerThemeData(color: VsmColors.stroke, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: VsmColors.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        textStyle: sans(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: VsmColors.textPrimary,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: VsmColors.stroke),
        textStyle: sans(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: VsmColors.brandDim,
        textStyle: sans(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: VsmColors.surface,
      indicatorColor: VsmColors.brand.withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      height: 70,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return sans(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? VsmColors.brand : VsmColors.textMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? VsmColors.brand : VsmColors.textMuted,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VsmColors.surfaceHigh,
      labelStyle: const TextStyle(color: VsmColors.textSecondary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: VsmColors.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: VsmColors.brand),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: VsmColors.livery,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  );
}
