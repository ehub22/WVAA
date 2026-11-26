import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Student-facing safety behaviors that are about *being safe while using an
/// app on a shared or watched device*, rather than about crisis resources
/// (those live in `support.dart`).
///
/// Two protections live here:
///
///  1. **Quick exit** — when enabled, a long-press on the Help button (or any
///     other control wired to [QuickExit.longPressHandler]) instantly leaves
///     the app and clears the help screen from the back stack, so a student
///     researching support options is not left with that page on screen.
///     No confirmation dialog: a quick exit that asks "are you sure?" is not
///     a quick exit.
///
///  2. **Recents privacy** — an optional setting that asks Android to hide
///     the app's content in the recents/app-switcher thumbnail.
///
/// Both protections start switched on, are stored only on the device, and are
/// never reported anywhere.

/// Persisted safety toggles.
class SafetySettings extends ChangeNotifier {
  SafetySettings._();

  static final SafetySettings instance = SafetySettings._();

  static const String _hideRecentsKey = 'safety_hide_recents_v1';
  static const String _quickExitKey = 'safety_quick_exit_v1';

  bool _hideRecents = true;
  bool _quickExit = true;
  bool _loaded = false;

  /// Hide app content from the Android recents/app-switcher thumbnail.
  bool get hideRecents => _hideRecents;

  /// Enable the quick-exit long-press gesture.
  bool get quickExitEnabled => _quickExit;

  /// True once values have been read off disk. Defaults are already the safe
  /// ones (both protections on), so this is informational.
  bool get isLoaded => _loaded;

  /// Loads persisted values. Never throws; defaults stay on if storage fails.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hideRecents = prefs.getBool(_hideRecentsKey) ?? true;
      _quickExit = prefs.getBool(_quickExitKey) ?? true;
    } catch (_) {
      // Keep the safe defaults.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setHideRecents(bool value) async {
    if (_hideRecents == value) return;
    _hideRecents = value;
    notifyListeners();
    await _persist(_hideRecentsKey, value);
    // Best effort: tell the platform to update the recents flag.
    unawaited(QuickExit.applyRecentsPrivacy(value));
  }

  Future<void> setQuickExitEnabled(bool value) async {
    if (_quickExit == value) return;
    _quickExit = value;
    notifyListeners();
    await _persist(_quickExitKey, value);
  }

  /// Resets in-memory state (used by tests so suites don't leak toggles).
  @visibleForTesting
  void resetForTesting() {
    _hideRecents = true;
    _quickExit = true;
    _loaded = false;
    notifyListeners();
  }

  Future<void> _persist(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {
      // Best effort: a failed write must never break the UI.
    }
  }
}

/// Implements the quick exit gesture and the recents-privacy flag.
class QuickExit {
  QuickExit._();

  /// Method channel handled by `MainActivity.kt`.
  static const MethodChannel channel =
      MethodChannel('com.westviewhs.app/safety');

  /// Leaves the app as fast as the platform allows: clear the back stack, then
  /// send the task to the background (Android) or pop the app (elsewhere).
  ///
  /// Returns true when the platform acknowledged the request.
  static Future<bool> trigger() async {
    HapticFeedback.selectionClick();
    try {
      final handled =
          await channel.invokeMethod<bool>('moveTaskToBack').timeout(
                const Duration(milliseconds: 400),
              );
      if (handled == true) return true;
    } catch (_) {
      // Channel missing (tests, desktop, iOS) — fall through.
    }
    try {
      await SystemNavigator.pop();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Applies the recents-privacy setting to the current Android task.
  static Future<void> applyRecentsPrivacy(bool hide) async {
    try {
      await channel.invokeMethod<void>(
        'setRecentsPrivacy',
        <String, Object?>{'hide': hide},
      );
    } catch (_) {
      // Platform doesn't implement it (iOS/desktop/tests): nothing to do.
    }
  }

  /// Wraps a normal tap action so a long-press on the same widget triggers the
  /// quick exit instead. Returns null when the gesture is disabled, so callers
  /// can pass the result straight into a widget's `onLongPress`.
  static VoidCallback? longPressHandler(BuildContext context) {
    if (!SafetySettings.instance.quickExitEnabled) return null;
    return () => _exitFrom(context);
  }

  static Future<void> _exitFrom(BuildContext context) async {
    // Clear the navigation stack first so the help screen is not the state the
    // app restores to, then leave. No animation, no confirmation.
    try {
      Navigator.of(context, rootNavigator: true)
          .popUntil((route) => route.isFirst);
    } catch (_) {
      // Navigator unavailable — still try to leave.
    }
    await trigger();
  }
}
