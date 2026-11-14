import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// VITAL ORBIT design tokens (spec §2). Three themes; Midnight Cobalt is the
/// spec default, Paper Lab is the light "lab bench" theme, Aurora Lab the
/// playful alternate. Legacy screens were drawn for light surfaces, so in
/// the dark themes cards stay light ("lit lab bench in a dark cockpit") -
/// every legacy label remains readable while the shell goes full cockpit.
class BOTokens extends ThemeExtension<BOTokens> {
  final Color bgVoid;
  final Color bgDeep;
  final Color surfaceGlass;
  final Color surfaceRaised;
  final Color cardSurface;
  final Color lineHair;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDim;
  final Color accentCore;
  final Color accentPulse;
  final Color accentHeat;
  final Color ok;
  final Color watch;
  final Color bad;
  final Color ghost;
  final bool dark;
  const BOTokens({
    required this.bgVoid,
    required this.bgDeep,
    required this.surfaceGlass,
    required this.surfaceRaised,
    required this.cardSurface,
    required this.lineHair,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDim,
    required this.accentCore,
    required this.accentPulse,
    required this.accentHeat,
    required this.ok,
    required this.watch,
    required this.bad,
    required this.ghost,
    required this.dark,
  });

  static BOTokens of(BuildContext context) => Theme.of(context).extension<BOTokens>() ?? midnight;

  static const midnight = BOTokens(
    bgVoid: Color(0xFF05070D),
    bgDeep: Color(0xFF0A0F1C),
    surfaceGlass: Color(0xFF121A2E),
    surfaceRaised: Color(0xFF1A2440),
    cardSurface: Color(0xFFF4F6FB),
    lineHair: Color(0x1FFFFFFF),
    textPrimary: Color(0xFFEAF0FF),
    textSecondary: Color(0xFF9AA8C7),
    textDim: Color(0xFF5B6785),
    accentCore: Color(0xFF4DE1FF),
    accentPulse: Color(0xFF7B61FF),
    accentHeat: Color(0xFFFF8A3D),
    ok: Color(0xFF38F2A8),
    watch: Color(0xFFFFD23F),
    bad: Color(0xFFFF4D6D),
    ghost: Color(0xFF2B3552),
    dark: true,
  );

  static const aurora = BOTokens(
    bgVoid: Color(0xFF07100E),
    bgDeep: Color(0xFF0A1713),
    surfaceGlass: Color(0xFF10231F),
    surfaceRaised: Color(0xFF16302A),
    cardSurface: Color(0xFFF2FBF6),
    lineHair: Color(0x1FFFFFFF),
    textPrimary: Color(0xFFE8FFF7),
    textSecondary: Color(0xFF9CC7B8),
    textDim: Color(0xFF5F7A70),
    accentCore: Color(0xFF2BFFC6),
    accentPulse: Color(0xFFB7FF4A),
    accentHeat: Color(0xFFFF9F1C),
    ok: Color(0xFF2BFFC6),
    watch: Color(0xFFFFD23F),
    bad: Color(0xFFFF4D6D),
    ghost: Color(0xFF24443B),
    dark: true,
  );

  static const paper = BOTokens(
    bgVoid: Color(0xFFF4F6FB),
    bgDeep: Color(0xFFEDF1F8),
    surfaceGlass: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFE9EDF7),
    cardSurface: Color(0xFFFFFFFF),
    lineHair: Color(0x14000000),
    textPrimary: Color(0xFF0E1424),
    textSecondary: Color(0xFF5A6580),
    textDim: Color(0xFF8A94AD),
    accentCore: Color(0xFF0A84FF),
    accentPulse: Color(0xFF5E3BFF),
    accentHeat: Color(0xFFFF8A3D),
    ok: Color(0xFF10B97A),
    watch: Color(0xFFE0A800),
    bad: Color(0xFFE5334F),
    ghost: Color(0xFFC3CADB),
    dark: false,
  );

  @override
  BOTokens copyWith() => this;
  @override
  BOTokens lerp(ThemeExtension<BOTokens>? other, double t) => this;
}

/// The active theme name ('midnight' | 'aurora' | 'paper'), persisted.
final boThemeName = ValueNotifier<String>('midnight');

BOTokens boTokensFor(String name) => switch (name) {
      'aurora' => BOTokens.aurora,
      'paper' => BOTokens.paper,
      _ => BOTokens.midnight,
    };

Future<void> loadBOTheme() async {
  final sp = await SharedPreferences.getInstance();
  boThemeName.value = sp.getString('bb_theme') ?? 'midnight';
}

Future<void> setBOTheme(String name) async {
  boThemeName.value = name;
  final sp = await SharedPreferences.getInstance();
  await sp.setString('bb_theme', name);
}

ThemeData boMaterialTheme(BOTokens t) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: t.dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: t.bgVoid,
    colorScheme: ColorScheme(
      brightness: t.dark ? Brightness.dark : Brightness.light,
      primary: t.accentCore,
      onPrimary: t.dark ? const Color(0xFF04222E) : Colors.white,
      secondary: t.accentPulse,
      onSecondary: Colors.white,
      error: t.bad,
      onError: Colors.white,
      surface: t.cardSurface,
      onSurface: t.dark ? const Color(0xFF12283F) : t.textPrimary,
    ),
    cardTheme: CardThemeData(
      color: t.cardSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: t.lineHair)),
      margin: const EdgeInsets.symmetric(vertical: 5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: t.dark ? t.accentCore : const Color(0xFF17457A), foregroundColor: t.dark ? const Color(0xFF04222E) : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    ),
    dividerColor: t.lineHair,
    extensions: [t],
  );
  // Spec §3: Space Grotesk display, Inter body, JetBrains Mono data.
  // google_fonts fetches once and falls back silently when offline.
  final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
    displayLarge: GoogleFonts.spaceGrotesk(textStyle: base.textTheme.displayLarge, fontWeight: FontWeight.w700, letterSpacing: -0.5),
    headlineMedium: GoogleFonts.spaceGrotesk(textStyle: base.textTheme.headlineMedium, fontWeight: FontWeight.w700),
    titleLarge: GoogleFonts.spaceGrotesk(textStyle: base.textTheme.titleLarge, fontWeight: FontWeight.w600),
    titleMedium: GoogleFonts.spaceGrotesk(textStyle: base.textTheme.titleMedium, fontWeight: FontWeight.w600),
  );
  return base.copyWith(textTheme: textTheme);
}

/// Mono data style for numbers that must not jitter (spec §3).
TextStyle boData(BuildContext context, {double size = 13, Color? color, FontWeight weight = FontWeight.w600}) {
  final t = BOTokens.of(context);
  return GoogleFonts.jetBrainsMono(fontSize: size, color: color ?? t.textPrimary, fontWeight: weight);
}

/// Title style that follows the theme (for legacy bare titles on the shell).
TextStyle boTitle(BuildContext context, {double size = 19}) {
  final t = BOTokens.of(context);
  return GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: FontWeight.w700, color: t.textPrimary);
}
