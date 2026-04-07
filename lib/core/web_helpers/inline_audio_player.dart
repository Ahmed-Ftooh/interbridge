library;

class InlineAudioHandle {
  const InlineAudioHandle._();
}

InlineAudioHandle? createInlineAudio({
  required String assetPath,
  required void Function() onEnded,
}) {
  return null;
}

Future<void> playInlineAudio(InlineAudioHandle? handle) async {}

Future<void> pauseInlineAudio(InlineAudioHandle? handle) async {}

Future<void> stopInlineAudio(InlineAudioHandle? handle) async {}

void disposeInlineAudio(InlineAudioHandle? handle) {}
