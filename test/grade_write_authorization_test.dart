import 'package:edubridge/models/firestore_class_subject_teacher.dart';
import 'package:edubridge/models/firestore_teacher.dart';
import 'package:edubridge/services/firestore_staff_repository.dart';
import 'package:edubridge/services/firestore_grade_repository.dart';
import 'package:edubridge/services/grade_write_authorization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const auth = GradeWriteAuthorization();

  FirestoreTeacher teacher({
    required String id,
    required String schoolId,
    String? authUid,
    String fullName = 'Bold',
  }) {
    return FirestoreTeacher(
      id: id,
      schoolId: schoolId,
      fullName: fullName,
      authUid: authUid,
    );
  }

  FirestoreClassSubjectTeacher assignment({
    required String schoolId,
    required String classId,
    required int subjectId,
    required String teacherId,
  }) {
    return FirestoreClassSubjectTeacher(
      id: FirestoreClassSubjectTeacher.documentId(
        schoolId: schoolId,
        classId: classId,
        subjectId: subjectId,
      ),
      schoolId: schoolId,
      classId: classId,
      subjectId: subjectId,
      teacherId: teacherId,
    );
  }

  group('GradeWriteAuthorization', () {
    test('assigned Math teacher can create a Math grade for 12a', () {
      const schoolId = 'sch-1';
      const classId = '12a';
      const subjectId = 10;
      const teacherId = 'tch-bold';
      const uid = 'firebase-bold-uid';

      final allowed = auth.canCreateGrade(
        authUid: uid,
        schoolId: schoolId,
        classId: classId,
        subjectId: subjectId,
        gradeTeacherId: teacherId,
        teacherDoc: teacher(id: teacherId, schoolId: schoolId, authUid: uid),
        assignmentDoc: assignment(
          schoolId: schoolId,
          classId: classId,
          subjectId: subjectId,
          teacherId: teacherId,
        ),
        membershipRole: 'teacher',
        membershipActive: true,
        membershipSchoolId: schoolId,
      );
      expect(allowed, isTrue);
    });

    test('unassigned teacher is denied', () {
      const schoolId = 'sch-1';
      const uid = 'firebase-other-uid';
      final allowed = auth.canCreateGrade(
        authUid: uid,
        schoolId: schoolId,
        classId: '12a',
        subjectId: 10,
        gradeTeacherId: 'tch-other',
        teacherDoc: teacher(
          id: 'tch-other',
          schoolId: schoolId,
          authUid: uid,
          fullName: 'Other',
        ),
        // Assignment is for Bold, not this teacher.
        assignmentDoc: assignment(
          schoolId: schoolId,
          classId: '12a',
          subjectId: 10,
          teacherId: 'tch-bold',
        ),
        membershipRole: 'teacher',
        membershipActive: true,
        membershipSchoolId: schoolId,
      );
      expect(allowed, isFalse);
    });

    test('teacher from another school is denied', () {
      const uid = 'firebase-bold-uid';
      final allowed = auth.canCreateGrade(
        authUid: uid,
        schoolId: 'sch-a',
        classId: '12a',
        subjectId: 10,
        gradeTeacherId: 'tch-bold',
        teacherDoc: teacher(
          id: 'tch-bold',
          schoolId: 'sch-b',
          authUid: uid,
        ),
        assignmentDoc: assignment(
          schoolId: 'sch-a',
          classId: '12a',
          subjectId: 10,
          teacherId: 'tch-bold',
        ),
        membershipRole: 'teacher',
        membershipActive: true,
        membershipSchoolId: 'sch-a',
      );
      expect(allowed, isFalse);
    });

    test('admin can save', () {
      final allowed = auth.canCreateGrade(
        authUid: 'firebase-admin-uid',
        schoolId: 'sch-1',
        classId: '12a',
        subjectId: 10,
        gradeTeacherId: 'tch-any',
        teacherDoc: null,
        assignmentDoc: null,
        membershipRole: 'schoolAdmin',
        membershipActive: true,
        membershipSchoolId: 'sch-1',
      );
      expect(allowed, isTrue);
    });

    test('matching by display name alone does not grant access', () {
      expect(
        auth.canCreateByDisplayNameAlone(
          authUid: 'uid-1',
          teacherFullName: 'Bold',
          requestedName: 'Bold',
        ),
        isFalse,
      );

      // Same name, but authUid not linked on teacher doc.
      final allowed = auth.canCreateGrade(
        authUid: 'firebase-uid',
        schoolId: 'sch-1',
        classId: '12a',
        subjectId: 10,
        gradeTeacherId: 'tch-bold',
        teacherDoc: teacher(
          id: 'tch-bold',
          schoolId: 'sch-1',
          authUid: null,
          fullName: 'Bold',
        ),
        assignmentDoc: assignment(
          schoolId: 'sch-1',
          classId: '12a',
          subjectId: 10,
          teacherId: 'tch-bold',
        ),
        membershipRole: 'teacher',
        membershipActive: true,
        membershipSchoolId: 'sch-1',
      );
      expect(allowed, isFalse);
    });

    test('correct auth uid mapping grants access', () {
      const uid = 'firebase-bold-uid';
      final allowed = auth.canCreateGrade(
        authUid: uid,
        schoolId: 'sch-1',
        classId: '12a',
        subjectId: 10,
        gradeTeacherId: 'tch-bold',
        teacherDoc: teacher(
          id: 'tch-bold',
          schoolId: 'sch-1',
          authUid: uid,
        ),
        assignmentDoc: assignment(
          schoolId: 'sch-1',
          classId: '12a',
          subjectId: 10,
          teacherId: 'tch-bold',
        ),
        membershipRole: 'teacher',
        membershipActive: true,
        membershipSchoolId: 'sch-1',
      );
      expect(allowed, isTrue);
    });
  });

  group('FirestoreStaffRepository authUid sync', () {
    test('upserts teacher with authUid and assignment by stable IDs', () async {
      final memory = MemoryGradeDocumentStore();
      final staff = FirestoreStaffRepository(store: memory);

      await staff.upsertTeacher(
        teacher(
          id: 'tch-bold',
          schoolId: 'sch-1',
          authUid: 'firebase-bold-uid',
        ),
      );
      await staff.upsertAssignment(
        assignment(
          schoolId: 'sch-1',
          classId: '12a',
          subjectId: 10,
          teacherId: 'tch-bold',
        ),
      );

      final teacherDoc = await staff.getTeacher('tch-bold');
      expect(teacherDoc?.authUid, 'firebase-bold-uid');
      expect(teacherDoc?.id, 'tch-bold');

      final assignmentDoc = await staff.getAssignment(
        schoolId: 'sch-1',
        classId: '12a',
        subjectId: 10,
      );
      expect(assignmentDoc?.teacherId, 'tch-bold');
      expect(assignmentDoc?.classId, '12a');
      expect(assignmentDoc?.subjectId, 10);

      final path = FirestoreTeacher.pathFor('tch-bold');
      final raw = await memory.get(path);
      expect(raw?[FirestoreTeacher.authUidField], 'firebase-bold-uid');
      expect(raw?.containsKey('userId'), isFalse);
    });
  });
}
