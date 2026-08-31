import 'package:flutter/material.dart';

import 'web_page.dart';

class NewsletterPage extends StatefulWidget {
  const NewsletterPage({super.key});

  @override
  State<NewsletterPage> createState() => _NewsletterPageState();
}

class _NewsletterPageState extends State<NewsletterPage> {
  int selectedIndex = 0;
  late final PageController _carouselController;

  final List<_Newsletter> _newsletters = const [
    _Newsletter(
      'Weekly Newsletter',
      'https://www.canva.com/design/DAHAfg0kzy4/j0rtuhnsLlGu4XMtz5mqRA/view'
      '?utm_content=DAHAfg0kzy4&utm_campaign=designshare&utm_medium=link2'
      '&utm_source=uniquelinks&utlId=hf1baa97a03',
    ),
    _Newsletter(
      'Counseling Newsletters',
      'https://westview.powayusd.com/apps/pages/newsletters',
    ),
    _Newsletter(
      'Den Announcements',
      'https://docs.google.com/presentation/d/1Q6zH31VmOOnrPJMprtT6IL9rH8tEMmlKyBovYB0Ukq4/edit',
    ),
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
              itemCount: _newsletters.length,
              onPageChanged: (index) => setState(() => selectedIndex = index),
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
                          : Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : Theme.of(context).colorScheme.outlineVariant,
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
                        _newsletters[index].title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurface,
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
            child: WebPageView(url: _newsletters[selectedIndex].url),
          ),
        ],
      ),
    );
  }
}

class _Newsletter {
  const _Newsletter(this.title, this.url);
  final String title;
  final String url;
}
