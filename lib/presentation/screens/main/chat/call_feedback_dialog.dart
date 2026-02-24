import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/data/services/call_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
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

  static const _qualityOptions = ['excellent', 'good', 'fair', 'poor'];
  static const _experienceOptions = [
    'very_satisfied',
    'satisfied',
    'neutral',
    'dissatisfied',
  ];

  String _labelFor(String value) {
    return value.replaceAll('_', ' ').replaceFirst(
      value[0],
      value[0].toUpperCase(),
    );
  }

  Future<void> _submitFeedback() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating before submitting.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final ratingInt = _rating.toInt();
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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('How was your call?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please rate your experience.'),
            const SizedBox(height: 16),
            Center(
              child: RatingBar.builder(
                initialRating: 0,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                itemCount: 5,
                itemSize: 32.0,
                itemPadding: const EdgeInsets.symmetric(horizontal: 2.0),
                itemBuilder:
                    (context, _) => Icon(Icons.star, color: Colors.amber[600]),
                onRatingUpdate: (rating) {
                  setState(() {
                    _rating = rating;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
            // Connection Quality
            const Text(
              'Connection Quality',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _connectionQuality,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: _qualityOptions
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
            const SizedBox(height: 16),
            // Call Experience
            const Text(
              'Overall Experience',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _callExperience,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: _experienceOptions
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
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Any comments? (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isSubmitting
                  ? null
                  : () {
                    Navigator.of(context).pop();
                    widget.onComplete?.call();
                  },
          child: const Text('Skip'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorManager.primary2,
            foregroundColor: Colors.white,
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
      ],
    );
  }
}
