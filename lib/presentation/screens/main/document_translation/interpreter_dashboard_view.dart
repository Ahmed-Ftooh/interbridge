import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/screens/main/document_translation/interpreter_accepted_documents_view.dart';
import 'package:interbridge/presentation/screens/main/document_translation/interpreter_document_view.dart';

class InterpreterDashboardView extends StatelessWidget {
  const InterpreterDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Interpreter Dashboard'),
          backgroundColor: ColorManager.primary2,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Available'),
              Tab(text: 'My Tasks'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            InterpreterDocumentView(),
            InterpreterAcceptedDocumentsView(),
          ],
        ),
      ),
    );
  }
}
