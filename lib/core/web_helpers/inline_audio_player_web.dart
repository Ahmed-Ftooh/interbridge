// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

library;

import 'dart:html' as html;

class InlineAudioHandle {
  final html.AudioElement _element;

  const InlineAudioHandle._(this._element);
}

InlineAudioHandle? createInlineAudio({
  required String assetPath,
  required void Function() onEnded,
}) {
  try {
    final String baseHref =
        html.document.querySelector('base')?.getAttribute('href') ?? '/';
    final String resolvedBase =
        baseHref.endsWith('/') ? baseHref : '$baseHref/';

    final String normalizedAsset =
        assetPath.startsWith('assets/') ? assetPath : 'assets/$assetPath';
    final String webPath = '${resolvedBase}assets/$normalizedAsset';

    final element =
        html.AudioElement(webPath)
          ..autoplay = false
          ..loop = false
          ..preload = 'auto';

    element.onEnded.listen((_) => onEnded());

    return InlineAudioHandle._(element);
  } catch (_) {
    return null;
  }
}

Future<void> playInlineAudio(InlineAudioHandle? handle) async {
  if (handle == null) return;
  await handle._element.play();
}

Future<void> pauseInlineAudio(InlineAudioHandle? handle) async {
  if (handle == null) return;
  handle._element.pause();
}

Future<void> stopInlineAudio(InlineAudioHandle? handle) async {
  if (handle == null) return;
  handle._element.pause();
  handle._element.currentTime = 0;
}

void disposeInlineAudio(InlineAudioHandle? handle) {
  if (handle == null) return;
  try {
    handle._element.pause();
    handle._element.src = '';
    handle._element.remove();
  } catch (_) {}
}
