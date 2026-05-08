import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'services/notification_service.dart';
import 'services/firestore_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/auth_check_screen.dart';
import 'screens/admin/admin_gate_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    
    // Background tasks (no need to wait for them to block app start)
    Supabase.initialize(
      url: 'https://pgfdqvtlpiiwvwvqzfgs.supabase.co',
      anonKey: 'sb_publishable_4DyMdv2Uev08ejpJ6josCA_AUvsRNm_',
    ).catchError((e) => print('Supabase init failed: $e'));

    NotificationService().initialize().then((_) {
      NotificationService().configureHandlers();
    }).catchError((e) => print('Notification init failed: $e'));

    FirestoreService().cleanupExpiredData().catchError((e) => print('Cleanup failed: $e'));
    
  } catch (e) {
    print('Initialization error: $e');
  }

  runApp(const AlumniConnectApp());
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
