// lib/core/file_utility.dart
import 'package:flutter/material.dart';
import 'package:interbridge/presentation/screens/main/preview/pdf_preview_screen.dart';
import 'package:interbridge/presentation/widgets/audio_player_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- ADDED: Imports for our new preview widgets ---

// ----------------------------------------------------

class FileUtility {
  static Future<void> openFilePreview(
    BuildContext context,
    String fileUrl,
    String? translationMethod,
    String? fileName, // --- CHANGED: Added fileName
    String? fileType, // --- ADDED: Use actual file type
  ) async {
    if (!context.mounted) return;

    try {
      // 1. Resolve URL (This logic is correct)
      final resolvedUrl = await _ensureViewableUrl(fileUrl);
      final lower = (translationMethod ?? '').toLowerCase();
      final fileTypeLower = (fileType ?? '').toLowerCase();
      final uri = Uri.parse(resolvedUrl);

      // --- NEW LOGIC: Check for specific types ---

      // Helper to check file extension from URL or filename
      final urlLower = resolvedUrl.toLowerCase();
      final fileNameLower = (fileName ?? '').toLowerCase();
      final bool isAudioExt =
          urlLower.endsWith('.mp3') ||
          urlLower.endsWith('.wav') ||
          urlLower.endsWith('.m4a') ||
          urlLower.endsWith('.aac') ||
          fileNameLower.endsWith('.mp3') ||
          fileNameLower.endsWith('.wav') ||
          fileNameLower.endsWith('.m4a') ||
          fileNameLower.endsWith('.aac');
      final bool isPdfExt =
          urlLower.endsWith('.pdf') || fileNameLower.endsWith('.pdf');

      // 1) Handle Audio/Voice FIRST to avoid misclassifying as document/PDF
      final isAudio =
          lower == 'voice' ||
          fileTypeLower == 'voice' ||
          isAudioExt ||
          fileTypeLower == 'mp3' ||
          fileTypeLower == 'wav' ||
          fileTypeLower == 'm4a' ||
          fileTypeLower == 'aac' ||
          fileTypeLower == 'ogg' ||
          (lower == 'document' && isAudioExt);
      if (isAudio) {
        // Return the widget directly for inline display
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (ctx) => Scaffold(
                  appBar: AppBar(title: Text(fileName ?? 'Audio Preview')),
                  body: Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: AudioPlayerWidget(
                          url: resolvedUrl,
                          fileName: fileName,
                          isInline: true,
                        ),
                      ),
                    ),
                  ),
                ),
          ),
        );
        return;
      }

      // 2) Handle 'document' type - infer from file extension
      // Backend stores both 'pdf' and 'voice' as 'document', so we need to check extension
      if (lower == 'document') {
        // Check if it's an audio file by extension (this is a fallback check)
        if (isAudioExt ||
            fileTypeLower.contains('audio') ||
            fileTypeLower.contains('mp3') ||
            fileTypeLower.contains('wav') ||
            fileTypeLower.contains('m4a')) {
          // Return the widget directly for inline display
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (ctx) => Scaffold(
                    appBar: AppBar(title: Text(fileName ?? 'Audio Preview')),
                    body: Center(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: AudioPlayerWidget(
                            url: resolvedUrl,
                            fileName: fileName,
                            isInline: true,
                          ),
                        ),
                      ),
                    ),
                  ),
            ),
          );
          return;
        }

        // Otherwise assume it's a PDF
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (ctx) => PdfPreviewScreen(url: resolvedUrl, fileName: fileName),
          ),
        );
        return;
      }

      // 3) Handle PDF by explicit type or extension
      final isPdf = lower == 'pdf' || fileTypeLower == 'pdf' || isPdfExt;
      if (isPdf) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (ctx) => PdfPreviewScreen(url: resolvedUrl, fileName: fileName),
          ),
        );
        return;
      }

      // 4. Handle Images (Original logic is good)
      final isImage =
          lower == 'image' ||
          resolvedUrl.toLowerCase().endsWith('.png') ||
          resolvedUrl.toLowerCase().endsWith('.jpg') ||
          resolvedUrl.toLowerCase().endsWith('.jpeg') ||
          resolvedUrl.toLowerCase().endsWith('.webp') ||
          resolvedUrl.toLowerCase().endsWith('.heic');

      if (isImage) {
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder:
              (ctx) => Dialog(
                backgroundColor: Colors.black,
                insetPadding: const EdgeInsets.all(8),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: Image.network(
                    resolvedUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                    errorBuilder:
                        (context, error, stackTrace) => const Center(
                          child: Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                  ),
                ),
              ),
        );
        return;
      }

      // 5. Fallback for other file types
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open file type: $lower. URL: $resolvedUrl',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Attempt to create a signed URL for Supabase Storage objects when needed.
  /// If parsing or signing fails, returns the original URL.
  static Future<String> _ensureViewableUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      // Only handle Supabase Storage URLs
      if (!uri.path.contains('/storage/v1/object/')) return url;

      // Expected formats:
      // - /storage/v1/object/public/<bucket>/<path>
      // - /storage/v1/object/sign/<bucket>/<path>?token=...
      // - /storage/v1/object/<bucket>/<path>
      final segments = uri.pathSegments;
      final objectIndex = segments.indexOf('object');
      if (objectIndex == -1 || objectIndex + 2 >= segments.length) return url;
      String bucket;
      List<String> pathParts;
      final visibilityOrBucket = segments[objectIndex + 1];
      if (visibilityOrBucket == 'public' || visibilityOrBucket == 'sign') {
        // object/public/<bucket>/<path> OR object/sign/<bucket>/<path>
        if (objectIndex + 3 >= segments.length) return url;
        bucket = segments[objectIndex + 2];
        pathParts = segments.sublist(objectIndex + 3);
      } else {
        // object/<bucket>/<path>
        bucket = visibilityOrBucket;
        pathParts = segments.sublist(objectIndex + 2);
      }
      if (bucket.isEmpty || pathParts.isEmpty) return url;
      final objectPath = pathParts.join('/');

      // Generate a short-lived signed URL (60 minutes)
      final client = Supabase.instance.client;
      final res = await client.storage
          .from(bucket)
          .createSignedUrl(objectPath, const Duration(minutes: 60).inSeconds);
      return res;
    } catch (_) {
      return url; // Fallback to original
    }
  }

  static Widget getFileTypeIcon(String? translationMethod, {String? fileName}) {
    IconData iconData;
    switch (translationMethod?.toLowerCase()) {
      case 'pdf':
        iconData = Icons.picture_as_pdf;
        break;
      case 'document':
        // Check if it's an audio file by extension
        if (fileName != null) {
          final fileNameLower = fileName.toLowerCase();
          if (fileNameLower.endsWith('.mp3') ||
              fileNameLower.endsWith('.wav') ||
              fileNameLower.endsWith('.m4a') ||
              fileNameLower.endsWith('.aac')) {
            iconData = Icons.mic;
            break;
          }
        }
        iconData = Icons.description;
        break;
      case 'image':
        iconData = Icons.image;
        break;
      case 'voice':
        iconData = Icons.mic;
        break;
      default:
        iconData = Icons.insert_drive_file;
    }
    return Icon(iconData, color: Colors.blue);
  }

  static String getFileTypeLabel(
    String? translationMethod, {
    String? fileName,
  }) {
    switch (translationMethod?.toLowerCase()) {
      case 'pdf':
        return 'PDF Document';
      case 'document':
        // Check if it's an audio file by extension
        if (fileName != null) {
          final fileNameLower = fileName.toLowerCase();
          if (fileNameLower.endsWith('.mp3') ||
              fileNameLower.endsWith('.wav') ||
              fileNameLower.endsWith('.m4a') ||
              fileNameLower.endsWith('.aac')) {
            return 'Voice Recording';
          }
        }
        return 'PDF Document';
      case 'image':
        return 'Image File';
      case 'voice':
        return 'Voice Recording';
      default:
        return 'File';
    }
  }
}
