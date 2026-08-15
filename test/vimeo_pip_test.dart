import 'package:flutter_test/flutter_test.dart';
import 'package:westview_app/vimeo_pip.dart';

void main() {
  group('isVimeoUrl', () {
    test('accepts Vimeo watch, channel, and player URLs', () {
      expect(isVimeoUrl('https://vimeo.com/123456789'), isTrue);
      expect(
        isVimeoUrl('https://vimeo.com/channels/westviewnewscast/123456789'),
        isTrue,
      );
      expect(
        isVimeoUrl('https://player.vimeo.com/video/123456789'),
        isTrue,
      );
    });

    test('rejects non-Vimeo and lookalike hosts', () {
      expect(isVimeoUrl('https://wvnexus.org/category/news/'), isFalse);
      expect(isVimeoUrl('https://vimeo.com.example.org/video/1'), isFalse);
      expect(isVimeoUrl('not a URL'), isFalse);
    });
  });

  test('PiP bridge handles iframe playback and full-viewport isolation', () {
    expect(vimeoPipScript, contains("post(frame, 'getPaused')"));
    expect(vimeoPipScript, contains("eventName === 'play'"));
    expect(vimeoPipScript, contains("important(target, 'position', 'fixed')"));
    expect(vimeoPipScript, contains("important(target, 'width', '100vw')"));
    expect(vimeoPipScript, contains("important(target, 'height', '100vh')"));
  });
}
