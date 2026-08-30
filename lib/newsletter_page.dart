import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

class _WebPageState extends State<WebPage> {
  late final WebViewController controller;
  int loadingPercentage = 0;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => loadingPercentage = 0),
          onProgress: (progress) => setState(() => loadingPercentage = progress),
          onPageFinished: (_) => setState(() => loadingPercentage = 100),
        ),
      )
      ..loadRequest(Uri.parse(widget.webPage.webPageURL));
  }

  @override
  void didUpdateWidget(WebPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.webPage.webPageURL != widget.webPage.webPageURL) {
      setState(() => loadingPercentage = 0);
      controller.loadRequest(Uri.parse(widget.webPage.webPageURL));
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

class NewsletterPage extends StatefulWidget {
  const NewsletterPage({super.key});

  @override
  State<NewsletterPage> createState() => _NewsletterPageState();
}

class _NewsletterPageState extends State<NewsletterPage> {
  int selectedIndex = 0;
  late PageController _carouselController;

  final List<WebPageInfo> newsletters = const [
    WebPageInfo('Weekly Newsletter', 'https://www.canva.com/design/DAHAfg0kzy4/j0rtuhnsLlGu4XMtz5mqRA/view?utm_content=DAHAfg0kzy4&utm_campaign=designshare&utm_medium=link2&utm_source=uniquelinks&utlId=hf1baa97a03'),
    WebPageInfo('Counseling Newsletters', 'https://westview.powayusd.com/apps/pages/newsletters'),
    WebPageInfo('Den Announcements', 'https://docs.google.com/presentation/d/1Q6zH31VmOOnrPJMprtT6IL9rH8tEMmlKyBovYB0Ukq4/edit'),
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
    return SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 90,
            child: PageView.builder(
              controller: _carouselController,
              itemCount: newsletters.length,
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
                        color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.3),
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
                        newsletters[index].title,
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
          Expanded(child: WebPage(webPage: newsletters[selectedIndex])),
        ],
      ),
    );
  }
}
