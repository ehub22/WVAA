import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:simple_pip_mode/simple_pip.dart';


// Note: PiP does not work currently.

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
  int loadingPercentage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() => loadingPercentage = 0),
          onProgress: (progress) => setState(() => loadingPercentage = progress),
          onPageFinished: (url) => setState(() => loadingPercentage = 100),
        ),
      )
      ..loadRequest(Uri.parse(widget.webPage.webPageURL));
  }

  @override
  void didUpdateWidget(WebPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.webPage.webPageURL != widget.webPage.webPageURL) {
      // Reset loading state when the URL changes with carousel
      setState(() {
        loadingPercentage = 0;
      });
      controller.loadRequest(Uri.parse(widget.webPage.webPageURL));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // This detects when the user swipes up to go home, doesn't work though
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && widget.webPage.title.contains('Newscast')) {
      SimplePip().enterPipMode(); // Manually force the system into PiP (still doesn't work)
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
                                offset: const Offset(0, 4)
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