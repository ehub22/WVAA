import 'package:flutter_test/flutter_test.dart';
import 'package:westview_app/video_pip.dart';

void main() {
  group('isPipVideoUrl', () {
    test('accepts the hosts the bridge knows how to follow', () {
      expect(isPipVideoUrl('https://vimeo.com/123456789'), isTrue);
      expect(
        isPipVideoUrl('https://player.vimeo.com/video/123456789'),
        isTrue,
      );
      expect(
        isPipVideoUrl('https://www.youtube.com/@westviewnewscast7337/videos'),
        isTrue,
      );
      expect(
        isPipVideoUrl('https://www.youtube.com/watch?v=abcdefghijk'),
        isTrue,
      );
      expect(isPipVideoUrl('https://m.youtube.com/watch?v=abcdefghijk'), isTrue);
      expect(isPipVideoUrl('https://youtu.be/abcdefghijk'), isTrue);
    });

    test('rejects non-video pages and lookalike hosts', () {
      expect(isPipVideoUrl('https://wvnexus.org/category/news/'), isFalse);
      expect(isPipVideoUrl('https://vimeo.com.example.org/video/1'), isFalse);
      expect(isPipVideoUrl('https://youtube.com.example.org/watch'), isFalse);
      expect(isPipVideoUrl('not a URL'), isFalse);
    });

    test('host helpers stay specific', () {
      expect(isVimeoUrl('https://vimeo.com/123456789'), isTrue);
      expect(isVimeoUrl('https://www.youtube.com/watch?v=x'), isFalse);
      expect(isYouTubeUrl('https://www.youtube.com/watch?v=x'), isTrue);
      expect(isYouTubeUrl('https://vimeo.com/123456789'), isFalse);
    });
  });

  test('PiP bridge handles iframe playback and full-viewport isolation', () {
    expect(videoPipScript, contains('post(frame, \'getPaused\')'));
    expect(videoPipScript, contains("eventName === 'play'"));
    expect(videoPipScript, contains("important(target, 'position', 'fixed')"));
    expect(videoPipScript, contains("important(target, 'width', '100vw')"));
    expect(videoPipScript, contains("important(target, 'height', '100vh')"));
  });

  group('youtubeVideoId', () {
    test('reads the shapes the channel page produces', () {
      expect(youtubeVideoId('https://www.youtube.com/watch?v=lGIZvN0V3w0'),
          'lGIZvN0V3w0');
      expect(
        youtubeVideoId(
            'https://www.youtube.com/watch?v=ekCYmZh54Wg&pp=0gcJCUYIAYcqIYzv'),
        'ekCYmZh54Wg',
      );
      expect(youtubeVideoId('https://youtu.be/Bj65fg1l8_Y'), 'Bj65fg1l8_Y');
      expect(youtubeVideoId('https://www.youtube.com/shorts/abcdefghijk'),
          'abcdefghijk');
      expect(youtubeVideoId('https://www.youtube.com/embed/lGIZvN0V3w0'),
          'lGIZvN0V3w0');
    });

    test('ignores channel pages, playlists, and lookalike hosts', () {
      expect(
        youtubeVideoId('https://www.youtube.com/@westviewnewscast7337/videos'),
        isNull,
      );
      expect(youtubeVideoId('https://www.youtube.com/channel/UCzfU2dfIYoi'), isNull);
      expect(
        youtubeVideoId('https://www.youtube.com/playlist?list=PL1234567890'),
        isNull,
      );
      expect(youtubeVideoId('https://youtube.com.example.org/watch?v=abcdefghijk'),
          isNull);
      expect(youtubeVideoId('not a URL'), isNull);
      // Too short to be a real id.
      expect(youtubeVideoId('https://www.youtube.com/watch?v=short'), isNull);
    });
  });

  group('embedRequest', () {
    test('loads a bare embed with previews limited to the same channel', () {
      final uri = embedRequest('lGIZvN0V3w0');
      expect(uri.host, 'www.youtube-nocookie.com');
      expect(uri.path, '/embed/lGIZvN0V3w0');
      expect(uri.queryParameters['rel'], '0');
      // No `origin` parameter: that is what lets the embed show a preview
      // instead of opening youtube.com on a stray tap.
      expect(uri.queryParameters.containsKey('origin'), isFalse);
      expect(uri.toString(), isNot(contains('youtube.com/@')));
    });
  });

  test('PiP bridge also listens to YouTube player events', () {
    // YouTube reports state through its iframe API rather than Vimeo's
    // method calls, so both paths have to stay in the script.
    expect(videoPipScript, contains("enablejsapi"));
    expect(videoPipScript, contains("postYouTube(frame, 'listening')"));
    expect(videoPipScript, contains("eventName === 'onstatechange'"));
  });
}
