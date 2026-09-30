// The rules for when a turn should search the web. Pure functions of the
// prompt: no network, no model (ADR 0001).

/// Why a turn did or did not search. Kept as data so the eval and the UI can
/// report the decision without re-deriving it.
enum SearchPlanReason {
  disabled,
  attachment,
  noCue,
  backReference,
  stableFact,
  explicit,
  fresh,
  factCheck;

  /// Whether this reason means "search".
  bool get searches => this == explicit || this == fresh || this == factCheck;
}

/// Decides locally whether a request may benefit from current internet results.
class WebSearchPolicy {
  const WebSearchPolicy();

  bool shouldSearch(String prompt) => reasonFor(prompt).searches;

  /// The decision and the rule that made it. [shouldSearch] is this reduced
  /// to a bool; the eval and the UI want the reason.
  SearchPlanReason reasonFor(String prompt) {
    final value = _collapse(prompt).toLowerCase();
    if (value.isEmpty) return SearchPlanReason.noCue;
    // A user who asks for the web gets the web, whatever else is true of the
    // prompt. This is checked first so an explicit request is never suppressed
    // by a heuristic below.
    if (_explicit.any(value.contains)) return SearchPlanReason.explicit;
    // A question about what was already said can only be answered from the
    // transcript, so retrieval is never the right tool for it.
    if (_refersBack(value)) return SearchPlanReason.backReference;
    // Freshness and news win over everything below: a stable *subject* is not
    // a stable *answer*. "What is the capital of France right now" is a
    // closed-domain shape asked in a time-sensitive way, and it must browse.
    if (_freshness.any(value.contains) || _news.any(value.contains)) {
      return SearchPlanReason.fresh;
    }
    // Closed-domain facts do not change between installs. Browsing for them
    // was the single largest source of wasted time on the device: the capital
    // of France, a planet's size, a prime number and a recipe's method all
    // matched the "needs a fact check" question shape and each cost ~3s of
    // retrieval before the model answered the same thing it already knew.
    if (_isStableFact(value)) return SearchPlanReason.stableFact;
    if (_isAboutTheUser(value)) return SearchPlanReason.backReference;
    return _recipes.any(value.contains) ||
            _requiresFactCheck(value, _collapse(prompt))
        ? SearchPlanReason.factCheck
        : SearchPlanReason.noCue;
  }

  /// Whether a prompt is about something that is settled enough to answer
  /// from what the model already has.
  ///
  /// Deliberately conservative: it suppresses only closed-domain shapes the
  /// model is reliable about, and every one of these is a category the eval
  /// suite can check. A false negative costs a few seconds of retrieval; a
  /// false positive is the model confidently stating a stale number, so
  /// anything time-sensitive, comparative or specific is left to browse.
  static bool _isStableFact(String value) {
    // Arithmetic and counting: answered exactly, never a lookup.
    if (RegExp(
      r'\b(?:what\s+is|calculate|compute|solve|how\s+many\s+is)\b[^?]*'
      r'\d+\s*(?:[\+\-\*\/x×÷]\s*\d+|\bof\b|\bin\s+\d)',
    ).hasMatch(value)) {
      return true;
    }
    if (_closedDomainTopics.any(value.contains)) {
      return true;
    }
    return false;
  }

  /// Whether a prompt refers back to something already in the conversation.
  ///
  /// A follow-up can only be answered from the transcript. On the device
  /// "What did you reply above? Say it again." searched the web, opened
  /// Wikipedia and read two more pages before the model restated an answer it
  /// had just given. Retrieval cannot help with a question about what was
  /// already said, so these never browse.
  ///
  /// Matched on anaphora rather than on question words, so it does not need to
  /// know the language: a pronoun or a "the same/again" is language-neutral in
  /// a way a keyword list is not.
  static bool _refersBack(String value) {
    if (_backReferenceMarkers.any(value.contains)) return true;
    // A one-or-two-word follow-up ("again", "why?", "and then?") is a
    // continuation by construction.
    final words = value.split(' ').where((w) => w.isNotEmpty).length;
    return words <= 2;
  }

  static const _backReferenceMarkers = [
    'again',
    'what did you',
    'what did i',
    'what you said',
    'what i said',
    'you said',
    'i said',
    'you replied',
    'you answered',
    'the above',
    'earlier',
    'just told',
    'tell me again',
    'repeat that',
    'as before',
    'like before',
    'same as',
    'you just',
    'ripeti',
    'repete',
    'ce que tu',
    'ce que vous',
    'what did you say',
    'come hai detto',
    'was hast du',
    'nochmal',
    'wie gesagt',
  ];

  /// Question shapes whose subject matter is fixed, in the five shipped
  /// locales. Matched as whole phrases so a genuinely current question of the
  /// same shape ("what is the price of gold today") is not caught: the
  /// freshness words are checked before this.
  static const _closedDomainTopics = [
    // Authorship and discovery are settled history the model knows. A
    // "latest"/"new" version of the same question is caught by the freshness
    // words, which are checked first.
    'who wrote',
    'who painted',
    'who composed',
    'who invented',
    'who discovered',
    'who directed',
    'who founded',
    'who was the first',
    'meaning of the word',
    'definition of',
    'what does the word',
    'what year did',
    'in what year',
    'capital of',
    'largest planet',
    'smallest planet',
    'red planet',
    'prime number',
    'is prime',
    'prime factors',
    'gcd',
    'lcm',
    'factorial',
    'how many continents',
    'how many oceans',
    'how many days',
    'how many months',
    'how many letters in the',
    'how many letters in a',
    'how many sides does a',
    'how many bones',
    'how many chromosomes',
    'how many teeth',
    'how many states',
    'capitale de',
    'capitale du',
    'mayor planeta',
    'numero primo',
    'primi',
    'nombre premier',
    'plus grand',
    'continent',
    'hauptstadt',
    'größte planet',
    'primzahl',
  ];

  static String _collapse(String prompt) =>
      prompt.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Whether a question is about a specific person, place, thing or year,
  /// which is where the model's memory is thinnest and a retrieval helps.
  ///
  /// This used to be "any question", so "How do I boil an egg?", "What is the
  /// chemical formula for water?" and "How do I fix a flat bicycle tire?" each
  /// paid a 5-9 s search, and the eval measured 76% of must-not-browse turns
  /// searching. A generic explanation, how-to or definition is the model's own
  /// territory. A question that *names* something ("How does routing in
  /// Bridgetown work?") is where a 1.6B model guesses, so that one browses.
  static bool _requiresFactCheck(String value, String original) {
    final stripped = value.replaceFirst(_leadingPunctuation, '');
    if (!_questionOpener.hasMatch(stripped)) return false;
    if (_conversationalQuestions.any(value.contains)) return false;
    if (_isSelfContained(value)) return false;
    // German capitalises every noun, so a capital letter says nothing there.
    if (_germanOpener.hasMatch(stripped)) return false;
    return _namesSomething(original);
  }

  static final RegExp _germanOpener = RegExp(
    r'^(?:wie|wer|was|warum|wieso|welche|welcher|welches|wo|wann)(?!\w)',
    caseSensitive: false,
  );

  /// A capitalised word that is not the first word, or a number that looks
  /// like a year or a quantity. A lone "I" is a pronoun, not a name.
  static bool _namesSomething(String original) {
    final words = original.split(' ');
    for (var i = 1; i < words.length; i++) {
      // A capital after a full stop is the next sentence, not a name.
      if (RegExp(r'[.!?…]["”)]*$').hasMatch(words[i - 1])) continue;
      final word = words[i].replaceAll(
          RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true), '');
      if (word.length < 2) continue;
      final first = word.substring(0, 1);
      if (first != first.toLowerCase() && first == first.toUpperCase()) {
        return true;
      }
    }
    return RegExp(r'\d{3,}').hasMatch(original);
  }

  /// A question about what the user themselves said or own is answered from
  /// the conversation, not the web: "How many cartons of milk did I buy?".
  static bool _isAboutTheUser(String value) => _userMarkers.hasMatch(value);

  static final RegExp _userMarkers = RegExp(
    r"\b(?:my|mine|did i|do i|have i|i bought|i told|i said|i have|"
    r"i am|i'm|i was|our|we)\b|\b(?:il mio|la mia|i miei|mio|mia)\b|"
    r"\b(?:mi|mis|nuestro|nuestra)\b|\b(?:mon|ma|mes|notre)\b|"
    r"\b(?:mein|meine|meinen|unser)\b",
  );

  static bool _isSelfContained(String value) {
    // Pure arithmetic expressions like "what is 2 + 2", "what is 15 * 8"
    if (RegExp(r'\b(?:calculate|solve)\b|\d+\s*[\+\-\*\/]\s*\d+')
        .hasMatch(value)) {
      return true;
    }
    // Self-contained programming, creative, or casual requests
    if (RegExp(
      r'\b(?:write\s+code|python\s+code|dart\s+code|javascript\s+code|'
      r'debug\s+this|write\s+a\s+function|write\s+a\s+poem|write\s+a\s+story|tell\s+a\s+joke)\b',
    ).hasMatch(value)) {
      return true;
    }
    return false;
  }

  static final RegExp _leadingPunctuation = RegExp(r'^[¿¡«»“”‘’\s.!?,:;()\-]+');

  static final RegExp _questionOpener = RegExp(
    r"^(?:"
    r"how|what|why|who|which|where|when|does|do|is|are|can|could|should|"
    r"come|cosa|che\s+cos|perché|perche|chi|quale|quali|dove|quando|"
    r"cómo|como|qué|que\s+es|por\s+qué|por\s+que|quién|quien|cuál|cual|"
    r"dónde|donde|cuándo|cuando|"
    r"comment|qu'est|qu'est-ce|pourquoi|quel|quelle|où|combien|"
    r"wie|was|warum|wer|welche|welcher|welches|wo|wann|wieso"
    r")(?!\w)",
    caseSensitive: false,
  );

  static const _conversationalQuestions = [
    'how are you',
    'how are u',
    'how is it going',
    "how's it going",
    'how do you do',
    'how are you doing',
    'how are you feeling',
    'how do you feel',
    'how do i feel',
    "what's up",
    'whats up',
    'how was your day',
    'what is your name',
    "what's your name",
    'who are you',
    'what are you',
    'what can you do',
    'what do you do',
    'how old are you',
    'what is your favourite',
    'what is your favorite',
    'how do you say',
    'come stai',
    'come va',
    'come state',
    'come andiamo',
    'che si dice',
    'chi sei',
    'cosa puoi fare',
    'quanti anni hai',
    'come ti chiami',
    'cómo estás',
    'como estas',
    'cómo está',
    'como esta',
    'qué tal',
    'que tal',
    'cómo te va',
    'como te va',
    'quién eres',
    'quien eres',
    'qué puedes hacer',
    'que puedes hacer',
    'cuántos años',
    'cuantos anos',
    'cómo te llamas',
    'como te llamas',
    'comment ça va',
    'comment ca va',
    'comment vas-tu',
    'comment allez-vous',
    'quoi de neuf',
    'qui es-tu',
    'qui es tu',
    'que peux-tu faire',
    'quel âge',
    'quel age',
    "comment tu t'appelles",
    'wie geht es dir',
    'wie gehts',
    'wie geht es',
    'was geht',
    'wer bist du',
    'was kannst du',
    'wie alt bist du',
    'wie heißt du',
    'wie heisst du',
  ];

  static const _explicit = [
    'search the web',
    'search online',
    'search for',
    'look up',
    'browse the web',
    'on the internet',
    'find sources',
    'with sources',
    'cerca online',
    'cerca su internet',
    'cerca sul web',
    'buscar en internet',
    'recherche sur internet',
    'im internet suchen',
  ];
  static const _freshness = [
    'latest',
    'today',
    'current',
    'right now',
    'recent',
    'this week',
    'this month',
    'price of',
    'weather',
    'score',
    'schedule',
    'opening hours',
    'ultimo',
    'ultima',
    'oggi',
    'attuale',
    'recente',
    'meteo',
    'prezzo',
    'hoy',
    'actual',
    'récent',
    'aujourd’hui',
    'aktuell',
    'heute',
  ];
  static const _news = [
    'news',
    'headlines',
    'breaking',
    'what happened',
    'notizie',
    'novità',
    'ultime notizie',
    'noticias',
    'actualités',
    'nachrichten',
  ];
  static const _recipes = [
    'recipe',
    'recipes',
    'ricetta',
    'ricette',
    'receta',
    'recette',
    'rezept',
  ];
}
