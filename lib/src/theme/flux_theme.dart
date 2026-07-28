import 'package:flutter/material.dart';

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
  static const darkCanvas = Color(0xFF0F0F11);
  static const darkInk = Color(0xFFF5F5F7);
  static const darkMuted = Color(0xFF9898A0);
  static const darkLine = Color(0xFF26262D);
  static const darkSurface = Color(0xFF18181B);
  static const darkCard = Color(0xFF222226);

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

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}

abstract final class FluxTheme {
  static TextTheme _textTheme(Color color) => TextTheme(
    headlineLarge: TextStyle(
      fontSize: 24,
      height: 1.08,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.55,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      height: 1.2,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.3,
    ),
    titleMedium: TextStyle(
      fontSize: 20,
      height: 1.2,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.15,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      height: 1.45,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.1,
    ),
    bodyMedium: TextStyle(
      fontSize: 15,
      height: 1.2,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.08,
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
  ).apply(bodyColor: color, displayColor: color);

  static ThemeData get light => ThemeData(
    useMaterial3: false,
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
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: false,
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
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}
