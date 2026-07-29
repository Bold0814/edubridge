import 'package:edubridge/models/firestore_school.dart';
import 'package:edubridge/models/firestore_school_membership.dart';
import 'package:edubridge/models/firestore_user_profile.dart';
import 'package:edubridge/services/firestore_identity_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestoreSchool', () {
    test('normalizes school code to uppercase without spaces', () {
      expect(FirestoreSchool.normalizeCode(' test 001 '), 'TEST001');
      expect(FirestoreSchool.normalizeCode('ab-12'), 'AB-12');
      expect(FirestoreSchool.normalizeCode('  te st '), 'TEST');
    });

    test('rejects empty school name and uid', () {
      expect(
        () => FirestoreSchool.validate(
          name: '  ',
          code: 'TEST001',
          createdByUid: 'uid-1',
          status: FirestoreSchoolStatus.active,
        ),
        throwsArgumentError,
      );
      expect(
        () => FirestoreSchool.validate(
          name: 'School',
          code: 'TEST001',
          createdByUid: '',
          status: FirestoreSchoolStatus.active,
        ),
        throwsArgumentError,
      );
    });

    test('rejects unsupported school status', () {
      expect(
        () => FirestoreSchoolStatus.parse('archived'),
        throwsArgumentError,
      );
      expect(
        FirestoreSchoolStatus.parse('active'),
        FirestoreSchoolStatus.active,
      );
    });

    test('serializes and deserializes school', () {
      final school = FirestoreSchool(
        id: 'TEST001',
        name: 'EduBridge Туршилтын сургууль',
        code: 'test001',
        status: FirestoreSchoolStatus.active,
        createdByUid: 'uid-1',
      );
      final map = school.toCreateMap(
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
      );
      expect(map.containsKey('password'), isFalse);
      expect(map.containsKey('pin'), isFalse);
      expect(map['code'], 'TEST001');
      expect(map['schemaVersion'], 1);

      final roundTrip = FirestoreSchool.fromMap('TEST001', map);
      expect(roundTrip.name, 'EduBridge Туршилтын сургууль');
      expect(roundTrip.code, 'TEST001');
      expect(roundTrip.status, FirestoreSchoolStatus.active);
      expect(roundTrip.createdByUid, 'uid-1');
    });
  });

  group('FirestoreUserProfile', () {
    test('rejects empty uid and unsupported roles/status', () {
      expect(
        () => FirestoreUserProfile.validate(
          uid: '',
          displayName: 'A',
          internalEmail: 'a@test.com',
          role: FirestoreUserRole.schoolAdmin,
          status: FirestoreUserStatus.active,
        ),
        throwsArgumentError,
      );
      expect(() => FirestoreUserRole.parse('superuser'), throwsArgumentError);
      expect(() => FirestoreUserStatus.parse('banned'), throwsArgumentError);
      expect(
        FirestoreUserRole.parse('schoolAdmin'),
        FirestoreUserRole.schoolAdmin,
      );
      expect(
        FirestoreUserStatus.parse('pendingActivation'),
        FirestoreUserStatus.pendingActivation,
      );
    });

    test('serializes and deserializes user profile without secrets', () {
      final profile = FirestoreUserProfile(
        uid: 'uid-1',
        displayName: 'Admin',
        internalEmail: 'Admin@Test.com',
        role: FirestoreUserRole.schoolAdmin,
        status: FirestoreUserStatus.active,
      );
      final map = profile.toCreateMap(
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(map['internalEmail'], 'admin@test.com');
      expect(map.containsKey('password'), isFalse);
      expect(map.containsKey('pin'), isFalse);

      final roundTrip = FirestoreUserProfile.fromMap('uid-1', map);
      expect(roundTrip.role, FirestoreUserRole.schoolAdmin);
      expect(roundTrip.status, FirestoreUserStatus.active);
      expect(roundTrip.internalEmail, 'admin@test.com');
    });
  });

  group('FirestoreSchoolMembership', () {
    test('uses deterministic membership id', () {
      expect(
        FirestoreSchoolMembership.membershipId(
          schoolId: 'TEST001',
          uid: 'uid-abc',
        ),
        'TEST001_uid-abc',
      );
      expect(
        FirestoreSchoolMembership.membershipId(
          schoolId: ' TEST001 ',
          uid: ' uid-abc ',
        ),
        'TEST001_uid-abc',
      );
    });

    test('rejects unsupported membership status', () {
      expect(
        () => FirestoreMembershipStatus.parse('invited'),
        throwsArgumentError,
      );
      expect(
        FirestoreMembershipStatus.parse('disabled'),
        FirestoreMembershipStatus.disabled,
      );
    });

    test('serializes and deserializes membership', () {
      final membership = FirestoreSchoolMembership(
        id: 'TEST001_uid-1',
        schoolId: 'TEST001',
        uid: 'uid-1',
        role: 'schoolAdmin',
        status: FirestoreMembershipStatus.active,
      );
      final map = membership.toCreateMap(
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final roundTrip = FirestoreSchoolMembership.fromMap('TEST001_uid-1', map);
      expect(roundTrip.schoolId, 'TEST001');
      expect(roundTrip.uid, 'uid-1');
      expect(roundTrip.role, 'schoolAdmin');
      expect(roundTrip.status, FirestoreMembershipStatus.active);
    });
  });

  group('FirestoreIdentityRepository', () {
    test('repeated debug setup does not duplicate documents', () async {
      final store = MemoryIdentityDocumentStore();
      final repo = FirestoreIdentityRepository(store: store);
      final setup = FirestoreIdentityDebugSetup(
        repository: repo,
        forceDebugMode: true,
      );

      final first = await setup.run(
        uid: 'uid-1',
        displayName: 'Admin',
        internalEmail: 'admin@test.com',
      );
      expect(first.success, isTrue);
      expect(store.documents.length, 3);
      final pathsAfterFirst = store.documents.keys.toSet();
      final setCountAfterFirst = store.setCount;

      final second = await setup.run(
        uid: 'uid-1',
        displayName: 'Admin',
        internalEmail: 'admin@test.com',
      );
      expect(second.success, isTrue);
      expect(store.documents.keys.toSet(), pathsAfterFirst);
      expect(store.documents.length, 3);
      // Updates merge into existing docs; no new document keys.
      expect(store.setCount, greaterThan(setCountAfterFirst));

      final school = await repo.getSchool('TEST001');
      final profile = await repo.getUserProfile('uid-1');
      final membership = await repo.getMembership(
        schoolId: 'TEST001',
        uid: 'uid-1',
      );
      expect(school?.code, 'TEST001');
      expect(profile?.role, FirestoreUserRole.schoolAdmin);
      expect(membership?.id, 'TEST001_uid-1');
      expect(
        store.documents.keys,
        containsAll(<String>[
          'schools/TEST001',
          'users/uid-1',
          'school_memberships/TEST001_uid-1',
        ]),
      );
    });

    test('debug action is hidden in release mode', () async {
      final store = MemoryIdentityDocumentStore();
      final setup = FirestoreIdentityDebugSetup(
        repository: FirestoreIdentityRepository(store: store),
        forceDebugMode: false,
      );
      final result = await setup.run(
        uid: 'uid-1',
        displayName: 'Admin',
        internalEmail: 'admin@test.com',
      );
      expect(result.success, isFalse);
      expect(result.message, FirestoreIdentityDebugSetup.releaseBlockedMessage);
      expect(store.documents, isEmpty);
      expect(
        FirestoreIdentityDebugSetup.isDebugActionEnabled(forceDebugMode: false),
        isFalse,
      );
    });

    test('requires signed-in uid', () async {
      final setup = FirestoreIdentityDebugSetup(
        repository: FirestoreIdentityRepository(
          store: MemoryIdentityDocumentStore(),
        ),
        forceDebugMode: true,
      );
      final result = await setup.run(
        uid: '',
        displayName: 'Admin',
        internalEmail: 'admin@test.com',
      );
      expect(result.success, isFalse);
      expect(result.message, FirestoreIdentityDebugSetup.notSignedInMessage);
    });
  });
}
