import 'package:finn_ai/src/features/actions/device_action.dart';

/// System screens Finn can open. Ids are stable and matched tolerantly; the
/// Android constant for each lives in [FinnDeviceActionsBridge].
abstract final class DeviceSettingsScreens {
  static const system = 'system';
  static const wifi = 'wifi';
  static const bluetooth = 'bluetooth';
  static const airplane = 'airplane';
  static const hotspot = 'hotspot';
  static const mobileData = 'mobile_data';
  static const batterySaver = 'battery_saver';
  static const batteryUsage = 'battery_usage';
  static const dnd = 'dnd';
  static const display = 'display';
  static const sound = 'sound';
  static const location = 'location';
  static const storage = 'storage';
  static const dateTime = 'date_time';
  static const keyboard = 'keyboard';
  static const language = 'language';
  static const accessibility = 'accessibility';
  static const applications = 'applications';
  static const nfc = 'nfc';
  static const cast = 'cast';
  static const vpn = 'vpn';
  static const developer = 'developer';
  static const home = 'home';

  static const all = <String>[
    system,
    wifi,
    bluetooth,
    airplane,
    hotspot,
    mobileData,
    batterySaver,
    batteryUsage,
    dnd,
    display,
    sound,
    location,
    storage,
    dateTime,
    keyboard,
    language,
    accessibility,
    applications,
    nfc,
    cast,
    vpn,
    developer,
    home,
  ];
}

/// The closed set of actions Finn can perform on the device.
///
/// The catalog is the contract shared by the deterministic matcher, the prompt
/// directive and the executor, so it is the single place an action is declared.
abstract final class DeviceActionCatalog {
  static const setAlarm = DeviceAction(
    name: 'set_alarm',
    tier: DeviceActionTier.execute,
    summary: 'Set an alarm. hour is 0-23, minute is 0-59.',
    params: [
      DeviceActionParam(name: 'hour', type: DeviceActionParamType.integer),
      DeviceActionParam(
        name: 'minute',
        type: DeviceActionParamType.integer,
        required: false,
      ),
      DeviceActionParam(
        name: 'label',
        type: DeviceActionParamType.text,
        required: false,
      ),
    ],
    phrases: ['alarm', 'wake me', 'wake up'],
  );

  static const setTimer = DeviceAction(
    name: 'set_timer',
    tier: DeviceActionTier.execute,
    summary: 'Start a countdown timer. seconds is the total length.',
    params: [
      DeviceActionParam(name: 'seconds', type: DeviceActionParamType.integer),
      DeviceActionParam(
        name: 'label',
        type: DeviceActionParamType.text,
        required: false,
      ),
    ],
    phrases: ['timer', 'countdown'],
  );

  static const showAlarms = DeviceAction(
    name: 'show_alarms',
    tier: DeviceActionTier.open,
    summary: "Open the device's alarm clock.",
    phrases: ['show alarms', 'my alarms', 'list alarms'],
  );

  static const torch = DeviceAction(
    name: 'torch',
    tier: DeviceActionTier.execute,
    summary: 'Turn the flashlight on or off. on is true or false.',
    params: [
      DeviceActionParam(name: 'on', type: DeviceActionParamType.boolean),
    ],
    phrases: ['flashlight', 'torch', 'light'],
  );

  static const media = DeviceAction(
    name: 'media',
    tier: DeviceActionTier.execute,
    summary:
        'Control media playback. action is one of: play, pause, next, previous.',
    params: [
      DeviceActionParam(name: 'action', type: DeviceActionParamType.text),
    ],
    phrases: ['play music', 'pause', 'next track', 'previous track'],
  );

  static const volume = DeviceAction(
    name: 'volume',
    tier: DeviceActionTier.execute,
    summary: 'Change the volume. direction is one of: up, down, mute.',
    params: [
      DeviceActionParam(name: 'direction', type: DeviceActionParamType.text),
    ],
    phrases: ['volume', 'louder', 'quieter', 'mute'],
  );

  static const openSettings = DeviceAction(
    name: 'open_settings',
    tier: DeviceActionTier.open,
    summary: 'Open a system settings screen. screen is one of: system, wifi, '
        'bluetooth, airplane, hotspot, mobile_data, battery_saver, '
        'battery_usage, dnd, display, sound, location, storage, date_time, '
        'keyboard, language, accessibility, applications, nfc, cast, vpn, '
        'developer, home.',
    params: [
      DeviceActionParam(name: 'screen', type: DeviceActionParamType.text),
    ],
    phrases: [
      'settings',
      'wifi',
      'wi-fi',
      'wireless',
      'bluetooth',
      'airplane',
      'flight mode',
      'hotspot',
      'tethering',
      'mobile data',
      'cellular',
      'battery',
      'power saving',
      'do not disturb',
      'silent',
      'brightness',
      'display',
      'sound',
      'location',
      'gps',
      'storage',
      'date',
      'time zone',
      'keyboard',
      'language',
      'accessibility',
      'apps',
      'nfc',
      'cast',
      'screen mirroring',
      'vpn',
      'developer',
    ],
  );

  static const openApp = DeviceAction(
    name: 'open_app',
    tier: DeviceActionTier.execute,
    summary: 'Launch an installed app by name.',
    params: [DeviceActionParam(name: 'name', type: DeviceActionParamType.text)],
    phrases: ['open app', 'launch', 'start app'],
  );

  static const dial = DeviceAction(
    name: 'dial',
    tier: DeviceActionTier.execute,
    summary: 'Open the dialer with a number ready to call.',
    params: [
      DeviceActionParam(name: 'number', type: DeviceActionParamType.text),
    ],
    phrases: ['call', 'dial', 'phone'],
  );

  static const composeSms = DeviceAction(
    name: 'compose_sms',
    tier: DeviceActionTier.execute,
    summary: 'Open the messaging app with a draft to a number.',
    params: [
      DeviceActionParam(
        name: 'to',
        type: DeviceActionParamType.text,
        required: false,
      ),
      DeviceActionParam(
        name: 'body',
        type: DeviceActionParamType.text,
        required: false,
      ),
    ],
    phrases: ['text', 'sms', 'message'],
  );

  static const composeEmail = DeviceAction(
    name: 'compose_email',
    tier: DeviceActionTier.execute,
    summary: 'Open the mail app with a draft.',
    params: [
      DeviceActionParam(
        name: 'to',
        type: DeviceActionParamType.text,
        required: false,
      ),
      DeviceActionParam(
        name: 'subject',
        type: DeviceActionParamType.text,
        required: false,
      ),
      DeviceActionParam(
        name: 'body',
        type: DeviceActionParamType.text,
        required: false,
      ),
    ],
    phrases: ['email', 'mail'],
  );

  static const takePhoto = DeviceAction(
    name: 'take_photo',
    tier: DeviceActionTier.execute,
    summary: 'Open the camera.',
    phrases: ['camera', 'take a photo', 'take a picture'],
  );

  static const openUrl = DeviceAction(
    name: 'open_url',
    tier: DeviceActionTier.execute,
    summary: 'Open a web address in the browser.',
    params: [DeviceActionParam(name: 'url', type: DeviceActionParamType.text)],
    phrases: ['open website', 'browse to'],
  );

  static const navigate = DeviceAction(
    name: 'navigate',
    tier: DeviceActionTier.execute,
    summary: 'Open maps with directions to a place or address.',
    params: [
      DeviceActionParam(name: 'query', type: DeviceActionParamType.text),
    ],
    phrases: ['navigate', 'directions', 'take me to', 'map'],
  );

  static const share = DeviceAction(
    name: 'share',
    tier: DeviceActionTier.execute,
    summary: 'Share a piece of text through another app.',
    params: [DeviceActionParam(name: 'text', type: DeviceActionParamType.text)],
    phrases: ['share'],
  );

  static const all = <DeviceAction>[
    setAlarm,
    setTimer,
    showAlarms,
    torch,
    media,
    volume,
    openSettings,
    openApp,
    dial,
    composeSms,
    composeEmail,
    takePhoto,
    openUrl,
    navigate,
    share,
  ];

  static DeviceAction? byName(String name) {
    final needle = name.trim().toLowerCase();
    for (final action in all) {
      if (action.name == needle) return action;
    }
    return null;
  }

  static bool isValidSettingsScreen(String screen) =>
      DeviceSettingsScreens.all.contains(screen);
}
