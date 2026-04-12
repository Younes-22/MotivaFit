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

// The ignition switch for the entire app. It ensures Flutter is ready, locks the screen so it doesn't rotate sideways, boots up Firebase, and securely loads our hidden API keys before finally painting the UI on the screen.
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

// The root widget of the app. By wrapping our MaterialApp in an Auth Stream first, we ensure the app only connects to the database theme listener AFTER the user is fully logged in. This prevents the app from getting stuck on a blank default theme.
class MotivafitApp extends StatelessWidget {
  const MotivafitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        // If no one is logged in yet (or the app is just booting up), we safely fall back to the default MotivaFit light theme for the login screens.
        if (user == null) {
          return MaterialApp(
            title: 'Motivafit',
            debugShowCheckedModeBanner: false,
            theme: AppThemes.getTheme('default'),
            home: const AuthWrapper(),
          );
        }

        // Once they are logged in, we tap directly into their personal database profile. 
        // This StreamBuilder forces the entire app to instantly repaint the split-second they buy a new theme from the shop or toggle dark mode in settings.
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

            // This logic gracefully handles the standard Apple/Android system settings, manual light/dark toggles, and completely custom shop themes.
            if (activeThemeId == 'default' || activeThemeId == 'system') {
              appTheme = AppThemes.getTheme('default');
              appDarkTheme = AppThemes.getTheme('theme_dark');
              currentThemeMode = ThemeMode.system;
            } else if (activeThemeId == 'theme_light') {
              appTheme = AppThemes.getTheme('default');
              appDarkTheme = AppThemes.getTheme('default');
              currentThemeMode = ThemeMode.light;
            } else if (activeThemeId == 'theme_dark') {
              appTheme = AppThemes.getTheme('theme_dark');
              appDarkTheme = AppThemes.getTheme('theme_dark');
              currentThemeMode = ThemeMode.dark;
            } else {
              // If they have a custom shop theme equipped, we force both light and dark modes to use the custom colors so their phone's native settings don't override their purchase.
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
      },
    );
  }
}

// The app's Traffic Cop. It sits at the very front door and checks every user's ID. 
// It silently routes them to the Login Screen, the Onboarding Setup, or the home dashboard depending on their exact account state.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        
        // Still checking Firebase to see if they are logged in...
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = authSnapshot.data;

        // If they have a valid login session, we need to make sure they actually finished setting up their profile metrics before letting them into the app.
        if (user != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, docSnapshot) {
              if (docSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              // If their database profile exists, send them straight to the Home dashboard.
              if (docSnapshot.hasData && docSnapshot.data!.exists) {
                return const HomeScreen();
              } else {
                // But if their database profile doesn't exist yet, force them through the Onboarding flow.
                return const OnboardingScreen();
              }
            },
          );
        }

        // If they have no active session at all, kick them to the Login Screen.
        return const LoginScreen();
      },
    );
  }
}