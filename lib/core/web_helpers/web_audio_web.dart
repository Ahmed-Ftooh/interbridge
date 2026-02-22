/// Web audio helper — web implementation using dart:html.
import 'dart:html' as html;

/// Opaque handle wrapping an [html.AudioElement].
class WebAudioHandle {
  final html.AudioElement _element;
  const WebAudioHandle._(this._element);
}

/// Create an [html.AudioElement] that plays [assetPath] in a loop.
WebAudioHandle? createLoopingAudio(String assetPath) {
  try {
    final el = html.AudioElement(assetPath);
    el.loop = true;
    el.play();
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
    handle._element.remove();
  } catch (_) {}
}
