import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/data/services/call_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';

class CallFeedbackDialog extends StatefulWidget {
  final String requestId;

  const CallFeedbackDialog({super.key, required this.requestId});

  @override
  State<CallFeedbackDialog> createState() => _CallFeedbackDialogState();
}

class _CallFeedbackDialogState extends State<CallFeedbackDialog> {
  double _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

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
      await instance<CallService>().submitCallFeedback(
        channelId: widget.requestId,
        rating: _rating.toInt(),
        comments:
            _commentController.text.trim().isEmpty
                ? null
                : _commentController.text.trim(),
        callExperience: '',
        connectionQuality: '',
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback submitted. Thank you!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting feedback: $e'),
            backgroundColor: Colors.red,
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
          children: [
            const Text('Please rate your experience with the interpreter.'),
            const SizedBox(height: 20),
            RatingBar.builder(
              initialRating: 0,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: false,
              itemCount: 5,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder:
                  (context, _) => Icon(Icons.star, color: Colors.amber[600]),
              onRatingUpdate: (rating) {
                setState(() {
                  _rating = rating;
                });
              },
            ),
            const SizedBox(height: 24),
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
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
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
