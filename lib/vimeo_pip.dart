import 'package:flutter/foundation.dart';

/// Whether Android is currently presenting the Vimeo player in picture-in-picture.
///
/// Android PiP captures the whole activity, not an individual Flutter widget. The
/// app shell listens to this value and removes all of its chrome while PiP is
/// active so the WebView can occupy the complete activity surface.
final ValueNotifier<bool> vimeoPipActive = ValueNotifier<bool>(false);

/// Returns whether [url] belongs to Vimeo.
///
/// PiP must never be enabled for arbitrary videos that might appear on one of the
/// other publication pages.
bool isVimeoUrl(String url) {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) return false;

  final String host = uri.host.toLowerCase();
  return host == 'vimeo.com' || host.endsWith('.vimeo.com');
}

/// Installs a small bridge in the Vimeo page.
///
/// A Vimeo watch page normally renders its player in a cross-origin
/// `player.vimeo.com` iframe. JavaScript in the parent page cannot access that
/// iframe's `<video>` element, so the bridge uses Vimeo's documented postMessage
/// player API to observe playback. When Android enters activity PiP, [enter]
/// expands either the playing video or its player iframe over the entire WebView.
/// The original inline styles are restored by [exit] when PiP closes.
const String vimeoPipScript = r'''
(function() {
  'use strict';

  if (window.__westviewVimeoPip) {
    window.__westviewVimeoPip.scan();
    return;
  }

  var lastReportedState = null;
  var activeFrame = null;
  var visualTarget = null;
  var savedStyles = [];
  var visualEntered = false;
  var retryTimer = null;

  function isVimeoOrigin(origin) {
    try {
      var host = new URL(origin).hostname.toLowerCase();
      return host === 'vimeo.com' || host.slice(-10) === '.vimeo.com';
    } catch (_) {
      return false;
    }
  }

  function isVimeoFrame(frame) {
    if (!frame || frame.tagName !== 'IFRAME') return false;
    var src = (frame.getAttribute('src') || '').toLowerCase();
    var title = (frame.getAttribute('title') || '').toLowerCase();
    return src.indexOf('vimeo.com') !== -1 || title.indexOf('vimeo') !== -1;
  }

  function vimeoFrames() {
    var all = document.querySelectorAll('iframe');
    var result = [];
    for (var i = 0; i < all.length; i++) {
      if (isVimeoFrame(all[i]) || all[i].__westviewVimeoFrame) {
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
          // The message origin was already validated as Vimeo, so remember
          // players whose lazy iframe has no src/title hint yet.
          frames[i].__westviewVimeoFrame = true;
          return frames[i];
        }
      } catch (_) {}
    }
    return null;
  }

  function post(frame, method, value) {
    try {
      var message = {method: method};
      if (value !== undefined) message.value = value;
      frame.contentWindow.postMessage(message, '*');
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

    if (!frame.__westviewSubscribed || force) {
      frame.__westviewSubscribed = true;
      post(frame, 'addEventListener', 'play');
      post(frame, 'addEventListener', 'playing');
      post(frame, 'addEventListener', 'pause');
      post(frame, 'addEventListener', 'ended');
      post(frame, 'addEventListener', 'finish');
      post(frame, 'addEventListener', 'playProgress');
      if (sendPing !== false) post(frame, 'ping');
    }

    // Poll the documented state getter as a fallback for a player that was
    // already running before the event subscriptions were installed.
    post(frame, 'getPaused');
  }

  function documentVideoPlaying() {
    var videos = document.querySelectorAll('video');
    for (var i = 0; i < videos.length; i++) {
      if (!videos[i].paused && !videos[i].ended && videos[i].readyState > 0) {
        return true;
      }
    }
    return false;
  }

  function iframeVideoPlaying() {
    var frames = vimeoFrames();
    for (var i = 0; i < frames.length; i++) {
      if (frames[i].__westviewPlaying === true) return true;
    }
    return false;
  }

  function reportState() {
    var playing = documentVideoPlaying() || iframeVideoPlaying();
    if (playing === lastReportedState) return;
    lastReportedState = playing;
    try {
      PiPChannel.postMessage(playing ? 'playing' : 'paused');
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

    var frames = vimeoFrames();
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
    if (!isVimeoOrigin(event.origin)) return;

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

    if (eventName === 'ready' || methodName === 'ping') {
      subscribe(frame, true, false);
    }

    if (eventName === 'play' || eventName === 'playing' ||
        eventName === 'playprogress') {
      frame.__westviewPlaying = true;
      activeFrame = frame;
    } else if (eventName === 'pause' || eventName === 'ended' ||
               eventName === 'finish') {
      frame.__westviewPlaying = false;
    } else if (methodName === 'getpaused' && typeof data.value === 'boolean') {
      frame.__westviewPlaying = !data.value;
      if (!data.value) activeFrame = frame;
    }

    reportState();
  }, false);

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

    var frames = vimeoFrames();
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
    if (visualEntered) return true;

    var target = selectPlayer();
    if (!target) {
      // The iframe can be replaced during navigation. Retry briefly rather
      // than ever promoting the comments/watch-page UI into PiP.
      if ((attempt || 0) < 20) {
        clearTimeout(retryTimer);
        retryTimer = setTimeout(function() {
          enterVisual((attempt || 0) + 1);
        }, 100);
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

  window.__westviewVimeoPip = {
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

  // Polling covers Vimeo replacing an iframe's internal document without
  // mutating the parent DOM and WebView versions that miss a media event.
  setInterval(scan, 1500);
  scan();
})();
''';
