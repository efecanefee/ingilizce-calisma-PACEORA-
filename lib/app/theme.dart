import 'package:flutter/material.dart';

/// Arayüz vurgu rengi seçenekleri. Her biri üç tondan oluşur:
/// [spark] koyu zeminde parlayan ana ton, [dim] ara ton, [dark] açık
/// zeminde okunabilen koyu ton. Grafit zemin her seçenekte aynı kalır.
enum AppAccent {
  lime('Lime', Color(0xFFC6F432), Color(0xFF9BC427), Color(0xFF5A7414)),
  ocean('Okyanus', Color(0xFF5EEAD4), Color(0xFF2DB5A3), Color(0xFF0F766E)),
  sky('Gökyüzü', Color(0xFF7DD3FC), Color(0xFF38A3E0), Color(0xFF0369A1)),
  sunset('Gün batımı', Color(0xFFFDBA74), Color(0xFFF59E0B), Color(0xFFC2410C)),
  lavender('Lavanta', Color(0xFFC4B5FD), Color(0xFFA78BFA), Color(0xFF6D28D9)),
  rose('Gül', Color(0xFFF9A8D4), Color(0xFFF472B6), Color(0xFFBE185D));

  const AppAccent(this.label, this.spark, this.dim, this.dark);

  final String label;
  final Color spark;
  final Color dim;
  final Color dark;

  static AppAccent fromName(String? name) => values.firstWhere(
    (a) => a.name == name,
    orElse: () => AppAccent.lime,
  );
}

/// Seçili vurgunun üç tonu; temaya uzantı olarak eklenir.
///
/// Widget'lar `context.pace.accent` ile okur. Tema değişince Theme'e bağlı
/// her widget yeniden çizildiği için renk her ekranda anında güncellenir.
@immutable
class PaceColors extends ThemeExtension<PaceColors> {
  const PaceColors({
    required this.accent,
    required this.accentDim,
    required this.accentDark,
  });

  PaceColors.of(AppAccent a)
    : accent = a.spark,
      accentDim = a.dim,
      accentDark = a.dark;

  static final fallback = PaceColors.of(AppAccent.lime);

  /// Koyu zeminde parlayan ana ton.
  final Color accent;

  /// Ara ton.
  final Color accentDim;

  /// Açık zeminde okunabilen koyu ton.
  final Color accentDark;

  @override
  PaceColors copyWith({Color? accent, Color? accentDim, Color? accentDark}) =>
      PaceColors(
        accent: accent ?? this.accent,
        accentDim: accentDim ?? this.accentDim,
        accentDark: accentDark ?? this.accentDark,
      );

  @override
  PaceColors lerp(PaceColors? other, double t) {
    if (other == null) return this;
    return PaceColors(
      accent: Color.lerp(accent, other.accent, t)!,
      accentDim: Color.lerp(accentDim, other.accentDim, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
    );
  }
}

extension PaceColorsContext on BuildContext {
  /// Etkin temanın vurgu tonları.
  PaceColors get pace =>
      Theme.of(this).extension<PaceColors>() ?? PaceColors.fallback;
}

/// Uygulamanın yazı tipleri (pubspec.yaml > fonts).
abstract class AppFonts {
  static const inter = 'Inter';
  static const emoji = 'Noto Color Emoji';
}

/// Paceora renk paleti: Graphite ve sabit marka/durum renkleri. Vurgu
/// renkleri için [PaceColors] kullanılır.
abstract class AppColors {
  // Marka renkleri: logo ve maskot her temada lime kalır.
  static const brandLime = Color(0xFFC6F432);
  static const brandLimeDark = Color(0xFF5A7414);

  // Graphite tonları
  static const graphite900 = Color(0xFF15171A);
  static const graphite800 = Color(0xFF1C1E22);
  static const graphite700 = Color(0xFF24272C);
  static const graphite600 = Color(0xFF2E3238);
  static const graphite400 = Color(0xFF6B7280);
  static const graphite200 = Color(0xFFD1D5DB);
  static const graphite100 = Color(0xFFE8EAED);
  static const graphite50 = Color(0xFFF7F8F9);

  // Seri ve ödül renkleri
  static const fire = Color(0xFFFF9F1C);
  static const fireLight = Color(0xFFFFD166);
  static const fireRed = Color(0xFFFF4D4D);
  static const fireGlow = Color(0xFFFFE8B0);
  static const ice = Color(0xFF7DD3FC);
  static const iceLight = Color(0xFFBAE6FD);
  static const iceDeep = Color(0xFF38BDF8);
  static const iceDark = Color(0xFF0EA5E9);

  // Kategori renkleri (ayar satırları, pratik kutucukları vb.)
  static const blue = Color(0xFF60A5FA);
  static const pink = Color(0xFFF472B6);
  static const violet = Color(0xFFA78BFA);
  static const mint = Color(0xFF34D399);
  static const gemini = Color(0xFF8E75B2);

  /// Kutlama gibi katmanların arkasındaki karartma.
  static const scrim = Color(0xB3000000);

  // Durum renkleri
  static const success = Color(0xFF4ADE80);
  static const successDark = Color(0xFF166534);
  static const error = Color(0xFFF87171);
  static const errorDark = Color(0xFF991B1B);
  static const warning = Color(0xFFFBBF24);
}

/// Vurguya göre renk şeması; tema ve testler bunu kullanır.
ColorScheme colorSchemeFor(Brightness brightness, AppAccent accent) {
  final isDark = brightness == Brightness.dark;
  return isDark
      ? ColorScheme.dark(
          primary: accent.spark,
          onPrimary: AppColors.graphite900,
          secondary: accent.dim,
          onSecondary: AppColors.graphite900,
          surface: AppColors.graphite800,
          onSurface: AppColors.graphite50,
          surfaceContainerHighest: AppColors.graphite600,
          surfaceContainerHigh: AppColors.graphite700,
          surfaceContainer: AppColors.graphite700,
          surfaceContainerLow: AppColors.graphite800,
          surfaceContainerLowest: AppColors.graphite900,
          error: AppColors.error,
          onError: AppColors.graphite900,
          outline: AppColors.graphite400,
          outlineVariant: AppColors.graphite600,
        )
      : ColorScheme.light(
          primary: accent.dark,
          onPrimary: Colors.white,
          secondary: accent.dim,
          onSecondary: AppColors.graphite900,
          surface: AppColors.graphite50,
          onSurface: AppColors.graphite900,
          surfaceContainerHighest: AppColors.graphite200,
          surfaceContainerHigh: AppColors.graphite100,
          surfaceContainer: Colors.white,
          surfaceContainerLow: Colors.white,
          surfaceContainerLowest: Colors.white,
          error: AppColors.errorDark,
          onError: Colors.white,
          outline: AppColors.graphite400,
          outlineVariant: AppColors.graphite200,
        );
}

ThemeData _base(Brightness brightness, AppAccent accent) {
  final isDark = brightness == Brightness.dark;

  final colorScheme = colorSchemeFor(brightness, accent);

  // Inter uygulamanın içinde gelir (assets/fonts); çalışma sırasında
  // internetten indirilmez, çevrimdışı ilk açılışta da aynı görünür.
  // Emoji için açık yedek: Android'deki sistem emoji ailesi; ekran görüntüsü
  // üretiminde de aynı aileyle çizilir. Bulunamazsa sistem kendi seçer.
  final textTheme = ThemeData(brightness: brightness).textTheme.apply(
    fontFamily: AppFonts.inter,
    fontFamilyFallback: const [AppFonts.emoji],
  );

  return ThemeData(
    useMaterial3: true,
    extensions: [PaceColors.of(accent)],
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor:
        isDark ? AppColors.graphite900 : AppColors.graphite50,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? AppColors.graphite900 : AppColors.graphite50,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      // Kaydırınca vurgu rengine bürünmesin; zemin sabit kalır.
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: isDark ? accent.spark : accent.dark,
        foregroundColor: isDark ? AppColors.graphite900 : Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? accent.spark : accent.dark,
          width: 2,
        ),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: isDark ? accent.spark : accent.dark,
      linearTrackColor: colorScheme.surfaceContainerHighest,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: colorScheme.outlineVariant),
    ),
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
  );
}

/// Seçilen vurguyla açık/koyu temayı kurar. Sonuçlar önbelleğe alınır;
/// aynı seçim için her yeniden çizimde tema baştan üretilmez.
ThemeData buildTheme(Brightness brightness, AppAccent accent) =>
    _cache.putIfAbsent((brightness, accent), () => _base(brightness, accent));

final _cache = <(Brightness, AppAccent), ThemeData>{};

final lightTheme = buildTheme(Brightness.light, AppAccent.lime);
final darkTheme = buildTheme(Brightness.dark, AppAccent.lime);
