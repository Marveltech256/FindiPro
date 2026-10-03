import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'main_screen.dart';
import 'services/analytics_service.dart';
import 'services/presence_service.dart';
import 'services/push_notification_service.dart';
import 'services/service_reminder_service.dart';
import 'services/theme_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Optimize Image and Memory Cache limits for high responsiveness and smooth image persistence
  PaintingBinding.instance.imageCache.maximumSize = 500;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100 MB cache for instant loads

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SupabaseConfig.initialize();
  await PushNotificationService().initialize(navKey: appNavigatorKey);
  PresenceService().initialize();
  AnalyticsService().initialize();
  runApp(const FindiProApp());
}

class FindiProApp extends StatefulWidget {
  const FindiProApp({super.key});

  @override
  State<FindiProApp> createState() => _FindiProAppState();
}

class _FindiProAppState extends State<FindiProApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ServiceReminderService().checkPendingRemindersOnAppResume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      ServiceReminderService().checkPendingRemindersOnAppResume();
    }
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    // Only prune images if the operating system issues an actual low-memory warning
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService(),
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
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
