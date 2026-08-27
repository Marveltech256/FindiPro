import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'main_screen.dart';
import 'services/push_notification_service.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SupabaseConfig.initialize();
  await PushNotificationService().initialize();
  runApp(const FindiProApp());
}

class FindiProApp extends StatelessWidget {
  const FindiProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService(),
      builder: (context, _) {
        return MaterialApp(
          title: 'FindiPro',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeService().themeMode,
          home: const MainScreen(),
        );
      },
    );
  }
}
