import 'package:flutter/material.dart';

import '../navigation/app_navigation.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../widgets/edubridge_logo.dart';
import 'auth/login_screen.dart';

/// Brief brand splash shown once at startup.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 900), _goNext);
  }

  Future<void> _goNext() async {
    if (!mounted) return;

    if (widget.store.hasValidRememberedSession) {
      await AppNavigation.continueFromSchoolResolution(
        context,
        widget.store,
        preferLastSchool: true,
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => LoginScreen(store: widget.store)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.card,
      body: Center(child: EduBridgeLogo(size: 160)),
    );
  }
}
