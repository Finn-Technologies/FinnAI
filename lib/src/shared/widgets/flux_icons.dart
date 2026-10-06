import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/figma_assets.dart';

/// The app's icon set: Lucide, one stroke weight, everywhere. Every glyph
/// shares the same 24-unit grid, rounded caps and joins, and line weight, so no
/// screen mixes outline and filled styles.
abstract final class FluxIcons {
  // Lucide at a 1.55 stroke on its 24-unit grid ("300"): a thin, rounded
  // line that reads as one family with the type, the way the references
  // (libraries.dev, SF Symbols' regular weight) draw their chrome. One
  // weight everywhere; a selected or toggled state is shown with colour or
  // a backing, never by swapping the glyph for a filled one.
  static const add = LucideIcons.plus300;
  static const close = LucideIcons.x300;
  static const arrowUp01 = LucideIcons.chevronUp300;
  static const arrowUp02 = LucideIcons.arrowUp300;
  static const menu = LucideIcons.menu300;
  static const chevronLeft = LucideIcons.chevronLeft300;
  static const chevronRight = LucideIcons.chevronRight300;
  static const chevronUp = LucideIcons.chevronUp300;
  static const chevronDown = LucideIcons.chevronDown300;
  static const arrowLeft = LucideIcons.arrowLeft300;
  static const newChat = LucideIcons.squarePen300;
  static const creations = LucideIcons.layoutGrid300;
  static const widget = LucideIcons.panelsTopLeft300;
  static const contacts = LucideIcons.bookUser300;
  static const notifications = LucideIcons.bell300;
  static const location = LucideIcons.mapPin300;
  static const share = LucideIcons.share300;
  static const pin = LucideIcons.pin300;
  static const feedback = LucideIcons.messageSquareText300;
  static const selectText = LucideIcons.textCursorInput300;
  static const miniApp = LucideIcons.smartphone300;
  static const presentation = LucideIcons.presentation300;
  static const photo = LucideIcons.image300;
  static const file = LucideIcons.file300;
  static const copy = LucideIcons.copy300;
  static const exchange = LucideIcons.arrowLeftRight300;
  static const internet = LucideIcons.globe300;
  static const sad = LucideIcons.frown300;
  static const canvas = LucideIcons.paintbrush300;
  static const you = LucideIcons.smile300;
  static const flows = LucideIcons.workflow300;
  static const chip = LucideIcons.cpu300;
  static const settings = LucideIcons.settings300;
  static const edit = LucideIcons.pencil300;
  static const security = LucideIcons.shieldAlert300;
  static const magic = LucideIcons.sparkles300;
  static const lock = LucideIcons.lock300;
  static const download = LucideIcons.download300;
  static const delete = LucideIcons.trash2300;
  static const translate = LucideIcons.languages300;
  static const voiceId = LucideIcons.speech300;
  static const speed = LucideIcons.gauge300;
  static const subtitle = LucideIcons.captions300;
  static const bluetooth = LucideIcons.bluetooth300;
  static const robot = LucideIcons.bot300;
  static const leaf = LucideIcons.leaf300;
  static const game = LucideIcons.gamepad2300;
  static const refresh = LucideIcons.rotateCw300;
  static const loading = LucideIcons.loaderCircle300;
  static const check = LucideIcons.circleCheck300;
  static const flag = LucideIcons.flag300;
  static const mic = LucideIcons.mic300;
  static const micOff = LucideIcons.micOff300;
  static const voiceWaveform = LucideIcons.audioLines300;
  static const cpu = LucideIcons.cpu300;
  static const error = LucideIcons.circleAlert300;
  static const info = LucideIcons.info300;
  static const moreHorizontal = LucideIcons.ellipsis300;
  static const arrowRight01 = LucideIcons.chevronRight300;
  static const arrowRight02 = LucideIcons.arrowRight300;
  static const cloudOff = LucideIcons.cloudOff300;
  static const image = LucideIcons.image300;
  static const brokenImage = LucideIcons.imageOff300;
  static const note = LucideIcons.stickyNote300;
  static const sourceCode = LucideIcons.codeXml300;
  static const education = LucideIcons.graduationCap300;
  static const task = LucideIcons.clipboardList300;
  static const search = LucideIcons.search300;
  static const alarm = LucideIcons.alarmClock300;
  static const timer = LucideIcons.timer300;
  static const flashlight = LucideIcons.flashlight300;
  static const volume = LucideIcons.volume2300;
  static const wifi = LucideIcons.wifi300;
  static const calendar = LucideIcons.calendar300;
  static const navigation = LucideIcons.navigation300;
  static const camera = LucideIcons.camera300;
  static const battery = LucideIcons.batteryFull300;
  static const moon = LucideIcons.moon300;
  static const sun = LucideIcons.sun300;

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

  /// A glyph from [FluxIcons] (Lucide, one stroke weight). One style app
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
