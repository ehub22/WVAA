import 'package:flutter/material.dart';

import 'l10n/strings.dart';
import 'support.dart';
import 'web_page.dart';
import 'widgets/section_selector.dart';

/// The newsletters tab: the weekly newsletter and the counseling newsletters,
/// each in an embedded WebView.
///
/// Each newsletter keeps its own WebView alive (lazy IndexedStack) so content
/// loaded once stays on screen when switching sections — and keeps rendering
/// even when the network drops mid-session.
class NewsletterPage extends StatefulWidget {
  const NewsletterPage({super.key});

  @override
  State<NewsletterPage> createState() => _NewsletterPageState();
}

class _NewsletterPageState extends State<NewsletterPage> {
  int selectedIndex = 0;

  static const List<_Newsletter> _newsletters = [
    _Newsletter(
      'newsletter.weekly',
      'https://www.canva.com/design/DAHAfg0kzy4/I_JhwzEhBL8HMWSlQmZH3g/view'
      '?utm_content=DAHAfg0kzy4&utm_campaign=designshare&utm_medium=link2'
      '&utm_source=uniquelinks&utlId=he2477552fc',
    ),
    _Newsletter(
      'newsletter.counseling',
      'https://westview.powayusd.com/apps/pages/newsletters',
    ),
  ];

  /// One key per newsletter so the header refresh button can reach the
  /// currently visible WebView.
  final List<GlobalKey<WebPageViewState>> _webKeys = [
    for (var i = 0; i < _newsletters.length; i++) GlobalKey<WebPageViewState>(),
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
    return SafeArea(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SectionSelector(
                  labels: [
                    for (final n in _newsletters) strings[n.titleKey],
                  ],
                  selectedIndex: selectedIndex,
                  onSelected: _onItemTapped,
                ),
              ),
              // WebViews don't participate in Flutter's pull-to-refresh, so
              // this tab (and Publications) gets an explicit refresh button.
              // The tooltip doubles as the screen-reader label.
              IconButton.filledTonal(
                tooltip: strings['common.refresh'],
                onPressed: _refreshCurrent,
                icon: const Icon(Icons.refresh),
              ),
              // Help is reachable from every tab, not just the home screen.
              const HelpIconButton(),
              const SizedBox(width: 4),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: LazyIndexedStack(
              index: selectedIndex,
              itemCount: _newsletters.length,
              itemBuilder: (context, index) => WebPageView(
                key: _webKeys[index],
                url: _newsletters[index].url,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Newsletter {
  const _Newsletter(this.titleKey, this.url);

  /// Key in `strings.dart` for the translated tab label.
  final String titleKey;
  final String url;
}
