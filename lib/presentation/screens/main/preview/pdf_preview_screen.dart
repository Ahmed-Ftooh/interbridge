// lib/previews/pdf_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';

class PdfPreviewScreen extends StatelessWidget {
  final String url;
  final String? fileName;

  const PdfPreviewScreen({super.key, required this.url, this.fileName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName ?? 'PDF Preview'),
        backgroundColor: ColorManager.primary2,
        foregroundColor: Colors.white,
      ),
      body: SfPdfViewer.network(
        url,
        canShowPageLoadingIndicator: true,
        canShowScrollHead: true,
      ),
    );
  }
}
