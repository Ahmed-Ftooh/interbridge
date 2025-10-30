import 'package:flutter/material.dart';
import 'package:interbridge/core/language_mapping_utility.dart';

String getTranslationMethodLabel(String? method) {
  switch (method?.toLowerCase()) {
    case 'text':
      return 'Text';
    case 'pdf':
      return 'PDF';
    case 'document':
      return 'Document';
    case 'image':
      return 'Image';
    case 'voice':
      return 'Voice';
    default:
      return 'File';
  }
}

String formatDt(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);
  if (difference.inSeconds < 60) {
    return 'Just now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  } else {
    return '${date.day}/${date.month}/${date.year}';
  }
}

Color getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return Colors.green.shade700;
    case 'accepted':
      return Colors.blue.shade700;
    case 'pending':
      return Colors.orange.shade800;
    case 'cancelled':
      return Colors.red.shade700;
    default:
      return Colors.grey.shade600;
  }
}

IconData getStatusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return Icons.check_circle_outline_rounded;
    case 'accepted':
      return Icons.hourglass_bottom_rounded;
    case 'pending':
      return Icons.schedule_rounded;
    case 'cancelled':
      return Icons.cancel_outlined;
    default:
      return Icons.help_outline_rounded;
  }
}

String getLanguageDisplayText(String fromLanguage, String toLanguage) {
  final fromLanguageId = int.tryParse(fromLanguage) ?? 0;
  final toLanguageId = int.tryParse(toLanguage) ?? 0;
  final fromLanguageName = LanguageMappingUtility.getLanguageName(
    fromLanguageId,
  );
  final toLanguageName = LanguageMappingUtility.getLanguageName(toLanguageId);
  if (fromLanguageName.isNotEmpty && toLanguageName.isNotEmpty) {
    return '$fromLanguageName → $toLanguageName';
  } else {
    return '$fromLanguage → $toLanguage';
  }
}
