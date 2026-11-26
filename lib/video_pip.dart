import 'package:flutter/foundation.dart';

/// Tracks whether Android is currently showing an embedded video in PiP mode.
///
/// Because Android PiP captures the whole activity window rather than a single
/// widget, the app shell watches this flag and hides its headers and navigation
/// bar while PiP is active so the video fills the entire window.
final ValueNotifier<bool> videoPipActive = ValueNotifier<bool>(false);

/// Hosts whose players the PiP bridge knows how to follow.
///
/// Most videos appear inside a cross-origin iframe, which the page's own
/// JavaScript cannot read. Each host below gets handled one of two ways: its
/// documented `postMessage` player API (Vimeo) or its public iframe API
/// (YouTube), so playback state can be observed from the parent page.
const Set<String> _videoHosts = <String>{
  'vimeo.com',
  'youtube.com',
  'youtube-nocookie.com',
};

/// Returns whether [url] points at a page whose video the PiP bridge can follow.
///
/// PiP must never be enabled for arbitrary videos that might appear on one of
/// the other publication pages, so the check is a host allowlist rather than
/// "does this page have a video".
bool isPipVideoUrl(String url) {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) return false;

  final String host = uri.host.toLowerCase();
  for (final String allowed in _videoHosts) {
    if (host == allowed || host.endsWith('.$allowed')) return true;
  }
  // YouTube's short-link host still serves the same player.
  return host == 'youtu.be';
}

/// Returns whether [url] is a Vimeo page.
bool isVimeoUrl(String url) => _matchesHost(url, 'vimeo.com');

/// Returns whether [url] is a YouTube page.
bool isYouTubeUrl(String url) => _matchesHost(url, 'youtube.com');

/// The video id from a YouTube link, or null when [url] is not a video.
///
/// Handles the three shapes the channel page produces (`/watch?v=`,
/// `/shorts/`, and `youtu.be/`) plus the embed URL this app builds itself.
String? youtubeVideoId(String url) {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) return null;

  final String host = uri.host.toLowerCase();
  if (!(host == 'youtu.be' ||
      host == 'youtube.com' ||
      host.endsWith('.youtube.com') ||
      host == 'youtube-nocookie.com' ||
      host.endsWith('.youtube-nocookie.com'))) {
    return null;
  }

  final List<String> segments = uri.pathSegments;
  String? candidate;

  if (host == 'youtu.be' && segments.isNotEmpty) {
    candidate = segments.first;
  } else if (uri.queryParameters['v'] != null) {
    candidate = uri.queryParameters['v'];
  } else if (segments.length >= 2 &&
      (segments[0] == 'embed' ||
          segments[0] == 'shorts' ||
          segments[0] == 'live' ||
          segments[0] == 'v')) {
    candidate = segments[1];
  }

  if (candidate == null) return null;
  // Ids are always 11 URL-safe characters; anything else is a redirect or a
  // path we should not treat as a video.
  return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(candidate) ? candidate : null;
}

/// The identity this app presents to the YouTube player.
///
/// YouTube will not configure its player for a request that arrives without a
/// `Referer` header; it shows "Error 153: Video player configuration error"
/// instead. An Android WebView sends no referrer on a top-level navigation, so
/// the app has to name itself, and a package id is the closest thing a school
/// app has to a domain. YouTube uses it only to identify the embedding client.
const String embedOrigin = 'https://com.westviewhs.app';

/// Header that tells YouTube which app is embedding the video.
///
/// Without it the player fails with error 153, so this is not optional.
const Map<String, String> embedHeaders = <String, String>{
  // Spelled `Referer`, not `Referrer`; the misspelling is in the HTTP standard.
  'Referer': embedOrigin,
  'Referrer-Policy': 'strict-origin-when-cross-origin',
};

/// An embed URL that shows one video and almost nothing else.
///
/// `rel=0` limits the end-of-video grid to the same channel, `playsinline=1`
/// keeps playback inside the page instead of letting Android's player take over
/// the screen, which is what the picture-in-picture bridge needs to find a
/// `<video>` element to promote, and `modestbranding` drops the YouTube
/// wordmark from the control bar so the player does not read as a browser. The
/// page around it has no search box or recommendations at all.
///
/// `origin` matches [embedOrigin] so the player's idea of where it is embedded
/// agrees with the `Referer` header it received. A mismatch is another way to
/// land on error 153.
Uri embedRequest(String videoId) => Uri.https(
      'www.youtube-nocookie.com',
      '/embed/$videoId',
      <String, String>{
        'rel': '0',
        'playsinline': '1',
        'modestbranding': '1',
        'iv_load_policy': '3',
        'fs': '1',
        'origin': embedOrigin,
      },
    );

bool _matchesHost(String url, String host) {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) return false;
  final String actual = uri.host.toLowerCase();
  return actual == host || actual.endsWith('.$host');
}

/// Installs a small bridge in a page that hosts a video player.
///
/// Two things make this necessary:
///
///  * Playback state. A watch page renders its player in a cross-origin iframe,
///    so the parent page cannot read the `<video>` element directly. Vimeo is
///    observed through its documented `postMessage` player API, and YouTube
///    through its public iframe API, which the bridge enables by adding
///    `enablejsapi=1` to the embed URL and posting `listening` to the frame.
///  * Layout. When Android enters activity PiP, [enter] promotes either the
///    playing `<video>` or its player iframe to fill the whole WebView, so PiP
///    shows the video instead of the page header, thumbnail wall, or comments.
///    [exit] puts the original inline styles back.
const String videoPipScript = r'''
(function() {
  'use strict';

  if (window.__westviewVideoPip) {
    window.__westviewVideoPip.scan();
    return;
  }

  var lastReportedState = null;
  var activeFrame = null;
  var visualTarget = null;
  var savedStyles = [];
  var visualEntered = false;
  var retryTimer = null;

  // ---------------------------------------------------------------- hosts

  function hostOf(origin) {
    try {
      return new URL(origin).hostname.toLowerCase();
    } catch (_) {
      return '';
    }
  }

  function isVimeoHost(host) {
    return host === 'vimeo.com' || host.slice(-10) === '.vimeo.com';
  }

  function isYouTubeHost(host) {
    return host === 'youtube.com' || host.slice(-12) === '.youtube.com' ||
        host === 'youtube-nocookie.com' ||
        host.slice(-21) === '.youtube-nocookie.com';
  }

  function isPlayerOrigin(origin) {
    var host = hostOf(origin);
    return isVimeoHost(host) || isYouTubeHost(host);
  }

  // ---------------------------------------------------------------- frames

  function isVimeoFrame(frame) {
    if (!frame || frame.tagName !== 'IFRAME') return false;
    var src = (frame.getAttribute('src') || '').toLowerCase();
    var title = (frame.getAttribute('title') || '').toLowerCase();
    return src.indexOf('vimeo.com') !== -1 || title.indexOf('vimeo') !== -1;
  }

  function isYouTubeFrame(frame) {
    if (!frame || frame.tagName !== 'IFRAME') return false;
    var src = (frame.getAttribute('src') || '').toLowerCase();
    var title = (frame.getAttribute('title') || '').toLowerCase();
    return src.indexOf('youtube.com') !== -1 ||
        src.indexOf('youtube-nocookie.com') !== -1 ||
        title.indexOf('youtube') !== -1;
  }

  function playerFrames() {
    var all = document.querySelectorAll('iframe');
    var result = [];
    for (var i = 0; i < all.length; i++) {
      if (isVimeoFrame(all[i]) || isYouTubeFrame(all[i]) ||
          all[i].__westviewPlayerFrame) {
        result.push(all[i]);
      }
    }
    return result;
  }

  function frameForWindow(source) {
    var frames = document.querySelectorAll('iframe');
    for (var i = 0; i < frames.length; i++) {
      try {
        if (frames[i].contentWindow === source) {
          // The message origin was already validated, so remember players
          // whose lazy iframe has no src/title hint yet.
          frames[i].__westviewPlayerFrame = true;
          return frames[i];
        }
      } catch (_) {}
    }
    return null;
  }

  // Target origin for outbound player messages: the frame's own origin
  // when it can be derived from src, so messages are not broadcast to
  // whatever happens to be listening. Falls back to '*' only when the
  // frame has no src yet (lazy iframe) — inbound messages are still
  // origin-checked in the listener below.
  function frameOrigin(frame) {
    try {
      var src = frame.getAttribute('src') || '';
      if (!src) return '*';
      var origin = new URL(src, window.location.href).origin;
      return origin && origin !== 'null' ? origin : '*';
    } catch (_) {
      return '*';
    }
  }

  function post(frame, method, value) {
    try {
      var message = {method: method};
      if (value !== undefined) message.value = value;
      frame.contentWindow.postMessage(message, frameOrigin(frame));
    } catch (_) {}
  }

  // YouTube's iframe API uses event names instead of method calls.
  function postYouTube(frame, eventName) {
    try {
      frame.contentWindow.postMessage(
        JSON.stringify({event: eventName, id: '__westview'}),
        frameOrigin(frame));
    } catch (_) {}
  }

  /// YouTube needs `enablejsapi=1` in the embed URL before it will answer, and
  /// its videos only start reporting after a `listening` message arrives.
  function enableYouTubeApi(frame) {
    try {
      var src = frame.getAttribute('src');
      if (src && src.indexOf('enablejsapi') === -1) {
        var url = new URL(src, window.location.href);
        url.searchParams.set('enablejsapi', '1');
        frame.setAttribute('src', url.toString());
        return;
      }
      frame.contentWindow.postMessage(
        JSON.stringify({event: 'listening', id: '__westview'}),
        frameOrigin(frame));
    } catch (_) {}
  }

  function subscribe(frame, force, sendPing) {
    if (!frame) return;

    if (!frame.__westviewLoadObserved) {
      frame.__westviewLoadObserved = true;
      frame.addEventListener('load', function() {
        frame.__westviewSubscribed = false;
        subscribe(frame, true, true);
      });
    }

    var youtube = isYouTubeFrame(frame);
    if (youtube) {
      enableYouTubeApi(frame);
    }

    if (!frame.__westviewSubscribed || force) {
      frame.__westviewSubscribed = true;
      if (youtube) {
        postYouTube(frame, 'listening');
      } else {
        post(frame, 'addEventListener', 'play');
        post(frame, 'addEventListener', 'playing');
        post(frame, 'addEventListener', 'pause');
        post(frame, 'addEventListener', 'ended');
        post(frame, 'addEventListener', 'finish');
        post(frame, 'addEventListener', 'playProgress');
        if (sendPing !== false) post(frame, 'ping');
      }
    }

    // Vimeo's documented state getter, as a fallback for a player that was
    // already running before the subscriptions were installed.
    if (!youtube) post(frame, 'getPaused');
  }

  // ---------------------------------------------------------------- state

  function documentVideoPlaying() {
    var videos = document.querySelectorAll('video');
    for (var i = 0; i < videos.length; i++) {
      if (!videos[i].paused && !videos[i].ended && videos[i].readyState > 0) {
        return true;
      }
    }
    return false;
  }

  function frameVideoPlaying() {
    var frames = playerFrames();
    for (var i = 0; i < frames.length; i++) {
      if (frames[i].__westviewPlaying === true) return true;
    }
    return false;
  }

  function reportState() {
    var playing = documentVideoPlaying() || frameVideoPlaying();
    if (playing === lastReportedState) return;
    lastReportedState = playing;
    try {
      PiPChannel.postMessage(playing ? 'playing' : 'paused');
    } catch (_) {}
  }

  function reportEntered(ok) {
    try {
      PiPChannel.postMessage(ok ? 'entered' : 'no-target');
    } catch (_) {}
  }

  function attachVideo(video) {
    if (!video || video.__westviewPipObserved) return;
    video.__westviewPipObserved = true;
    video.addEventListener('play', reportState);
    video.addEventListener('playing', reportState);
    video.addEventListener('pause', reportState);
    video.addEventListener('ended', reportState);
  }

  function scan() {
    var videos = document.querySelectorAll('video');
    for (var i = 0; i < videos.length; i++) attachVideo(videos[i]);

    var frames = playerFrames();
    for (var j = 0; j < frames.length; j++) subscribe(frames[j]);
    reportState();
  }

  function parseMessage(data) {
    if (typeof data === 'string') {
      try { return JSON.parse(data); } catch (_) { return null; }
    }
    return data && typeof data === 'object' ? data : null;
  }

  window.addEventListener('message', function(event) {
    if (!isPlayerOrigin(event.origin)) return;

    var frame = frameForWindow(event.source);
    if (!frame) return;

    var data = parseMessage(event.data);
    if (!data) return;

    var eventName = typeof data.event === 'string'
        ? data.event.toLowerCase()
        : '';
    var methodName = typeof data.method === 'string'
        ? data.method.toLowerCase()
        : '';

    if (eventName === 'ready' || eventName === 'initialdelivery' ||
        methodName === 'ping') {
      subscribe(frame, true, false);
    }

    if (eventName === 'play' || eventName === 'playing' ||
        eventName === 'playprogress' ||
        eventName === 'onstatechange') {
      // YouTube reports state as a number on `onStateChange`; 1 is playing.
      var youtubePlaying = typeof data.info === 'number' && data.info === 1;
      var youtubeStopped = typeof data.info === 'number' &&
          (data.info === 0 || data.info === 2 || data.info === 5);
      if (youtubeStopped) {
        frame.__westviewPlaying = false;
        // YouTube hides the play state inside the iframe, so poll it again
        // once playback stops to catch a restart.
        postYouTube(frame, 'listening');
      } else if (eventName !== 'onstatechange' || youtubePlaying) {
        frame.__westviewPlaying = true;
        activeFrame = frame;
      }
    } else if (eventName === 'pause' || eventName === 'ended' ||
               eventName === 'finish') {
      frame.__westviewPlaying = false;
    } else if (methodName === 'getpaused' && typeof data.value === 'boolean') {
      frame.__westviewPlaying = !data.value;
      if (!data.value) activeFrame = frame;
    }

    reportState();
  }, false);

  // ---------------------------------------------------------------- layout

  function visibleArea(element) {
    try {
      var rect = element.getBoundingClientRect();
      if (rect.width <= 0 || rect.height <= 0) return 0;
      return rect.width * rect.height;
    } catch (_) {
      return 0;
    }
  }

  function playingDocumentVideo() {
    var videos = document.querySelectorAll('video');
    var best = null;
    var bestArea = -1;
    for (var i = 0; i < videos.length; i++) {
      if (videos[i].paused || videos[i].ended) continue;
      var area = visibleArea(videos[i]);
      if (area > bestArea) {
        best = videos[i];
        bestArea = area;
      }
    }
    return best;
  }

  function selectPlayer() {
    var video = playingDocumentVideo();
    if (video) return video;

    if (activeFrame && document.documentElement.contains(activeFrame)) {
      return activeFrame;
    }

    var frames = playerFrames();
    var best = null;
    var bestArea = -1;
    for (var i = 0; i < frames.length; i++) {
      var area = visibleArea(frames[i]);
      if (area > bestArea) {
        best = frames[i];
        bestArea = area;
      }
    }
    return best;
  }

  function remember(element) {
    if (!element) return;
    for (var i = 0; i < savedStyles.length; i++) {
      if (savedStyles[i].element === element) return;
    }
    savedStyles.push({
      element: element,
      style: element.getAttribute('style')
    });
  }

  function important(element, property, value) {
    element.style.setProperty(property, value, 'important');
  }

  function enterVisual(attempt) {
    if (visualEntered) {
      reportEntered(true);
      return true;
    }

    var target = selectPlayer();
    if (!target) {
      // The iframe can be replaced during navigation. Retry briefly rather
      // than ever promoting the page chrome into PiP.
      if ((attempt || 0) < 20) {
        clearTimeout(retryTimer);
        retryTimer = setTimeout(function() {
          enterVisual((attempt || 0) + 1);
        }, 100);
      } else {
        // Nothing to show. Dart uses this to leave the app full screen
        // instead of shrinking a page into a PiP window.
        reportEntered(false);
      }
      return false;
    }

    clearTimeout(retryTimer);
    visualEntered = true;
    visualTarget = target;
    savedStyles = [];

    remember(document.documentElement);
    remember(document.body);
    important(document.documentElement, 'background', '#000');
    important(document.documentElement, 'overflow', 'hidden');
    important(document.body, 'background', '#000');
    important(document.body, 'overflow', 'hidden');
    important(document.body, 'margin', '0');
    important(document.body, 'padding', '0');

    // CSS transforms/containment on an ancestor can make a fixed child use
    // that ancestor as its containing block. Neutralize those properties so
    // the player is fixed to the WebView viewport instead.
    var ancestor = target.parentElement;
    while (ancestor && ancestor !== document.documentElement &&
           ancestor !== document.body) {
      remember(ancestor);
      important(ancestor, 'position', 'static');
      important(ancestor, 'z-index', 'auto');
      important(ancestor, 'transform', 'none');
      important(ancestor, 'filter', 'none');
      important(ancestor, 'perspective', 'none');
      important(ancestor, 'contain', 'none');
      important(ancestor, 'isolation', 'auto');
      important(ancestor, 'clip-path', 'none');
      important(ancestor, 'mask', 'none');
      important(ancestor, 'overflow', 'visible');
      important(ancestor, 'visibility', 'visible');
      important(ancestor, 'opacity', '1');
      ancestor = ancestor.parentElement;
    }

    remember(target);
    important(target, 'position', 'fixed');
    important(target, 'inset', '0');
    important(target, 'top', '0');
    important(target, 'left', '0');
    important(target, 'width', '100vw');
    important(target, 'height', '100vh');
    important(target, 'min-width', '100vw');
    important(target, 'min-height', '100vh');
    important(target, 'max-width', 'none');
    important(target, 'max-height', 'none');
    important(target, 'margin', '0');
    important(target, 'padding', '0');
    important(target, 'border', '0');
    important(target, 'transform', 'none');
    important(target, 'z-index', '2147483647');
    important(target, 'display', 'block');
    important(target, 'visibility', 'visible');
    important(target, 'opacity', '1');
    important(target, 'object-fit', 'contain');
    important(target, 'background', '#000');
    reportEntered(true);
    return true;
  }

  function exitVisual() {
    clearTimeout(retryTimer);
    retryTimer = null;

    for (var i = savedStyles.length - 1; i >= 0; i--) {
      var saved = savedStyles[i];
      if (!saved.element) continue;
      if (saved.style === null) {
        saved.element.removeAttribute('style');
      } else {
        saved.element.setAttribute('style', saved.style);
      }
    }

    savedStyles = [];
    visualTarget = null;
    visualEntered = false;
    scan();
  }

  window.__westviewVideoPip = {
    scan: scan,
    enter: function() { return enterVisual(0); },
    exit: exitVisual,
    isEntered: function() { return visualEntered; },
    target: function() { return visualTarget; }
  };

  try {
    var observer = new MutationObserver(function() { scan(); });
    observer.observe(document.documentElement || document.body, {
      childList: true,
      subtree: true
    });
  } catch (_) {}

  // Polling covers a player that swaps an iframe's internal document without
  // mutating the parent DOM, plus WebView versions that miss a media event.
  setInterval(scan, 1500);
  scan();
})();
''';
