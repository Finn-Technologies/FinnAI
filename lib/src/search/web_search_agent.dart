import 'search_agent.dart';

/// UI adapter kept separate from the inference owner so continuation and
/// regeneration actions can reuse the same safe retrieval contract.
class WebSearchAgent extends SearchAgent {
  WebSearchAgent({super.searchService});
}
