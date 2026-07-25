import 'package:flutter/material.dart';

import 'repositories/edubridge_repository.dart';
import 'screens/splash_screen.dart';
import 'services/database_service.dart';
import 'state/app_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop / tests: FFI SQLite. Mobile: default sqflite factory.
  await DatabaseService.initializeFactory();

  final database = await DatabaseService.instance.database;
  final repository = EduBridgeRepository(database);
  final store = AppStore(repository);
  await store.load();
  await store.ensureDemoAccountsIfNeeded();

  runApp(EduBridgeApp(store: store));
}

class EduBridgeApp extends StatelessWidget {
  const EduBridgeApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduBridge',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      themeMode: ThemeMode.light,
      home: SplashScreen(store: store),
    );
  }
}
