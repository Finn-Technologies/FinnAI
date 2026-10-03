/*
 * `plugins.flutter.io/image_picker` for OpenHarmony.
 *
 * The Dart side (method_channel_image_picker.dart) only needs an absolute,
 * dart:io-readable path: `XFile(path)` ignores every other field. HarmonyOS's
 * pickers hand back `file://` URIs into the media library, which are not
 * readable by name, so each picked photo is copied into the app cache first and
 * that path is returned.
 *
 * Only what FinnAI calls is implemented: `pickImage` from the gallery. Camera
 * capture, multi-select, video and `retrieve` report notImplemented so the Dart
 * side raises MissingPluginException and the app shows its own "attachment
 * failed" message instead of silently returning nothing.
 */

import { BinaryMessenger, MethodCall, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';

const CHANNEL = 'plugins.flutter.io/image_picker';
const TAG = 'FinnImagePicker';

// image_picker's ImageSource enum: camera = 0, gallery = 1.
const IMAGE_SOURCE_GALLERY = 1;

export class ImagePickerPlugin {
  static register(messenger: BinaryMessenger, context: common.UIAbilityContext): void {
    const channel = new MethodChannel(messenger, CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        ImagePickerPlugin.handle(call, result, context);
      },
    });
  }

  static handle(
    call: MethodCall,
    result: MethodResult,
    context: common.UIAbilityContext,
  ): void {
    if (call.method !== 'pickImage') {
      result.notImplemented();
      return;
    }
    const source = call.argument('source') as number;
    if (source !== IMAGE_SOURCE_GALLERY) {
      // No camera picker is wired up; be explicit rather than returning null,
      // which Dart would read as "the user cancelled".
      result.error('camera_unavailable', 'Camera capture is not implemented on HarmonyOS.', null);
      return;
    }

    const photoPicker = new picker.PhotoViewPicker(context);
    const options = new picker.PhotoSelectOptions();
    options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;

    photoPicker.select(options).then((selected: picker.PhotoSelectResult): void => {
      const uris = selected.photoUris;
      if (uris === undefined || uris.length === 0) {
        // Cancelled: Dart expects null, not an empty list.
        result.success(null);
        return;
      }
      ImagePickerPlugin.copyIntoCache(context, uris[0]).then((path: string): void => {
        result.success(path);
      }).catch((error: BusinessError): void => {
        result.error('copy_failed', `${error.code}: ${error.message}`, null);
      });
    }).catch((error: BusinessError): void => {
      // 13900012 = user cancelled the picker; that is not an error.
      if (error.code === 13900012) {
        result.success(null);
        return;
      }
      console.error(`${TAG} select failed: ${error.code} ${error.message}`);
      result.error('pick_failed', `${error.code}: ${error.message}`, null);
    });
  }

  /**
   * Copies a picked photo into the app's cache directory and returns the plain
   * path. `fs.copyFileSync` accepts a file:// URI, and the cache is the only
   * directory Dart can read by path.
   */
  private static async copyIntoCache(context: common.UIAbilityContext, uri: string): Promise<string> {
    const cacheDir = context.cacheDir;
    const suffix = uri.substring(uri.lastIndexOf('.'));
    const target = `${cacheDir}/finn_pick_${Date.now()}${suffix}`;
    const srcFd = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    try {
      const dstFd = fileIo.openSync(target, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      try {
        fileIo.copyFileSync(srcFd.fd, dstFd.fd);
      } finally {
        fileIo.closeSync(dstFd.fd);
      }
    } finally {
      fileIo.closeSync(srcFd.fd);
    }
    return target;
  }
}