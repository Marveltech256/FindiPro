import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../services/saved_provider_service.dart';
import 'Provider/provider_detail_screen.dart';
import '../widgets/empty_state.dart';

class SavedScreen extends StatefulWidget{const SavedScreen({super.key});@override State<SavedScreen> createState()=>_SavedScreenState();}
class _SavedScreenState extends State<SavedScreen>{List<String> _ids=[];bool _loading=true;final _saved=SavedProviderService();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ids = await _saved.getSavedIds();
    if (mounted) setState(() { _ids = ids; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Saved Providers')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _ids.isEmpty
                ? const EmptyState(
                    icon: Icons.bookmark_outline,
                    title: 'No Saved Providers',
                    subtitle: 'Tap the heart icon on a provider\'s profile to save them for later.',
                  )
                : StreamBuilder<List<UserModel>>(
                    stream: UserRepository().getProvidersStream(),
                    builder: (context, s) {
                      if (!s.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final list = s.data!.where((p) => _ids.contains(p.uid)).toList();
                      if (list.isEmpty) {
                        return const EmptyState(
                          icon: Icons.bookmark_remove_outlined,
                          title: 'Providers Not Found',
                          subtitle: 'Your saved providers may no longer be available.',
                        );
                      }
                      return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final p = list[i];
                            return ListTile(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                leading: CircleAvatar(backgroundImage: p.photoUrl == null ? null : NetworkImage(p.photoUrl!), child: p.photoUrl == null ? const Icon(Icons.person) : null),
                                title: Row(
                                  children: [
                                    Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                                    if (p.isPremiumBadge)
                                      const Icon(Icons.stars, color: Color(0xFFD97706), size: 18)
                                    else if (p.isVerifiedBadge)
                                      const Icon(Icons.verified, color: Colors.blue, size: 18),
                                  ],
                                ),
                                subtitle: Text(p.category ?? ''),
                                trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      await _saved.toggle(p.uid);
                                      _load();
                                    }),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderDetailScreen(provider: p))));
                          });
                    }));
  }
}
