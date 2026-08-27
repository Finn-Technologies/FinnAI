/// N-gram continuation table used to draft speculative tokens for lookahead
/// decoding.
///
/// The table is built exclusively from *verified* tokens — the prompt and
/// tokens that were accepted by the sampler. Given the last (nGram - 1)
/// tokens of the verified stream it returns the most frequent observed
/// continuation, which becomes a draft token for the next position.
///
/// Drafts are chained: once a draft is picked for position `pos + i`, the
/// key for position `pos + i + 1` is the last (nGram - 1) tokens of
/// (verified stream + drafts so far). Chained drafts are pure guesses and
/// get verified in a single batched forward pass.
final class NGramTable {
  NGramTable({this.nGram = 4, this.maxPerKey = 8, this.maxKeys = 65536});

  /// Number of tokens in one n-gram (key length is [nGram] - 1).
  final int nGram;

  /// Maximum continuation candidates retained per key.
  final int maxPerKey;

  /// Soft cap on distinct keys. When exceeded the table is cleared and
  /// rebuilt from the verified stream (keeps memory bounded on long
  /// conversations; drafts simply disappear for a short while).
  final int maxKeys;

  final Map<_GramKey, List<_Continuation>> _table =
      <_GramKey, List<_Continuation>>{};
  final List<int> _window = <int>[];

  /// Total number of entries currently stored.
  int get keyCount => _table.length;

  /// Feed one verified token, extending the running (nGram - 1) window and
  /// recording its observed continuation.
  void add(int token) {
    if (_window.length == nGram - 1) {
      _insert(_GramKey(_window), token);
    }
    _window.add(token);
    if (_window.length > nGram - 1) _window.removeAt(0);
  }

  /// Seed the table from a verified token stream (prompt + history).
  void seed(Iterable<int> tokens) {
    for (final t in tokens) {
      add(t);
    }
  }

  /// Best continuation for [key], or `null` when the table has no data.
  int? lookup(List<int> key) {
    final entries = _table[_GramKey(key)];
    if (entries == null || entries.isEmpty) return null;
    var best = entries.first;
    for (final e in entries) {
      if (e.count > best.count) best = e;
    }
    return best.token;
  }

  /// Build a draft window of up to [window] tokens for the positions that
  /// follow [history] (the verified stream, ending at the last committed
  /// position).
  ///
  /// Employs Prompt Lookup Decoding (PLD): searches backwards in [history]
  /// for the current suffix to extract exact prompt/context continuations,
  /// falling back to chained n-gram frequency lookup when no direct prompt
  /// match is found. Returns fewer tokens when the table runs dry.
  List<int> draft(List<int> history, int window) {
    if (history.isEmpty || window <= 0) return const <int>[];

    // 1. Try Prompt Lookup Decoding: match longest suffix (3-gram down to 2-gram)
    for (var matchLen = nGram - 1; matchLen >= 2; matchLen--) {
      if (history.length > matchLen) {
        final query = history.sublist(history.length - matchLen);
        final promptDraft = _findPromptContinuation(history, query, window);
        if (promptDraft != null && promptDraft.isNotEmpty) {
          return promptDraft;
        }
      }
    }

    // 2. Chained n-gram continuation fallback
    final out = <int>[];
    while (out.length < window) {
      final key = _keyFor(history, out);
      if (key == null) break;
      final cont = lookup(key);
      if (cont == null) break;
      out.add(cont);
    }
    return out;
  }

  /// Searches backwards in [source] for the most recent occurrence of [query]
  /// prior to the trailing position, returning up to [maxTokens] that followed it.
  List<int>? _findPromptContinuation(
    List<int> source,
    List<int> query,
    int maxTokens,
  ) {
    final qLen = query.length;
    final searchLimit = source.length - qLen;
    for (var i = searchLimit - 1; i >= 0; i--) {
      var match = true;
      for (var j = 0; j < qLen; j++) {
        if (source[i + j] != query[j]) {
          match = false;
          break;
        }
      }
      if (match) {
        final start = i + qLen;
        final end = (start + maxTokens) > source.length
            ? source.length
            : (start + maxTokens);
        if (start < end) {
          return source.sublist(start, end);
        }
      }
    }
    return null;
  }

  void _insert(_GramKey key, int continuation) {
    if (_table.length >= maxKeys && !_table.containsKey(key)) {
      // Bounded memory: drop everything rather than letting the table grow
      // without bound across very long conversations.
      _table.clear();
    }
    final entries = _table.putIfAbsent(key, () => <_Continuation>[]);
    for (final e in entries) {
      if (e.token == continuation) {
        e.count++;
        return;
      }
    }
    if (entries.length >= maxPerKey) {
      // Evict the least frequent candidate to make room.
      var worst = 0;
      for (var i = 1; i < entries.length; i++) {
        if (entries[i].count < entries[worst].count) worst = i;
      }
      entries[worst] = _Continuation(continuation);
    } else {
      entries.add(_Continuation(continuation));
    }
  }

  List<int>? _keyFor(List<int> history, List<int> drafts) {
    final total = history.length + drafts.length;
    if (total < nGram - 1) return null;
    final key = <int>[];
    final start = total - (nGram - 1);
    for (var i = start; i < total; i++) {
      key.add(i < history.length ? history[i] : drafts[i - history.length]);
    }
    return key;
  }
}

final class _Continuation {
  _Continuation(this.token) : count = 1;
  final int token;
  int count;
}

/// Value-equality wrapper so `List<int>` keys work in a Dart map.
final class _GramKey {
  _GramKey(List<int> tokens)
      : tokens = List<int>.unmodifiable(tokens),
        _hash = _fold(tokens);

  final List<int> tokens;
  final int _hash;

  static int _fold(List<int> t) {
    var h = 0;
    for (final x in t) {
      h = (h * 31) ^ x;
    }
    return h;
  }

  @override
  bool operator ==(Object other) {
    if (other is! _GramKey) return false;
    if (other.tokens.length != tokens.length) return false;
    for (var i = 0; i < tokens.length; i++) {
      if (other.tokens[i] != tokens[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => _hash;
}
