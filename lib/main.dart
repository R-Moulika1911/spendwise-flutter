import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/category_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/recurring_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/initial_setup_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );

  await FirebaseService.initialize();
  if (FirebaseService.isReady) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  await NotificationService.instance.initialize();

  final settings = SettingsProvider();
  final categories = CategoryProvider();
  final expenses = ExpenseProvider();
  final recurring = RecurringProvider();
  final auth = AuthProvider();

  await settings.load();
  await categories.load();
  await expenses.load();
  await recurring.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: categories),
        ChangeNotifierProvider.value(value: expenses),
        ChangeNotifierProvider.value(value: recurring),
        ChangeNotifierProvider.value(value: auth),
      ],
      child: const SpendWiseApp(),
    ),
  );
}

class SpendWiseApp extends StatelessWidget {
  const SpendWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      routes: {
        '/home': (_) => const _PostAuthGate(),
        '/setup': (_) => const InitialSetupScreen(),
      },
      home: !settings.onboardingComplete
          ? const OnboardingScreen()
          : !settings.initialSetupComplete
              ? const InitialSetupScreen()
              : const MainShell(),
    );
  }
}

/// After login/register, land on setup if needed, otherwise home.
class _PostAuthGate extends StatelessWidget {
  const _PostAuthGate();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (!settings.initialSetupComplete) {
      return const InitialSetupScreen();
    }
    return const MainShell();
  }
}
