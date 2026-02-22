/// Fetch bytes from a blob URL.
///
/// This file is the default (mobile/non-web) stub. It always returns null
/// because blob URLs only exist in a browser context.
import 'dart:typed_data';

Future<Uint8List?> fetchBlobBytes(String url) async {
  // blob: URLs don't exist outside a web browser — nothing to fetch.
  return null;
}
