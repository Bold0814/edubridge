import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/auth/login_screen.dart';
import 'package:edubridge/screens/onboarding/create_school_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppStore store;

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    store = AppStore(EduBridgeRepository(database));
    await store.load();
    await store.ensureDemoAccountsIfNeeded();
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('public label is Сургууль бүртгүүлэх хүсэлт', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen(store: store)));
    expect(find.text('Сургууль бүртгүүлэх хүсэлт'), findsOneWidget);
    expect(find.text('Шинэ сургууль үүсгэх'), findsNothing);
  });

  testWidgets('release-style public tap cannot open direct school creation', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen(store: store)));
    await tester.pumpAndSettle();

    final schoolsBefore = store.schools.length;

    await tester.tap(find.text('Сургууль бүртгүүлэх хүсэлт'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateSchoolScreen), findsNothing);
    expect(
      find.textContaining('Онлайн хүсэлтийн систем удахгүй идэвхжинэ'),
      findsOneWidget,
    );
    expect(store.schools.length, schoolsBefore);
  });

  testWidgets('debug flow may open test school creation', (tester) async {
    expect(kDebugMode, isTrue);

    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(home: LoginScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('Туршилтын сургууль үүсгэх'), findsOneWidget);
    await tester.ensureVisible(find.text('Туршилтын сургууль үүсгэх'));
    await tester.tap(find.text('Туршилтын сургууль үүсгэх'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateSchoolScreen), findsOneWidget);
  });

  test('existing admin login remains unchanged', () async {
    final result = await store.login(
      username: 'admin1',
      password: 'test123',
      rememberMe: false,
    );
    expect(result, LoginResult.success);
    expect(store.authenticatedUser?.username, 'admin1');
  });

  test(
    'existing school data is not modified by login screen presence',
    () async {
      final before = store.schools.map((s) => s.id).toList();
      await store.ensureDemoAccountsIfNeeded();
      expect(store.schools.map((s) => s.id).toList(), before);
    },
  );
}
