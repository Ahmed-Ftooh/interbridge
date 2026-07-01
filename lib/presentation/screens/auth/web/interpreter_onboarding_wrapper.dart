import 'package:flutter/material.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_palette.dart';

class InterpreterOnboardingWrapper extends StatelessWidget {
  final Widget child;
  final int currentStepIndex; // 0 to 4
  final String stepTitle;
  final String stepSubtitle;

  const InterpreterOnboardingWrapper({
    super.key,
    required this.child,
    required this.currentStepIndex,
    required this.stepTitle,
    required this.stepSubtitle,
  });

 static const List<String> _steps = [
    'Select Languages',
    'Language Fluency',
    'Specializations',
    'Voice Sample',
    'Phone Verification',
    'Government ID',
    'Certificates & Credentials'
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Light slate right background
      body: Row(
        children: [
          // LEFT PANEL: Branded Sidebar (Hidden on mobile)
          if (!isMobile)
            Container(
              width: 400,
              color: AuthWebPalette.primary, // Interbridge Deep Blue
              child: Center(
                child: _buildGettingStartedCard(),
              ),
            ),

          // RIGHT PANEL: Dynamic Step Content
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Step Headers
                      Text(
                        stepTitle,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AuthWebPalette.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        stepSubtitle,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AuthWebPalette.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // The actual form/screen content goes here
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // The floating white card inside the blue sidebar
  Widget _buildGettingStartedCard() {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Getting Started Guide',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AuthWebPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          
          // Segmented Progress Bar
          Row(
            children: List.generate(_steps.length, (index) {
              final isCompletedOrActive = index <= currentStepIndex;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index < _steps.length - 1 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: isCompletedOrActive 
                        ? AuthWebPalette.primary 
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Text(
            'Step ${currentStepIndex + 1} of ${_steps.length}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AuthWebPalette.primary,
            ),
          ),
          const SizedBox(height: 32),
          
          // Vertical Step List
          ...List.generate(_steps.length, (index) {
            final isActive = index == currentStepIndex;
            final isCompleted = index < currentStepIndex;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                children: [
                  // Step Number Indicator
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive 
                          ? AuthWebPalette.primary.withValues(alpha: 0.1) 
                          : isCompleted
                              ? AuthWebPalette.primary
                              : Colors.transparent,
                      border: Border.all(
                        color: isActive || isCompleted
                            ? AuthWebPalette.primary
                            : const Color(0xFFCBD5E1),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isActive 
                                    ? AuthWebPalette.primary 
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Step Name
                  Expanded(
                    child: Text(
                      _steps[index],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive || isCompleted 
                            ? AuthWebPalette.textPrimary 
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}