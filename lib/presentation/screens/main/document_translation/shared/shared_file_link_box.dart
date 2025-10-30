import 'package:flutter/material.dart';
import 'package:interbridge/core/file_utility.dart';
import 'helpers.dart';

class SharedFileLinkBox extends StatelessWidget {
  final BuildContext context;
  final String fileUrl;
  final String? fileName;
  final String? method;
  final bool isOriginal;
  final void Function()? onView;

  const SharedFileLinkBox({
    super.key,
    required this.context,
    required this.fileUrl,
    this.fileName,
    this.method,
    required this.isOriginal,
    this.onView,
  });

  @override
  Widget build(BuildContext contextFromBuilder) {
    final fileIcon = FileUtility.getFileTypeIcon(method, fileName: fileName);
    final fileColor = isOriginal ? Colors.blue.shade700 : Colors.green.shade700;
    final defaultLabel =
        isOriginal ? getTranslationMethodLabel(method) : 'Translated File';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: fileColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fileColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.mode(fileColor, BlendMode.srcIn),
            child: fileIcon,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fileName ?? defaultLabel,
              style: TextStyle(fontWeight: FontWeight.w500, color: fileColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
              foregroundColor: fileColor,
            ),
            onPressed:
                onView ??
                () {
                  FileUtility.openFilePreview(
                    context,
                    fileUrl,
                    method,
                    fileName,
                    null,
                  );
                },
            child: Text(isOriginal ? 'View' : 'Open'),
          ),
        ],
      ),
    );
  }
}
