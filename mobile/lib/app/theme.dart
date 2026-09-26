import 'package:flutter/material.dart';

/// Палитра приложения.
///
/// Тёмная тема выбрана осознанно: тренажёр запускают в депо и в поезде,
/// часто при слабом освещении, а красный акцент РЖД на тёмном фоне читается
/// лучше, чем на светлом.
abstract final class VsmColors {
  static const background = Color(0xFF080D1A);
  static const surface = Color(0xFF121A2E);
  static const surfaceHigh = Color(0xFF1B2540);
  static const stroke = Color(0xFF263252);

  /// Фирменный красный РЖД — основной акцент и цвет действия.
  static const brand = Color(0xFFE4222B);
  static const brandDim = Color(0xFF8E1520);

  /// Шкала «лояльность пассажира».
  static const loyalty = Color(0xFFFFB020);

  /// Шкала «рейтинг безопасности».
  static const safety = Color(0xFF21C7A8);

  static const textPrimary = Color(0xFFF2F5FA);
  static const textSecondary = Color(0xFF8D9AB8);
  static const textMuted = Color(0xFF5C688B);

  static const danger = Color(0xFFFF4D5E);
  static const success = Color(0xFF21C7A8);
  static const warning = Color(0xFFFFB020);
}

/// Единые радиусы и отступы, чтобы экраны не разъезжались по стилю.
abstract final class VsmSpacing {
  static const cardRadius = 20.0;
  static const chipRadius = 12.0;
  static const screenPadding = 20.0;
}

/// Градиенты вынесены в тему, а не разбросаны по виджетам:
/// поменять «фирменный вид» приложения можно в одном месте.
abstract final class VsmGradients {
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE4222B), Color(0xFF8E1520)],
  );

  static const speed = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B2540), Color(0xFF0D1426)],
  );

  static const glass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x14FFFFFF), Color(0x05FFFFFF)],
  );
}

ThemeData buildVsmTheme() {
  const scheme = ColorScheme.dark(
    primary: VsmColors.brand,
    onPrimary: Colors.white,
    secondary: VsmColors.safety,
    onSecondary: Color(0xFF00201A),
    surface: VsmColors.surface,
    onSurface: VsmColors.textPrimary,
    error: VsmColors.danger,
    onError: Colors.white,
  );

  final base = ThemeData.from(colorScheme: scheme, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: VsmColors.background,
    splashFactory: InkSparkle.splashFactory,
    textTheme: base.textTheme
        .apply(
          bodyColor: VsmColors.textPrimary,
          displayColor: VsmColors.textPrimary,
        )
        .copyWith(
          displaySmall: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: VsmColors.textPrimary,
          ),
          headlineSmall: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: VsmColors.textPrimary,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: VsmColors.textPrimary,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: VsmColors.textPrimary,
          ),
          bodySmall: const TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: VsmColors.textSecondary,
          ),
          labelSmall: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: VsmColors.textMuted,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: VsmColors.textPrimary,
      ),
      iconTheme: IconThemeData(color: VsmColors.textPrimary),
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
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: VsmColors.textPrimary,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: VsmColors.stroke),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: VsmColors.surface,
      indicatorColor: VsmColors.brand.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      height: 68,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: VsmColors.surfaceHigh,
      contentTextStyle: const TextStyle(color: VsmColors.textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
