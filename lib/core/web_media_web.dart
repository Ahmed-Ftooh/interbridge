import 'dart:html' as html;

html.MediaStream? _activeStream;

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

  if (_activeStream != null) {
    for (final track in _activeStream!.getTracks()) {
      track.stop();
    }
  }
  _activeStream = stream;

  if (keepAlive != null) {
    Future<void>.delayed(keepAlive, () {
      if (_activeStream == stream) {
        for (final track in stream.getTracks()) {
          track.stop();
        }
        _activeStream = null;
      }
    });
  }
}

void stopWebMediaTracks() {
  if (_activeStream != null) {
    for (final track in _activeStream!.getTracks()) {
      track.stop();
    }
    _activeStream = null;
  }
}
