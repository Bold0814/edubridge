import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'repositories/edubridge_repository.dart';
import 'screens/splash_screen.dart';
import 'services/database_service.dart';
import 'services/firestore_grade_repository.dart';
import 'services/firestore_staff_repository.dart';
import 'services/sqlite_grade_repository.dart';
import 'services/synced_grade_repository.dart';
import 'state/app_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Desktop / tests: FFI SQLite. Mobile: default sqflite factory.
  await DatabaseService.initializeFactory();

  final database = await DatabaseService.instance.database;
  final repository = EduBridgeRepository(database);
  final firestoreDocs = FirestoreGradeDocumentStore();
  final gradeRepository = SyncedGradeRepository(
    primary: FirestoreGradeRepository(store: firestoreDocs),
    mirror: SqliteGradeRepository(repository),
  );
  final store = AppStore(
    repository,
    gradeRepository: gradeRepository,
    firestoreStaff: FirestoreStaffRepository(store: firestoreDocs),
  );
  await store.load();
  await store.ensureDemoAccountsIfNeeded();
  // Backfill Firebase Auth + Firestore authUid for any legacy local accounts.
  await store.ensureCloudAuthForAccountsMissingUid();

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
