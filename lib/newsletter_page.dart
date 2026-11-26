import 'package:flutter/material.dart';

import 'l10n/strings.dart';
import 'support.dart';
import 'telemetry.dart';
import 'web_page.dart';
import 'widgets/section_selector.dart';

/// The newsletters tab: weekly newsletter, counseling newsletters and DEN
/// announcements, each in an embedded WebView.
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

  /// Stable, language-independent section id for analytics (never the
  /// translated label, so metrics stay comparable across languages).
  String get _sectionId => _newsletters[selectedIndex].titleKey;

  static const List<_Newsletter> _newsletters = [
    _Newsletter(
      'newsletter.weekly',
      'https://www.canva.com/design/DAHAfg0kzy4/j0rtuhnsLlGu4XMtz5mqRA/view'
      '?utm_content=DAHAfg0kzy4&utm_campaign=designshare&utm_medium=link2'
      '&utm_source=uniquelinks&utlId=hf1baa97a03',
    ),
    _Newsletter(
      'newsletter.counseling',
      'https://westview.powayusd.com/apps/pages/newsletters',
    ),
    _Newsletter(
      'newsletter.den',
      'https://docs.google.com/presentation/d/1Q6zH31VmOOnrPJMprtT6IL9rH8tEMmlKyBovYB0Ukq4/edit',
    ),
  ];

  /// One key per newsletter so the header refresh button can reach the
  /// currently visible WebView.
  final List<GlobalKey<WebPageViewState>> _webKeys = [
    for (var i = 0; i < _newsletters.length; i++) GlobalKey<WebPageViewState>(),
  ];

  void _onItemTapped(int index) {
    setState(() => selectedIndex = index);
    Telemetry.instance
        .logEvent('view_section', {'screen': 'newsletters', 'section': _newsletters[index].titleKey});
  }

  void _refreshCurrent() {
    Telemetry.instance
        .logEvent('newsletter_refresh', {'section': _sectionId});
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
