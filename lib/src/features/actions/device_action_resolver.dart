import 'package:finn_ai/src/features/actions/action_directive.dart';
import 'package:finn_ai/src/features/actions/action_matcher.dart';
import 'package:finn_ai/src/features/actions/action_parser.dart';
import 'package:finn_ai/src/features/actions/device_action.dart';

/// Asks the model to resolve a request the matcher could not. Returns the raw
/// completion; parsing and validation stay here.
typedef DeviceActionModelQuery = Future<String> Function(String prompt);

/// Turns a request into an action.
///
/// The deterministic matcher runs first and settles "set an alarm for 7am" and
/// "turn on wifi" outright, which is both faster and more reliable at 1.6B than
/// a generation pass. The model is only consulted for phrasings the matcher
/// declines to guess at, and a null result is a first-class outcome — the caller
/// says so rather than running something plausible.
class DeviceActionResolver {
  const DeviceActionResolver({
    this.modelQuery,
    this.matcher = const DeviceActionMatcher(),
  });

  final DeviceActionModelQuery? modelQuery;
  final DeviceActionMatcher matcher;

  bool get hasModel => modelQuery != null;

  Future<DeviceActionInvocation?> resolve(String request) async {
    final direct = matcher.match(request);
    if (direct != null) return direct;

    final query = modelQuery;
    if (query == null) return null;
    final String raw;
    try {
      raw = await query(DeviceActionDirective.promptFor(request));
    } catch (_) {
      // A model that fails or returns nothing is the same outcome as one that
      // declined: unresolved, which the UI can say out loud. Rethrowing turned
      // it into a raw error string the page never renders.
      return null;
    }
    return const DeviceActionParser().parse(raw);
  }
}
