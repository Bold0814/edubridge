import 'package:edubridge/screens/admin/firebase_auth_debug_dialog.dart';
import 'package:edubridge/services/firebase_auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirebaseAuthService internal emails', () {
    test('teacher email normalization', () {
      expect(
        FirebaseAuthService.teacherInternalEmail('99112233'),
        '99112233@teacher.edubridge.local',
      );
      expect(
        FirebaseAuthService.teacherInternalEmail(' 99-11 22 33 '),
        '99112233@teacher.edubridge.local',
      );
      expect(
        FirebaseAuthService.teacherInternalEmail('+976 9911-2233'),
        '97699112233@teacher.edubridge.local',
      );
    });

    test('guardian email normalization', () {
      expect(
        FirebaseAuthService.guardianInternalEmail('99112233'),
        '99112233@guardian.edubridge.local',
      );
      expect(
        FirebaseAuthService.guardianInternalEmail(' (9911) 2233 '),
        '99112233@guardian.edubridge.local',
      );
    });

    test('student code normalization', () {
      expect(
        FirebaseAuthService.studentInternalEmail('133-s0001'),
        '133-s0001@student.edubridge.local',
      );
      expect(
        FirebaseAuthService.studentInternalEmail(' 133 - S0001 '),
        '133-s0001@student.edubridge.local',
      );
      expect(
        FirebaseAuthService.studentInternalEmail('133––S0001'),
        '133-s0001@student.edubridge.local',
      );
      expect(
        FirebaseAuthService.normalizeStudentCode('133—S0001'),
        '133-s0001',
      );
    });

    test('admin email normalization', () {
      expect(
        FirebaseAuthService.adminInternalEmail('admin'),
        'admin@admin.edubridge.local',
      );
      expect(
        FirebaseAuthService.adminInternalEmail(' Admin '),
        'admin@admin.edubridge.local',
      );
      expect(
        FirebaseAuthService.adminInternalEmail('School Admin'),
        'schooladmin@admin.edubridge.local',
      );
    });
  });

  group('FirebaseAuthService password policy', () {
    test('admin/teacher password requires 8+ with letter and digit', () {
      expect(
        FirebaseAuthService.meetsAdminTeacherPasswordPolicy('Abcd1234'),
        isTrue,
      );
      expect(
        FirebaseAuthService.meetsAdminTeacherPasswordPolicy('short1A'),
        isFalse,
      );
      expect(
        FirebaseAuthService.meetsAdminTeacherPasswordPolicy('abcdefgh'),
        isFalse,
      );
      expect(
        FirebaseAuthService.meetsAdminTeacherPasswordPolicy('12345678'),
        isFalse,
      );
      expect(
        FirebaseAuthService.meetsAdminTeacherPasswordPolicy('1234'),
        isFalse,
      );
    });

    test('createAccount rejects weak local password before Firebase', () async {
      final service = FirebaseAuthService();
      await expectLater(
        service.createAccount(
          internalEmail: FirebaseAuthService.adminInternalEmail('admin'),
          password: '1234',
        ),
        throwsA(
          isA<FirebaseAuthServiceException>().having(
            (e) => e.message,
            'message',
            FirebaseAuthService.weakPasswordMessage,
          ),
        ),
      );
    });
  });

  group('FirebaseAuthService error mapping', () {
    test('maps Firebase Auth codes to Mongolian messages', () {
      expect(
        FirebaseAuthService.messageForAuthCode('email-already-in-use'),
        'Энэ нэвтрэх мэдээлэл бүртгэлтэй байна.',
      );
      expect(
        FirebaseAuthService.messageForAuthCode('weak-password'),
        'Нууц үг шаардлага хангахгүй байна.',
      );
      expect(
        FirebaseAuthService.messageForAuthCode('invalid-credential'),
        'Нэвтрэх мэдээлэл буруу байна.',
      );
      expect(
        FirebaseAuthService.messageForAuthCode('wrong-password'),
        'Нэвтрэх мэдээлэл буруу байна.',
      );
      expect(
        FirebaseAuthService.messageForAuthCode('user-not-found'),
        'Нэвтрэх мэдээлэл буруу байна.',
      );
      expect(
        FirebaseAuthService.messageForAuthCode('network-request-failed'),
        'Сүлжээний алдаа гарлаа.',
      );
      expect(
        FirebaseAuthService.messageForAuthCode('too-many-requests'),
        'Олон удаа оролдлоо. Түр хүлээгээд дахин оролдоно уу.',
      );
      expect(
        FirebaseAuthService.messageForAuthCode('something-else'),
        'Нэвтрэх үед алдаа гарлаа.',
      );
    });
  });

  group('Firebase Auth debug UI gate', () {
    test('debug action hidden in release mode', () {
      expect(
        FirebaseAuthService.isDebugAuthCheckEnabled(forceDebugMode: false),
        isFalse,
      );
      expect(
        FirebaseAuthService.isDebugAuthCheckEnabled(forceDebugMode: true),
        isTrue,
      );
    });

    test('flutter_test runs as debug so gate matches kDebugMode', () {
      expect(kDebugMode, isTrue);
      expect(FirebaseAuthService.isDebugAuthCheckEnabled(), isTrue);
    });

    test('debug dialog labels are Mongolian', () {
      expect(FirebaseAuthDebugDialog.title, 'Firebase Auth шалгах');
      expect(FirebaseAuthDebugDialog.createButtonLabel, 'Туршилтын эрх үүсгэх');
      expect(FirebaseAuthDebugDialog.signInButtonLabel, 'Нэвтрэх');
      expect(FirebaseAuthDebugDialog.signOutButtonLabel, 'Гарах');
      expect(
        FirebaseAuthDebugDialog.deleteTestUserButtonLabel,
        'Туршилтын хэрэглэгч устгах',
      );
      expect(
        FirebaseAuthDebugDialog.invalidEmailMessage,
        'Зөв имэйл хаяг оруулна уу.',
      );
      expect(FirebaseAuthService.debugTestUserEmail, 'admin@test.com');
    });
  });
}
