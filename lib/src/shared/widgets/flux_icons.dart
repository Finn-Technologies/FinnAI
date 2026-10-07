import 'package:flutter/material.dart';
import 'package:hugeicons_pro/hugeicons.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/figma_assets.dart';

/// The app's icon set: Hugeicons, one solid (filled) style, everywhere.
///
/// Icons are named after what they mean, not how they are drawn, so the set can
/// change under the app without touching a call site. The values are the filled
/// glyphs; contrast is carried by colour, never by an outline/filled swap.
abstract final class FluxIcons {
  // Hugeicons Solid: one filled family on the same 24-unit grid. Selection and
  // state are shown with colour or a backing, never by swapping the glyph for
  // an outline.
  static const add = HugeIconsSolid.plusSign;
  static const close = HugeIconsSolid.cancel01;
  static const arrowUp01 = HugeIconsSolid.arrowUp01;
  static const arrowUp02 = HugeIconsSolid.arrowUp02;
  static const menu = HugeIconsSolid.menu01;
  static const chevronLeft = HugeIconsSolid.arrowLeft01;
  static const chevronRight = HugeIconsSolid.arrowRight01;
  static const chevronUp = HugeIconsSolid.arrowUp01;
  static const chevronDown = HugeIconsSolid.arrowDown01;
  static const arrowLeft = HugeIconsSolid.arrowLeft01;
  static const newChat = HugeIconsSolid.edit01;
  static const creations = HugeIconsSolid.dashboardSquare01;
  static const widget = HugeIconsSolid.layout01;
  static const contacts = HugeIconsSolid.contactBook;
  static const notifications = HugeIconsSolid.notification01;
  static const location = HugeIconsSolid.mapPin;
  static const share = HugeIconsSolid.share01;
  static const pin = HugeIconsSolid.pin;
  static const feedback = HugeIconsSolid.comment01;
  static const selectText = HugeIconsSolid.inputCursorText;
  static const miniApp = HugeIconsSolid.smartPhone01;
  static const presentation = HugeIconsSolid.presentation01;
  static const photo = HugeIconsSolid.image01;
  static const file = HugeIconsSolid.file01;
  static const copy = HugeIconsSolid.copy01;
  static const exchange = HugeIconsSolid.arrowLeftRight;
  static const internet = HugeIconsSolid.globe;
  static const sad = HugeIconsSolid.sad01;
  static const canvas = HugeIconsSolid.paintBrush01;
  static const you = HugeIconsSolid.smile;
  static const flows = HugeIconsSolid.flowchart01;
  static const chip = HugeIconsSolid.cpu;
  static const settings = HugeIconsSolid.settings01;
  static const edit = HugeIconsSolid.pencil;
  static const security = HugeIconsSolid.securityWarning;
  static const magic = HugeIconsSolid.sparkles;
  static const lock = HugeIconsSolid.squareLock01;
  static const download = HugeIconsSolid.download01;
  static const delete = HugeIconsSolid.delete01;
  static const translate = HugeIconsSolid.translate;
  static const voiceId = HugeIconsSolid.speechToText;
  static const speed = HugeIconsSolid.dashboardSpeed01;
  static const subtitle = HugeIconsSolid.closedCaption;
  static const bluetooth = HugeIconsSolid.bluetooth;
  static const robot = HugeIconsSolid.robot01;
  static const leaf = HugeIconsSolid.leaf01;
  static const game = HugeIconsSolid.gameController01;
  static const refresh = HugeIconsSolid.refresh01;
  static const loading = HugeIconsSolid.loading01;
  static const check = HugeIconsSolid.checkmarkCircle01;
  static const checkBox = HugeIconsSolid.checkmarkSquare01;
  static const checkBoxEmpty = HugeIconsSolid.square;
  static const flag = HugeIconsSolid.flag01;
  static const mic = HugeIconsSolid.mic01;
  static const micOff = HugeIconsSolid.micOff01;
  static const voiceWaveform = HugeIconsSolid.audioWave01;
  static const cpu = HugeIconsSolid.cpu;
  static const error = HugeIconsSolid.alertCircle;
  static const info = HugeIconsSolid.informationCircle;
  static const moreHorizontal = HugeIconsSolid.moreHorizontal;
  static const arrowRight01 = HugeIconsSolid.arrowRight01;
  static const arrowRight02 = HugeIconsSolid.arrowRight02;
  static const cloudOff = HugeIconsSolid.cloud;
  static const image = HugeIconsSolid.image01;
  static const brokenImage = HugeIconsSolid.imageNotFound01;
  static const note = HugeIconsSolid.stickyNote01;
  static const sourceCode = HugeIconsSolid.sourceCode;
  static const education = HugeIconsSolid.school01;
  static const task = HugeIconsSolid.task01;
  static const search = HugeIconsSolid.search01;
  static const alarm = HugeIconsSolid.alarmClock;
  static const timer = HugeIconsSolid.timer01;
  static const flashlight = HugeIconsSolid.flashlight;
  static const volume = HugeIconsSolid.volumeHigh;
  static const wifi = HugeIconsSolid.wifi01;
  static const calendar = HugeIconsSolid.calendar01;
  static const navigation = HugeIconsSolid.navigation01;
  static const camera = HugeIconsSolid.camera01;
  static const battery = HugeIconsSolid.batteryFull;
  static const moon = HugeIconsSolid.moon01;
  static const sun = HugeIconsSolid.sun01;

  /// The design's chrome icons, drawn from the app's one icon set instead of
  /// their mixed outline/filled SVGs (`FluxIcons`). Artwork is untouched.
  static final Map<String, IconData> forDesignAsset = {
    FigmaAssets.back: FluxIcons.chevronLeft,
    FigmaAssets.creationBack: FluxIcons.chevronLeft,
    FigmaAssets.appClose: FluxIcons.close,
    FigmaAssets.appMenu: FluxIcons.menu,
    FigmaAssets.menu: FluxIcons.menu,
    FigmaAssets.appSettings: FluxIcons.settings,
    FigmaAssets.appNewChat: FluxIcons.newChat,
    FigmaAssets.tileCreations: FluxIcons.creations,
    FigmaAssets.tileFlows: FluxIcons.flows,
    FigmaAssets.tileYou: FluxIcons.you,
    FigmaAssets.sidebarCreations: FluxIcons.creations,
    FigmaAssets.sidebarFlows: FluxIcons.flows,
    FigmaAssets.sidebarYou: FluxIcons.you,
    FigmaAssets.replyCopy: FluxIcons.copy,
    FigmaAssets.replyAlert: FluxIcons.flag,
    FigmaAssets.replyMore: FluxIcons.moreHorizontal,
    FigmaAssets.voiceMic: FluxIcons.mic,
    FigmaAssets.composerVoice: FluxIcons.voiceWaveform,
    FigmaAssets.composerAdd: FluxIcons.add,
    FigmaAssets.add: FluxIcons.add,
    FigmaAssets.creationAdd: FluxIcons.add,
    FigmaAssets.send: FluxIcons.arrowUp02,
    FigmaAssets.activeSend: FluxIcons.arrowUp02,
    FigmaAssets.creationSend: FluxIcons.arrowUp02,
    FigmaAssets.stepNext: FluxIcons.arrowRight02,
    FigmaAssets.stepBack: FluxIcons.arrowLeft,
    FigmaAssets.swipeUp: FluxIcons.chevronUp,
    FigmaAssets.modelChevron: FluxIcons.chevronDown,
  };
}

class FluxIcon extends StatelessWidget {
  const FluxIcon({
    super.key,
    required this.icon,
    this.size = 24,
    this.color,
  });

  /// A glyph from [FluxIcons] (Hugeicons, one filled weight). One style app
  /// wide: selection is shown with colour or a backing, never by swapping
  /// the glyph.
  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Icon(
        icon,
        size: size,
        color: color ??
            DefaultTextStyle.of(context).style.color ??
            FluxColors.inkOf(context),
      );
}
