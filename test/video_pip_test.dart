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

  test('PiP bridge also listens to YouTube player events', () {
    // YouTube reports state through its iframe API rather than Vimeo's
    // method calls, so both paths have to stay in the script.
    expect(videoPipScript, contains("enablejsapi"));
    expect(videoPipScript, contains("postYouTube(frame, 'listening')"));
    expect(videoPipScript, contains("eventName === 'onstatechange'"));
  });
}
