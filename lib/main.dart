import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/auth_check_screen.dart';
import 'screens/admin/admin_gate_screen.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    print('Starting Alumni Connect initialization...');

    // Initialize Supabase with a timeout
    try {
      print('Alumni Connect: Initializing Supabase...');
      await Supabase.initialize(
        url: 'https://pgfdqvtlpiiwvwvqzfgs.supabase.co',
        anonKey: 'sb_publishable_4DyMdv2Uev08ejpJ6josCA_AUvsRNm_',
      ).timeout(const Duration(seconds: 5));
      print('Alumni Connect: Supabase initialized successfully');
    } catch (e) {
      print('Alumni Connect: Supabase initialization failed or timed out: $e');
    }

    // Initialize Firebase
    try {
      print('Alumni Connect: Initializing Firebase...');
      await Firebase.initializeApp().timeout(const Duration(seconds: 5));
      print('Alumni Connect: Firebase initialized successfully');
    } catch (e) {
      print('Alumni Connect: Firebase initialization failed or timed out: $e');
    }
    
    // Initialize notifications with error handling
    try {
      print('Alumni Connect: Initializing NotificationService...');
      final notificationService = NotificationService();
      await notificationService.initialize().timeout(const Duration(seconds: 5));
      notificationService.configureHandlers();
      print('Alumni Connect: Notifications initialized successfully');
    } catch (e) {
      print('Alumni Connect: Notification service initialization failed or timed out: $e');
    }
  } catch (e) {
    print('Critical initialization error: $e');
  } finally {
    runApp(const AlumniConnectApp());
  }
}

class AlumniConnectApp extends StatelessWidget {
  const AlumniConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        navigatorKey: NotificationService.navigatorKey,
        title: 'Alumni Connect',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/auth-check': (context) => const AuthCheckScreen(),
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignUpScreen(),
          '/home': (context) => const AuthCheckScreen(),
          '/admin': (context) => const AdminGateScreen(),
        },
      ),
    );
  }
}
