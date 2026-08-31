import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'widgets/status_views.dart';

/// Reusable WebView wrapper with explicit loading, error and retry states.
///
/// Behavior on flaky networks:
///  * the first load shows a full-screen loading state, and a main-frame
///    failure replaces it with a retry screen;
///  * a *refresh* of an already loaded page never destroys the content: a slim
///    progress bar runs at the top, and a failure just shows a dismissible
///    notice above the last-known page.
///
/// PiP support for the Publications tab lives in `publications.dart`; this
/// widget is intentionally simple so Newsletter and Calendar tabs stay
/// lightweight.
class WebPageView extends StatefulWidget {
  const WebPageView({super.key, required this.url, this.backgroundColor});

  final String url;
  final Color? backgroundColor;

  @override
  State<WebPageView> createState() => WebPageViewState();
}

class WebPageViewState extends State<WebPageView> {
  late final WebViewController _controller;
  int _loading = 0;

  /// Whether any page has finished loading in this session. Once true, the
  /// last-known content is never covered up by an opaque error screen.
  bool _hasLoadedOnce = false;
  bool _initialLoadFailed = false;
  bool _refreshFailed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = 1;
              _refreshFailed = false;
            });
          },
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _loading = progress);
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _loading = 100;
              _hasLoadedOnce = true;
              _initialLoadFailed = false;
              _refreshFailed = false;
            });
          },
          onWebResourceError: (error) {
            // Only main-frame failures mean "the page didn't load"; broken
            // sub-resources (ads, fonts) surface through the partial page.
            final isMainFrame = error.isForMainFrame ?? false;
            if (!isMainFrame || !mounted) return;
            setState(() {
              if (_hasLoadedOnce) {
                _refreshFailed = true;
              } else {
                _initialLoadFailed = true;
              }
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void didUpdateWidget(covariant WebPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      setState(() {
        _loading = 1;
        _refreshFailed = false;
        _initialLoadFailed = false;
      });
      _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  /// Reloads the current page (used by the header refresh buttons).
  void reload() {
    if (!mounted) return;
    setState(() {
      _initialLoadFailed = false;
      _refreshFailed = false;
      _loading = 1;
    });
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final bg =
        widget.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_initialLoadFailed)
          ColoredBox(
            color: bg,
            child: ErrorStatusView(
              title: "Couldn't open this page",
              message: 'The page could not be loaded. Check your connection '
                  'and try again.',
              onRetry: reload,
              retryLabel: 'Try again',
            ),
          )
        else if (!_hasLoadedOnce && _loading < 100)
          ColoredBox(
            color: bg,
            child: const LoadingStatusView(label: 'Loading page…'),
          )
        else if (_loading < 100)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 4),
          ),
        if (_refreshFailed)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: scheme.errorContainer,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off,
                        size: 18, color: scheme.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Couldn't refresh — still showing the last loaded "
                        'page.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onErrorContainer),
                      ),
                    ),
                    // Full 48dp tap target; only the glyph is small.
                    IconButton(
                      tooltip: 'Dismiss',
                      iconSize: 18,
                      color: scheme.onErrorContainer,
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          setState(() => _refreshFailed = false),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
