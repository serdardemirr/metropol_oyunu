import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'services/app_services.dart';
import 'services/profile_service.dart';

class MetropolApp extends StatelessWidget {
  const MetropolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Metropol',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF2E7D32),
      ),
      home: const _StartGate(),
    );
  }
}

/// Kayıtlı profil varsa ana ekrana, yoksa profil oluşturmaya yönlendirir.
class _StartGate extends StatelessWidget {
  const _StartGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: AppServices.profile.load(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final profile = snap.data;
        return profile == null
            ? const ProfileScreen()
            : HomeScreen(profile: profile);
      },
    );
  }
}
