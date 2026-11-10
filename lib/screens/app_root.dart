import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'auth/auth_screen.dart';
import 'auth/profile_setup_screen.dart';
import 'home/home_shell.dart';
import 'splash/splash_screen.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.status) {
          case AuthStatus.loading:
            return const SplashScreen();
          case AuthStatus.unauthenticated:
            return const AuthScreen();
          case AuthStatus.profileIncomplete:
            return const ProfileSetupScreen();
          case AuthStatus.authenticated:
            return const HomeShell();
        }
      },
    );
  }
}
