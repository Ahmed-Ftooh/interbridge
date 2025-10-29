import 'package:flutter/material.dart';
import 'package:interbridge/data/services/call_service.dart';

class CallFeedbackForm extends StatefulWidget {
  final String channelId;
  final Duration callDuration;
  final VoidCallback onFeedbackSubmitted;

  const CallFeedbackForm({
    super.key,
    required this.channelId,
    required this.callDuration,
    required this.onFeedbackSubmitted,
  });

  @override
  State<CallFeedbackForm> createState() => _CallFeedbackFormState();
}

class _CallFeedbackFormState extends State<CallFeedbackForm> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();

  int _rating = 5; // Default to 5 stars
  String _connectionQuality = 'excellent';
  String _callExperience = 'satisfied';
  bool _isSubmitting = false;

  final List<String> _connectionOptions = [
    'excellent',
    'good',
    'poor',
    'failed',
  ];

  final List<String> _experienceOptions = [
    'very_satisfied',
    'satisfied',
    'neutral',
    'dissatisfied',
    'very_dissatisfied',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.feedback, color: Colors.blue, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Call Feedback',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Duration: ${_formatDuration(widget.callDuration)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Star Rating
                      _buildStarRating(),

                      const SizedBox(height: 20),

                      // Connection Quality
                      _buildConnectionQuality(),

                      const SizedBox(height: 20),

                      // Call Experience
                      _buildCallExperience(),

                      const SizedBox(height: 20),

                      // Comments
                      _buildCommentsField(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons - Fixed at bottom
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStarRating() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overall Rating',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            return GestureDetector(
              onTap: () => setState(() => _rating = index + 1),
              child: Icon(
                index < _rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 32,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildConnectionQuality() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Connection Quality',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children:
              _connectionOptions.map((option) {
                final isSelected = _connectionQuality == option;
                return FilterChip(
                  label: Text(_formatConnectionQuality(option)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _connectionQuality = option);
                  },
                  selectedColor: Colors.blue.withValues(alpha: 0.2),
                  checkmarkColor: Colors.blue,
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildCallExperience() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Call Experience',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children:
              _experienceOptions.map((option) {
                final isSelected = _callExperience == option;
                return FilterChip(
                  label: Text(_formatExperience(option)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _callExperience = option);
                  },
                  selectedColor: Colors.green.withValues(alpha: 0.2),
                  checkmarkColor: Colors.green,
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildCommentsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Comments (Optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _commentController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Share your thoughts about the call...',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: TextButton(
            onPressed: _isSubmitting ? null : _skipFeedback,
            child: const Text('Skip'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitFeedback,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child:
                _isSubmitting
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Text('Submit'),
          ),
        ),
      ],
    );
  }

  void _skipFeedback() {
    Navigator.of(context).pop();
    // Add a small delay to ensure the dialog is closed before calling the callback
    Future.delayed(const Duration(milliseconds: 100), () {
      widget.onFeedbackSubmitted();
    });
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final callService = CallService();
      await callService.submitCallFeedback(
        channelId: widget.channelId,
        rating: _rating,
        connectionQuality: _connectionQuality,
        callExperience: _callExperience,
        comments: _commentController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
        // Add a small delay to ensure the dialog is closed before calling the callback
        Future.delayed(const Duration(milliseconds: 100), () {
          widget.onFeedbackSubmitted();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit feedback: $e'),
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String _formatConnectionQuality(String quality) {
    switch (quality) {
      case 'excellent':
        return 'Excellent';
      case 'good':
        return 'Good';
      case 'poor':
        return 'Poor';
      case 'failed':
        return 'Failed';
      default:
        return quality;
    }
  }

  String _formatExperience(String experience) {
    switch (experience) {
      case 'very_satisfied':
        return 'Very Satisfied';
      case 'satisfied':
        return 'Satisfied';
      case 'neutral':
        return 'Neutral';
      case 'dissatisfied':
        return 'Dissatisfied';
      case 'very_dissatisfied':
        return 'Very Dissatisfied';
      default:
        return experience;
    }
  }
}
