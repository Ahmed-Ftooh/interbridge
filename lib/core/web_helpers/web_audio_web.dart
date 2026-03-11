/// Web audio helper — web implementation using dart:html.
library;

import 'dart:html' as html;

/// Opaque handle wrapping an [html.AudioElement].
class WebAudioHandle {
  final html.AudioElement _element;
  const WebAudioHandle._(this._element);
}

/// Create an [html.AudioElement] that plays [assetPath] in a loop.
///
/// Flutter web stores assets under assets/[original-path] in the build output,
/// so a pubspec asset path like "assets/audio/foo.mp3" is served at the URL
/// "assets/assets/audio/foo.mp3". Adjust the path here before passing to the
/// DOM so the browser can fetch it.
///
/// Also handles browser autoplay policy: modern browsers block audio that isn't
/// triggered by a user gesture. We attempt play() and, if it is blocked, we
/// retry automatically on the next user interaction (click/touchstart).
WebAudioHandle? createLoopingAudio(String assetPath) {
  try {
    // Rewrite Flutter asset path → web-served URL:
    //   "assets/audio/Call_Ring.mp3"  →  "assets/assets/audio/Call_Ring.mp3"
    final webPath =
        assetPath.startsWith('assets/') ? 'assets/$assetPath' : assetPath;

    final el = html.AudioElement(webPath);
    el.loop = true;

    // Attempt to play; catch autoplay-policy rejection and retry on interaction.
    el.play().catchError((_) {
      void retryOnInteraction(html.Event _) {
        el.play().catchError((_) {});
      }

      html.document.addEventListener('click', retryOnInteraction, false);
      html.document.addEventListener('touchstart', retryOnInteraction, false);
    });

    return WebAudioHandle._(el);
  } catch (_) {
    return null;
  }
}

/// Stop and dispose of a previously created audio element.
void stopAudio(WebAudioHandle? handle) {
  if (handle == null) return;
  try {
    handle._element.pause();
    handle._element.src = '';
    handle._element.remove();
  } catch (_) {}
}
