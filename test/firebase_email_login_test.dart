import 'package:edubridge/models/app_role.dart';
import 'package:edubridge/models/firestore_school.dart';
import 'package:edubridge/models/firestore_school_membership.dart';
import 'package:edubridge/models/firestore_user_profile.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/firebase_auth_service.dart';
import 'package:edubridge/services/firestore_identity_repository.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late MemoryIdentityDocumentStore identityStore;
  late FirestoreIdentityRepository identity;
  late AppStore store;

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    identityStore = MemoryIdentityDocumentStore();
    identity = FirestoreIdentityRepository(store: identityStore);
    store = AppStore(
      EduBridgeRepository(database),
      firestoreIdentity: identity,
      firebaseEmailSignIn: ({required email, required password}) async {
        if (email == 'admin3@test.com' && password == 'Admin2026') {
          return const FirebaseEmailSession(
            uid: 'uid-admin3',
            email: 'admin3@test.com',
            displayName: 'Admin Three',
          );
        }
        throw FirebaseAuthServiceException(
          FirebaseAuthService.invalidCredentialMessage,
          code: 'invalid-credential',
        );
      },
    );
    await store.load();
    await store.ensureDemoAccountsIfNeeded();

    await identity.createSchool(
      schoolId: 'TEST001',
      name: 'EduBridge Туршилтын сургууль',
      code: 'TEST001',
      status: FirestoreSchoolStatus.active,
      createdByUid: 'uid-admin3',
    );
    await identity.createUserProfile(
      uid: 'uid-admin3',
      displayName: 'Admin Three',
      internalEmail: 'admin3@test.com',
      role: FirestoreUserRole.schoolAdmin,
      status: FirestoreUserStatus.active,
    );
    await identity.createMembership(
      schoolId: 'TEST001',
      uid: 'uid-admin3',
      role: FirestoreUserRole.schoolAdmin.wireValue,
      status: FirestoreMembershipStatus.active,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'admin email/password logs in via Firebase without local hash',
    () async {
      final result = await store.login(
        username: 'admin3@test.com',
        password: 'Admin2026',
        rememberMe: false,
      );

      expect(result, LoginResult.success);
      expect(store.authenticatedUser?.username, 'admin3@test.com');
      expect(store.authenticatedUser?.role, AppRole.admin);
      expect(store.authenticatedUser?.id, 'fb_uid-admin3');
      expect(
        store.activeMembershipsForUser(store.authenticatedUser!.id),
        isNotEmpty,
      );
      expect(
        store
            .activeMembershipsForUser(store.authenticatedUser!.id)
            .first
            .schoolId,
        'TEST001',
      );
    },
  );

  test('Firebase auth failure surfaces Firebase error detail', () async {
    final result = await store.login(
      username: 'admin3@test.com',
      password: 'WrongPass1',
      rememberMe: false,
    );

    expect(result, LoginResult.invalidCredentials);
    expect(
      store.loginErrorDetail,
      FirebaseAuthService.invalidCredentialMessage,
    );
    expect(store.authenticatedUser, isNull);
  });

  test('guardian local PIN login remains unchanged', () async {
    final result = await store.login(
      username: 'guardian1',
      password: 'test123',
      rememberMe: false,
    );
    expect(result, LoginResult.success);
    expect(store.authenticatedUser?.role, AppRole.guardian);
  });
}
