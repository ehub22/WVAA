import 'package:flutter_test/flutter_test.dart';
import 'package:westview_app/newscast_embed.dart';
import 'package:westview_app/newscast_page.dart';
import 'package:westview_app/video_pip.dart';

void main() {
  // Trimmed from a real response so the parser is tested against the shape
  // YouTube actually serves, including the media namespace and CDATA.
  const feed = '''<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns:yt="http://www.youtube.com/xml/schemas/2015"
      xmlns:media="http://search.yahoo.com/mrss/"
      xmlns="http://www.w3.org/2005/Atom">
 <title>Uploads from Westview Newscast</title>
 <entry>
  <id>yt:video:lGIZvN0V3w0</id>
  <yt:videoId>lGIZvN0V3w0</yt:videoId>
  <title>WVN 11-09-2026</title>
  <published>2026-11-09T16:24:02+00:00</published>
  <media:group>
   <media:description>Weekly news introduction &amp; more</media:description>
  </media:group>
 </entry>
 <entry>
  <yt:videoId>ie2jN-MR1l4</yt:videoId>
  <title>WVN 10-5-2026</title>
  <published>2026-10-05T15:00:39+00:00</published>
  <media:group>
   <media:description><![CDATA[In This Broadcast: A Pep Rally?]]></media:description>
  </media:group>
 </entry>
 <entry>
  <yt:videoId>ekCYmZh54Wg</yt:videoId>
  <title>WVN 10-19-2026</title>
  <published>2026-10-19T15:00:05+00:00</published>
 </entry>
</feed>''';

  group('NewscastChannel.parseFeed', () {
    test('reads ids, titles, dates, and descriptions', () {
      final episodes = NewscastChannel.parseFeed(feed);

      expect(episodes, hasLength(3));
      expect(episodes.first.videoId, 'lGIZvN0V3w0');
      expect(episodes.first.title, 'WVN 11-09-2026');
      expect(episodes.first.published.year, 2026);
      expect(episodes.first.description, 'Weekly news introduction & more');
    });

    test('sorts newest first and unwraps CDATA descriptions', () {
      final episodes = NewscastChannel.parseFeed(feed);

      expect(
        episodes.map((e) => e.videoId).toList(),
        <String>['lGIZvN0V3w0', 'ekCYmZh54Wg', 'ie2jN-MR1l4'],
      );
      expect(episodes.last.description,
          'In This Broadcast: A Pep Rally?');
    });

    test('caps the list so the tab cannot grow without bound', () {
      expect(NewscastChannel.parseFeed(feed, limit: 2), hasLength(2));
      expect(NewscastChannel.maxEpisodes, lessThan(100));
    });

    test('an HTML page or garbage parses to an empty list', () {
      expect(NewscastChannel.parseFeed('<html><body>nope</body></html>'),
          isEmpty);
      expect(NewscastChannel.parseFeed(''), isEmpty);
    });

    test('entries missing an id or title are skipped', () {
      const partial = '<feed><entry><title>No id</title></entry>'
          '<entry><yt:videoId>abcdefghijk</yt:videoId></entry></feed>';
      expect(NewscastChannel.parseFeed(partial), isEmpty);
    });

    test('thumbnails come from the video id', () {
      final episode = NewscastChannel.parseFeed(feed).first;
      expect(episode.thumbnailUrl, contains('lGIZvN0V3w0'));
      expect(episode.thumbnailUrl, startsWith('https://'));
    });
  });

  group('isNewscastEmbedUrl', () {
    bool allowed(String url) => isNewscastEmbedUrl(Uri.parse(url));

    test('lets the embed and its player resources load', () {
      expect(allowed('https://www.youtube-nocookie.com/embed/lGIZvN0V3w0'), isTrue);
      expect(allowed('https://www.youtube.com/embed/lGIZvN0V3w0?rel=0'), isTrue);
      expect(embedRequest('lGIZvN0V3w0').toString(), startsWith('https://'));
      expect(
        allowed('https://rr3---sn-abc.googlevideo.com/videoplayback?x=1'),
        isTrue,
      );
      expect(allowed('https://www.gstatic.com/yts/jsbin/base.js'), isTrue);
    });

    test('blocks the rest of YouTube', () {
      // The whole point: a school app must not become a browser for YouTube.
      expect(allowed('https://www.youtube.com/watch?v=lGIZvN0V3w0'), isFalse);
      expect(allowed('https://m.youtube.com/watch?v=lGIZvN0V3w0'), isFalse);
      expect(allowed('https://www.youtube.com/results?search_query=anything'),
          isFalse);
      expect(
        allowed('https://www.youtube.com/@westviewnewscast7337/videos'),
        isFalse,
      );
      expect(allowed('https://www.youtube.com/playlist?list=PL1234567890'),
          isFalse);
      // Even the bare host is the site's home page, not the player.
      expect(allowed('https://www.youtube.com/'), isFalse);
      expect(allowed('https://example.com/'), isFalse);
    });
  });

  // Error 153 is what YouTube shows when the embed arrives without a Referer,
  // and a WebView sends none on a top-level request. These assertions exist so
  // the headers cannot be dropped again without a test failing.
  group('embedRequest headers', () {
    test('names the app as the referrer', () {
      expect(embedHeaders['Referer'], embedOrigin);
      expect(embedOrigin, startsWith('https://'));
      // YouTube's documentation spells it `Referer`; `Referrer` is ignored.
      expect(embedHeaders.containsKey('Referrer'), isFalse);
    });

    test('does not suppress the referrer', () {
      expect(embedHeaders['Referrer-Policy'], 'strict-origin-when-cross-origin');
    });

    test('asks for inline playback so the player can be promoted to PiP', () {
      // playsinline=0 hands the video to Android's own player, which is a
      // different window and cannot be put in a picture-in-picture box.
      expect(embedRequest('lGIZvN0V3w0').queryParameters['playsinline'], '1');
    });

    test('the origin it declares matches the referrer it sends', () {
      // A player whose `origin` disagrees with the `Referer` it received is
      // another route to error 153, so the two must stay equal.
      expect(
        embedRequest('lGIZvN0V3w0').queryParameters['origin'],
        embedHeaders['Referer'],
      );
      expect(embedOrigin, embedHeaders['Referer']);
    });

    test('keeps the embed locked to one video', () {
      final uri = embedRequest('lGIZvN0V3w0');
      expect(uri.host, 'www.youtube-nocookie.com');
      expect(uri.path, '/embed/lGIZvN0V3w0');
      expect(uri.queryParameters['rel'], '0');
      expect(uri.queryParameters['iv_load_policy'], '3');
    });
  });

  group('NewscastPage', () {
    test('reads the channel upload feed rather than a channel page', () {
      expect(NewscastPage.feedUrl, contains('feeds/videos.xml'));
      // The `UU` upload playlist for the Westview Newscast channel, derived
      // from its `UC` channel id.
      expect(NewscastPage.feedUrl, contains('UUzfU2dfIYoiLWe8OkLGArFQ'));
      expect(NewscastPage.feedUrl, isNot(contains('/@')));
    });
  });
}
