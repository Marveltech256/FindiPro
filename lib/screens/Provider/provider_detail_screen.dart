import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/utils/uuid_utils.dart';
import '../../models/review_model.dart';
import '../../models/service_model.dart';
import '../../models/user_model.dart';
import '../../repositories/booking_repository.dart';
import '../../repositories/review_repository.dart';
import '../../repositories/service_repository.dart';
import '../auth/login_screen.dart';
import '../chat_screen.dart';
import '../hire/request_hire_screen.dart';
import 'write_review_screen.dart';

class ProviderDetailScreen extends StatefulWidget {
  final UserModel provider;

  const ProviderDetailScreen({super.key, required this.provider});

  @override
  State<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends State<ProviderDetailScreen> {
  bool _isSaved = false;
  final _reviewRepo = ReviewRepository();
  final _bookingRepo = BookingRepository();
  final _serviceRepo = ServiceRepository();

  List<ReviewModel> _reviews = [];
  List<ServiceModel> _services = [];
  double _avgRating = 0.0;
  int _reviewCount = 0;
  bool _loadingReviews = true;
  bool _loadingServices = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final list = await _serviceRepo.getProviderServices(widget.provider);
      if (mounted) {
        setState(() {
          _services = list;
          _loadingServices = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingServices = false;
        });
      }
    }
  }

  bool get _isSelf {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;
    final currentUid = currentUser.uid.trim().toLowerCase();
    final providerUid = widget.provider.uid.trim().toLowerCase();
    if (currentUid.isNotEmpty && providerUid.isNotEmpty && currentUid == providerUid) {
      return true;
    }
    final convertedCurrent = UuidUtils.firebaseUidToUuid(currentUser.uid).trim().toLowerCase();
    final convertedProvider = UuidUtils.firebaseUidToUuid(widget.provider.uid).trim().toLowerCase();
    if (convertedCurrent == convertedProvider) return true;
    if (convertedCurrent == providerUid || currentUid == convertedProvider) return true;

    final currentEmail = (currentUser.email ?? '').trim().toLowerCase();
    final providerEmail = widget.provider.email.trim().toLowerCase();
    if (currentEmail.isNotEmpty && providerEmail.isNotEmpty && currentEmail == providerEmail) {
      return true;
    }
    return false;
  }

  Future<void> _loadReviews() async {
    if (mounted) setState(() => _loadingReviews = true);
    try {
      final list = await _reviewRepo.getProviderReviews(widget.provider.uid);
      double avg = 0.0;
      if (list.isNotEmpty) {
        double sum = 0;
        for (final r in list) {
          sum += r.rating;
        }
        avg = double.parse((sum / list.length).toStringAsFixed(1));
      }
      if (mounted) {
        setState(() {
          _reviews = list;
          _avgRating = avg;
          _reviewCount = list.length;
          _loadingReviews = false;
        });
      }
    } catch (e) {
      debugPrint('>>> [ProviderDetailScreen._loadReviews] error: $e');
      if (mounted) {
        setState(() {
          _reviews = [];
          _avgRating = 0.0;
          _reviewCount = 0;
          _loadingReviews = false;
        });
      }
    }
  }

  void _toggleSaved() {
    setState(() {
      _isSaved = !_isSaved;
    });
  }

  void _onMessage() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to message this service provider.')),
      );
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    // Self-message guard (UI layer; repository layer also enforces this)
    if (_isSelf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot message yourself.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUserId: user.uid,
          otherUserId: widget.provider.uid,
          otherUserName: widget.provider.name,
          otherUserPhotoUrl: widget.provider.photoUrl,
        ),
      ),
    );
  }

  void _onHire() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to request this service.')),
      );
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    // Self-hire guard (UI layer; repository layer also enforces this)
    if (_isSelf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot hire yourself.')),
      );
      return;
    }

    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RequestHireScreen(provider: widget.provider),
      ),
    );
    if (res == true) {
      _loadReviews();
    }
  }

  void _onReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to write a review.')),
      );
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    // Self-review guard
    if (_isSelf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot review your own service.')),
      );
      return;
    }

    // Check if the user has a completed request with this provider
    String? targetJobId;
    String? targetBookingId;
    String? targetSourceTable;

    try {
      final requests = await _bookingRepo.getClientRequests(user.uid);
      final providerUuid = UuidUtils.isValidUuid(widget.provider.uid)
          ? widget.provider.uid
          : UuidUtils.firebaseUidToUuid(widget.provider.uid);

      final completedForProvider = requests.where((r) {
        final pid = (r['provider_id'] ?? r['providerId'] ?? '').toString();
        final status = (r['status'] ?? '').toString().toLowerCase();
        final isMatch = pid == widget.provider.uid ||
            pid == providerUuid ||
            pid == widget.provider.name;
        return isMatch && status == 'completed';
      }).toList();

      if (completedForProvider.isNotEmpty) {
        final targetJob = completedForProvider.first;
        final requestId = (targetJob['id'] ?? '').toString();
        targetSourceTable = (targetJob['source_table'] ?? 'jobs').toString();

        if (targetSourceTable == 'jobs') {
          targetJobId = requestId.isNotEmpty ? requestId : null;
        } else if (targetSourceTable == 'bookings') {
          targetBookingId = requestId.isNotEmpty ? requestId : null;
        }
      }
    } catch (e) {
      debugPrint('>>> [ProviderDetailScreen._onReview] requests query note: $e');
    }

    // Check duplicate using the appropriate IDs + provider for business_id check
    try {
      final already = await _reviewRepo.hasReviewed(
        customerId: user.uid,
        jobId: targetJobId,
        bookingId: targetBookingId,
        providerId: widget.provider.uid,
      );

      if (already) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have already reviewed this service.')),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('>>> [ProviderDetailScreen._onReview] hasReviewed note: $e');
    }

    if (mounted) {
      final res = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => WriteReviewScreen(
            provider: widget.provider,
            jobId: targetJobId,
            bookingId: targetBookingId,
          ),
        ),
      );
      if (res == true) {
        await _loadReviews();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF0F172A),
            actions: [
              IconButton(
                onPressed: _toggleSaved,
                icon: Icon(
                  _isSaved ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: widget.provider.photoUrl != null &&
                      widget.provider.photoUrl!.isNotEmpty
                  ? Image.network(
                      widget.provider.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatar(),
                    )
                  : _avatar(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.provider.name,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      if (widget.provider.isPremiumBadge)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.stars,
                            color: Color(0xFFD97706),
                            size: 24,
                          ),
                        )
                      else if (widget.provider.isVerifiedBadge)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.verified,
                            color: Colors.blue,
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        widget.provider.category ?? 'Service Provider',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: const Color(0xFF06B6D4),
                            ),
                      ),
                      const Spacer(),
                      // Real rating summary
                      if (_loadingReviews) ...[
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                        ),
                      ] else if (_reviewCount > 0) ...[
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '$_avgRating',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '($_reviewCount ${_reviewCount == 1 ? 'review' : 'reviews'})',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(153), fontSize: 13),
                        ),
                      ] else ...[
                        Text(
                          'No reviews yet',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(120), fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.provider.location ?? 'Kampala',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _heading('About'),
                  Text(
                    widget.provider.bio ??
                        'This professional has not added an about section yet.',
                    style: const TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // Services Offered Section
                  _heading('Services Offered'),
                  if (_loadingServices)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    )
                  else if (_services.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).colorScheme.outline.withAlpha(50)),
                      ),
                      child: Text(
                        'No services listed yet',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(140), fontSize: 14),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _services.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final s = _services[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Theme.of(context).colorScheme.outline.withAlpha(50)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  if (s.price != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF06B6D4).withAlpha(30),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${s.currency} ${s.price!.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: Color(0xFF0891B2),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    )
                                  else if (widget.provider.priceRange.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF06B6D4).withAlpha(30),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        widget.provider.priceRange,
                                        style: const TextStyle(
                                          color: Color(0xFF0891B2),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (s.description != null && s.description!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  s.description!,
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(220), fontSize: 13, height: 1.3),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                children: [
                                  if (s.category != null && s.category!.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.category_outlined, size: 14, color: Theme.of(context).colorScheme.onSurface.withAlpha(110)),
                                        const SizedBox(width: 4),
                                        Text(
                                          s.category!,
                                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(153)),
                                        ),
                                      ],
                                    ),
                                  if (s.duration != null && s.duration!.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.schedule, size: 14, color: Theme.of(context).colorScheme.onSurface.withAlpha(110)),
                                        const SizedBox(width: 4),
                                        Text(
                                          s.duration!,
                                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(153)),
                                        ),
                                      ],
                                    ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: s.isActive ? Colors.green : Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        s.isActive ? 'Available' : 'Unavailable',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: s.isActive ? Colors.green.shade700 : Colors.grey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),

                  _heading('Professional details'),
                  _info(Icons.phone, 'Phone', widget.provider.phone),
                  _info(Icons.email_outlined, 'Email', widget.provider.email),
                  const SizedBox(height: 24),
                  _heading('Portfolio'),
                  _gallerySection(widget.provider.images),
                  const SizedBox(height: 24),

                  // Reviews List Section
                  _heading(_loadingReviews ? 'Customer Reviews' : 'Customer Reviews (${_reviews.length})'),
                  if (_loadingReviews)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    )
                  else if (_reviews.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).colorScheme.outline.withAlpha(50)),
                      ),
                      child: Text(
                        'No reviews yet for this provider.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(140), fontSize: 14),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _reviews.length,
                      separatorBuilder: (_, __) => const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final rev = _reviews[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ClipOval(
                                  child: SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: (rev.customerPhotoUrl != null && rev.customerPhotoUrl!.isNotEmpty)
                                        ? Image.network(
                                            rev.customerPhotoUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                              child: const Icon(Icons.person, size: 20, color: Colors.grey),
                                            ),
                                          )
                                        : Container(
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                            child: const Icon(Icons.person, size: 20, color: Colors.grey),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        rev.customerName ?? 'Customer',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                      Text(
                                        '${rev.createdAt.day}/${rev.createdAt.month}/${rev.createdAt.year}',
                                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withAlpha(110)),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: List.generate(5, (starIdx) {
                                    return Icon(
                                      starIdx < rev.rating ? Icons.star : Icons.star_border,
                                      color: Colors.amber,
                                      size: 16,
                                    );
                                  }),
                                ),
                              ],
                            ),
                            if (rev.comment != null && rev.comment!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                rev.comment!,
                                style: const TextStyle(fontSize: 13, height: 1.4),
                              ),
                            ],
                          ],
                        );
                      },
                    ),

                  const SizedBox(height: 28),
                  Builder(builder: (ctx) {
                    if (_isSelf) return const SizedBox.shrink();
                    return Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.work_outline),
                            label: const Text('Request Service / Hire'),
                            onPressed: _onHire,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF06B6D4),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Message Provider'),
                            onPressed: _onMessage,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.rate_review_outlined),
                            label: const Text('Write Review'),
                            onPressed: _onReview,
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Text(
          widget.provider.name.isEmpty
              ? '?'
              : widget.provider.name[0].toUpperCase(),
          style: const TextStyle(
            fontSize: 72,
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _heading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _info(IconData icon, String title, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF06B6D4).withAlpha(30),
        child: Icon(icon, color: const Color(0xFF06B6D4)),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
          fontSize: 12,
        ),
      ),
      subtitle: Text(
        value.isEmpty ? 'Not provided' : value,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _gallerySection(List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('No portfolio images yet'),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              images[index],
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          );
        },
      ),
    );
  }
}