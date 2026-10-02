import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/presentation/screens/sign_in_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure status bar and navigation bar system overlay
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize shared Supabase backend (Mono database architecture with Web)
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  runApp(const BuckApp());
}

class BuckApp extends StatelessWidget {
  const BuckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buck - Finance & Expenses Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primaryOrange,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryOrange,
          secondary: AppColors.amberAccent,
          surface: AppColors.cardSurface,
        ),
      ),
      home: const SignInScreen(),
    );
  }
}
