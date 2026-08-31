import 'dart:async';

import 'package:flutter/material.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'vimeo_pip.dart';

class _Publication {
  const _Publication(this.title, this.url);
  final String title;
  final String url;
}

class PublicationsPage extends StatefulWidget {
  const PublicationsPage({super.key});

  @override
  State<PublicationsPage> createState() => _PublicationsPageState();
}

class _PublicationsPageState extends State<PublicationsPage> {
  int selectedIndex = 0;
  late final PageController _carouselController;

  static const List<_Publication> _publications = [
    _Publication('Westview Nexus', 'https://wvnexus.org/category/news/'),
    _Publication(
        'Westview Newscast', 'https://vimeo.com/channels/westviewnewscast'),
  ];

  @override
  void initState() {
    super.initState();
    _carouselController = PageController(viewportFraction: 0.7);
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    _carouselController.animateToPage(
      index,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: vimeoPipActive,
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
                  height: isPipActive ? 0 : 90,
                  child: Offstage(
                    offstage: isPipActive,
                    child: PageView.builder(
                      controller: _carouselController,
                      itemCount: _publications.length,
                      onPageChanged: (index) =>
                          setState(() => selectedIndex = index),
                      itemBuilder: (context, index) {
                        final isSelected = selectedIndex == index;
                        return GestureDetector(
                          onTap: () => _onItemTapped(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                width: 2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : const [],
                            ),
                            child: Center(
                              child: Text(
                                _publications[index].title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                  fontSize: isSelected ? 16 : 14,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(
                  height: isPipActive ? 0 : 1,
                  child: const Divider(height: 1),
                ),
                Expanded(
                  child: _PipWebView(url: _publications[selectedIndex].url),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// WebView that bridges Vimeo playback to Android picture-in-picture. Only
/// used by the Publications tab because other tabs do not host videos.
class _PipWebView extends StatefulWidget {
  const _PipWebView({required this.url});
  final String url;

  @override
  State<_PipWebView> createState() => _PipWebViewState();
}

class _PipWebViewState extends State<_PipWebView> with WidgetsBindingObserver {
  late final WebViewController _controller;
  late final SimplePip _pip;
  int _loading = 0;

  bool _pipAvailable = false;
  bool _autoPipSupported = false;
  bool _isVideoPlaying = false;
  bool _pipInitialized = false;

  bool get _isVimeoPage => isVimeoUrl(widget.url);

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
            setState(() => _loading = 1);
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
            setState(() => _loading = 100);
            if (_isVimeoPage) {
              unawaited(_installVimeoBridge());
              unawaited(_setupPipMode());
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _installVimeoBridge() async {
    try {
      await _controller.runJavaScript(vimeoPipScript);
    } catch (e) {
      debugPrint('Vimeo PiP script injection error: $e');
    }
  }

  Future<void> _setupPipMode() async {
    if (_pipInitialized || !_isVimeoPage) return;
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
    if (!mounted || !_isVimeoPage) return;
    final state = message.trim();
    if (state != 'playing' && state != 'paused') return;
    final playing = state == 'playing';
    if (playing == _isVideoPlaying) return;
    _isVideoPlaying = playing;
    unawaited(_syncPipMode());
  }

  Future<void> _syncPipMode() async {
    if (!_pipAvailable || !_autoPipSupported) return;
    final shouldAutoEnter = _isVimeoPage && _isVideoPlaying;
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
    if (!_isVimeoPage) return;
    // Tell the parent shell to hide its chrome (tab bar, selector) without
    // detaching the WebView so playback is uninterrupted.
    vimeoPipActive.value = true;
    try {
      await _controller.runJavaScript(
        'window.__westviewVimeoPip && window.__westviewVimeoPip.enter();',
      );
    } catch (e) {
      debugPrint('PiP visual enter error: $e');
    }
  }

  Future<void> _exitPipVisual() async {
    try {
      await _controller.runJavaScript(
        'window.__westviewVimeoPip && window.__westviewVimeoPip.exit();',
      );
    } catch (e) {
      debugPrint('PiP visual exit error: $e');
    } finally {
      vimeoPipActive.value = false;
    }
  }

  @override
  void didUpdateWidget(covariant _PipWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url) return;
    final wasPlaying = _isVideoPlaying;
    setState(() {
      _loading = 1;
      _pipInitialized = false;
      _isVideoPlaying = false;
    });
    if (wasPlaying || !isVimeoUrl(widget.url)) {
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
    vimeoPipActive.value = false;
    super.dispose();
  }

  /// Android <12 doesn't support auto-enter; we manually enter PiP when the
  /// app backgrounds while a Vimeo video is playing.
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
        _isVimeoPage) {
      unawaited(_enterLegacyPip());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading < 100)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
