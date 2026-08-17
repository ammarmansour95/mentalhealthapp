import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/providers/auth_provider.dart';
import 'package:frontend/features/auth/login_screen.dart';
import 'package:frontend/features/patient/patient_dashboard_screen.dart';
import 'package:frontend/features/doctor_portal/doctor_dashboard_screen.dart';
import 'package:frontend/features/admin/admin_dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initAuth()),
      ],
      child: const MentalHealthApp(),
    ),
  );
}

class MentalHealthApp extends StatelessWidget {
  const MentalHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'منصة الرعاية النفسية الذكية',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [
        Locale('ar', 'SA'),
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (auth.isAuthenticated) {
            if (auth.role == 'ADMIN') {
              return const AdminDashboardScreen();
            } else if (auth.role == 'DOCTOR') {
              return const DoctorDashboardScreen();
            } else {
              return const PatientDashboardScreen();
            }
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
