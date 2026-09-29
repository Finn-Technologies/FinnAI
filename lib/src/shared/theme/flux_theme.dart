import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class FluxColors {
  // Light Palette
  static const canvas = Color(0xFFF8F8F8);
  static const ink = Color(0xFF121212);
  static const muted = Color(0xFF686966);
  static const line = Color(0xFFEAEAE7);
  static const surface = Color(0xFFF3F3F3);
  static const card = Color(0xFFFFFFFF);
  static const blue = Color(0xFF3E86F7);
  static const lime = Color(0xFFD6FF7D);
  static const mint = Color(0xFF7DFFCD);
  static const green = Color(0xFF00FF2B);

  // Dark Palette (Sleek Dark Mode)
  static const darkCanvas = Color(0xFF000000);
  static const darkInk = Color(0xFFF5F5F7);
  static const darkMuted = Color(0xFF9898A0);
  static const darkLine = Color(0xFF26262D);
  static const darkSurface = Color(0xFF18181B);
  static const darkCard = Color(0xFF222226);

  // Destructive (unified red)
  static const destructive = Color(0xFFD32F2F);
  static const destructiveDark = Color(0xFFFF6B6B);

  // Accent tokens (previously orphaned hardcodes)
  static const accentBlue = Color(0xFF3B82F6);
  static const accentBlueMuted = Color(0xFF4A7CF3);
  static const accentGreen = Color(0xFF16A34A);
  static const accentGreenDark = Color(0xFF4ADE80);
  static const accentAmber = Color(0xFFF59E0B);
  static const accentAmberDark = Color(0xFFFBBF24);
  static const accentAmberDeep = Color(0xFFD97706);

  // Overlay / scrim (frosted glass, context menus, scrims)
  static const overlay = Color(0x33000000);
  static const overlayStrong = Color(0x66000000);
  static const scrimLight = Color(0x1F000000);
  static const scrimDark = Color(0x33000000);
  static const scrimMenuLight = Color(0x18000000);
  static const scrimMenuDark = Color(0x33000000);

  // Bubble / surface helpers
  static const bubbleUserLight = Color(0xFFE5E5EA);
  static const bubbleUserDark = Color(0xFF2C2C2E);
  static const bubbleAssistantLight = Color(0xFFF2F2F7);
  static const bubbleAssistantDark = Color(0xFF1C1C1E);

  // Reveal pills that sit under a reply (sources, browser steps)
  static const disclosureLight = Color(0xFFEAEAEE);
  static const disclosureDark = Color(0xFF1E1E22);

  // Chat shell controls: the circular surfaces the design uses for the menu,
  // attachment, mic and close buttons, and the near-black it uses for primary
  // actions such as send.
  static const controlLight = Color(0xFFFFFFFF);
  static const controlDark = Color(0xFF1E1E22);
  static const actionLight = Color(0xFF414141);
  static const actionDark = Color(0xFFF5F5F7);

  // Flat tiles: sidebar chat cards and their circular shortcuts.
  static const tileLight = Color(0xFFF5F5F5);
  static const tileDark = Color(0xFF18181C);

  // Secondary copy on a tile, e.g. a chat card's timestamp.
  static const timestampLight = Color(0xFF848484);

  /// Links inside body copy, e.g. the privacy policy line in onboarding.
  static const link = Color(0xFF5D75FF);

  // Listening pill behind the composer (design: Chat - Voice).
  static const voiceStart = Color(0xFFC9E7A8);
  static const voiceEnd = Color(0xFFA7E9E1);

  /// Diagonal wash used while the composer is listening.
  static const LinearGradient voiceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [voiceStart, voiceEnd],
  );

  // Rows inside a reveal pill
  static const disclosureRowLight = Color(0xFFF2F2F7);
  static const disclosureRowDark = Color(0xFF18181C);

  // Dynamic Context Resolvers
  static Color canvasOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCanvas : canvas;

  static Color inkOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkInk : ink;

  static Color mutedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkMuted : muted;

  static Color lineOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkLine : line;

  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurface : surface;

  static Color cardOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCard : card;

  static Color disclosureOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? disclosureDark
          : disclosureLight;

  static Color disclosureRowOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? disclosureRowDark
          : disclosureRowLight;

  static Color destructiveOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? destructiveDark
          : destructive;

  static Color accentGreenOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? accentGreenDark
          : accentGreen;

  /// Circular button surface behind the menu, attachment, mic and close glyphs.
  static Color controlOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? controlDark
          : controlLight;

  /// Fill for primary actions, such as the round send button.
  static Color actionOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? actionDark
          : actionLight;

  /// Glyph drawn on top of [actionOf].
  static Color actionInkOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? actionLight : card;

  /// Flat tile surface used by the sidebar's chat cards.
  static Color tileOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? tileDark : tileLight;

  /// Secondary copy on a tile — deliberately lighter than [mutedOf].
  static Color timestampOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkMuted
          : timestampLight;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}

abstract final class FluxRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double card = 20;
  static const double sheet = 24;
  static const double pill = 999;
}

abstract final class FluxBlur {
  static const double menu = 20;
  static const double sheet = 24;
}

abstract final class FluxTheme {
  static SystemUiOverlayStyle systemUiOverlayStyle(BuildContext context) {
    final isDark = FluxColors.isDark(context);
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    );
  }

  static Widget applySystemUi(BuildContext context, Widget? child) =>
      AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemUiOverlayStyle(context),
        child: child ?? const SizedBox.shrink(),
      );

  static TextTheme _textTheme(Color color) => TextTheme(
        headlineLarge: TextStyle(
          fontSize: 24,
          height: 1.08,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.55,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          height: 1.1,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.45,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          height: 1.2,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 1.25,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.15,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          height: 1.25,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          height: 1.45,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.1,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          height: 1.35,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.08,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          height: 1.3,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.05,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          height: 1.2,
          fontWeight: FontWeight.w400,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          height: 1.25,
          fontWeight: FontWeight.w400,
        ),
        // Matches the M3 default this role previously inherited, so existing
        // labelSmall usages keep rendering at the same size.
        labelSmall: TextStyle(
          fontSize: 11,
          height: 1.25,
          fontWeight: FontWeight.w400,
        ),
      ).apply(bodyColor: color, displayColor: color);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: FluxColors.canvas,
        fontFamily: 'InstrumentSans',
        colorScheme: const ColorScheme.light(
          primary: FluxColors.ink,
          surface: FluxColors.canvas,
          onSurface: FluxColors.ink,
        ),
        splashFactory: InkRipple.splashFactory,
        textTheme: _textTheme(FluxColors.ink),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {TargetPlatform.android: ZoomPageTransitionsBuilder()},
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: FluxColors.darkCanvas,
        fontFamily: 'InstrumentSans',
        colorScheme: const ColorScheme.dark(
          primary: FluxColors.darkInk,
          surface: FluxColors.darkCanvas,
          onSurface: FluxColors.darkInk,
        ),
        splashFactory: InkRipple.splashFactory,
        textTheme: _textTheme(FluxColors.darkInk),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {TargetPlatform.android: ZoomPageTransitionsBuilder()},
        ),
      );
}
