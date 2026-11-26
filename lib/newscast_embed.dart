import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'video_pip.dart';

/// Hosts the embed may load from, as long as the path is player code.
const List<String> _allowedHosts = <String>[
  'www.youtube-nocookie.com',
  'www.youtube.com',
  'youtube.com',
  'youtube-nocookie.com',
];

/// Paths on those hosts that are part of the player rather than the site.
const List<String> _allowedPrefixes = <String>[
  '/embed/',
  '/yts/',
  '/s/player/',
  '/player_api',
  '/generate_204',
  '/favicon',
];

/// Hosts that serve the player's own media rather than the site.
const List<String> _assetHosts = <String>[
  'www.gstatic.com',
  'i.ytimg.com',
  'yt3.ggpht.com',
];

/// Paths on the asset hosts that are player code or artwork.
const List<String> _assetPrefixes = <String>[
  '/yts/',
  '/jsbin/',
  '/s/player/',
  '/vi/',
  '/ytc/',
];

/// A single YouTube embed, locked to the video it was given.
///
/// Everything a normal YouTube page would let a student reach is missing on
/// purpose: the embed has no search box, no channel link, no comments, and no
/// recommendation rail. The navigation delegate then refuses every URL except
/// the embed itself and YouTube's own player endpoint, so a tap on the title,
/// the watermark, or an end-screen preview does nothing instead of opening the
/// site. A student who really wants the full page has the explicit
/// "Open on YouTube" button, which leaves the app.
class NewscastEmbed extends StatefulWidget {
  const NewscastEmbed({super.key, required this.videoId});

  final String videoId;

  @override
  State<NewscastEmbed> createState() => _NewscastEmbedState();
}

class _NewscastEmbedState extends State<NewscastEmbed> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            return uri != null && isNewscastEmbedUrl(uri)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      );
    _load(widget.videoId);
  }

  @override
  void didUpdateWidget(covariant NewscastEmbed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _load(widget.videoId);
    }
  }

  /// Loads one video, with the headers YouTube requires.
  ///
  /// The headers matter: a WebView sends no referrer on a top-level request,
  /// and YouTube answers a request it cannot identify with "Error 153: Video
  /// player configuration error" instead of a player.
  void _load(String videoId) {
    _controller.loadRequest(embedRequest(videoId), headers: embedHeaders);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: WebViewWidget(controller: _controller),
    );
  }
}

/// Whether [uri] is part of playing the embedded video rather than the
/// surrounding YouTube site.
///
/// This is the app's guarantee that a school app never turns into a browser for
/// YouTube: the embed itself is allowed, its player code and video bytes are
/// allowed, and every watch page, search result, channel, and playlist is not.
///
/// Video bytes come from `*.googlevideo.com` with no useful path prefix, so
/// that host family is allowed outright.
@visibleForTesting
bool isNewscastEmbedUrl(Uri uri) {
  if (uri.scheme == 'about') return true;
  if (uri.scheme != 'https') return false;

  final host = uri.host.toLowerCase();
  final path = uri.path.isEmpty ? '/' : uri.path;

  if (host.endsWith('.googlevideo.com')) return true;

  if (_assetHosts.contains(host)) {
    return _assetPrefixes.any((prefix) => path.startsWith(prefix));
  }

  if (!_allowedHosts.contains(host)) return false;
  // A bare `youtube.com/` is the site's home page, so it stays blocked too.
  return _allowedPrefixes.any((prefix) => path.startsWith(prefix));
}
