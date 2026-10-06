import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:finn_ai/src/features/code/container/container_host.dart';

/// The WebView FinnAI Code's Linux container runs in.
///
/// It is one logical pixel, transparent and untouchable, and it exists only
/// while the container is starting or running. It sits above the navigator
/// (`MaterialApp.builder`), so it stays painted, and the platform keeps its
/// scripts running at full speed, while any Code page is on screen.
class ContainerView extends StatefulWidget {
  const ContainerView({super.key, required this.host, required this.child});

  final ContainerHost host;
  final Widget child;

  /// Where a WebView is available to run the container in: Android, iOS
  /// and macOS through webview_flutter, OpenHarmony through its SIG fork
  /// (ArkWeb). Linux desktop has none.
  static bool get supported =>
      !kIsWeb &&
      (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.operatingSystem == 'ohos');

  @override
  State<ContainerView> createState() => _ContainerViewState();
}

class _ContainerViewState extends State<ContainerView> {
  WebViewController? _controller;
  Uri? _loaded;

  @override
  void initState() {
    super.initState();
    widget.host.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(ContainerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.host != widget.host) {
      oldWidget.host.removeListener(_sync);
      widget.host.addListener(_sync);
      _sync();
    }
  }

  @override
  void dispose() {
    widget.host.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (!ContainerView.supported) return;
    final url = widget.host.viewUrl;
    if (url == _loaded) return;
    setState(() {
      _loaded = url;
      // A new machine gets a new page; the old one is dropped with its
      // controller, which tears its emulator down.
      _controller = url == null
          ? null
          : (WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(const Color(0x00000000))
            // The page's own errors land in the log under FINN_CONTAINER,
            // next to the host's; nothing else reports a page that failed.
            ..setOnConsoleMessage((message) => debugPrint(
                'FINN_CONTAINER page ${message.level.name}: ${message.message}'))
            ..setNavigationDelegate(NavigationDelegate(
              onWebResourceError: (error) =>
                  debugPrint('FINN_CONTAINER load error ${error.errorCode}: '
                      '${error.description}'),
            ))
            ..loadRequest(url));
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    // Always a Stack, so the app below keeps its state when the view comes
    // and goes.
    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.expand,
      children: [
        widget.child,
        if (controller != null)
          Positioned(
            left: 0,
            top: 0,
            width: 1,
            height: 1,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: 0.01,
                  child: WebViewWidget(
                    key: ValueKey(_loaded),
                    controller: controller,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
