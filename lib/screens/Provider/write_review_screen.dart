import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../repositories/review_repository.dart';

class WriteReviewScreen extends StatefulWidget {
  final UserModel provider;
  final String? jobId;
  final String? bookingId;

  const WriteReviewScreen({
    super.key,
    required this.provider,
    this.jobId,
    this.bookingId,
  });

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  int _rating = 0; // Default 0 stars selected
  final _comment = TextEditingController();
  final _repo = ReviewRepository();
  bool _loading = false;
  bool _alreadyReviewed = false;

  @override
  void initState() {
    super.initState();
    _checkReviewStatus();
  }

  Future<void> _checkReviewStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final reviewed = await _repo.hasReviewed(
        customerId: user.uid,
        jobId: widget.jobId,
        bookingId: widget.bookingId,
        providerId: widget.provider.uid,
      );
      if (mounted) {
        setState(() {
          _alreadyReviewed = reviewed;
        });
      }
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a review.')),
      );
      return;
    }

    if (_rating < 1 || _rating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating.')),
      );
      return;
    }

    setState(() => _loading = true);

    // Pre-check duplicate review
    try {
      final already = await _repo.hasReviewed(
        customerId: user.uid,
        jobId: widget.jobId,
        bookingId: widget.bookingId,
        providerId: widget.provider.uid,
      );

      if (already) {
        setState(() => _alreadyReviewed = true);
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF06B6D4), size: 26),
                SizedBox(width: 10),
                Text('Review Already Submitted'),
              ],
            ),
            content: const Text(
              'You have already submitted a review for this service. '
              'Each service can only be reviewed once.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, false);
                },
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        return;
      }
    } catch (_) {}

    try {
      await _repo.addReview(
        customerId: user.uid,
        providerId: widget.provider.uid,
        jobId: widget.jobId,
        bookingId: widget.bookingId,
        rating: _rating,
        comment: _comment.text.trim().isNotEmpty ? _comment.text.trim() : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully. Thank you!'),
            backgroundColor: Color(0xFF06B6D4),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('>>> [WriteReviewScreen._submitReview] Error: $e');
      final rawMsg = e.toString().replaceAll('Exception: ', '');
      if (!mounted) return;

      final isAlreadyReviewed =
          rawMsg.contains('already reviewed') ||
          rawMsg.contains('23505') ||
          rawMsg.contains('unique') ||
          rawMsg.contains('duplicate');

      if (isAlreadyReviewed) {
        // Show a dismissible dialog for "already reviewed"
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF06B6D4), size: 26),
                SizedBox(width: 10),
                Text('Review Already Submitted'),
              ],
            ),
            content: const Text(
              'You have already submitted a review for this service. '
              'Each service can only be reviewed once.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, false);
                },
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        return;
      }

      String displayError;
      if (rawMsg.contains('cannot review your own')) {
        displayError = 'You cannot review your own service.';
      } else if (rawMsg.contains('Only completed')) {
        displayError = 'Only completed services can be reviewed.';
      } else if (rawMsg.contains('own completed service')) {
        displayError = 'You can only review your own completed service.';
      } else if (rawMsg.contains('not linked to a provider') ||
          rawMsg.contains('no assigned provider')) {
        displayError = 'This service is not linked to a provider yet.';
      } else if (rawMsg.contains('select a rating')) {
        displayError = 'Please select a rating between 1 and 5 stars.';
      } else if (rawMsg.contains('could not be found') ||
          rawMsg.contains('service could not')) {
        displayError = 'Service not found. Please try again.';
      } else {
        // Surface the real error so we can debug it
        displayError = 'Unable to submit review. Please try again.\n\nDetails: $rawMsg';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayError),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Write Review')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              // Provider Avatar
              ClipOval(
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: widget.provider.photoUrl != null && widget.provider.photoUrl!.isNotEmpty
                      ? Image.network(
                          widget.provider.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.person, size: 36, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.person, size: 36, color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.provider.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              if (widget.provider.category != null && widget.provider.category!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.provider.category!,
                  style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 28),

              if (_alreadyReviewed) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withAlpha(80)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You have already submitted a review for this service.',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              const Text(
                'How was your experience?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              // Interactive Star Rating Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  final isFilled = starIndex <= _rating;
                  return IconButton(
                    iconSize: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: _alreadyReviewed
                        ? null
                        : () {
                            setState(() {
                              _rating = starIndex;
                            });
                          },
                    icon: Icon(
                      isFilled ? Icons.star : Icons.star_border,
                      color: isFilled ? Colors.amber : Colors.grey.shade400,
                    ),
                  );
                }),
              ),
              if (_rating > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '$_rating / 5 Stars',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.amber),
                  ),
                ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _comment,
                enabled: !_alreadyReviewed,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Your Experience (Optional)',
                  hintText: 'Tell us about your experience with this service provider...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _alreadyReviewed ? Colors.grey : const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (_loading || _alreadyReviewed) ? null : _submitReview,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _alreadyReviewed ? 'Review Already Submitted' : 'Submit Review',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}