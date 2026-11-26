import 'package:flutter_test/flutter_test.dart';
import 'package:westview_app/web_page.dart';

void main() {
  group('isAllowedWebNavigation', () {
    test('allows https pages and about:blank', () {
      expect(
        isAllowedWebNavigation(Uri.parse('https://wvnexus.org/category/news/')),
        isTrue,
      );
      expect(
        isAllowedWebNavigation(Uri.parse('https://www.canva.com/design/x/view')),
        isTrue,
      );
      expect(isAllowedWebNavigation(Uri.parse('about:blank')), isTrue);
    });

    test('blocks cleartext, local files, and external schemes', () {
      for (final url in [
        'http://wvnexus.org/',
        'file:///etc/passwd',
        'javascript:alert(1)',
        'data:text/html,<script>alert(1)</script>',
        'intent://scan#Intent;scheme=zxing;end',
        'tel:911',
        'mailto:a@b.com',
        'sms:988',
        'ftp://example.com/file',
        'https://', // no host
      ]) {
        expect(
          isAllowedWebNavigation(Uri.parse(url)),
          isFalse,
          reason: url,
        );
      }
    });
  });
}
