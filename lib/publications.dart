import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:simple_pip_mode/simple_pip.dart';

import 'vimeo_pip.dart';

class WebPageInfo {
  final String title;
  final String webPageURL;
  const WebPageInfo(this.title, this.webPageURL);
}

class WebPage extends StatefulWidget {
  const WebPage({super.key, required this.webPage});
  final WebPageInfo webPage;

  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> with WidgetsBindingObserver {
  late final WebViewController controller;
  late final SimplePip _pip;
  int loadingPercentage = 0;

  bool _pipAvailable = false;
  bool _autoPipSupported = false;
  bool _isVideoPlaying = false;
  bool _pipInitialized = false;

  bool get _isVimeoPage => isVimeoUrl(widget.webPage.webPageURL);

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

    controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'PiPChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handlePipMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() => loadingPercentage = 0);
            if (_isVideoPlaying) {
              _isVideoPlaying = false;
              _syncPipMode();
            }
          },
          onProgress: (progress) {
            if (mounted) setState(() => loadingPercentage = progress);
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() => loadingPercentage = 100);

            if (_isVimeoPage) {
              _installVimeoPipBridge();
              _setupPipMode();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.webPage.webPageURL));
  }

  Future<void> _installVimeoPipBridge() async {
    try {
      await controller.runJavaScript(vimeoPipScript);
    } catch (error) {
      debugPrint('Vimeo PiP script injection error: $error');
    }
  }

  /// Checks Android PiP support and applies any playback state that arrived
  /// while the asynchronous platform checks were running.
  Future<void> _setupPipMode() async {
    if (_pipInitialized || !_isVimeoPage) return;
    _pipInitialized = true;

    try {
      _pipAvailable = await SimplePip.isPipAvailable;
      _autoPipSupported = await SimplePip.isAutoPipAvailable;
      await _syncPipMode();
    } catch (error) {
      debugPrint('PiP availability check error: $error');
    }
  }

  /// Handles play/pause messages from direct HTML video elements and Vimeo's
  /// cross-origin player iframe.
  void _handlePipMessage(String message) {
    if (!mounted || !_isVimeoPage) return;

    final String state = message.trim();
    if (state != 'playing' && state != 'paused') return;

    final bool isPlaying = state == 'playing';
    if (isPlaying == _isVideoPlaying) return;

    _isVideoPlaying = isPlaying;
    _syncPipMode();
  }

  /// Enables Android 12+ auto-PiP only for an actively playing Vimeo video.
  Future<void> _syncPipMode() async {
    if (!_pipAvailable || !_autoPipSupported) return;

    final bool shouldAutoEnter = _isVimeoPage && _isVideoPlaying;
    try {
      await _pip.setAutoPipMode(
        aspectRatio: const (16, 9),
        seamlessResize: shouldAutoEnter,
        autoEnter: shouldAutoEnter,
      );
    } catch (error) {
      debugPrint('PiP sync error: $error');
    }
  }

  /// Removes all Flutter app chrome and expands only the Vimeo player over the
  /// WebView. Android PiP captures the activity, so both steps are required.
  Future<void> _enterPipVisual() async {
    if (!_isVimeoPage) return;

    // Rebuild the persistent app tree without its tab bars. The WebView is not
    // moved or recreated, so playback continues uninterrupted.
    vimeoPipActive.value = true;

    try {
      await controller.runJavaScript(
        'window.__westviewVimeoPip && window.__westviewVimeoPip.enter();',
      );
    } catch (error) {
      debugPrint('PiP visual enter error: $error');
    }
  }

  /// Restores the inline Vimeo watch page before showing the normal app chrome.
  Future<void> _exitPipVisual() async {
    try {
      await controller.runJavaScript(
        'window.__westviewVimeoPip && window.__westviewVimeoPip.exit();',
      );
    } catch (error) {
      debugPrint('PiP visual exit error: $error');
    } finally {
      vimeoPipActive.value = false;
    }
  }

  @override
  void didUpdateWidget(WebPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.webPage.webPageURL == widget.webPage.webPageURL) return;

    final bool wasPlaying = _isVideoPlaying;
    setState(() {
      loadingPercentage = 0;
      _pipInitialized = false;
      _isVideoPlaying = false;
    });

    // Disable an auto-PiP configuration left by the Vimeo page before loading
    // Nexus (or any future non-Vimeo publication).
    if (wasPlaying || !isVimeoUrl(widget.webPage.webPageURL)) {
      _syncPipMode();
    }
    controller.loadRequest(Uri.parse(widget.webPage.webPageURL));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isVideoPlaying = false;
    _syncPipMode();
    _pip.onPipEntered = null;
    _pip.onPipExited = null;
    vimeoPipActive.value = false;
    super.dispose();
  }

  /// Android versions before 12 do not support auto-enter. Prepare the video
  /// presentation first, then manually request PiP as the app is backgrounded.
  Future<void> _enterLegacyPip() async {
    await _enterPipVisual();

    bool entered = false;
    try {
      entered = await _pip.enterPipMode(
        aspectRatio: const (16, 9),
        seamlessResize: true,
      );
    } catch (error) {
      debugPrint('Legacy PiP entry error: $error');
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
      _enterLegacyPip();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (loadingPercentage < 100)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class PublicationsPage extends StatefulWidget {
  const PublicationsPage({super.key});

  @override
  State<PublicationsPage> createState() => _PublicationsPageState();
}

class _PublicationsPageState extends State<PublicationsPage> {
  int selectedIndex = 0;
  late PageController _carouselController;

  final List<WebPageInfo> publications = const [
    WebPageInfo('Westview Nexus', 'https://wvnexus.org/category/news/'),
    WebPageInfo('Westview Newscast', 'https://vimeo.com/channels/westviewnewscast'),
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
      builder: (context, isPipActive, child) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            top: !isPipActive,
            bottom: !isPipActive,
            left: !isPipActive,
            right: !isPipActive,
            child: Column(
              children: [
                // Keep the same widget structure while changing the height so
                // the platform WebView is never detached during PiP entry.
                SizedBox(
                  height: isPipActive ? 0 : 90,
                  child: Offstage(
                    offstage: isPipActive,
                    child: PageView.builder(
                      controller: _carouselController,
                      itemCount: publications.length,
                      onPageChanged: (index) =>
                          setState(() => selectedIndex = index),
                      itemBuilder: (context, index) {
                        final bool isSelected = selectedIndex == index;

                        return GestureDetector(
                          onTap: () => _onItemTapped(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).appBarTheme.backgroundColor
                                  : Theme.of(context).appBarTheme.foregroundColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : Colors.grey.withOpacity(0.3),
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
                                  : [],
                            ),
                            child: Center(
                              child: Text(
                                publications[index].title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
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
                  child: WebPage(webPage: publications[selectedIndex]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
