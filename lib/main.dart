import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'services/firestore_service.dart';
import 'models/user_model.dart';
import 'theme/app_themes.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await dotenv.load(fileName: ".env");
  runApp(const MotivafitApp());
}

class MotivafitApp extends StatelessWidget {
  const MotivafitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel>(
      stream: FirestoreService().getUserStream(),
      builder: (context, snapshot) {
        String activeThemeId = 'default';

        if (snapshot.hasData) {
          activeThemeId = snapshot.data!.selectedThemeId;
        }

        ThemeData appTheme;
        ThemeData appDarkTheme;
        ThemeMode currentThemeMode;

        if (activeThemeId == 'default' || activeThemeId == 'system') {
          appTheme = AppThemes.getTheme('default');
          appDarkTheme = AppThemes.getTheme('theme_dark');
          currentThemeMode = ThemeMode.system;
        } 
        else if (activeThemeId == 'theme_light') {
          appTheme = AppThemes.getTheme('default');
          appDarkTheme = AppThemes.getTheme('default'); 
          currentThemeMode = ThemeMode.light;
        } 
        else if (activeThemeId == 'theme_dark') {
          appTheme = AppThemes.getTheme('theme_dark');
          appDarkTheme = AppThemes.getTheme('theme_dark');
          currentThemeMode = ThemeMode.dark;
        } 
        else {
          appTheme = AppThemes.getTheme(activeThemeId);
          appDarkTheme = AppThemes.getTheme(activeThemeId);
          currentThemeMode = ThemeMode.light; 
        }

        return MaterialApp(
          title: 'Motivafit',
          debugShowCheckedModeBanner: false,
          theme: appTheme,
          darkTheme: appDarkTheme,
          themeMode: currentThemeMode,
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = authSnapshot.data;

        if (user != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, docSnapshot) {
              if (docSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              if (docSnapshot.hasData && docSnapshot.data!.exists) {
                return const HomeScreen();
              } else {
                return const OnboardingScreen();
              }
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}