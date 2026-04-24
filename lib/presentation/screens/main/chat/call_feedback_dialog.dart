import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/data/services/call_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'dart:math' hide log;
import 'dart:developer';

class CallFeedbackDialog extends StatefulWidget {
  final String requestId;
  final VoidCallback? onComplete;

  const CallFeedbackDialog({
    super.key,
    required this.requestId,
    this.onComplete,
  });

  @override
  State<CallFeedbackDialog> createState() => _CallFeedbackDialogState();
}

class _CallFeedbackDialogState extends State<CallFeedbackDialog> {
  double _rating = 0;
  String _connectionQuality = 'good';
  String _callExperience = 'satisfied';
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoadingRole = true;
  String? _userRole;
  String _selectedPrompt = '';

  static const _interpreterMotivationPhrases = [
    'Take a breath - you handled that well.',
    'Another voice heard. Another message delivered.',
    'You made a difference in that conversation.',
    'Clear communication starts with you. Great job.',
    'You made communication possible. Well done.',
  ];

  static const _doctorFeedbackPhrases = [
    'Thank you for using InterBridge. How was your experience?',
    'We appreciate your time. Please rate your experience.',
    'Your feedback helps us maintain quality. How did we do?',
    'Thank you for your time. We would appreciate your feedback.',
    'We hope your experience felt smooth and supported. Could you share how it went?',
    'Every interaction matters to us. How did we do today?',
    'We would love to know if we made your experience easier and clearer.',
  ];

  static const _qualityOptions = ['excellent', 'good', 'fair', 'poor'];
  static const _experienceOptions = [
    'very_satisfied',
    'satisfied',
    'neutral',
    'dissatisfied',
  ];

  String _pickRandomPrompt() {
    final source =
        _isInterpreter ? _interpreterMotivationPhrases : _doctorFeedbackPhrases;
    return source[Random().nextInt(source.length)];
  }

  String get _activePrompt {
    if (_selectedPrompt.isNotEmpty) return _selectedPrompt;
    return _isInterpreter
        ? _interpreterMotivationPhrases.first
        : _doctorFeedbackPhrases.first;
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Very poor';
      case 2:
        return 'Needs improvement';
      case 3:
        return 'Okay';
      case 4:
        return 'Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final profile =
            await supabase
                .from('users_profile')
                .select('role')
                .eq('user_id', userId)
                .maybeSingle();
        if (profile != null) {
          _userRole = profile['role'] as String?;
        }
      }
    } catch (e) {
      log('Error checking user role for feedback dialog: $e');
    }
    if (mounted) {
      setState(() {
        _selectedPrompt = _pickRandomPrompt();
        _isLoadingRole = false;
      });
    }
  }

  String _labelFor(String value) {
    return value
        .replaceAll('_', ' ')
        .replaceFirst(value[0], value[0].toUpperCase());
  }

  bool get _isInterpreter => _userRole == 'interpreter';

  bool get _isLowRatingIssueFlow =>
      !_isInterpreter && _rating > 0 && _rating <= 2;

  Future<void> _submitFeedback() async {
    if (!_isInterpreter && _rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating before submitting.'),
        ),
      );
      return;
    }

    if (_isLowRatingIssueFlow && _commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe the issue so we can review it.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Full scoring fields are only shown for non-interpreter roles.
      final ratingInt = _isInterpreter ? 5 : _rating.toInt();
      final commentsText = _commentController.text.trim();

      log('Submitting feedback:');
      log('  RequestId: ${widget.requestId}');
      log('  Rating: $ratingInt');
      log('  Connection: $_connectionQuality');
      log('  Experience: $_callExperience');
      log('  Comments: ${commentsText.isEmpty ? "none" : commentsText}');

      await instance<CallService>().submitCallFeedback(
        channelId: widget.requestId,
        rating: ratingInt,
        comments: commentsText.isEmpty ? null : commentsText,
        callExperience: _callExperience,
        connectionQuality: _connectionQuality,
      );

      log('Feedback submitted successfully');

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        widget.onComplete?.call(); // Notify completion
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback submitted. Thank you!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      log('Error submitting feedback: $e');
      log('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting feedback: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final bannerStart =
        _isInterpreter ? const Color(0xFF0F766E) : const Color(0xFF1D4ED8);
    final bannerEnd =
        _isInterpreter ? const Color(0xFF14B8A6) : const Color(0xFF3B82F6);
    final bannerIcon =
        _isInterpreter
            ? Icons.emoji_emotions_outlined
            : Icons.health_and_safety_outlined;
    final commentsTitle =
        _isLowRatingIssueFlow
            ? 'Would you like to report a problem or an issue?'
            : 'Optional comments';
    final commentsHint =
        _isLowRatingIssueFlow
            ? 'Please describe the problem you faced during this call.'
            : 'Any comments? (Optional)';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [bannerStart, bannerEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(bannerIcon, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isInterpreter
                                  ? 'Session Follow-up'
                                  : 'Thank You for Using InterBridge',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _activePrompt,
                              style: const TextStyle(
                                color: Colors.white,
                                height: 1.4,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                if (!_isInterpreter) ...[
                  const Text(
                    'Please rate your experience',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: RatingBar.builder(
                      initialRating: 0,
                      minRating: 1,
                      direction: Axis.horizontal,
                      allowHalfRating: false,
                      itemCount: 5,
                      itemSize: 34,
                      itemPadding: const EdgeInsets.symmetric(horizontal: 2),
                      itemBuilder:
                          (context, _) => Icon(
                            Icons.star_rounded,
                            color: Colors.amber[600],
                          ),
                      onRatingUpdate: (rating) {
                        setState(() {
                          _rating = rating;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      _rating == 0
                          ? 'Tap to select a rating'
                          : _ratingLabel(_rating.toInt()),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Connection quality',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _connectionQuality,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items:
                        _qualityOptions
                            .map(
                              (q) => DropdownMenuItem(
                                value: q,
                                child: Text(_labelFor(q)),
                              ),
                            )
                            .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _connectionQuality = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Overall experience',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _callExperience,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items:
                        _experienceOptions
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(_labelFor(e)),
                              ),
                            )
                            .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _callExperience = v);
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                Text(
                  commentsTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                if (_isLowRatingIssueFlow) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.report_problem_outlined,
                          size: 16,
                          color: Color(0xFFB45309),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your report helps us investigate low-rated sessions quickly.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF92400E),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: commentsHint,
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isSubmitting
                                ? null
                                : () {
                                  Navigator.of(context).pop();
                                  widget.onComplete?.call();
                                },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Skip'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorManager.primary2,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _isSubmitting ? null : _submitFeedback,
                        child:
                            _isSubmitting
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text('Submit'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
