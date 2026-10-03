import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/findipro_logo.dart';
import '../../models/feedback_model.dart';
import '../../models/user_model.dart';
import '../../repositories/feedback_repository.dart';
import '../../repositories/user_repository.dart';

class FeedbackScreen extends StatefulWidget {
  final UserModel? user;
  final int initialTabIndex;

  const FeedbackScreen({
    super.key,
    this.user,
    this.initialTabIndex = 0,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _feedbackRepo = FeedbackRepository();
  final _userRepo = UserRepository();

  UserModel? _currentUser;

  // Feedback Form State
  double _rating = 5.0;
  String _feedbackCategory = 'General Experience';
  final _feedbackController = TextEditingController();
  final _feedbackTitleController = TextEditingController();
  bool _submittingFeedback = false;

  final List<String> _feedbackCategories = const [
    'General Experience',
    'Finding & Booking Providers',
    'Chat & Messaging',
    'Payments & Pricing',
    'App Speed & Reliability',
    'Provider Quality',
    'Other',
  ];

  final List<String> _featureCategories = const [
    'New Service / Trade Category',
    'App Feature / Tool',
    'General App Improvement',
    'Booking & Hires',
    'Payments & Mobile Money',
    'Provider & Business Tools',
    'Location & Distance',
    'Chat & Media',
    'Notifications & Alerts',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _loadUser();
  }

  Future<void> _loadUser() async {
    if (widget.user != null) {
      if (mounted) setState(() => _currentUser = widget.user);
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final user = await _userRepo.getUser(uid);
      if (mounted) {
        setState(() => _currentUser = user);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _feedbackController.dispose();
    _feedbackTitleController.dispose();
    super.dispose();
  }

  Future<void> _submitAppFeedback() async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write your feedback or suggestions.')),
      );
      return;
    }

    setState(() => _submittingFeedback = true);

    final firebaseUser = FirebaseAuth.instance.currentUser;
    final uid = _currentUser?.uid ?? firebaseUser?.uid ?? 'guest';
    final name = _currentUser?.name ?? firebaseUser?.displayName ?? 'FindiPro User';
    final email = _currentUser?.email ?? firebaseUser?.email ?? 'user@findipro.com';
    final role = _currentUser?.role ?? 'customer';

    try {
      await _feedbackRepo.submitFeedback(
        userId: uid,
        userName: name,
        userEmail: email,
        userRole: role,
        category: _feedbackCategory,
        rating: _rating,
        title: _feedbackTitleController.text.trim().isNotEmpty
            ? _feedbackTitleController.text.trim()
            : null,
        description: text,
      );

      if (!mounted) return;

      _feedbackController.clear();
      _feedbackTitleController.clear();
      setState(() {
        _rating = 5.0;
        _feedbackCategory = 'General Experience';
        _submittingFeedback = false;
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 18),
              const Text(
                'Thank You!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your feedback has been submitted directly to the FindiPro team. We use your insights to continually improve the service experience.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _submittingFeedback = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting feedback: $e')),
        );
      }
    }
  }

  void _showProposeFeatureDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String category = _featureCategories.first;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06B6D4).withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.lightbulb_outline, color: Color(0xFF0891B2), size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Request a New Feature',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'What would make FindiPro better for you?',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Feature Title
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Feature Title',
                        hintText: 'e.g. Schedule recurring cleaning weekly',
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _featureCategories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => category = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Detailed Description
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Feature Description & Benefits',
                        hintText: 'Describe how this feature should work and how it will help clients or service providers...',
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final title = titleController.text.trim();
                                final desc = descriptionController.text.trim();
                                if (title.isEmpty || desc.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please provide both title and description.')),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);

                                final firebaseUser = FirebaseAuth.instance.currentUser;
                                final uid = _currentUser?.uid ?? firebaseUser?.uid ?? 'guest';
                                final name = _currentUser?.name ?? firebaseUser?.displayName ?? 'FindiPro User';
                                final email = _currentUser?.email ?? firebaseUser?.email ?? 'user@findipro.com';
                                final role = _currentUser?.role ?? 'customer';

                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(ctx);

                                try {
                                  await _feedbackRepo.submitFeatureRequest(
                                    userId: uid,
                                    userName: name,
                                    userEmail: email,
                                    userRole: role,
                                    title: title,
                                    category: category,
                                    description: desc,
                                  );

                                  if (nav.canPop()) {
                                    nav.pop();
                                  }
                                  if (mounted) {
                                    setState(() {});
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Feature request submitted! Community members can now upvote it.'),
                                        backgroundColor: Color(0xFF10B981),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                              )
                            : const Text('Submit Feature Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRatingSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How is your experience with FindiPro?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            final isFilled = starIndex <= _rating;
            return IconButton(
              iconSize: 38,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              icon: Icon(
                isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isFilled ? Colors.amber : Colors.grey.shade400,
              ),
              onPressed: () => setState(() => _rating = starIndex.toDouble()),
            );
          }),
        ),
        Center(
          child: Text(
            _getRatingLabel(_rating),
            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0891B2), fontSize: 14),
          ),
        ),
      ],
    );
  }

  String _getRatingLabel(double rating) {
    if (rating >= 5) return '⭐⭐⭐⭐⭐ Excellent - Loving FindiPro!';
    if (rating >= 4) return '⭐⭐⭐⭐ Good - Great overall service';
    if (rating >= 3) return '⭐⭐⭐ Average - Satisfactory';
    if (rating >= 2) return '⭐⭐ Needs Improvement';
    return '⭐ Poor - Needs immediate attention';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'in_progress':
        return Colors.purple;
      case 'planned':
        return const Color(0xFF0284C7);
      case 'under_review':
        return const Color(0xFFD97706);
      case 'declined':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'COMPLETED';
      case 'in_progress':
        return 'IN PROGRESS';
      case 'planned':
        return 'PLANNED';
      case 'under_review':
        return 'UNDER REVIEW';
      case 'declined':
        return 'DECLINED';
      default:
        return 'SUBMITTED';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtleBorder = theme.colorScheme.outline.withAlpha(40);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback & Features'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF06B6D4),
          indicatorWeight: 3,
          labelColor: const Color(0xFF06B6D4),
          unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(150),
          tabs: const [
            Tab(icon: Icon(Icons.rate_review_outlined), text: 'Share Feedback'),
            Tab(icon: Icon(Icons.lightbulb_outline), text: 'Feature Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ==========================================
          // TAB 1: SHARE APP FEEDBACK
          // ==========================================
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Center(child: FindiProLogo(height: 52)),
              const SizedBox(height: 16),
              Text(
                'We value your experience',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Help us shape FindiPro to serve you and your community better.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color ?? theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: subtleBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRatingSelector(),
                    const Divider(height: 28),

                    const Text('Feedback Topic', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _feedbackCategory,
                      decoration: InputDecoration(
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _feedbackCategories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _feedbackCategory = v);
                      },
                    ),
                    const SizedBox(height: 16),

                    const Text('Title / Summary (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _feedbackTitleController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Quick quote response was great',
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Your Detailed Feedback *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _feedbackController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Share what you enjoyed or what we can do better...',
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _submittingFeedback ? null : _submitAppFeedback,
                        child: _submittingFeedback
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator.adaptive(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                              )
                            : const Text('Submit Feedback', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),

          // ==========================================
          // TAB 2: REQUEST & VOTE ON FEATURES
          // ==========================================
          StreamBuilder<List<FeedbackItem>>(
            stream: _feedbackRepo.watchFeatureRequests(),
            builder: (context, snapshot) {
              final features = snapshot.data ?? [];
              final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;

              return Column(
                children: [
                  // Action Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFF06B6D4).withAlpha(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Community Feature Ideas',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Upvote ideas you want to see built first in FindiPro!',
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF06B6D4),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onPressed: _showProposeFeatureDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Propose', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator.adaptive())
                        : features.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.lightbulb_outline, size: 56, color: Colors.grey),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No Feature Requests Yet',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Be the first to propose a new feature for FindiPro!',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.grey, fontSize: 13),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: _showProposeFeatureDialog,
                                        icon: const Icon(Icons.add),
                                        label: const Text('Propose Feature'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: features.length,
                                itemBuilder: (context, i) {
                                  final item = features[i];
                                  final hasUpvoted = currentUserId.isNotEmpty && item.upvoterUids.contains(currentUserId);
                                  final statusColor = _getStatusColor(item.status);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: theme.cardTheme.color ?? theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: subtleBorder),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Upvote Button
                                        InkWell(
                                          onTap: () async {
                                            if (currentUserId.isEmpty) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Please log in to upvote feature requests.')),
                                              );
                                              return;
                                            }
                                            await _feedbackRepo.toggleUpvoteFeatureRequest(
                                              requestId: item.id,
                                              userId: currentUserId,
                                            );
                                            setState(() {});
                                          },
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            width: 52,
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            decoration: BoxDecoration(
                                              color: hasUpvoted
                                                  ? const Color(0xFF06B6D4).withAlpha(35)
                                                  : theme.colorScheme.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: hasUpvoted
                                                    ? const Color(0xFF06B6D4)
                                                    : Colors.transparent,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Icon(
                                                  Icons.arrow_drop_up_rounded,
                                                  size: 28,
                                                  color: hasUpvoted ? const Color(0xFF0891B2) : Colors.grey,
                                                ),
                                                Text(
                                                  '${item.votes}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: hasUpvoted ? const Color(0xFF0891B2) : theme.colorScheme.onSurface,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Feature Content
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      item.title,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: statusColor.withAlpha(25),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: statusColor.withAlpha(100), width: 0.8),
                                                    ),
                                                    child: Text(
                                                      _getStatusLabel(item.status),
                                                      style: TextStyle(
                                                        color: statusColor,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.surfaceContainerHighest,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  item.category,
                                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                item.description,
                                                style: TextStyle(fontSize: 13, height: 1.35, color: theme.colorScheme.onSurface.withAlpha(220)),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Proposed by ${item.userName} • ${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                                                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withAlpha(120)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

