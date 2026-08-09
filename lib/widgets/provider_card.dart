import 'package:findipro/screens/provider/provider_profile_screen.dart';

// inside onTap
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProviderProfileScreen(provider: provider),
    ),
  );
},