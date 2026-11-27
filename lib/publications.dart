import 'dart:async';

import 'package:flutter/material.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'l10n/strings.dart';
import 'newscast_page.dart';
import 'support.dart';
import 'video_pip.dart';
import 'widgets/section_selector.dart';
import 'widgets/status_views.dart';

class _Publication {
  const _Publication(this.titleKey, this.url, {this.isNewscast = false});

  /// Key in `strings.dart` for the translated tab label.
  final String titleKey;

  /// Page loaded in a WebView. Ignored for the Newscast tab, which draws its
  /// own episode list instead of embedding youtube.com.
  final String url;

  /// When true this tab is the Newscast: a Flutter list fed by the channel's
  /// upload feed, with one embedded video per tap. Nothing on this tab is a
  /// YouTube page, so there is no search box or recommendation rail to wander
  /// into from a school app.
  final bool isNewscast;
}

class PublicationsPage extends StatefulWidget {
  const PublicationsPage({super.key});

  @override
  State<PublicationsPage> createState() => _PublicationsPageState();
}

class _PublicationsPageState extends State<PublicationsPage> {
  int selectedIndex = 0;

  static const List<_Publication> _publications = [
    _Publication('publications.nexus', 'https://wvnexus.org/category/news/'),
    _Publication(
      'publications.newscast',
      'https://www.youtube.com/@westviewnewscast7337/videos',
      isNewscast: true,
    ),
  ];

  /// One key per publication so the header refresh button can reach the
  /// currently visible WebView.
  final List<GlobalKey<PublicationWebViewState>> _webKeys = [
    for (var i = 0; i < _publications.length; i++)
      GlobalKey<PublicationWebViewState>(),
  ];

  void _onItemTapped(int index) {
    setState(() => selectedIndex = index);
  }

  /// Key for the Newscast list so the header refresh button can reach it.
  final GlobalKey<NewscastPageState> _newscastKey =
      GlobalKey<NewscastPageState>();

  void _refreshCurrent() {
    if (_publications[selectedIndex].isNewscast) {
      _newscastKey.currentState?.refresh();
      return;
    }
    _webKeys[selectedIndex].currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: videoPipActive,
      builder: (context, isPipActive, _) {
        return Scaffold(
          backgroundColor: isPipActive ? Colors.black : null,
          body: SafeArea(
            top: !isPipActive,
            bottom: !isPipActive,
            left: !isPipActive,
            right: !isPipActive,
            child: Column(
              children: [
                // Height collapses to 0 during PiP so the WebView can fill the
                // activity surface without the PlatformView being detached.
                SizedBox(
                  height: isPipActive ? 0 : null,
                  child: Offstage(
                    offstage: isPipActive,
                    child: Row(
                      children: [
                        Expanded(
                          child: SectionSelector(
                            labels: [
                              for (final p in _publications)
                                strings[p.titleKey],
                            ],
                            selectedIndex: selectedIndex,
                            onSelected: _onItemTapped,
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: strings['common.refresh'],
                          onPressed: _refreshCurrent,
                          icon: const Icon(Icons.refresh),
                        ),
                        const HelpIconButton(),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: isPipActive ? 0 : 1,
                  child: const Divider(height: 1),
                ),
                Expanded(
                  child: LazyIndexedStack(
                    index: selectedIndex,
                    itemCount: _publications.length,
                    itemBuilder: (context, index) {
                      final publication = _publications[index];
                      if (publication.isNewscast) {
                        return NewscastPage(key: _newscastKey);
                      }
                      return PublicationWebView(
                        key: _webKeys[index],
                        url: publication.url,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// WebView for the sites that are read as pages, like the Nexus. It is the only
/// thing on the Publications tab that could play a video, so the PiP bridge
/// lives here; the Newscast draws its own list and player instead of loading
/// youtube.com.
///
/// Exposes the same last-known-content error handling as `web_page.dart`
/// (full-screen retry state on first load, non-destructive notice when a
/// refresh fails later).
class PublicationWebView extends StatefulWidget {
  const PublicationWebView({super.key, required this.url});

  final String url;

  @override
  State<PublicationWebView> createState() => PublicationWebViewState();
}

class PublicationWebViewState extends State<PublicationWebView>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  late final SimplePip _pip;
  int _loading = 0;

  bool _pipAvailable = false;
  bool _autoPipSupported = false;
  bool _isVideoPlaying = false;
  bool _pipInitialized = false;

  bool _hasLoadedOnce = false;
  bool _initialLoadFailed = false;
  bool _refreshFailed = false;

  /// Whether this page can hold a video the PiP bridge understands. Only the
  /// Nexus tab loads a site directly now; the Newscast draws its own list and
  /// player (`newscast_page.dart`), so it never reaches this widget.
  bool get _isPipVideoPage => isPipVideoUrl(widget.url);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Android 12+ shrinks the window on its own when the app is backgrounded
    // mid-video. `onPipEntered` then fires after the shrink, so promoting the
    // video there is a recovery step; `_enterPipVisual` also runs ahead of the
    // shrink wherever the app controls the timing.
    _pip = SimplePip(
      onPipEntered: () => unawaited(_enterPipVisual()),
      onPipExited: _exitPipVisual,
    );

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'PiPChannel',
        onMessageReceived: (message) => _handlePipMessage(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = 1;
              _refreshFailed = false;
            });
            if (_isVideoPlaying) {
              _isVideoPlaying = false;
              unawaited(_syncPipMode());
            }
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
            if (_isPipVideoPage) {
              unawaited(_installPipBridge());
              unawaited(_setupPipMode());
            }
          },
          onWebResourceError: (error) {
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

  /// Reloads the current page (used by the header refresh button).
  void reload() {
    if (!mounted) return;
    setState(() {
      _initialLoadFailed = false;
      _refreshFailed = false;
      _loading = 1;
    });
    _controller.reload();
  }

  Future<void> _installPipBridge() async {
    try {
      await _controller.runJavaScript(videoPipScript);
    } catch (e) {
      debugPrint('PiP script injection error: $e');
    }
  }

  Future<void> _setupPipMode() async {
    if (_pipInitialized || !_isPipVideoPage) return;
    _pipInitialized = true;
    try {
      _pipAvailable = await SimplePip.isPipAvailable;
      _autoPipSupported = await SimplePip.isAutoPipAvailable;
      await _syncPipMode();
    } catch (e) {
      debugPrint('PiP availability check error: $e');
    }
  }

  void _handlePipMessage(String message) {
    if (!mounted || !_isPipVideoPage) return;
    final state = message.trim();
    // `entered` / `no-target` come back from the promotion itself so the app
    // knows whether there is a video to show before it shrinks.
    if (state == 'no-target') {
      // Either the request already failed and this is the retry giving up, or
      // the promotion never found a player at all. Either way the app stays
      // full screen instead of shrinking into a picture of a page.
      videoPipActive.value = false;
      return;
    }
    if (state == 'entered') {
      // The bridge can only answer a promotion request after it has retried, so
      // a slow player reports `entered` long after `_enterPipVisual` gave up
      // waiting on the JavaScript return value. Re-apply the layout then.
      if (!videoPipActive.value) videoPipActive.value = true;
      return;
    }
    if (state != 'playing' && state != 'paused') return;
    final playing = state == 'playing';
    if (playing == _isVideoPlaying) return;
    _isVideoPlaying = playing;
    unawaited(_syncPipMode());
  }

  Future<void> _syncPipMode() async {
    if (!_pipAvailable || !_autoPipSupported) return;
    final shouldAutoEnter = _isPipVideoPage && _isVideoPlaying;
    try {
      await _pip.setAutoPipMode(
        aspectRatio: const (16, 9),
        seamlessResize: shouldAutoEnter,
        autoEnter: shouldAutoEnter,
      );
    } catch (e) {
      debugPrint('PiP sync error: $e');
    }
  }

  /// Makes the playing video the only thing on screen, then lets Android
  /// shrink the activity.
  ///
  /// Order matters. PiP captures whatever the activity is drawing, so the
  /// video has to be promoted *before* the window shrinks — otherwise the
  /// snapshot Android takes is the page as it was, and the video ends up tiny
  /// inside a picture of the app. The promotion is only worth starting when
  /// the bridge can actually find a playing player; if it cannot, the app
  /// stays full screen rather than shrinking into something that shows a page
  /// instead of a video.
  Future<bool> _enterPipVisual() async {
    if (!_isPipVideoPage) return false;

    // Tell the app shell to hide its header and bottom navigation bar without
    // detaching the WebView so playback keeps running smoothly.
    videoPipActive.value = true;

    bool promoted = false;
    try {
      final result = await _controller.runJavaScriptReturningResult(
        'window.__westviewVideoPip && window.__westviewVideoPip.enter();',
      );
      promoted = result == true || result == 'true';
    } catch (e) {
      debugPrint('PiP visual enter error: $e');
    }

    if (!promoted) {
      // No player to show: undo the layout change and leave the app alone.
      videoPipActive.value = false;
    }
    return promoted;
  }

  Future<void> _exitPipVisual() async {
    try {
      await _controller.runJavaScript(
        'window.__westviewVideoPip && window.__westviewVideoPip.exit();',
      );
    } catch (e) {
      debugPrint('PiP visual exit error: $e');
    } finally {
      videoPipActive.value = false;
    }
  }

  @override
  void didUpdateWidget(covariant PublicationWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url) return;
    final wasPlaying = _isVideoPlaying;
    setState(() {
      _loading = 1;
      _pipInitialized = false;
      _isVideoPlaying = false;
      _initialLoadFailed = false;
      _refreshFailed = false;
    });
    if (wasPlaying || !isPipVideoUrl(widget.url)) {
      unawaited(_syncPipMode());
    }
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isVideoPlaying = false;
    unawaited(_syncPipMode());
    _pip.onPipEntered = null;
    _pip.onPipExited = null;
    videoPipActive.value = false;
    super.dispose();
  }

  /// Android <12 doesn't support auto-enter; we manually enter PiP when the
  /// app backgrounds while a video is playing.
  Future<void> _enterLegacyPip() async {
    if (!await _enterPipVisual()) return;
    bool entered = false;
    try {
      entered = await _pip.enterPipMode(
        aspectRatio: const (16, 9),
        seamlessResize: true,
      );
    } catch (e) {
      debugPrint('Legacy PiP entry error: $e');
    }
    if (!entered) await _exitPipVisual();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden &&
        _pipInitialized &&
        _pipAvailable &&
        !_autoPipSupported &&
        _isVideoPlaying &&
        _isPipVideoPage) {
      unawaited(_enterLegacyPip());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_initialLoadFailed)
          ErrorStatusView(
            title: strings['web.errorTitle'],
            message: strings['web.errorBody'],
            onRetry: reload,
            retryLabel: strings['web.retry'],
          )
        else if (!_hasLoadedOnce && _loading < 100)
          LoadingStatusView(label: strings['web.loading'])
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
