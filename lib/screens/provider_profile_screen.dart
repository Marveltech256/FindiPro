import 'package:flutter/material.dart';
import 'package:findipro/models/provider_model.dart';
import 'package:findipro/theme/app_theme.dart';
import 'package:findipro/widgets/skill_chip.dart';
import 'package:findipro/services/launcher_service.dart';
import 'package:findipro/services/auth_service.dart';
import 'package:findipro/screens/login_screen.dart';

class ProviderProfileScreen extends StatefulWidget {
  final ServiceProvider provider;
  const ProviderProfileScreen({super.key, required this.provider});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  final AuthService _authService = AuthService();
  bool isSaved = false; // TODO: Replace with SavedProviderService

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildIdentitySection(textTheme),
                      const Divider(height: 48),
                      _buildSectionHeader('About', textTheme),
                      Text(widget.provider.about, style: textTheme.bodyMedium),
                      const SizedBox(height: 24),
                      _buildSectionHeader('Skills', textTheme),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: widget.provider.skills.map((skill) => SkillChip(label: skill)).toList(),
                      ),
                      const Divider(height: 48),
                      _buildContactSection(textTheme),
                      const Divider(height: 48),
                      _buildDetailRow('Price Range', widget.provider.priceRange, textTheme),
                      const SizedBox(height: 16),
                      _buildDetailRow('Experience', '${widget.provider.yearsExperience} years', textTheme),
                      const SizedBox(height: 16),
                      _buildAvailabilityRow(textTheme),
                      const Divider(height: 48),
                      _buildSectionHeader('Reviews', textTheme),
                      // TODO: Implement reviews list
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Text('No reviews yet.', style: textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () { /* TODO: Show review bottom sheet */ },
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text('Rate this provider'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          foregroundColor: AppTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 100), // Space for the sticky button
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildStickyHireButton(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(title, style: textTheme.titleLarge),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200.0,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.primaryColor,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: Icon(
            isSaved ? Icons.favorite : Icons.favorite_border,
            color: Colors.white,
          ),
          onPressed: () {
            if (_authService.currentUser == null) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Login Required'),
                  content: const Text('Create an account to save providers for later.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LoginScreen()));
                      },
                      child: const Text('Login / Sign Up'),
                    ),
                  ],
                ),
              );
            } else {
              setState(() {
                isSaved = !isSaved;
                // TODO: Call SavedProviderService to update Firestore
              });
            }
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.provider.profileImageUrl,
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: 0.4),
              colorBlendMode: BlendMode.darken,
            ),
            Positioned(
              bottom: -1,
              left: 0,
              right: 0,
              child: Container(
                height: 30,
                decoration: const BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentitySection(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.provider.name, style: textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          '${widget.provider.category} • ${widget.provider.location}',
          style: textTheme.bodyLarge?.copyWith(color: AppTheme.iconColor),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 4),
            Text(
              '${widget.provider.rating} (${widget.provider.reviewCount} reviews)',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactSection(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Contact', textTheme),
        ListTile(
          leading: const Icon(Icons.phone_outlined, color: AppTheme.iconColor),
          title: Text(widget.provider.phone),
          onTap: () => LauncherService.launchPhone(widget.provider.phone),
        ),
        ListTile(
          leading: const Icon(Icons.chat_bubble_outline, color: AppTheme.iconColor),
          title: const Text('WhatsApp'),
          onTap: () => LauncherService.launchWhatsApp(widget.provider.whatsapp),
        ),
        ListTile(
          leading: const Icon(Icons.email_outlined, color: AppTheme.iconColor),
          title: Text(widget.provider.email),
          onTap: () => LauncherService.launchEmail(widget.provider.email),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, TextTheme textTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textTheme.bodyLarge?.copyWith(color: AppTheme.iconColor)),
        Text(value, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAvailabilityRow(TextTheme textTheme) {
    final bool isAvailable = widget.provider.available;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Availability', style: textTheme.bodyLarge?.copyWith(color: AppTheme.iconColor)),
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isAvailable ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isAvailable ? 'Available' : 'Busy',
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStickyHireButton() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.all(16),
        color: AppTheme.backgroundColor.withValues(alpha: 0.9),
        child: ElevatedButton(
          onPressed: () {
            // TODO: Show hire request modal
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text('Request to Hire'),
        ),
      ),
    );
  }
}