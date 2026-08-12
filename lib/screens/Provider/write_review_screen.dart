import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/review_model.dart';
import '../../models/user_model.dart';
import '../../repositories/review_repository.dart';

class WriteReviewScreen extends StatefulWidget {
  final UserModel provider;

  const WriteReviewScreen({super.key, required this.provider});

  @override
  State<WriteReviewScreen> createState() =>
      _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  double _rating = 5;
  final _comment = TextEditingController();
  final _repo = ReviewRepository();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Write Review')), body: Form(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Column(
              children: [
                Text('Reviewing', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(widget.provider.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Your Rating: ${_rating.toStringAsFixed(1)} ★', style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: _rating,
            min: 1,
            max: 5,
            divisions: 8, // Allows for half-star ratings
            label: _rating.toStringAsFixed(1),
            onChanged: (v) => setState(() => _rating = v),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _comment,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Your Experience',
              hintText: 'Tell others about the service you received...',
              alignLabelWithHint: true,
            ),
            validator: (value) {
              if (value == null || value.trim().length < 10) {
                return 'Please provide at least 10 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _submitReview,
              child: _loading ? const CircularProgressIndicator.adaptive() : const Text('Submit Review'),
            ),
          ),
        ]),
      ),
    ));
  }
}