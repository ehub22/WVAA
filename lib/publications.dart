import 'dart:async';

import 'package:flutter/material.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'l10n/strings.dart';
import 'support.dart';
import 'video_pip.dart';
import 'widgets/section_selector.dart';
import 'widgets/status_views.dart';

class _Publication {
  const _Publication(this.titleKey, this.url);

  /// Key in `strings.dart` for the translated tab label.
  final String titleKey;
  final String url;
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
        'https://www.youtube.com/@westviewnewscast7337/videos'),
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

  void _refreshCurrent() {
    _webKeys[selectedIndex].currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: videoPipActive,
      builder: (context, isPipActive, _) {
        return Scaffold(
          backgroundColor: Colors.black,
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
                    itemBuilder: (context, index) => PublicationWebView(
                      key: _webKeys[index],
                      url: _publications[index].url,
                    ),
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

/// WebView that bridges video playback (Vimeo or YouTube) to Android
/// picture-in-picture. Only used by the Publications tab because other tabs do
/// not host videos.
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

  /// Only pages the bridge understands get the script and PiP wiring.
  bool get _isPipVideoPage => isPipVideoUrl(widget.url);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pip = SimplePip(
      onPipEntered: _enterPipVisual,
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

  Future<void> _enterPipVisual() async {
    if (!_isPipVideoPage) return;
    // Tell the app shell to hide its header and bottom navigation bar without
    // detaching the WebView so video playback keeps running smoothly.
    videoPipActive.value = true;
    try {
      await _controller.runJavaScript(
        'window.__westviewVideoPip && window.__westviewVideoPip.enter();',
      );
    } catch (e) {
      debugPrint('PiP visual enter error: $e');
    }
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
    await _enterPipVisual();
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

    return ColoredBox(
      color: Colors.black,
      child: Stack(
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
      ),
    );
  }
}
