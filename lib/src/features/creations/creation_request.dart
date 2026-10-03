import 'package:finn_ai/src/features/creations/creation_model.dart';

/// A chat message that asks for an app, a widget or a presentation to be made.
class CreationRequest {
  const CreationRequest({required this.kind, required this.brief});

  final CreationKind kind;

  /// What the user wants, in their words, with the "make me a…" removed.
  final String brief;

  static const _make =
      r'(?:make|build|create|design|generate|whip up|put together|set up|develop)';

  /// The nouns that say what is wanted, by kind. A noun alone ("a counter") is
  /// not a request; it must follow a make-verb.
  static const _widgetNouns = r'(?:home[- ]?screen\s+)?widgets?';
  static const _deckNouns =
      r'(?:presentations?|slide\s?shows?|slides?|slide decks?|decks?|power\s?points?|pptx)';
  // Only nouns that mean a thing you *use*. "a shopping list" or "a timer" on
  // its own is a request for words, not for an app; they count when "app" is
  // beside them ("a shopping list app").
  static const _appNouns =
      r'(?:mini[- ]?apps?|apps?|applications?|trackers?|counters?|scoreboards?)';

  static final _widget = RegExp(
    '\\b$_make\\b[^.?!]{0,40}?\\b$_widgetNouns\\b',
    caseSensitive: false,
  );
  static final _deck = RegExp(
    '\\b$_make\\b[^.?!]{0,40}?\\b$_deckNouns\\b',
    caseSensitive: false,
  );
  static final _app = RegExp(
    '\\b$_make\\b[^.?!]{0,40}?\\b$_appNouns\\b',
    caseSensitive: false,
  );

  /// Questions *about* making things are for the model to answer, not for
  /// the builder: "how do I make an app", "what is a widget".
  static final _aboutMaking = RegExp(
    r'^\s*(?:how|what|why|which|where|when|can i|should i|is it|does|do you know|explain|'
    r'tell me (?:how|what|why)|teach)\b',
    caseSensitive: false,
  );

  /// Writing code is a chat answer unless it is clearly a Finn app.
  static final _codeLanguage = RegExp(
    r'\b(?:in|using|with)\s+(?:flutter|dart|python|swift|kotlin|java|javascript|typescript|react|html|css|c\+\+|rust|go|php|sql)\b|'
    r'\b(?:website|web app|web site|ios app|android app|api|backend|script|function|class|repo)\b',
    caseSensitive: false,
  );

  /// Null when [text] is not asking for something to be made.
  static CreationRequest? parse(String text) {
    final value = text.trim();
    if (value.isEmpty || value.length > 400) return null;
    if (_aboutMaking.hasMatch(value) || _codeLanguage.hasMatch(value)) {
      return null;
    }
    // A widget or deck noun beats an app noun: "a counter widget" is a widget.
    final kind = _widget.hasMatch(value)
        ? CreationKind.widget
        : _deck.hasMatch(value)
            ? CreationKind.presentation
            : _app.hasMatch(value)
                ? CreationKind.app
                : null;
    if (kind == null) return null;
    return CreationRequest(kind: kind, brief: _brief(value));
  }

  /// "make me a water counter app" -> "water counter app".
  static String _brief(String text) => text
      .replaceFirst(
        RegExp(
          '^(?:please\\s+)?(?:(?:can|could|would) you\\s+)?(?:i (?:want|need|would like)\\s+(?:you to\\s+)?)?'
          '$_make\\s+(?:me\\s+)?(?:an?\\s+|the\\s+|my\\s+|some\\s+)?',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'[?!.]+$'), '')
      .trim();
}
