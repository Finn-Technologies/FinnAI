import 'package:flutter/widgets.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/actions/action_catalog.dart';
import 'package:finn_ai/src/features/actions/device_action.dart';

/// Turns a resolved invocation into the sentence the user approves.
///
/// The confirmation has to state the *resolved* action, not the request, so a
/// misheard hour or the wrong app is visible before anything runs.
abstract final class DeviceActionDescriptions {
  static String describe(BuildContext context, DeviceActionInvocation call) {
    final l10n = L10n.of(context);
    final arguments = call.arguments;

    switch (call.action.name) {
      case 'set_alarm':
        final hour = call.intArgument('hour') ?? 0;
        final minute = call.intArgument('minute') ?? 0;
        return l10n.deviceActionSetAlarm(_clock(hour, minute));
      case 'set_timer':
        return l10n.deviceActionSetTimer(
          _duration(call.intArgument('seconds') ?? 0),
        );
      case 'show_alarms':
        return l10n.deviceActionShowAlarms;
      case 'torch':
        return call.boolArgument('on')
            ? l10n.deviceActionTorchOn
            : l10n.deviceActionTorchOff;
      case 'media':
        return l10n.deviceActionMedia(_mediaLabel(l10n, arguments['action']));
      case 'volume':
        return l10n.deviceActionVolume(
          _volumeLabel(l10n, arguments['direction']),
        );
      case 'vibrate':
        return l10n.deviceActionVibrate;
      case 'open_settings':
        return l10n.deviceActionOpenSettings(
          screenLabel(context, arguments['screen']?.toString() ?? ''),
        );
      case 'open_app':
        return l10n.deviceActionOpenApp(call.argument('name') ?? '');
      case 'dial':
        return l10n.deviceActionDial(call.argument('number') ?? '');
      case 'compose_sms':
        return l10n.deviceActionComposeSms;
      case 'compose_email':
        return l10n.deviceActionComposeEmail;
      case 'take_photo':
        return l10n.deviceActionTakePhoto;
      case 'open_url':
        return l10n.deviceActionOpenUrl(call.argument('url') ?? '');
      case 'navigate':
        return l10n.deviceActionNavigate(call.argument('query') ?? '');
      case 'share':
        return l10n.deviceActionShare;
      default:
        return call.action.summary;
    }
  }

  /// The single line a completed action leaves in the conversation.
  static String resultLine(BuildContext context, DeviceActionResult result) {
    final l10n = L10n.of(context);
    return switch (result.outcome) {
      DeviceActionOutcome.performed => result.detail.isEmpty
          ? l10n.deviceActionsResultDone
          : l10n.deviceActionsResultPerformed(result.detail),
      DeviceActionOutcome.opened => result.detail.isEmpty
          ? l10n.deviceActionsResultDone
          : l10n.deviceActionsResultOpened(
              screenLabel(context, result.detail),
            ),
      DeviceActionOutcome.unavailable => l10n.deviceActionsResultUnavailable,
      DeviceActionOutcome.failed => result.error.isEmpty
          ? l10n.deviceActionsResultFailed
          : l10n.deviceActionsResultFailedDetail(result.error),
    };
  }

  static String screenLabel(BuildContext context, String screen) {
    final l10n = L10n.of(context);
    return switch (screen) {
      DeviceSettingsScreens.wifi => l10n.deviceScreenWifi,
      DeviceSettingsScreens.bluetooth => l10n.deviceScreenBluetooth,
      DeviceSettingsScreens.airplane => l10n.deviceScreenAirplane,
      DeviceSettingsScreens.hotspot => l10n.deviceScreenHotspot,
      DeviceSettingsScreens.mobileData => l10n.deviceScreenMobileData,
      DeviceSettingsScreens.batterySaver => l10n.deviceScreenBatterySaver,
      DeviceSettingsScreens.batteryUsage => l10n.deviceScreenBatteryUsage,
      DeviceSettingsScreens.dnd => l10n.deviceScreenDnd,
      DeviceSettingsScreens.display => l10n.deviceScreenDisplay,
      DeviceSettingsScreens.sound => l10n.deviceScreenSound,
      DeviceSettingsScreens.location => l10n.deviceScreenLocation,
      DeviceSettingsScreens.storage => l10n.deviceScreenStorage,
      DeviceSettingsScreens.dateTime => l10n.deviceScreenDateTime,
      DeviceSettingsScreens.language => l10n.deviceScreenLanguage,
      DeviceSettingsScreens.keyboard => l10n.deviceScreenKeyboard,
      DeviceSettingsScreens.accessibility => l10n.deviceScreenAccessibility,
      DeviceSettingsScreens.applications => l10n.deviceScreenApplications,
      DeviceSettingsScreens.nfc => l10n.deviceScreenNfc,
      DeviceSettingsScreens.cast => l10n.deviceScreenCast,
      DeviceSettingsScreens.vpn => l10n.deviceScreenVpn,
      DeviceSettingsScreens.developer => l10n.deviceScreenDeveloper,
      DeviceSettingsScreens.home => l10n.deviceScreenHome,
      _ => screen,
    };
  }

  static String _mediaLabel(AppLocalizations l10n, Object? action) =>
      switch (action) {
        'play' => l10n.deviceActionMediaPlay,
        'pause' => l10n.deviceActionMediaPause,
        'next' => l10n.deviceActionMediaNext,
        _ => l10n.deviceActionMediaPrevious,
      };

  static String _volumeLabel(AppLocalizations l10n, Object? direction) =>
      switch (direction) {
        'up' => l10n.deviceActionVolumeUp,
        'down' => l10n.deviceActionVolumeDown,
        _ => l10n.deviceActionVolumeMute,
      };

  static String _clock(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static String _duration(int seconds) {
    if (seconds < 60) return '$seconds s';
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return remainder == 0 ? '$minutes min' : '$minutes min $remainder s';
  }
}
