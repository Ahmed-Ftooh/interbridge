import 'dart:html' as html;

Future<void> requestWebMediaPermissions({
  required bool video,
  Duration? keepAlive,
}) async {
  final media = html.window.navigator.mediaDevices;
  if (media == null) {
    throw Exception('MediaDevices API not available');
  }

  final constraints = <String, dynamic>{'audio': true, 'video': video};

  final stream = await media.getUserMedia(constraints);
  if (keepAlive == null) {
    // Stop tracks immediately; this is only for permission prompt.
    for (final track in stream.getTracks()) {
      track.stop();
    }
    return;
  }

  // Keep the stream alive briefly to avoid the camera turning off
  // right after permission is granted. This also prevents a race
  // where Agora requests the camera while the stream is stopping.
  Future<void>.delayed(keepAlive, () {
    for (final track in stream.getTracks()) {
      track.stop();
    }
  });
}
