import 'dart:convert';

/// How FinnAI Code talks to the shell inside the container.
///
/// The container's only channel is a serial console, so a command's output is
/// framed by markers the guest prints with `printf` and an argument: the
/// console echoing the command line back can never contain a whole marker,
/// and a program's output only could by printing one on purpose (the nonce
/// makes that a guess).
///
/// Inside the guest:
/// - `/mnt` is shared with the app (9p); `/mnt/p` is the project, `/mnt/.finn`
///   is ours.
/// - `run.sh <nonce>` unpacks `in.tar` over a fresh `/mnt/p`, runs `cmd.sh`
///   there through a pipe (so programs see no terminal and print no colour
///   codes), prints the exit code, and packs the project to `out.tar`.
/// - `pull.sh <nonce>` only packs; it is used after a command was stopped.
abstract final class ContainerProtocol {
  static const String project = '/mnt/p';

  /// Paths as the 9p share sees them (`/` is the guest's `/mnt`).
  static const String shareDir = '/.finn';
  static const String inTar = '$shareDir/in.tar';
  static const String outTar = '$shareDir/out.tar';
  static const String commandFile = '$shareDir/cmd.sh';
  static const String runScript = '$shareDir/run.sh';
  static const String pullScript = '$shareDir/pull.sh';

  static const String pullScriptBody = '''
cd $project 2>/dev/null && tar -cf /mnt/.finn/out.tar . 2>/dev/null
printf '<<FINN:%s:S>>\\n' "\$1"
''';

  static const String runScriptBody = '''
n=\$1
rm -rf $project && mkdir -p $project && cd $project
tar -xf /mnt/.finn/in.tar 2>/dev/null
rm -f /mnt/.finn/in.tar /mnt/.finn/out.tar
printf '\\n<<FINN:%s:B>>\\n' "\$n"
{ HOME=$project TMPDIR=/tmp PWD=$project sh /mnt/.finn/cmd.sh </dev/null
  echo \$? > /tmp/.finn-rc; } 2>&1 | cat
c=\$(cat /tmp/.finn-rc 2>/dev/null || echo 1)
printf '\\n<<FINN:%s:E:%d>>\\n' "\$n" "\$c"
sh /mnt/.finn/pull.sh "\$n"
''';

  /// Typed once the console shows its first prompt: stop echoing, quiet the
  /// prompt, make our folders, and say so.
  static String initLine(String nonce) =>
      'stty -echo 2>/dev/null; PS1=""; mkdir -p /mnt/.finn $project; '
      "printf '<<FINN:%s:R>>\\n' $nonce\n";

  static String runLine(String nonce) => 'sh /mnt/.finn/run.sh $nonce\n';
  static String pullLine(String nonce) => 'sh /mnt/.finn/pull.sh $nonce\n';

  /// Ctrl-C, as the console's line discipline understands it.
  static const String interrupt = '\x03';

  static String readyMarker(String nonce) => '<<FINN:$nonce:R>>';
  static String syncedMarker(String nonce) => '<<FINN:$nonce:S>>';

  /// True once the console looks like it is waiting at a shell prompt.
  static bool looksLikePrompt(String console) {
    final tail = console.replaceAll('\r', '').trimRight();
    return tail.endsWith('%') || tail.endsWith('#') || tail.endsWith(r'$');
  }
}

/// Reads one command's output off the console as it arrives.
///
/// Bytes come in as Latin-1 code units (one per serial byte) and are decoded
/// as UTF-8 at the end, so a multi-byte character split across two chunks
/// survives.
class SerialCapture {
  SerialCapture(this.nonce, {required this.maxOutputBytes});

  final String nonce;
  final int maxOutputBytes;

  final StringBuffer _raw = StringBuffer();
  int? _exitCode;
  bool _synced = false;

  String get _begin => '<<FINN:$nonce:B>>';
  String get _endPrefix => '<<FINN:$nonce:E:';

  bool get finished => _exitCode != null;
  bool get synced => _synced;
  int? get exitCode => _exitCode;

  void add(String chunk) {
    _raw.write(chunk);
    // A command that never stops talking (`yes`) is cut down to what will be
    // shown plus a tail long enough to still hold the end markers.
    final limit = maxOutputBytes * 2 + 4096;
    if (_raw.length > limit * 2) {
      final text = _raw.toString();
      _raw
        ..clear()
        ..write(text.substring(0, limit))
        ..write(text.substring(text.length - 1024));
    }
  }

  /// Re-reads everything seen so far. Cheap enough: output is capped long
  /// before it is large.
  void scan() {
    final text = _raw.toString().replaceAll('\r', '');
    if (_exitCode == null) {
      final start = text.indexOf(_endPrefix);
      if (start >= 0) {
        final close = text.indexOf('>>', start);
        if (close > 0) {
          _exitCode =
              int.tryParse(text.substring(start + _endPrefix.length, close));
        }
      }
    }
    if (!_synced) {
      _synced = text.contains(ContainerProtocol.syncedMarker(nonce));
    }
  }

  /// The command's own output: between the markers, minus the one newline
  /// the end marker added. While the command still runs, everything after
  /// the start marker.
  ({String output, bool truncated}) output() {
    final text = _raw.toString().replaceAll('\r', '');
    final begin = text.indexOf(_begin);
    if (begin < 0) return (output: '', truncated: false);
    var body = text.substring(begin + _begin.length);
    if (body.startsWith('\n')) body = body.substring(1);
    final end = body.indexOf('\n$_endPrefix');
    if (end >= 0) body = body.substring(0, end);
    final bytes = latin1.encode(body);
    final truncated = bytes.length > maxOutputBytes;
    final kept = truncated ? bytes.sublist(0, maxOutputBytes) : bytes;
    return (
      output: utf8.decode(kept, allowMalformed: true),
      truncated: truncated,
    );
  }
}
