import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:simple_pip_mode/simple_pip.dart';

/// JavaScript injected into the WebView to:
/// 1. Detect when a <video> element is actually playing (Vimeo player).
/// 2. Make the video fill the PiP window so only the video is visible.
const String _videoPipScript = r'''
(function() {
  if (window.__pipScriptInstalled) return;
  window.__pipScriptInstalled = true;

  // ---- video playback detection ----
  var lastState = null;

  function anyVideoPlaying() {
    var videos = document.querySelectorAll('video');
    for (var i = 0; i < videos.length; i++) {
      if (!videos[i].paused && !videos[i].ended) {
        return true;
      }
    }
    // Also check inside same-origin iframes (Vimeo embed player)
    var frames = document.querySelectorAll('iframe');
    for (var f = 0; f < frames.length; f++) {
      try {
        var doc = frames[f].contentDocument;
        if (doc) {
          var fvids = doc.querySelectorAll('video');
          for (var j = 0; j < fvids.length; j++) {
            if (!fvids[j].paused && !fvids[j].ended) return true;
          }
        }
      } catch (e) { /* cross-origin iframe: skip */ }
    }
    return false;
  }

  function checkState() {
    var playing = anyVideoPlaying();
    if (playing !== lastState) {
      lastState = playing;
      try {
        PiPChannel.postMessage(playing ? 'playing' : 'paused');
      } catch (e) {}
    }
  }

  function attachListeners(video) {
    video.addEventListener('play', checkState);
    video.addEventListener('playing', checkState);
    video.addEventListener('pause', checkState);
    video.addEventListener('ended', checkState);
  }

  // attach to existing videos
  var videos = document.querySelectorAll('video');
  for (var i = 0; i < videos.length; i++) {
    attachListeners(videos[i]);
  }

  // watch for dynamically added videos (Vimeo creates the player lazily)
  try {
    var observer = new MutationObserver(function(mutations) {
      mutations.forEach(function(mutation) {
        mutation.addedNodes.forEach(function(node) {
          if (node.tagName === 'VIDEO') {
            attachListeners(node);
            checkState();
          } else if (node.querySelectorAll) {
            var nested = node.querySelectorAll('video');
            for (var j = 0; j < nested.length; j++) {
              attachListeners(nested[j]);
            }
            if (nested.length > 0) checkState();
          }
        });
      });
    });
    observer.observe(document.body, { childList: true, subtree: true });
  } catch (e) {}

  // polling as a fallback for exotic player implementations
  setInterval(checkState, 1000);
  setTimeout(checkState, 800);

  // ---- PiP visual helpers: make only the video visible ----
  window.__pipVisual = {
    originalStyles: {},
    entered: false,
    enter: function() {
      var video = document.querySelector('video');
      if (!video || this.entered) return;
      this.entered = true;

      var props = ['position','top','left','width','height','zIndex','objectFit','background'];
      var style = video.style;
      this.originalStyles = {};
      for (var p = 0; p < props.length; p++) {
        this.originalStyles[props[p]] = style[props[p]] || '';
      }

      style.position = 'fixed';
      style.top = '0';
      style.left = '0';
      style.width = '100vw';
      style.height = '100vh';
      style.zIndex = '999999';
      style.objectFit = 'contain';
      style.background = '#000';

      try { document.body.style.overflow = 'hidden'; } catch (e) {}
    },
    exit: function() {
      if (!this.entered) return;
      this.entered = false;

      var video = document.querySelector('video');
      if (video) {
        var style = video.style;
        var keys = Object.keys(this.originalStyles);
        for (var k = 0; k < keys.length; k++) {
          style[keys[k]] = this.originalStyles[keys[k]];
        }
      }
      try { document.body.style.overflow = ''; } catch (e) {}
      this.originalStyles = {};
    }
  };
})();
''';

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
          onPageStarted: (url) => setState(() => loadingPercentage = 0),
          onProgress: (progress) => setState(() => loadingPercentage = progress),
          onPageFinished: (url) {
            setState(() => loadingPercentage = 100);
            // Inject video detection + PiP visual helpers, then init PiP
            controller.runJavaScript(_videoPipScript);
            _setupPipMode();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.webPage.webPageURL));
  }

  /// Check PiP availability and auto-PiP support on this device.
  Future<void> _setupPipMode() async {
    if (_pipInitialized) return;
    _pipInitialized = true;

    try {
      _pipAvailable = await SimplePip.isPipAvailable;
      _autoPipSupported = await SimplePip.isAutoPipAvailable;
    } catch (e) {
      debugPrint('PiP availability check error: $e');
    }
  }

  /// Handle messages from the injected JS: video playing/paused.
  void _handlePipMessage(String message) {
    final bool isPlaying = message.trim() == 'playing';
    if (isPlaying == _isVideoPlaying) return;

    setState(() => _isVideoPlaying = isPlaying);
    _syncPipMode();
  }

  /// Enable/disable auto-PiP based on whether a video is actually playing.
  Future<void> _syncPipMode() async {
    if (!_pipAvailable) return;

    try {
      if (_isVideoPlaying) {
        // Video is playing -> allow PiP
        if (_autoPipSupported) {
          await _pip.setAutoPipMode(
            aspectRatio: const (16, 9),
            seamlessResize: true,
            autoEnter: true,
          );
        }
      } else {
        // No video playing -> never auto-enter PiP
        if (_autoPipSupported) {
          await _pip.setAutoPipMode(autoEnter: false);
        }
      }
    } catch (e) {
      debugPrint('PiP sync error: $e');
    }
  }

  /// Maximize the video in the PiP window so only the video is visible.
  Future<void> _enterPipVisual() async {
    if (!widget.webPage.title.contains('Newscast')) return;
    try {
      await controller.runJavaScript(
        'window.__pipVisual && window.__pipVisual.enter();',
      );
    } catch (e) {
      debugPrint('PiP visual enter error: $e');
    }
  }

  /// Restore the page when PiP is exited.
  Future<void> _exitPipVisual() async {
    try {
      await controller.runJavaScript(
        'window.__pipVisual && window.__pipVisual.exit();',
      );
    } catch (e) {
      debugPrint('PiP visual exit error: $e');
    }
  }

  @override
  void didUpdateWidget(WebPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.webPage.webPageURL != widget.webPage.webPageURL) {
      setState(() {
        loadingPercentage = 0;
        _pipInitialized = false;
        _isVideoPlaying = false;
      });
      controller.loadRequest(Uri.parse(widget.webPage.webPageURL));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Manual PiP entry for Android < 12, only when a video is actually playing.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden &&
        _pipInitialized &&
        _pipAvailable &&
        !_autoPipSupported &&
        _isVideoPlaying &&
        widget.webPage.title.contains('Newscast')) {
      _pip.enterPipMode(
        aspectRatio: const (16, 9),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: controller),
        if (loadingPercentage < 100)
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 90,
              child: PageView.builder(
                controller: _carouselController,
                itemCount: publications.length,
                onPageChanged: (index) => setState(() => selectedIndex = index),
                itemBuilder: (context, index) {
                  bool isSelected = selectedIndex == index;

                  return GestureDetector(
                    onTap: () => _onItemTapped(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
                            ? [BoxShadow(
                                color: Theme.of(context).primaryColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          publications[index].title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontSize: isSelected ? 16 : 14,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 1),

            Expanded(
              child: WebPage(webPage: publications[selectedIndex]),
            ),
          ],
        ),
      ),
    );
  }
}
