/// Why a command was refused before it ran.
enum PolicyReason {
  empty,
  tooLong,

  /// A program that changes the device, other apps or the process tree.
  blockedProgram,

  /// A network program while network access is off.
  network,

  /// An absolute path outside the project folder.
  outsideWorkspace,

  /// A `..` segment, which can climb out of the project folder.
  parentPath,

  /// Shell syntax that hides what runs (`eval`, a fork bomb).
  obfuscated,
}

class PolicyVerdict {
  const PolicyVerdict.allowed()
      : allowed = true,
        reason = null,
        detail = '';
  const PolicyVerdict.denied(PolicyReason this.reason, [this.detail = ''])
      : allowed = false;

  final bool allowed;
  final PolicyReason? reason;

  /// The program or path that tripped the rule.
  final String detail;
}

/// The static check every command passes before it reaches the shell.
///
/// This is defence in depth, not a proof of confinement: a shell can always be
/// talked into something a token scan does not see. What actually keeps the
/// device safe is the layers around it — commands wait for the user's tap by
/// default, run as the app's own unprivileged user, in a private folder, with
/// a timeout and a size cap, and the file tool (which does not use the shell)
/// is exact. The policy removes the obvious ways out so a small model that is
/// merely wrong cannot do harm by accident.
class CommandPolicy {
  const CommandPolicy({this.allowNetwork = false});

  /// Lets `curl`, `wget` and friends run. Off by default: the project folder
  /// should not be uploadable by a model that was told to "check something".
  final bool allowNetwork;

  static const int maxLength = 4000;

  /// Programs that act on the device, other apps or the process tree.
  static const Set<String> blockedPrograms = {
    'su',
    'sudo',
    'doas',
    'reboot',
    'shutdown',
    'poweroff',
    'halt',
    'am',
    'pm',
    'cmd',
    'svc',
    'settings',
    'input',
    'dumpsys',
    'run-as',
    'setprop',
    'setenforce',
    'mount',
    'umount',
    'chown',
    'chroot',
    'kill',
    'killall',
    'pkill',
    'ln',
    'nsenter',
    'unshare',
    'insmod',
    'rmmod',
    'dd',
    'mkfs',
    'fdisk',
    'passwd',
    'crontab',
    'at',
    'logcat',
    'screencap',
    'screenrecord',
    'bugreport',
    'app_process',
    'eval',
  };

  static const Set<String> networkPrograms = {
    'curl',
    'wget',
    'nc',
    'netcat',
    'ncat',
    'telnet',
    'ftp',
    'ftpget',
    'ftpput',
    'ssh',
    'scp',
    'sftp',
    'rsync',
    'ping',
    'ping6',
    'traceroute',
    'nslookup',
    'dig',
    'host',
    'ifconfig',
    'ip',
    'netstat',
    'tcpsvd',
    'httpd',
  };

  /// Read-only locations a command may name even though they are outside the
  /// project folder: the system's own tools and a few harmless devices.
  static const List<String> _readablePrefixes = [
    '/system/bin',
    '/system/xbin',
    '/usr/bin',
    '/bin',
    '/dev/null',
    '/dev/zero',
    '/dev/urandom',
    '/dev/random',
    '/dev/stdin',
    '/dev/stdout',
    '/dev/stderr',
    '/proc/cpuinfo',
    '/proc/meminfo',
    '/proc/version',
  ];

  PolicyVerdict check(String command, {String workspaceRoot = ''}) {
    final text = command.trim();
    if (text.isEmpty) return const PolicyVerdict.denied(PolicyReason.empty);
    if (text.length > maxLength) {
      return const PolicyVerdict.denied(PolicyReason.tooLong);
    }
    if (text.contains('\u0000')) {
      return const PolicyVerdict.denied(PolicyReason.obfuscated, 'NUL');
    }
    if (RegExp(r':\s*\(\s*\)\s*\{').hasMatch(text)) {
      return const PolicyVerdict.denied(PolicyReason.obfuscated, 'fork bomb');
    }

    for (final program in _programs(text)) {
      final name = program.split('/').last;
      if (blockedPrograms.contains(name)) {
        return PolicyVerdict.denied(PolicyReason.blockedProgram, name);
      }
      if (!allowNetwork && networkPrograms.contains(name)) {
        return PolicyVerdict.denied(PolicyReason.network, name);
      }
    }

    for (final token in _tokens(text)) {
      if (token.split('/').contains('..')) {
        return PolicyVerdict.denied(PolicyReason.parentPath, token);
      }
      if (token.startsWith('~')) {
        return PolicyVerdict.denied(PolicyReason.outsideWorkspace, token);
      }
      if (token.startsWith('/') && !_allowedAbsolute(token, workspaceRoot)) {
        return PolicyVerdict.denied(PolicyReason.outsideWorkspace, token);
      }
    }
    return const PolicyVerdict.allowed();
  }

  static bool _allowedAbsolute(String path, String workspaceRoot) {
    if (workspaceRoot.isNotEmpty &&
        (path == workspaceRoot || path.startsWith('$workspaceRoot/'))) {
      return true;
    }
    for (final prefix in _readablePrefixes) {
      if (path == prefix || path.startsWith('$prefix/')) return true;
    }
    return false;
  }

  /// Every word that follows a command separator or a substitution opener:
  /// the programs the line will start.
  static Iterable<String> _programs(String text) sync* {
    final segments = text.split(RegExp(r'[;|&\n]|\$\(|`|\(|\{|\bthen\b|\bdo\b|'
        r'\belse\b|&&|\|\|'));
    for (final segment in segments) {
      final words = segment.trim().split(RegExp(r'\s+'));
      // Skip `VAR=value` prefixes and `env`/`command`/`exec`/`time` wrappers.
      var i = 0;
      while (i < words.length &&
          (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*=').hasMatch(words[i]) ||
              const {'env', 'command', 'exec', 'time', 'nohup', 'xargs'}
                  .contains(words[i]))) {
        i++;
      }
      if (i < words.length && words[i].isNotEmpty) {
        yield _unquote(words[i]);
      }
    }
  }

  /// Words and redirection targets, split on whitespace, quotes and shell
  /// punctuation, so `echo hi>/etc/x` yields `/etc/x`.
  static Iterable<String> _tokens(String text) => text
      .split(RegExp('''[\\s'"`<>|;&()=,{}\\[\\]]+'''))
      .where((token) => token.isNotEmpty);

  static String _unquote(String word) =>
      word.replaceAll(RegExp('''^['"]+|['"]+\$'''), '');
}
