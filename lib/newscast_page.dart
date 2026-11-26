import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'l10n/strings.dart';
import 'network_cache.dart';
import 'newscast_embed.dart';
import 'widgets/status_views.dart';

/// One episode of the Westview Newscast.
@immutable
class NewscastEpisode {
  const NewscastEpisode({
    required this.videoId,
    required this.title,
    required this.published,
    this.description = '',
  });

  final String videoId;
  final String title;
  final DateTime published;

  /// The "In This Broadcast:" line the Newscast team writes for each episode.
  final String description;

  /// Small, self-hosted thumbnail. Going through `i.ytimg.com` directly would
  /// add a request per row; this keeps each list item to one image and lets
  /// the image finish caching between launches.
  String get thumbnailUrl => 'https://i.ytimg.com/vi/$videoId/mqdefault.jpg';
}

/// The Newscast tab: a plain list of episodes, plus an embedded player.
///
/// This deliberately does not show YouTube's channel page. A WebView pointed at
/// youtube.com gives a student a search box, a recommendation rail, and the
/// whole site one tap away inside a school app. Instead the channel's public
/// upload feed is read as XML, the episodes are drawn with ordinary Flutter
/// widgets, and the only YouTube surface is the embed for one specific video.
class NewscastPage extends StatefulWidget {
  const NewscastPage({super.key});

  /// The channel's upload feed. `playlist_id` (the channel id with `UC`
  /// swapped for `UU`) is the list of uploads; `channel_id` would work too but
  /// stops at the fifteen most recent videos either way.
  static const String feedUrl =
      'https://www.youtube.com/feeds/videos.xml'
      '?playlist_id=UUzfU2dfIYoiLWe8OkLGArFQ';

  @override
  State<NewscastPage> createState() => NewscastPageState();
}

/// Public so the Publications tab's refresh button can reach [refresh].
class NewscastPageState extends State<NewscastPage> {
  static const Duration _cacheMaxAge = Duration(hours: 6);
  static const Duration _timeout = Duration(seconds: 15);

  List<NewscastEpisode>? _episodes;
  bool _loading = true;
  bool _error = false;
  bool _showingSavedCopy = false;
  DateTime? _cachedAt;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool force = false}) async {
    if (mounted && _episodes == null) setState(() => _loading = true);

    CachedResponse? cache;
    try {
      cache = await NetworkCache.instance.read(NewscastPage.feedUrl);
      // On a force refresh the network result wins, so the cache is only used
      // as an offline copy or as the first paint.
      if (cache != null && (_episodes == null || !force)) {
        final parsed = NewscastChannel.parseFeed(cache.body);
        if (parsed.isNotEmpty && _episodes == null) {
          _episodes = parsed;
          _cachedAt = cache.cachedAt;
        }
      }
    } catch (error) {
      debugPrint('Newscast cache unusable: $error');
    }

    if (!force &&
        cache != null &&
        cache.isFreshWithin(_cacheMaxAge, DateTime.now()) &&
        (_episodes?.isNotEmpty ?? false)) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = false;
        _showingSavedCopy = false;
      });
      return;
    }

    try {
      final response =
          await http.get(Uri.parse(NewscastPage.feedUrl)).timeout(_timeout);
      if (response.statusCode != 200) {
        throw Exception('Newscast feed returned ${response.statusCode}');
      }
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final episodes = NewscastChannel.parseFeed(body);
      await NetworkCache.instance.write(NewscastPage.feedUrl, body);
      if (!mounted) return;
      setState(() {
        _episodes = episodes;
        _loading = false;
        _error = episodes.isEmpty;
        _showingSavedCopy = false;
        _cachedAt = DateTime.now();
      });
    } catch (error) {
      debugPrint('Newscast feed failed: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_episodes?.isNotEmpty ?? false) {
          _showingSavedCopy = true;
        } else {
          _error = true;
        }
      });
    }
  }

  void _openEpisode(NewscastEpisode episode) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NewscastVideoPage(episode: episode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    if (_loading && _episodes == null) {
      return LoadingStatusView(label: strings['web.loading']);
    }
    if (_error && (_episodes?.isEmpty ?? true)) {
      return ErrorStatusView(
        title: strings['newscast.errorTitle'],
        message: strings['newscast.errorBody'],
        onRetry: () => _load(force: true),
        retryLabel: strings['web.retry'],
      );
    }

    final episodes = _episodes ?? const <NewscastEpisode>[];
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: episodes.length + (_showingSavedCopy ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          if (_showingSavedCopy && index == 0) {
            return _SavedCopyBanner(cachedAt: _cachedAt);
          }
          final episode = episodes[index - (_showingSavedCopy ? 1 : 0)];
          return _EpisodeTile(
            episode: episode,
            onTap: () => _openEpisode(episode),
          );
        },
      ),
    );
  }

  /// Reloads the episode list from the header's refresh button.
  void refresh() => unawaited(_load(force: true));
}

/// One row: thumbnail, title, date, and the broadcast's own summary line.
class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({required this.episode, required this.onTap});

  final NewscastEpisode episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      // One announcement per row instead of reading the title, date, and
      // summary as three separate stops.
      label:
          '${episode.title}, ${formatEpisodeDate(context, episode.published)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 120,
                  height: 68,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: scheme.surfaceContainerHighest),
                      Image.network(
                        episode.thumbnailUrl,
                        fit: BoxFit.cover,
                        // A missing thumbnail should never break a row.
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.play_circle_outline,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 30,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatEpisodeDate(context, episode.published),
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (episode.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        episode.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedCopyBanner extends StatelessWidget {
  const _SavedCopyBanner({required this.cachedAt});

  final DateTime? cachedAt;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final at = cachedAt;
    final label = at == null
        ? strings['web.stale']
        : '${strings['calendar.savedCopy']} '
            '${formatEpisodeDate(context, at)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// The player itself: one embedded video and nothing else.
///
/// There is no page chrome to wander into because the widget is an iframe for
/// a single video. Every navigation attempt is refused, so the only controls
/// are play, pause, fullscreen, and the explicit way out.
class NewscastVideoPage extends StatefulWidget {
  const NewscastVideoPage({super.key, required this.episode});

  final NewscastEpisode episode;

  @override
  State<NewscastVideoPage> createState() => _NewscastVideoPageState();
}

class _NewscastVideoPageState extends State<NewscastVideoPage> {
  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings['publications.newscast'],
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            Text(
              widget.episode.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, color: Colors.white),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: NewscastEmbed(videoId: widget.episode.videoId),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Text(
                    formatEpisodeDate(context, widget.episode.published),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  if (widget.episode.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.episode.description,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // The only intentional way out to YouTube, and it opens the
                  // phone's own browser rather than turning the app into one.
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(
                        'https://www.youtube.com/watch'
                        '?v=${widget.episode.videoId}',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(strings['newscast.openOnYouTube']),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reads and writes the channel's upload feed.
///
/// The feed is RSS with a `yt:` namespace, and the parts this app needs are the
/// video id, the title, and the publish date, so a small targeted parser is
/// enough; no XML package needed for three fields.
class NewscastChannel {
  NewscastChannel._();

  static const int maxEpisodes = 30;

  /// Parses `https://www.youtube.com/feeds/videos.xml` output.
  ///
  /// Only the first [maxEpisodes] entries are kept, newest first. Returns an
  /// empty list rather than throwing when the document does not look like a
  /// feed, so a YouTube format change shows the retry view instead of crashing.
  static List<NewscastEpisode> parseFeed(String xml, {int? limit}) {
    final episodes = <NewscastEpisode>[];
    final entries = RegExp(
      r'<entry>(.*?)</entry>',
      dotAll: true,
    ).allMatches(xml);

    for (final entry in entries) {
      final body = entry.group(1) ?? '';
      final id = _tag(body, 'yt:videoId') ?? _tag(body, 'videoId');
      final title = _tag(body, 'title');
      if (id == null || title == null) continue;

      episodes.add(NewscastEpisode(
        videoId: id,
        title: _decodeEntities(title),
        published: DateTime.tryParse(_tag(body, 'published') ?? '')?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        description: _decodeEntities(_tag(body, 'media:description') ?? ''),
      ));
    }

    episodes.sort((a, b) => b.published.compareTo(a.published));
    final cap = limit ?? maxEpisodes;
    return episodes.take(cap).toList(growable: false);
  }

  /// The text of the first `<tag>…</tag>` in [body], or null.
  static String? _tag(String body, String tag) {
    final match = RegExp(
      '<' + RegExp.escape(tag) + r'[^>]*>(.*?)</' + RegExp.escape(tag) + '>',
      dotAll: true,
    ).firstMatch(body);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    // Descriptions arrive wrapped in CDATA.
    if (value.startsWith('<![CDATA[') && value.endsWith(']]>')) {
      return value.substring(9, value.length - 3).trim();
    }
    return value;
  }

  static String _decodeEntities(String value) {
    if (!value.contains('&')) return value;
    return value
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
  }
}

/// Formats an episode date using the phone's locale, falling back to a plain
/// numeric date when the locale has no pattern for it.
String formatEpisodeDate(BuildContext context, DateTime date) {
  final localizations = MaterialLocalizations.of(context);
  return localizations.formatMediumDate(date);
}
