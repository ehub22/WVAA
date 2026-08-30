import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Reusable WebView wrapper that shows a loading spinner overlay while the
/// page is still loading and transparently swaps URLs when its parent
/// rebuilds with a new [url].
///
/// PiP support for the Publications tab lives in `publications.dart`; this
/// widget is intentionally simple so Newsletter and Calendar tabs stay
/// lightweight.
class WebPageView extends StatefulWidget {
  const WebPageView({super.key, required this.url, this.backgroundColor});

  final String url;
  final Color? backgroundColor;

  @override
  State<WebPageView> createState() => _WebPageViewState();
}

class _WebPageViewState extends State<WebPageView> {
  late final WebViewController _controller;
  int _loading = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() => _loading = 1);
          },
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _loading = progress);
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = 100);
          },
          onWebResourceError: (error) {
            // Non-fatal; surface via the partial page already rendered.
            debugPrint('WebView error (${error.errorCode}): ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void didUpdateWidget(covariant WebPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      setState(() => _loading = 1);
      _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading < 100)
          ColoredBox(
            color: bg,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
