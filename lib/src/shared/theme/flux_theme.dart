import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's colour system.
///
/// Every colour is declared twice — once for light, once for dark — and read
/// through a `…Of(context)` resolver so no screen has to branch on brightness.
/// The `*Of` resolvers are the only sanctioned way to reach these values: a
/// literal `Color(0x…)` in a widget bypasses the theme and is how the app ended
/// up with a white tile on a black sidebar and a 2.15:1 amber pill.
///
/// The semantic group (link/accent, info, warning, success, danger) is the set
/// that must clear WCAG AA: 4.5:1 for body-size text, 3.0:1 for large text
/// (>= 24px, or >= 18.66px bold) and for non-text marks. Each pair is asserted
/// in `test/shared/flux_color_tokens_test.dart`, which recomputes the WCAG ratio
/// from the same constants so the numbers cannot drift from the palette.
abstract final class FluxColors {
  // Light Palette
  static const canvas = Color(0xFFF5F5F5);
  static const ink = Color(0xFF121212);
  static const muted = Color(0xFF686966);
  static const line = Color(0xFFEAEAE7);

  /// Hairline on the sidebar panel's right edge. Darker than [line]: the
  /// design draws the panel's boundary as a visible 1px rule, not a hint.
  static const panelEdge = Color(0xFFDCDCDC);
  static const surface = Color(0xFFF3F3F3);
  static const card = Color(0xFFFFFFFF);
  static const blue = Color(0xFF15509E);
  static const lime = Color(0xFFD6FF7D);
  static const mint = Color(0xFF7DFFCD);
  static const green = Color(0xFF00FF2B);

  // Dark Palette (Sleek Dark Mode)
  static const darkCanvas = Color(0xFF000000);
  static const darkInk = Color(0xFFF5F5F7);
  static const darkMuted = Color(0xFF9898A0);
  static const darkLine = Color(0xFF26262D);
  static const darkPanelEdge = Color(0xFF3A3A42);
  static const darkSurface = Color(0xFF18181B);
  static const darkCard = Color(0xFF222226);

  // Destructive (unified red)
  static const destructive = Color(0xFFB3261E);
  static const destructiveDark = Color(0xFFFF9E96);

  // Semantic tokens — light variants. Values and their measured contrast are
  // documented in test/shared/flux_color_tokens_test.dart.
  //
  //   link/accent #2B49C8 — 6.84:1 on canvas, 7.27:1 on card
  //   info        #15509E — 7.40:1 on canvas, 7.86:1 on card
  //   warning     #8A4B00 — 6.41:1 on canvas, 6.80:1 on card
  //   success     #0E6B38 — 6.22:1 on canvas, 6.61:1 on card
  //   danger      #B3261E — 6.15:1 on canvas, 6.54:1 on card
  static const link = Color(0xFF2B49C8);
  static const accentLink = Color(0xFF2B49C8);
  static const infoLight = Color(0xFF15509E);
  static const warning = Color(0xFF8A4B00);
  static const success = Color(0xFF0E6B38);

  // Semantic tokens — dark variants.
  //
  //   link/accent #93B4FF — 10.21:1 on canvas, 7.71:1 on card
  //   info        #8FC0FF — 11.15:1 on canvas, 8.42:1 on card
  //   warning     #FBBF24 — 12.58:1 on canvas, 9.50:1 on card
  //   success     #5FD99A — 11.88:1 on canvas, 8.97:1 on card
  //   danger      #FF9E96 — 10.58:1 on canvas, 7.99:1 on card
  static const linkDark = Color(0xFF93B4FF);
  static const info = Color(0xFF8FC0FF);

  // De-emphasised body copy — the second paragraph on a step, a supporting
  // line under a title. This replaces `inkOf(context).withValues(alpha: .5)`,
  // which composited to ~3.5:1 and measured 2.3-3.2:1 on the lighter surfaces.
  //
  //   secondaryInk #515250 — 7.40:1 on canvas, 7.86:1 on card
  static const secondaryInk = Color(0xFF515250);
  static const secondaryInkDark = Color(0xFF94949C);

  // The former accent pair. Both members were re-purposed onto the AA-safe
  // semantic values above so the settings model pill, which tints its own
  // background from these, stops rendering body text at 2.15:1.
  static const accentBlue = infoLight;
  static const accentBlueMuted = infoLight;
  static const accentGreen = success;
  static const accentGreenDark = Color(0xFF5FD99A);
  static const accentAmber = warning;
  static const accentAmberDark = Color(0xFFFBBF24);
  static const accentAmberDeep = warning;

  // Overlay / scrim (frosted glass, context menus, scrims)
  static const overlay = Color(0x33000000);
  static const overlayStrong = Color(0x66000000);
  static const scrimLight = Color(0x1F000000);
  static const scrimDark = Color(0x33000000);
  static const scrimMenuLight = Color(0x18000000);
  static const scrimMenuDark = Color(0x33000000);

  // Elevation. A black shadow is a no-op on the #000000 dark canvas, so dark
  // mode separates a raised surface with a light rim instead — the same trick
  // a dark UI uses for a floating card. Both are declared as the *ink* colour
  // so [elevationOf] can tint them.
  static const double elevationRadius = 24;
  static const double elevationOffsetY = 8;

  /// The colour of an elevated surface's shadow in the active theme.
  ///
  /// Light mode darkens; dark mode lifts. Every elevated surface — cards,
  /// sheets, menus, the composer pill — goes through this, because a literal
  /// `Colors.black` shadow is invisible against the dark canvas.
  static Color elevationOf(BuildContext context) =>
      isDark(context) ? darkInk : Colors.black;

  /// A ready-made elevated shadow.
  ///
  /// One call so a raised surface cannot reintroduce a literal black shadow:
  /// this is what every card, sheet, menu and the composer pill use. [alpha] is
  /// the light-mode strength; dark uses a fraction of it, because a lift over
  /// black reads at a much lower contrast than a shade over white.
  static List<BoxShadow> elevationShadow(
    BuildContext context, {
    double alpha = .08,
    double blur = 24,
    double spread = 0,
    Offset offset = const Offset(0, 8),
  }) =>
      [
        BoxShadow(
          color: elevationOf(context).withValues(
            alpha: isDark(context) ? alpha * 1.5 : alpha,
          ),
          blurRadius: blur,
          spreadRadius: spread,
          offset: offset,
        ),
      ];

  /// Scrim behind a modal surface.
  ///
  /// Darkening a black canvas achieves nothing, so in dark the scrim *lightens*
  /// what is behind it, which is the only way to read as "this is now modal".
  static Color scrimOf(BuildContext context, {required double alpha}) =>
      isDark(context)
          ? darkInk.withValues(alpha: alpha * 0.30)
          : Colors.black.withValues(alpha: alpha);

  // Bubble / surface helpers.
  //
  // `bubbleUserDark` used to be #2C2C2E — 1.51:1 against the pure-black dark
  // canvas, which is why the user bubble read as "very dark grey on black" on
  // device. #575D6E keeps >= 4.5:1 for the text on it *and* >= 3:1 against the
  // canvas, so the bubble is visible without the copy becoming unreadable.
  static const bubbleUserLight = Color(0xFFFFFFFF);
  static const bubbleUserDark = Color(0xFF575D6E);
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

  // Secondary copy on a tile, e.g. a chat card's timestamp. #848484 measured
  // 3.43:1 on the light tile fill; #646464 measures 5.43:1 on the same tile.
  static const timestampLight = Color(0xFF646464);

  // Listening pill behind the composer (design: Chat - Voice). The dark pair
  // is a deep, desaturated version: the light pastels measure ~15:1 against
  // the black canvas, which reads as a slab of daylight pasted onto a dark UI.
  static const voiceStart = Color(0xFFC9E7A8);
  static const voiceEnd = Color(0xFFA7E9E1);
  static const voiceStartDark = Color(0xFF24361C);
  static const voiceEndDark = Color(0xFF16302F);

  /// The smallest text the app renders. Anything a user has to *read* — labels,
  /// hints, pills, section headers — goes through a text theme role that is at
  /// least this size; 10px and 11px copy was measured as unreadable on a phone
  /// and the audit flagged it. Non-text decoration (a superscript, a rule
  /// thickness) is unaffected.
  static const double minTextSize = 12;

  /// Diagonal wash used while the composer is listening, in the active theme.
  ///
  /// The light pastels are the design's; the dark pair is a deep equivalent so
  /// the listening state reads as a lit surface rather than a pasted-on slab.
  static LinearGradient voiceGradientOf(BuildContext context) {
    final dark = isDark(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        dark ? voiceStartDark : voiceStart,
        dark ? voiceEndDark : voiceEnd,
      ],
    );
  }

  // The ambient green wash under an empty chat. The light pair fades *up* from
  // transparent; on the dark canvas the same hue has to fade up from the
  // surface colour and at a fraction of the strength, or it reads as a glow.
  static const List<Color> ambientWashLight = <Color>[
    Color(0x00FFFFFF),
    Color(0x4092FF86),
  ];
  static const List<Color> ambientWashDark = <Color>[
    Color(0x0018181C),
    Color(0x1492FF86),
  ];

  /// Stops of the empty-chat ambient wash, in the active theme.
  static List<Color> ambientWashOf(BuildContext context) =>
      isDark(context) ? ambientWashDark : ambientWashLight;

  // Rows inside a reveal pill
  static const disclosureRowLight = Color(0xFFF2F2F7);
  static const disclosureRowDark = Color(0xFF18181C);

  // Dynamic Context Resolvers

  /// Link and the app's single accent colour, in the active theme. Both were
  /// #5D75FF, which measured 3.63:1 on the light canvas — below AA for
  /// body-size text, which is what the onboarding privacy link is.
  static Color linkOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? linkDark : link;

  /// Informational blue: the "an action is running / this is a fact" voice.
  static Color infoOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? info : infoLight;

  /// Amber: attention without alarm. The old #F59E0B measured 2.15:1 on white,
  /// which is what made the model-status pill unreadable.
  static Color warningOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? accentAmberDark
          : warning;

  static Color successOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? accentGreenDark
          : success;

  /// The app's accent. Deliberately the same token as [linkOf] — there is one
  /// accent hue, and having a second near-identical blue is how the palette
  /// drifted.
  static Color accentOf(BuildContext context) => linkOf(context);

  /// Text drawn on top of a chat bubble, a card, or any other raised surface.
  static Color onBubbleOf(BuildContext context) => inkOf(context);

  static Color bubbleUserOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? bubbleUserDark
          : bubbleUserLight;

  static Color bubbleAssistantOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? bubbleAssistantDark
          : bubbleAssistantLight;

  static Color canvasOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCanvas : canvas;

  static Color inkOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkInk : ink;

  static Color mutedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkMuted : muted;

  /// De-emphasised body copy. A solid token rather than a 50%-alpha
  /// `withValues`, because an alpha ink composites to roughly 3.5:1 on the
  /// canvas — below AA.
  static Color secondaryInkOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? secondaryInkDark
          : secondaryInk;

  static Color lineOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkLine : line;

  /// Hairline on the sidebar panel's right edge.
  static Color panelEdgeOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkPanelEdge
          : panelEdge;

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

/// The app's single motion language.
///
/// The audit found three page motions and three modal motions with different
/// durations and curves, so the same gesture felt like a different app on
/// different screens. There is now exactly one duration and one curve per kind
/// of transition, named here, and every shared widget routes through them. Any
/// screen-level motion that is not one of these — a long-press preview, a
/// progress ring — is a bug, and the call site belongs in the handoff list.
abstract final class FluxMotion {
  /// Push/pop of a secondary page (Settings, You, Creations, Flows).
  static const Duration pageDuration = Duration(milliseconds: 280);
  static const Curve pageCurve = Curves.easeOutCubic;
  static const Curve pageReverseCurve = Curves.easeInCubic;

  /// Presentation of a modal surface (context menu, bottom sheet, dialog).
  static const Duration modalDuration = Duration(milliseconds: 220);
  static const Curve modalCurve = Curves.easeOutCubic;
  static const Curve modalReverseCurve = Curves.easeInCubic;

  /// In-place content change: a disclosure opening, a chevron turning.
  static const Duration revealDuration = Duration(milliseconds: 180);
  static const Curve revealCurve = Curves.easeOutCubic;

  /// Press feedback. Shared by every tappable surface so a thumb gets the same
  /// answer everywhere.
  static const Duration pressIn = Duration(milliseconds: 120);
  static const Duration pressOut = Duration(milliseconds: 240);
  static const Curve pressCurve = Curves.easeOutCubic;
  static const Curve pressReturnCurve = Curves.easeOutBack;

  /// Minimum touch target, in logical pixels. Everything tappable in
  /// `lib/src/shared/widgets` reserves at least this much hit area even when
  /// the painted control is smaller.
  static const double minTapTarget = 48;
}

/// Bottom edge geometry shared by every screen that parks UI against the
/// bottom of the display.
///
/// `main()` puts the app in `SystemUiMode.edgeToEdge` with transparent system
/// bars, so every screen draws under the navigation bar and owns the space it
/// reserves for it. `paddingOf` alone is the wrong source for that: it is
/// `max(0, viewPadding - viewInsets)`, so it collapses to zero the moment a
/// keyboard opens or the navigation bar hides — the case where content would
/// otherwise sit flush on the glass. `viewPaddingOf` keeps the physical inset
/// but reports the gesture area rather than the bar, which is not what a
/// composer resting above the bar wants either.
///
/// So this resolves the bar from whichever view reports one, and floors it at
/// [minBar] so hiding the navigation bar still leaves breathing room instead of
/// dropping content onto the edge.
abstract final class FluxBottomInset {
  /// Distance kept between bottom-anchored UI and the screen edge when no
  /// system bar is reported, and the floor for the bar's own height.
  static const double minBar = 24;

  /// The height to reserve below bottom-anchored UI, in logical pixels.
  ///
  /// Takes the largest of the three sources so a bar is never underestimated:
  /// the fully hidden keyboard (`viewInsets`), the physical inset including a
  /// gesture bar (`viewPadding`), and the visible system bar (`padding`).
  static double bottomOf(BuildContext context) {
    final media = MediaQuery.of(context);
    return math.max(
      minBar,
      math.max(
        media.viewInsets.bottom,
        math.max(media.viewPadding.bottom, media.padding.bottom),
      ),
    );
  }
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
          fontSize: 24,
          height: 1.2,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          height: 1.22,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.1,
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
          fontSize: 16,
          height: 1.25,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.08,
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          height: 1.2,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.05,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          height: 1.2,
          fontWeight: FontWeight.w400,
        ),
        labelMedium: TextStyle(
          fontSize: FluxColors.minTextSize,
          height: 1.25,
          fontWeight: FontWeight.w400,
        ),
        // Was 11px (the M3 default this role inherited), which the a11y audit
        // measured as too small to read comfortably. Floored at
        // [FluxColors.minTextSize] like every other readable role.
        labelSmall: TextStyle(
          fontSize: FluxColors.minTextSize,
          height: 1.25,
          fontWeight: FontWeight.w400,
        ),
      ).apply(bodyColor: color, displayColor: color);

  static const _round = FluxRadius.sheet + 1;

  static DialogThemeData _dialog(Color bg) => DialogThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(_round)),
      );

  static BottomSheetThemeData _sheet(Color bg) => BottomSheetThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(_round)),
        ),
      );

  static PopupMenuThemeData _popup(Color bg) => PopupMenuThemeData(
        color: bg,
        surfaceTintColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(_round)),
      );

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
        dialogTheme: _dialog(FluxColors.controlLight),
        bottomSheetTheme: _sheet(FluxColors.controlLight),
        popupMenuTheme: _popup(FluxColors.controlLight),
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
        dialogTheme: _dialog(FluxColors.controlDark),
        bottomSheetTheme: _sheet(FluxColors.controlDark),
        popupMenuTheme: _popup(FluxColors.controlDark),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {TargetPlatform.android: ZoomPageTransitionsBuilder()},
        ),
      );
}
