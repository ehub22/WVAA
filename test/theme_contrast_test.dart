import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westview_app/theme/theme.dart';

/// WCAG relative luminance.
double luminance(Color c) {
  double channel(int v) {
    final s = v / 255.0;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(c.red) +
      0.7152 * channel(c.green) +
      0.0722 * channel(c.blue);
}

/// WCAG contrast ratio between two colors.
double contrastRatio(Color a, Color b) {
  final la = luminance(a);
  final lb = luminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void expectReadable(String description, Color fg, Color bg) {
    expect(
      contrastRatio(fg, bg),
      greaterThanOrEqualTo(4.5),
      reason:
          '$description should meet WCAG AA (4.5:1) but is only '
          '${contrastRatio(fg, bg).toStringAsFixed(2)}:1',
    );
  }

  group('dark theme keeps readable contrast', () {
    final scheme = darkTheme.colorScheme;

    test('body text on surfaces', () {
      expectReadable('onSurface / surface', scheme.onSurface, scheme.surface);
      expectReadable('onSurface / scaffold',
          scheme.onSurface, darkTheme.scaffoldBackgroundColor);
      expectReadable('onSurfaceVariant / surfaceContainer',
          scheme.onSurfaceVariant, scheme.surfaceContainer);
      expectReadable('onSurfaceVariant / surfaceContainerHigh',
          scheme.onSurfaceVariant, scheme.surfaceContainerHigh);
      expectReadable('onSurfaceVariant / surfaceContainerHighest',
          scheme.onSurfaceVariant, scheme.surfaceContainerHighest);
    });

    test('branded containers', () {
      expectReadable('onPrimaryContainer / primaryContainer',
          scheme.onPrimaryContainer, scheme.primaryContainer);
      expectReadable('onSecondaryContainer / secondaryContainer',
          scheme.onSecondaryContainer, scheme.secondaryContainer);
    });

    test('accent and error text used on surfaces', () {
      expectReadable('primary / surface', scheme.primary, scheme.surface);
      expectReadable('error / surface', scheme.error, scheme.surface);
      expectReadable('onError / error', scheme.onError, scheme.error);
      expectReadable(
          'onErrorContainer / errorContainer', scheme.onErrorContainer, scheme.errorContainer);
    });

    test('section selector pill pairs', () {
      expectReadable('selected pill', scheme.onPrimary, scheme.primary);
      expectReadable('unselected pill', scheme.onSurfaceVariant,
          scheme.surfaceContainerHigh);
    });
  });

  group('light theme keeps readable contrast', () {
    final scheme = lightTheme.colorScheme;

    test('body text on surfaces', () {
      expectReadable('onSurface / surface', scheme.onSurface, scheme.surface);
      expectReadable('onSurfaceVariant / surfaceContainer',
          scheme.onSurfaceVariant, scheme.surfaceContainer);
      expectReadable('onSurfaceVariant / surfaceContainerHigh',
          scheme.onSurfaceVariant, scheme.surfaceContainerHigh);
    });

    test('branded containers and selector pills', () {
      expectReadable('onPrimaryContainer / primaryContainer',
          scheme.onPrimaryContainer, scheme.primaryContainer);
      expectReadable('selected pill', scheme.onPrimary, scheme.primary);
      expectReadable('unselected pill', scheme.onSurfaceVariant,
          scheme.surfaceContainerHigh);
      expectReadable('onErrorContainer / errorContainer',
          scheme.onErrorContainer, scheme.errorContainer);
    });
  });
}
