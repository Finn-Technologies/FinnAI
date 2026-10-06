/// Paths of the design's exported SVG assets. Chrome icons among them are
/// drawn from the icon set instead (`FluxIcons.forDesignAsset`).
abstract final class FigmaAssets {
  static const _root = 'assets/runtime';

  static const back = '$_root/icon_144_180.svg';
  static const welcomeArrow = '$_root/icon_144_170.svg';
  static const privacy = '$_root/icon_144_195.svg';
  static const magic = '$_root/icon_144_243.svg';
  static const security = '$_root/icon_149_193.svg';
  static const download = '$_root/icon_144_238.svg';
  static const menu = '$_root/icon_59_31.svg';
  static const modelChevron = '$_root/icon_59_32.svg';
  static const send = '$_root/icon_59_14.svg';
  static const activeSend = '$_root/icon_59_65.svg';
  static const add = '$_root/icon_59_19.svg';
  static const sidebarActions = '$_root/icon_98_197.svg';
  static const sidebarCreations = '$_root/icon_98_202.svg';
  static const sidebarYou = '$_root/icon_101_181.svg';
  static const sidebarFlows = '$_root/icon_101_193.svg';
  static const noHistory = '$_root/icon_114_151.svg';
  static const creationBack = '$_root/icon_178_212.svg';
  static const creationSend = '$_root/icon_178_220.svg';
  static const creationAdd = '$_root/icon_178_228.svg';

  // App chrome, onboarding and chat, exported from the FinnAI App file.
  static const appMenu = '$_root/icon_298_47.svg';
  static const appNewChat = '$_root/icon_325_201.svg';
  static const appSettings = '$_root/icon_308_199.svg';
  static const appClose = '$_root/icon_298_70.svg';
  static const composerAdd = '$_root/icon_298_38.svg';
  static const composerVoice = '$_root/icon_298_43.svg';
  static const voiceMic = '$_root/icon_325_215.svg';
  static const replyCopy = '$_root/icon_308_265.svg';
  static const replyAlert = '$_root/icon_308_261.svg';
  static const replyMore = '$_root/icon_308_269.svg';
  static const tileCreations = '$_root/icon_298_89.svg';
  static const tileFlows = '$_root/icon_308_165.svg';
  static const tileYou = '$_root/icon_308_172.svg';
  static const toolMail = '$_root/icon_325_256.svg';
  static const stepBack = '$_root/icon_255_202.svg';
  static const stepNext = '$_root/icon_255_213.svg';
  static const swipeUp = '$_root/icon_255_179.svg';

  // Onboarding artwork and the welcome backdrop. The artwork is rasterised
  // from the design's 380x660 card: the exported SVGs fill the card with a
  // `<pattern>`, which flutter_svg does not implement, so the imagery has to
  // ship as the cropped bitmap the design actually renders.
  static const artworkPrivacy = '$_root/artwork_privacy.png';
  static const artworkDownload = '$_root/artwork_download.png';
  static const artworkConsent = '$_root/artwork_consent.png';
  static const artworkFinish = '$_root/artwork_finish.png';
  static const welcomeGlow = '$_root/welcome_glow.png';
}
