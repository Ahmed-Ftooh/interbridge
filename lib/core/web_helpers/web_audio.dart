/// Web audio helper — default (mobile) stub.
///
/// On non-web platforms these are no-ops.

/// Opaque handle for a web audio element. Null on non-web.
class WebAudioHandle {
  const WebAudioHandle._();
}

/// Create an audio element that plays [assetPath] in a loop.
/// Returns null on non-web platforms.
WebAudioHandle? createLoopingAudio(String assetPath) => null;

/// Stop and dispose of a previously created audio element.
void stopAudio(WebAudioHandle? handle) {}
