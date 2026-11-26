import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'l10n/strings.dart';
import 'widgets/status_views.dart';

/// Whether a WebView navigation should be allowed inside the app.
///
/// Only https pages (and the blank page) may load. `http`, `file`,
/// `javascript:`, `data:`, `intent:`, `tel:`, `mailto:` and friends are
/// blocked inside the WebView so a compromised or linked page cannot load
/// local files, downgrade to cleartext, or smuggle an external scheme past
/// the app. External actions belong in the phone's own apps via
/// `url_launcher` (see `support.dart`), not in an embedded browser.
///
/// Used by both `WebPageView` and `PublicationWebView`, so it is a regular
/// public helper (not `@visibleForTesting`).
bool isAllowedWebNavigation(Uri uri) {
  if (uri.scheme == 'about') return true;
  return uri.scheme == 'https' && uri.host.isNotEmpty;
}

/// Shared WebView wrapper with loading, error, and retry states.
///
/// How it handles bad Wi-Fi:
///  * If the initial load fails on the main frame, it shows a full-screen retry
///    view.
///  * Once a page has loaded at least once, a failed refresh keeps the loaded
///    page on screen and shows a small dismissible banner at the top instead of
///    wiping out what you were reading.
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
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            return uri != null && isAllowedWebNavigation(uri)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
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
    final strings = AppStrings.of(context);

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_initialLoadFailed)
          ColoredBox(
            color: bg,
            child: ErrorStatusView(
              title: strings['web.errorTitle'],
              message: strings['web.errorBody'],
              onRetry: reload,
              retryLabel: strings['web.retry'],
            ),
          )
        else if (!_hasLoadedOnce && _loading < 100)
          ColoredBox(
            color: bg,
            child: LoadingStatusView(label: strings['web.loading']),
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
                        strings['web.stale'],
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onErrorContainer),
                      ),
                    ),
                    // Full 48dp tap target; only the glyph is small.
                    IconButton(
                      tooltip: strings['common.dismiss'],
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
