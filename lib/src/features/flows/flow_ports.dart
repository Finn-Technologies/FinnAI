import 'package:finn_ai/src/engine/api/web_source.dart';
import 'package:finn_ai/src/features/flows/flow_model.dart';

/// Everything a flow reaches outside itself, as narrow interfaces.
///
/// The runner depends on these and nothing else, so it can be tested with no
/// model, network, notification or disk, and so `flows/` never imports the
/// engine, the search feature or the conversation store (`tool/verify_boundaries.sh`).
/// The chat feature, the composition root, supplies the real ones.

/// Produces the model's answer to one prompt.
abstract interface class FlowModel {
  /// [groundedContext] is web material already formatted for the prompt, or
  /// empty when the step had none.
  Future<String> answer(String prompt, {String groundedContext = ''});
}

/// What one bounded search returned.
class FlowSearchResult {
  const FlowSearchResult({
    this.groundedContext = '',
    this.sources = const [],
    this.failed = false,
  });

  final String groundedContext;
  final List<WebSource> sources;

  /// The web did not answer. A flow carries on without sources rather than
  /// failing: a morning brief with no news is still a morning brief.
  final bool failed;
}

/// Runs one search. At most one network round, inside a fixed budget.
abstract interface class FlowSearch {
  Future<FlowSearchResult> search(String query);
}

/// Where a flow's written result goes so the user can read it.
///
/// The run log deliberately holds no model text, so the result lives in the
/// encrypted conversation store instead, as a chat the user can open.
abstract interface class FlowOutputSink {
  Future<void> deliver(FinnFlow flow, String text, List<WebSource> sources);
}

/// Tells the user something happened, outside the app.
abstract interface class FlowNotifier {
  Future<void> notify({
    required String flowId,
    required String title,
    required String body,
  });
}
