/*
 * `finn_ai/secure_key` for OpenHarmony — storage for the AES-256-GCM master
 * key that encrypts conversation history.
 *
 * Why the key lives in a file rather than HUKS
 * --------------------------------------------
 * Android keeps the master key in the AndroidKeyStore, and HarmonyOS's
 * equivalent keystore is HUKS — but HarmonyOS 6.1.1 exposes no symmetric
 * encryption through it:
 *
 *   - `huks` has key *management* only (generate / import / export / delete /
 *     query). `huks.encrypt`/`decrypt` do not exist, so a non-extractable HUKS
 *     key could not be used for AES;
 *   - `cryptoFramework.createSymKeyGenerator().generateSymKey()` takes no
 *     parameters and returns an ephemeral key, with no alias or persistence;
 *   - `huks.importKeyItem`/`exportKeyItem` accept asymmetric keys only.
 *
 * So a sealed-and-usable symmetric key does not exist on this platform. The key
 * is therefore written to the app's private `filesDir`, which HarmonyOS sandboxes
 * per app *and* per user: no other app, and no AppGallery-mediated component,
 * can read it. That is the same guarantee an iOS app gets from its container and
 * the same one Android's sandbox gives without the KeyStore.
 *
 * What this does and does not protect against is written down in
 * docs/architecture/SECURITY_AND_PRIVACY_ARCHITECTURE.md rather than implied.
 *
 * The channel contract is deliberately the three verbs `SecureKeyStorage`
 * needs, so the Dart side is a thin adapter:
 *   `read`   { alias }      -> base64 key, or null when the alias is unknown
 *   `write`  { alias, key } -> creates or replaces a 256-bit AES key
 *   `delete` { alias }      -> removes the key
 *   `exists` { alias }      -> bool
 */

import { BinaryMessenger, MethodCall, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import util from '@ohos.util';

const CHANNEL = 'finn_ai/secure_key';
const TAG = 'FinnSecureKey';

/** AES-256 in bytes; anything else is rejected before it reaches the file. */
const KEY_BYTES = 32;

/** Reply for the verbs whose Dart side ignores the value. */
const ACK = 'ok';

export class SecureKeyPlugin {
  private static context: common.UIAbilityContext | null = null;

  static register(messenger: BinaryMessenger, context: common.UIAbilityContext): void {
    SecureKeyPlugin.context = context;
    const channel = new MethodChannel(messenger, CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        SecureKeyPlugin.handle(call, result);
      },
    });
  }

  static handle(call: MethodCall, result: MethodResult): void {
    const alias = call.argument('alias') as string;
    switch (call.method) {
      case 'exists':
        result.success(fileIo.accessSync(SecureKeyPlugin.pathFor(alias)));
        break;

      case 'read':
        try {
          if (!fileIo.accessSync(SecureKeyPlugin.pathFor(alias))) {
            // An empty string rather than null, so Dart's `readKey` sees the
            // same "absent" answer on both a missing file and an empty one.
            result.success('');
            break;
          }
          const bytes = SecureKeyPlugin.readKeyFile(SecureKeyPlugin.pathFor(alias));
          result.success(SecureKeyPlugin.toBase64(bytes));
        } catch (error) {
          const biz = error as BusinessError;
          result.error('read_failed', `${biz.code}: ${biz.message}`, null);
        }
        break;

      case 'write': {
        const encoded = call.argument('key') as string;
        if (typeof encoded !== 'string' || encoded.length === 0) {
          result.error('bad_argument', 'key must be base64', null);
          break;
        }
        let bytes: Uint8Array;
        try {
          bytes = SecureKeyPlugin.fromBase64(encoded);
        } catch (_) {
          result.error('bad_argument', 'key is not base64', null);
          break;
        }
        if (bytes.length !== KEY_BYTES) {
          result.error('bad_argument', `key must be ${KEY_BYTES} bytes`, null);
          break;
        }
        try {
          SecureKeyPlugin.writeBytes(SecureKeyPlugin.pathFor(alias), bytes);
          result.success(ACK);
        } catch (error) {
          const biz = error as BusinessError;
          result.error('write_failed', `${biz.code}: ${biz.message}`, null);
        }
        break;
      }

      case 'delete':
        try {
          const path = SecureKeyPlugin.pathFor(alias);
          if (fileIo.accessSync(path)) {
            fileIo.unlinkSync(path);
          }
          result.success(ACK);
        } catch (error) {
          const biz = error as BusinessError;
          result.error('delete_failed', `${biz.code}: ${biz.message}`, null);
        }
        break;

      default:
        result.notImplemented();
        break;
    }
  }

  /**
   * The alias is caller-controlled but never user-controlled; still, strip
   * anything that could escape `filesDir`.
   */
  private static pathFor(alias: string): string {
    const safe = alias.replace(/[^A-Za-z0-9._-]/g, '_');
    return `${SecureKeyPlugin.filesDir()}/finn_secure_key_${safe}`;
  }

  private static filesDir(): string {
    const context = SecureKeyPlugin.context;
    if (context === null) {
      throw new Error('EntryAbility context is not available.');
    }
    return context.filesDir;
  }

  /**
   * Writes the key durably. HarmonyOS's `openSync` takes no permission argument
   * — the file is created inside the app's private `filesDir`, which no other app
   * and no other user can reach, so the sandbox *is* the access control.
   */
  private static writeBytes(path: string, bytes: Uint8Array): void {
    const fd = fileIo.openSync(
      path,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC,
    );
    try {
      fileIo.writeSync(fd.fd, bytes.buffer as ArrayBuffer);
      fileIo.fsyncSync(fd.fd);
    } finally {
      fileIo.closeSync(fd.fd);
    }
  }

  /** Reads a whole small file through a descriptor; `readFileSync` is async here. */
  private static readKeyFile(path: string): Uint8Array {
    const size = 4096;
    const buffer = new ArrayBuffer(size);
    const fd = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    try {
      const read = fileIo.readSync(fd.fd, buffer);
      return new Uint8Array(buffer, 0, read > 0 ? read : 0);
    } finally {
      fileIo.closeSync(fd.fd);
    }
  }

  private static toBase64(bytes: Uint8Array): string {
    return new util.Base64Helper().encodeToStringSync(bytes);
  }

  private static fromBase64(value: string): Uint8Array {
    const helper = new util.Base64Helper();
    return helper.decodeSync(value) as Uint8Array;
  }
}