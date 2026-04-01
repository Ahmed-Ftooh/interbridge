import 'package:flutter/material.dart';
import 'package:interbridge/presentation/screens/main/document_translation/interpreter_accepted_documents_view.dart';
import 'package:interbridge/presentation/screens/main/document_translation/interpreter_completed_documents_view.dart';
import 'package:interbridge/presentation/screens/main/document_translation/interpreter_document_view.dart';

class InterpreterDashboardWeb extends StatefulWidget {
  const InterpreterDashboardWeb({super.key});

  @override
  State<InterpreterDashboardWeb> createState() =>
      _InterpreterDashboardWebState();
}

class _InterpreterDashboardWebState extends State<InterpreterDashboardWeb>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab Header
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF0955FA),
            unselectedLabelColor: const Color(0xFF64748B),
            labelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            indicatorColor: const Color(0xFF0955FA),
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.list_alt_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Available'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.work_outline_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('My Tasks'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Completed'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Tab Content
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(), // better for web
                children: const [
                  InterpreterDocumentView(),
                  InterpreterAcceptedDocumentsView(),
                  InterpreterCompletedDocumentsView(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
