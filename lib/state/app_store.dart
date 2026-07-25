import 'package:flutter/foundation.dart';

import '../models/account_status.dart';
import '../models/announcement.dart';
import '../models/app_role.dart';
import '../models/app_settings.dart';
import '../models/attendance_record.dart';
import '../models/class_subject_teacher.dart';
import '../models/grade.dart';
import '../models/guardian.dart';
import '../models/guardian_student.dart';
import '../models/homework.dart';
import '../models/school.dart';
import '../models/school_class.dart';
import '../models/school_settings.dart';
import '../models/student.dart';
import '../models/subject.dart';
import '../models/teacher.dart';
import '../models/teacher_assigned_class.dart';
import '../models/teacher_note.dart';
import '../models/timetable.dart';
import '../models/user_account.dart';
import '../repositories/edubridge_repository.dart';
import '../services/database_service.dart';
import '../services/password_hasher.dart';
import '../services/phone_normalizer.dart';
import '../services/pin_rules.dart';
import '../services/student_login_ids.dart';

enum SchoolResolveKind { none, single, multiple }

class SchoolResolveResult {
  const SchoolResolveResult._({
    required this.kind,
    this.membership,
    this.memberships,
  });

  final SchoolResolveKind kind;
  final UserSchoolMembership? membership;
  final List<UserSchoolMembership>? memberships;

  factory SchoolResolveResult.none() =>
      const SchoolResolveResult._(kind: SchoolResolveKind.none);

  factory SchoolResolveResult.single(UserSchoolMembership membership) =>
      SchoolResolveResult._(
        kind: SchoolResolveKind.single,
        membership: membership,
      );

  factory SchoolResolveResult.multiple(
    List<UserSchoolMembership> memberships,
  ) => SchoolResolveResult._(
    kind: SchoolResolveKind.multiple,
    memberships: memberships,
  );
}

enum LoginResult {
  success,
  missingUsername,
  missingPassword,
  invalidCredentials,
  inactive,
  pendingActivation,
}

extension LoginResultMessage on LoginResult {
  String get message {
    switch (this) {
      case LoginResult.success:
        return '';
      case LoginResult.missingUsername:
        return 'Нэвтрэх нэрээ оруулна уу';
      case LoginResult.missingPassword:
        return 'PIN эсвэл нууц үгээ оруулна уу';
      case LoginResult.invalidCredentials:
        return 'Нэвтрэх нэр эсвэл PIN буруу байна.';
      case LoginResult.inactive:
        return 'Энэ бүртгэл идэвхгүй байна';
      case LoginResult.pendingActivation:
        return 'Энэ бүртгэл идэвхжээгүй байна. Анх удаа нэвтрэх хэсгээр орно уу.';
    }
  }
}

/// Result of first-time activation identity checks (before PIN creation).
enum ActivationLookupResult { ok, mismatch, alreadyActive }

/// In-memory cache synchronized with SQLite through [EduBridgeRepository].
class AppStore extends ChangeNotifier {
  AppStore(this._repository);

  final EduBridgeRepository _repository;

  /// Used by debug-only developer tools for batch SQLite access.
  EduBridgeRepository get repository => _repository;

  static const defaultSchoolId = DatabaseService.defaultSchoolId;
  static const _prefLastRole = 'last_role';
  static const _prefGuardianStudentId = 'guardian_student_id';
  static const _prefDevUserId = 'dev_user_id';
  static const _prefLastSchoolId = 'last_school_id';
  static const _prefRememberSession = 'remember_session';

  List<School> _schools = const [];
  List<UserSchoolMembership> _memberships = const [];
  ActiveAppContext _activeContext = ActiveAppContext.empty;

  List<SchoolClass> _schoolClasses = const [];
  List<Announcement> _announcements = [];
  List<Homework> _homework = [];
  List<Grade> _grades = [];
  List<TeacherNote> _teacherNotes = [];
  List<LessonPeriod> _lessonPeriods = [];
  List<ClassTimetable> _classTimetable = [];
  List<Subject> _subjectModels = const [];
  List<Teacher> _teachers = const [];
  List<ClassSubjectTeacher> _assignments = const [];
  List<Guardian> _guardians = const [];
  List<GuardianStudent> _guardianStudentLinks = const [];
  List<UserAccount> _userAccounts = const [];
  SchoolSettings _schoolSettings = SchoolSettings.defaults;
  AppSettings _settings = AppSettings.defaults;
  final Map<String, List<AttendanceRecord>> _attendanceByClass = {};
  final Map<String, List<Student>> _studentsByClass = {};
  final Map<String, String?> _journalSubjectByClass = {};
  final Map<String, String?> _journalTermByClass = {};
  final Set<String> _unreadAnnouncementIds = {};
  final Set<String> _guardianReadAnnouncementIds = {};

  AppRole? _lastRole;
  String? _guardianStudentId;
  String? _selectedDevUserId;
  bool _rememberSession = false;

  int _studentIdCounter = 1000;
  int _announcementIdCounter = 100;
  int _homeworkIdCounter = 100;
  int _gradeIdCounter = 100;
  int _attendanceIdCounter = 100;
  int _teacherNoteIdCounter = 100;
  int _lessonPeriodIdCounter = 100;
  int _classTimetableIdCounter = 100;
  int _teacherIdCounter = 100;
  int _guardianIdCounter = 100;
  int _userIdCounter = 100;
  int _membershipIdCounter = 100;
  int _schoolIdCounter = 100;

  bool isLoaded = false;

  ActiveAppContext get activeContext => _activeContext;

  String? get activeSchoolId => _activeContext.schoolId;

  School? get activeSchool {
    final id = activeSchoolId;
    if (id == null) return null;
    for (final school in _schools) {
      if (school.id == id) return school;
    }
    return null;
  }

  List<School> get schools => List.unmodifiable(_schools);

  List<School> get activeSchools =>
      _schools.where((s) => s.isActive).toList(growable: false);

  List<SchoolClass> get _visibleSchoolClasses {
    final schoolId = activeSchoolId;
    if (schoolId == null) return _schoolClasses;
    return _schoolClasses
        .where((c) => c.schoolId == schoolId)
        .toList(growable: false);
  }

  bool _matchesActiveSchool(String schoolId) {
    final active = activeSchoolId;
    return active == null || active == schoolId;
  }

  AppRole? get lastRole => _lastRole;

  AppRole? get selectedDevelopmentRole => _lastRole;

  UserAccount? get selectedDevelopmentUser {
    final id = _selectedDevUserId;
    if (id == null) return null;
    return userById(id);
  }

  /// Alias for the authenticated local session user.
  UserAccount? get authenticatedUser => selectedDevelopmentUser;

  bool get rememberSession => _rememberSession;

  /// True when a remembered active session can resume past Login.
  bool get hasValidRememberedSession {
    if (!_rememberSession) return false;
    final user = selectedDevelopmentUser;
    return user != null && user.isActive;
  }

  String? get guardianStudentId => _guardianStudentId;

  Student? get selectedGuardianStudent {
    final id = _guardianStudentId;
    if (id == null) return null;
    return studentById(id);
  }

  List<Student> get allStudents {
    final list = <Student>[
      for (final students in _studentsByClass.values) ...students,
    ];
    list.sort((a, b) {
      final byClass = a.className.compareTo(b.className);
      if (byClass != 0) return byClass;
      return a.fullName.compareTo(b.fullName);
    });
    return List.unmodifiable(list);
  }

  /// Students linked to the active guardian within the selected school only.
  List<Student> get guardianPortalStudents {
    final guardianId =
        _activeContext.guardianId ?? selectedDevelopmentUser?.guardianId;
    if (guardianId == null) return const [];
    final linked = studentsForGuardian(guardianId);
    final schoolId = activeSchoolId;
    if (schoolId == null) return linked;
    final classIds = _schoolClasses
        .where((c) => c.schoolId == schoolId)
        .map((c) => c.id)
        .toSet();
    return linked
        .where((s) => classIds.contains(s.className))
        .toList(growable: false);
  }

  /// Homeroom classes for the active teacher in the selected school.
  List<SchoolClass> homeroomClassesForActiveTeacher() {
    final teacherId = _activeContext.teacherId;
    if (teacherId == null) return const [];
    return _visibleSchoolClasses
        .where((c) => c.homeroomTeacherId == teacherId)
        .toList(growable: false);
  }

  /// Subject teaching assignments for the active teacher in the selected school.
  List<({SchoolClass schoolClass, Subject subject})>
  teachingAssignmentsForActiveTeacher() {
    final teacherId = _activeContext.teacherId;
    if (teacherId == null) return const [];
    final classById = {for (final c in _visibleSchoolClasses) c.id: c};
    final result = <({SchoolClass schoolClass, Subject subject})>[];
    for (final assignment in _assignments) {
      if (assignment.teacherId != teacherId) continue;
      final schoolClass = classById[assignment.classId];
      final subject = subjectById(assignment.subjectId);
      if (schoolClass == null || subject == null || !subject.isActive) continue;
      if (!_matchesActiveSchool(subject.schoolId)) continue;
      result.add((schoolClass: schoolClass, subject: subject));
    }
    result.sort((a, b) {
      final byClass = a.schoolClass.name.compareTo(b.schoolClass.name);
      if (byClass != 0) return byClass;
      return a.subject.name.compareTo(b.subject.name);
    });
    return result;
  }

  /// Classes the active teacher may open (homeroom ∪ subject assignments).
  ///
  /// Deduplicated by class id. Uses [activeContext.teacherId] + [activeSchoolId]
  /// — never the admin all-class list.
  List<TeacherAssignedClass> assignedClassesForActiveTeacher() {
    final teacherId = _activeContext.teacherId;
    if (teacherId == null) return const [];

    final byClassId = <String, TeacherAssignedClass>{};

    for (final schoolClass in homeroomClassesForActiveTeacher()) {
      byClassId[schoolClass.id] = TeacherAssignedClass(
        schoolClass: schoolClass,
        isHomeroom: true,
        subjects: const [],
      );
    }

    for (final item in teachingAssignmentsForActiveTeacher()) {
      final existing = byClassId[item.schoolClass.id];
      if (existing == null) {
        byClassId[item.schoolClass.id] = TeacherAssignedClass(
          schoolClass: item.schoolClass,
          isHomeroom: false,
          subjects: [item.subject],
        );
      } else if (existing.subjects.every((s) => s.id != item.subject.id)) {
        final subjects = [...existing.subjects, item.subject]
          ..sort((a, b) => a.name.compareTo(b.name));
        byClassId[item.schoolClass.id] = TeacherAssignedClass(
          schoolClass: existing.schoolClass,
          isHomeroom: existing.isHomeroom,
          subjects: subjects,
        );
      }
    }

    final result = byClassId.values.toList()
      ..sort((a, b) => a.className.compareTo(b.className));
    return result;
  }

  TeacherAssignedClass? assignedClassForActiveTeacher(String classId) {
    for (final item in assignedClassesForActiveTeacher()) {
      if (item.classId == classId || item.className == classId) return item;
    }
    return null;
  }

  /// Whether the active teacher is assigned to [classId] (homeroom or subject).
  bool teacherCanAccessClass(String classId) {
    return assignedClassForActiveTeacher(classId) != null;
  }

  /// Subjects the active teacher teaches in [classId] (active subjects only).
  List<Subject> subjectsTaughtByActiveTeacherInClass(String classId) {
    return assignedClassForActiveTeacher(classId)?.subjects ?? const [];
  }

  /// Switch dashboard class and resolve subject context.
  ///
  /// - 1 subject → auto-select
  /// - many subjects → keep current only if it belongs to the class; else null
  ///   (caller may prompt for selection)
  /// - homeroom only → clear subjectId
  ///
  /// Returns false when the teacher cannot access [classId].
  Future<bool> selectTeacherDashboardClass(
    String classId, {
    int? preferredSubjectId,
  }) async {
    final access = assignedClassForActiveTeacher(classId);
    if (access == null) return false;

    final taught = access.subjects;
    int? nextSubjectId;
    if (taught.length == 1) {
      nextSubjectId = taught.first.id;
    } else if (taught.length > 1) {
      final preferred = preferredSubjectId ?? _activeContext.subjectId;
      if (preferred != null && taught.any((s) => s.id == preferred)) {
        nextSubjectId = preferred;
      } else {
        nextSubjectId = null;
      }
    } else {
      nextSubjectId = null;
    }

    await setTeacherWorkspace(classId: classId, subjectId: nextSubjectId);
    if (nextSubjectId != null) {
      final subject = subjectById(nextSubjectId);
      if (subject != null) {
        setJournalSubject(classId, subject.name);
      }
    }
    return true;
  }

  List<UserAccount> get userAccounts => List.unmodifiable(_userAccounts);

  List<UserAccount> get activeUserAccounts =>
      _userAccounts.where((u) => u.isActive).toList(growable: false);

  List<Guardian> get guardians {
    final schoolId = activeSchoolId;
    if (schoolId == null) return List.unmodifiable(_guardians);
    return _guardians
        .where((g) => g.schoolId == schoolId)
        .toList(growable: false);
  }

  List<Guardian> get activeGuardians =>
      guardians.where((g) => g.isActive).toList(growable: false);

  List<GuardianStudent> get guardianStudentLinks =>
      List.unmodifiable(_guardianStudentLinks);

  List<String> get classes =>
      _visibleSchoolClasses.map((c) => c.name).toList(growable: false);

  List<SchoolClass> get schoolClasses =>
      List.unmodifiable(_visibleSchoolClasses);

  List<SchoolClass> get schoolClassesForActiveSchool => schoolClasses;

  /// Active subject names (for dropdowns / existing screens).
  List<String> get subjects =>
      activeSubjects.map((s) => s.name).toList(growable: false);

  List<Subject> get allSubjects {
    final schoolId = activeSchoolId;
    if (schoolId == null) return List.unmodifiable(_subjectModels);
    return _subjectModels
        .where((s) => s.schoolId == schoolId)
        .toList(growable: false);
  }

  List<Subject> get activeSubjects =>
      allSubjects.where((s) => s.isActive).toList(growable: false);

  List<Teacher> get teachers {
    final schoolId = activeSchoolId;
    if (schoolId == null) return List.unmodifiable(_teachers);
    return _teachers
        .where((t) => t.schoolId == schoolId)
        .toList(growable: false);
  }

  List<Teacher> get activeTeachers =>
      teachers.where((t) => t.isActive).toList(growable: false);

  SchoolSettings get schoolSettings => _schoolSettings;

  AppSettings get settings => _settings;

  SchoolClass? schoolClassById(String classId) {
    for (final item in _schoolClasses) {
      if (item.id == classId) return item;
    }
    return null;
  }

  Teacher? teacherById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final teacher in _teachers) {
      if (teacher.id == id) return teacher;
    }
    return null;
  }

  Subject? subjectById(int id) {
    for (final subject in _subjectModels) {
      if (subject.id == id) return subject;
    }
    return null;
  }

  Subject? subjectByName(String name) {
    final schoolId = activeSchoolId;
    for (final subject in _subjectModels) {
      if (subject.name == name) {
        if (schoolId == null || subject.schoolId == schoolId) return subject;
      }
    }
    return null;
  }

  Teacher? homeroomTeacherForClass(String classId) {
    final schoolClass = schoolClassById(classId);
    return teacherById(schoolClass?.homeroomTeacherId);
  }

  Teacher? teacherForClassSubject(String classId, int subjectId) {
    for (final item in _assignments) {
      if (item.classId == classId && item.subjectId == subjectId) {
        return teacherById(item.teacherId);
      }
    }
    return null;
  }

  Teacher? teacherForClassSubjectName(String classId, String? subjectName) {
    if (subjectName == null || subjectName.isEmpty) return null;
    final subject = subjectByName(subjectName);
    if (subject == null) return null;
    return teacherForClassSubject(classId, subject.id);
  }

  String? teacherIdForClassSubject(String classId, int subjectId) {
    for (final item in _assignments) {
      if (item.classId == classId && item.subjectId == subjectId) {
        return item.teacherId;
      }
    }
    return null;
  }

  /// Greeting fragment for a class: "{name} багш" or "Багш".
  String greetingLabelForClass(String classId) {
    final selectedSubject = journalSubjectFor(classId);
    final subjectTeacher = teacherForClassSubjectName(classId, selectedSubject);
    if (subjectTeacher != null) {
      return '${subjectTeacher.fullName} багш';
    }
    final home = homeroomTeacherForClass(classId);
    if (home != null) {
      return '${home.fullName} багш';
    }
    return 'Багш';
  }

  /// Loads all tables from SQLite into memory.
  Future<void> load() async {
    _schools = await _repository.loadSchools();
    _memberships = await _repository.loadMemberships();
    _settings = await _repository.loadSettings();
    // Loaded after prefs restore via _restoreActiveContext / below.
    _subjectModels = await _repository.loadSubjectModels();
    _teachers = await _repository.loadTeachers();
    _assignments = await _repository.loadClassSubjectTeachers();
    _guardians = await _repository.loadGuardians();
    _guardianStudentLinks = await _repository.loadGuardianStudents();
    _userAccounts = await _repository.loadUserAccounts();
    _schoolClasses = await _repository.loadSchoolClasses();

    final students = await _repository.loadStudents();
    final allClassNames = _schoolClasses.map((c) => c.name).toList();
    _studentsByClass
      ..clear()
      ..addEntries(
        {for (final className in allClassNames) className: <Student>[]}.entries,
      );
    for (final student in students) {
      _studentsByClass
          .putIfAbsent(student.className, () => <Student>[])
          .add(student);
    }

    _grades = await _repository.loadGrades();
    _homework = await _repository.loadHomework();
    _announcements = await _repository.loadAnnouncements();
    _teacherNotes = await _repository.loadTeacherNotes();
    _lessonPeriods = await _repository.loadLessonPeriods();
    _classTimetable = await _repository.loadClassTimetable();

    _attendanceByClass
      ..clear()
      ..addEntries(
        {
          for (final className in allClassNames)
            className: <AttendanceRecord>[],
        }.entries,
      );
    final attendance = await _repository.loadAttendance();
    for (final record in attendance) {
      _attendanceByClass
          .putIfAbsent(record.className, () => <AttendanceRecord>[])
          .add(record);
    }

    _syncCountersFromLoadedData();

    _lastRole = AppRole.tryParse(await _repository.getPref(_prefLastRole));
    _guardianStudentId = await _repository.getPref(_prefGuardianStudentId);
    _rememberSession = (await _repository.getPref(_prefRememberSession)) == '1';
    final persistedUserId = await _repository.getPref(_prefDevUserId);
    final lastSchoolId = await _repository.getPref(_prefLastSchoolId);
    _guardianReadAnnouncementIds
      ..clear()
      ..addAll(await _repository.loadGuardianReadAnnouncementIds());

    _selectedDevUserId = null;
    if (_rememberSession && persistedUserId != null) {
      final user = userById(persistedUserId);
      if (user != null && user.isActive) {
        _selectedDevUserId = user.id;
      } else {
        await _clearSessionPrefs();
        _rememberSession = false;
      }
    } else if (!_rememberSession) {
      // Do not restore a signed-in user without "Намайг сана".
      _selectedDevUserId = null;
    }

    await backfillStudentCodesIfNeeded();

    _restoreActiveContext(lastSchoolId: lastSchoolId);
    _schoolSettings = await _repository.loadSchoolSettings(
      schoolId: activeSchoolId ?? defaultSchoolId,
    );

    isLoaded = true;
    notifyListeners();
  }

  void _restoreActiveContext({String? lastSchoolId}) {
    final userId = _selectedDevUserId;
    if (userId == null) {
      _activeContext = ActiveAppContext.empty;
      _ensureGuardianChildSelection();
      return;
    }

    final user = userById(userId);
    if (user == null) {
      _activeContext = ActiveAppContext.empty;
      _ensureGuardianChildSelection();
      return;
    }

    UserSchoolMembership? membership;
    if (lastSchoolId != null && lastSchoolId.isNotEmpty) {
      for (final item in _memberships) {
        if (item.userId == userId &&
            item.schoolId == lastSchoolId &&
            item.isActive) {
          membership = item;
          break;
        }
      }
    }

    if (membership != null) {
      _activeContext = ActiveAppContext(
        userId: userId,
        schoolId: membership.schoolId,
        role: membership.role,
        teacherId: membership.teacherId,
        guardianId: membership.guardianId,
        studentId: membership.studentId,
      );
    } else {
      _activeContext = ActiveAppContext(
        userId: userId,
        role: user.role,
        teacherId: user.teacherId,
        guardianId: user.guardianId,
        studentId: user.studentId,
      );
    }

    _ensureGuardianChildSelection();
  }

  List<UserSchoolMembership> activeMembershipsForUser(String userId) {
    return _memberships
        .where((m) => m.userId == userId && m.isActive)
        .toList(growable: false);
  }

  /// Resolves school memberships for the signed-in user.
  ///
  /// When [preferLastSchool] is true (startup restore), a valid last school
  /// skips the picker even if the user has multiple memberships.
  /// Fresh login should pass `preferLastSchool: false`.
  Future<SchoolResolveResult> resolveSchoolEntry({
    bool preferLastSchool = true,
  }) async {
    final userId = _selectedDevUserId;
    if (userId == null) return SchoolResolveResult.none();
    final memberships = activeMembershipsForUser(userId);
    if (memberships.isEmpty) return SchoolResolveResult.none();
    if (memberships.length == 1) {
      return SchoolResolveResult.single(memberships.first);
    }

    if (preferLastSchool) {
      final lastSchoolId = await _repository.getPref(_prefLastSchoolId);
      if (lastSchoolId != null && lastSchoolId.isNotEmpty) {
        for (final membership in memberships) {
          if (membership.schoolId == lastSchoolId) {
            return SchoolResolveResult.single(membership);
          }
        }
      }
      if (activeSchoolId != null) {
        for (final membership in memberships) {
          if (membership.schoolId == activeSchoolId) {
            return SchoolResolveResult.single(membership);
          }
        }
      }
    }
    return SchoolResolveResult.multiple(memberships);
  }

  Future<void> addSchool(School school) async {
    await _repository.insertSchool(school);
    _schools = [..._schools, school];
    notifyListeners();
  }

  String nextSchoolId() {
    _schoolIdCounter += 1;
    return 'sch-$_schoolIdCounter';
  }

  /// Creates a school + settings row. Idempotent for the same [id].
  Future<School> createSchool({
    required String id,
    required String name,
    String? code,
    String? address,
    required String academicYear,
    required String currentSemester,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('EMPTY_SCHOOL_NAME');
    if (academicYear.trim().isEmpty) throw ArgumentError('EMPTY_YEAR');
    if (currentSemester.trim().isEmpty) throw ArgumentError('EMPTY_SEMESTER');

    for (final existing in _schools) {
      if (existing.id == id) {
        return existing;
      }
    }

    final school = School(
      id: id,
      name: trimmed,
      code: code?.trim().isEmpty == true ? null : code?.trim(),
      address: address?.trim().isEmpty == true ? null : address?.trim(),
    );
    await _repository.insertSchool(school);
    _schools = [..._schools, school];

    final settings = SchoolSettings(
      schoolId: id,
      schoolName: trimmed,
      academicYear: academicYear.trim(),
      currentSemester: currentSemester.trim(),
    );
    await _repository.insertSchoolSettings(settings);
    _schoolSettings = settings;
    notifyListeners();
    return school;
  }

  /// Creates the first administrator for [schoolId] and signs them in.
  Future<UserAccount> createFirstSchoolAdmin({
    required String schoolId,
    required String fullName,
    String? phone,
    String? email,
    required String username,
    required String password,
  }) async {
    final name = fullName.trim();
    if (name.isEmpty) throw ArgumentError('EMPTY_NAME');
    final userName = username.trim();
    if (userName.isEmpty) throw ArgumentError('EMPTY_USERNAME');
    if (password.isEmpty) throw ArgumentError('EMPTY_PASSWORD');
    if (userByUsername(userName) != null) {
      throw ArgumentError('DUPLICATE_USERNAME');
    }

    School? school;
    for (final item in _schools) {
      if (item.id == schoolId) {
        school = item;
        break;
      }
    }
    if (school == null) throw ArgumentError('SCHOOL_NOT_FOUND');

    final teacher = Teacher(
      id: nextTeacherId(),
      schoolId: schoolId,
      fullName: name,
      phone: phone?.trim() ?? '',
      email: email?.trim() ?? '',
    );
    await _repository.insertTeacher(teacher);
    _teachers = [..._teachers, teacher]
      ..sort((a, b) => a.fullName.compareTo(b.fullName));

    final account = UserAccount(
      id: nextUserId(),
      username: userName,
      passwordHash: PasswordHasher.hashPassword(password),
      role: AppRole.admin,
      teacherId: teacher.id,
      createdAt: DateTime.now(),
    );
    _validateUserLinks(account);
    await _repository.insertUserAccount(account);
    _userAccounts = [..._userAccounts, account]
      ..sort((a, b) => a.username.compareTo(b.username));

    final membership = UserSchoolMembership(
      id: nextMembershipId(),
      userId: account.id,
      schoolId: schoolId,
      role: AppRole.admin,
      teacherId: teacher.id,
    );
    await _repository.insertMembership(membership);
    _memberships = [..._memberships, membership];

    await selectDevelopmentUser(account, rememberMe: true);
    await selectSchoolMembership(membership);
    return account;
  }

  Future<void> addSchoolClass({
    required String name,
    String? schoolId,
    String? homeroomTeacherId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('EMPTY_CLASS');
    final sid = schoolId ?? _effectiveSchoolId;
    if (_schoolClasses.any((c) => c.id == trimmed || c.name == trimmed)) {
      throw ArgumentError('DUPLICATE_CLASS');
    }
    final schoolClass = SchoolClass(
      id: trimmed,
      name: trimmed,
      schoolId: sid,
      homeroomTeacherId: homeroomTeacherId,
    );
    await _repository.insertSchoolClass(schoolClass);
    _schoolClasses = [..._schoolClasses, schoolClass]
      ..sort((a, b) => a.name.compareTo(b.name));
    _studentsByClass.putIfAbsent(trimmed, () => <Student>[]);
    _attendanceByClass.putIfAbsent(trimmed, () => <AttendanceRecord>[]);
    notifyListeners();
  }

  /// Students in classes belonging to the active school.
  List<Student> get studentsInActiveSchool {
    final classIds = classes.toSet();
    return allStudents
        .where((s) => classIds.contains(s.className))
        .toList(growable: false);
  }

  /// Active guardian in [schoolId] with the same normalized phone.
  Guardian? findGuardianByPhoneInSchool(String phone, {String? schoolId}) {
    final normalized = PhoneNormalizer.normalize(phone);
    if (normalized.isEmpty) return null;
    final sid = schoolId ?? _effectiveSchoolId;
    for (final guardian in _guardians) {
      if (!guardian.isActive) continue;
      if (guardian.schoolId != sid) continue;
      if (PhoneNormalizer.normalize(guardian.phone) == normalized) {
        return guardian;
      }
    }
    return null;
  }

  /// Finds a guardian [UserAccount] by normalized phone username (login readiness).
  ///
  /// Does not authenticate by phone alone — PIN/password verification is required.
  UserAccount? findGuardianAccountByNormalizedPhone(String phone) {
    final normalized = PhoneNormalizer.normalize(phone);
    if (normalized.isEmpty) return null;
    for (final user in _userAccounts) {
      if (user.role != AppRole.guardian) continue;
      if (!user.isActive && user.status != AccountStatus.pendingActivation) {
        continue;
      }
      if (PhoneNormalizer.normalize(user.username) == normalized) {
        return user;
      }
    }
    return null;
  }

  /// Creates/reuses a guardian in [schoolId] and links them to [studentId].
  ///
  /// Does not create a guardian [UserAccount] or invent a PIN — activation is a
  /// separate secure step (hashed PIN/password setup).
  Future<Guardian> linkRequiredGuardianToStudent({
    required String studentId,
    required String guardianFullName,
    required String guardianPhone,
    String? guardianEmail,
    required String relationship,
    String? schoolId,
  }) async {
    final name = guardianFullName.trim();
    final phone = PhoneNormalizer.normalize(guardianPhone);
    final email = guardianEmail?.trim() ?? '';
    final rel = relationship.trim();
    final sid = schoolId ?? _effectiveSchoolId;

    if (name.isEmpty) throw ArgumentError('EMPTY_GUARDIAN_NAME');
    if (phone.isEmpty) throw ArgumentError('EMPTY_GUARDIAN_PHONE');
    if (rel.isEmpty) throw ArgumentError('EMPTY_RELATIONSHIP');

    var guardian = findGuardianByPhoneInSchool(phone, schoolId: sid);
    if (guardian == null) {
      guardian = Guardian(
        id: nextGuardianId(),
        fullName: name,
        schoolId: sid,
        phone: phone,
        email: email,
      );
      await addGuardian(guardian);
    }

    final alreadyLinked = _guardianStudentLinks.any(
      (l) => l.guardianId == guardian!.id && l.studentId == studentId,
    );
    if (!alreadyLinked) {
      final link = GuardianStudent(
        guardianId: guardian.id,
        studentId: studentId,
        relationship: rel,
      );
      await _repository.insertGuardianStudentLinks([link]);
      _guardianStudentLinks = [..._guardianStudentLinks, link];
      notifyListeners();
    }
    return guardian;
  }

  /// Creates/reuses a guardian in the active school and links them to [studentId].
  Future<Guardian?> linkOptionalGuardianToStudent({
    required String studentId,
    String? guardianFullName,
    String? guardianPhone,
    String? guardianEmail,
    String? relationship,
  }) async {
    final name = guardianFullName?.trim() ?? '';
    final phone = PhoneNormalizer.normalize(guardianPhone ?? '');
    final email = guardianEmail?.trim() ?? '';
    final rel = (relationship == null || relationship.trim().isEmpty)
        ? 'Асран хамгаалагч'
        : relationship.trim();

    if (name.isEmpty) return null;
    if (phone.isEmpty) {
      // Optional path without phone: create a school-scoped guardian (no reuse).
      final guardian = Guardian(
        id: nextGuardianId(),
        fullName: name,
        schoolId: _effectiveSchoolId,
        phone: '',
        email: email,
      );
      await addGuardian(guardian);
      final alreadyLinked = _guardianStudentLinks.any(
        (l) => l.guardianId == guardian.id && l.studentId == studentId,
      );
      if (!alreadyLinked) {
        final link = GuardianStudent(
          guardianId: guardian.id,
          studentId: studentId,
          relationship: rel,
        );
        await _repository.insertGuardianStudentLinks([link]);
        _guardianStudentLinks = [..._guardianStudentLinks, link];
        notifyListeners();
      }
      return guardian;
    }

    return linkRequiredGuardianToStudent(
      studentId: studentId,
      guardianFullName: name,
      guardianPhone: phone,
      guardianEmail: email.isEmpty ? null : email,
      relationship: rel,
    );
  }

  /// Creates a student with a required guardian (reuse by normalized phone in school).
  ///
  /// Always allocates a school-scoped student code and pending student login.
  /// Creates a pending guardian login only when none exists for that phone.
  /// Never stores an administrator-chosen PIN.
  Future<Student> addStudentWithRequiredGuardian({
    required Student student,
    required String guardianFullName,
    required String guardianPhone,
    String? guardianEmail,
    required String relationship,
    String? schoolId,
  }) async {
    final name = guardianFullName.trim();
    final phone = PhoneNormalizer.normalize(guardianPhone);
    final email = guardianEmail?.trim() ?? '';
    final rel = relationship.trim();
    final sid = schoolId ?? _effectiveSchoolId;

    if (name.isEmpty) throw ArgumentError('EMPTY_GUARDIAN_NAME');
    if (phone.isEmpty) throw ArgumentError('EMPTY_GUARDIAN_PHONE');
    if (rel.isEmpty) throw ArgumentError('EMPTY_RELATIONSHIP');

    final allocated = await _repository.allocateNextStudentCode(sid);
    _replaceSchool(allocated.school);
    final code = allocated.code;

    final existingGuardianAccount = findGuardianAccountByNormalizedPhone(phone);

    final savedStudent = student.copyWith(guardian: name, studentCode: code);

    var guardian = findGuardianByPhoneInSchool(phone, schoolId: sid);
    Guardian? newGuardian;
    if (guardian == null) {
      newGuardian = Guardian(
        id: nextGuardianId(),
        fullName: name,
        schoolId: sid,
        phone: phone,
        email: email,
      );
      guardian = newGuardian;
    }

    final alreadyLinked = _guardianStudentLinks.any(
      (l) => l.guardianId == guardian!.id && l.studentId == savedStudent.id,
    );
    final link = GuardianStudent(
      guardianId: guardian.id,
      studentId: savedStudent.id,
      relationship: rel,
    );

    final studentUsername = StudentLoginIds.usernameFor(
      schoolId: sid,
      code: code,
    );
    if (userByUsername(studentUsername) != null) {
      throw ArgumentError('DUPLICATE_STUDENT_CODE');
    }
    final newStudentAccount = UserAccount(
      id: nextUserId(),
      username: studentUsername,
      passwordHash: '',
      role: AppRole.student,
      studentId: savedStudent.id,
      status: AccountStatus.pendingActivation,
      createdAt: DateTime.now(),
    );
    final newStudentMembership = UserSchoolMembership(
      id: nextMembershipId(),
      userId: newStudentAccount.id,
      schoolId: sid,
      role: AppRole.student,
      studentId: savedStudent.id,
    );

    UserAccount? newGuardianAccount;
    UserSchoolMembership? newGuardianMembership;
    if (existingGuardianAccount == null) {
      if (userByUsername(phone) != null) {
        throw ArgumentError('DUPLICATE_USERNAME');
      }
      newGuardianAccount = UserAccount(
        id: nextUserId(),
        username: phone,
        passwordHash: '',
        role: AppRole.guardian,
        guardianId: guardian.id,
        status: AccountStatus.pendingActivation,
        createdAt: DateTime.now(),
      );
      newGuardianMembership = UserSchoolMembership(
        id: nextMembershipId(),
        userId: newGuardianAccount.id,
        schoolId: sid,
        role: AppRole.guardian,
        guardianId: guardian.id,
      );
    } else {
      final hasMembership = _memberships.any(
        (m) =>
            m.userId == existingGuardianAccount.id &&
            m.schoolId == sid &&
            m.isActive,
      );
      if (!hasMembership) {
        newGuardianMembership = UserSchoolMembership(
          id: nextMembershipId(),
          userId: existingGuardianAccount.id,
          schoolId: sid,
          role: AppRole.guardian,
          guardianId: guardian.id,
        );
      }
    }

    await _repository.insertStudentWithGuardianTxn(
      student: savedStudent,
      newGuardian: newGuardian,
      link: link,
      createLink: !alreadyLinked,
      newStudentAccount: newStudentAccount,
      newStudentMembership: newStudentMembership,
      newGuardianAccount: newGuardianAccount,
      newGuardianMembership: newGuardianMembership,
    );

    final students = _studentsByClass.putIfAbsent(
      savedStudent.className,
      () => <Student>[],
    );
    students.add(savedStudent);
    if (newGuardian != null) {
      _guardians = [..._guardians, newGuardian]
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
    }
    if (!alreadyLinked) {
      _guardianStudentLinks = [..._guardianStudentLinks, link];
    }
    _userAccounts = [..._userAccounts, newStudentAccount]
      ..sort((a, b) => a.username.compareTo(b.username));
    if (newGuardianAccount != null) {
      _userAccounts = [..._userAccounts, newGuardianAccount]
        ..sort((a, b) => a.username.compareTo(b.username));
    }
    _memberships = [..._memberships, newStudentMembership];
    if (newGuardianMembership != null) {
      _memberships = [..._memberships, newGuardianMembership];
    }
    notifyListeners();
    return savedStudent;
  }

  void _replaceSchool(School school) {
    _schools = [
      for (final item in _schools)
        if (item.id == school.id) school else item,
    ];
  }

  /// Whether [code] is already used by another student in [schoolId].
  Future<bool> isStudentCodeTakenInSchool(
    String code, {
    String? schoolId,
    String? excludeStudentId,
  }) async {
    final key = StudentLoginIds.compareKey(code);
    if (key.isEmpty) return false;
    final sid = schoolId ?? _effectiveSchoolId;
    final classIds = _schoolClasses
        .where((c) => c.schoolId == sid)
        .map((c) => c.id)
        .toSet();
    for (final student in allStudents) {
      if (excludeStudentId != null && student.id == excludeStudentId) {
        continue;
      }
      if (!classIds.contains(student.className)) continue;
      final existing = student.studentCode;
      if (existing == null || existing.isEmpty) continue;
      if (StudentLoginIds.compareKey(existing) == key) return true;
    }
    return _repository.isStudentCodeReserved(schoolId: sid, code: code);
  }

  /// Account linked to [studentId], if any.
  UserAccount? accountForStudentId(String studentId) {
    for (final user in _userAccounts) {
      if (user.role == AppRole.student && user.studentId == studentId) {
        return user;
      }
    }
    return null;
  }

  /// Primary linked guardian for [studentId] within [schoolId], if any.
  Guardian? primaryGuardianForStudent(String studentId, {String? schoolId}) {
    final sid = schoolId ?? _effectiveSchoolId;
    for (final link in _guardianStudentLinks) {
      if (link.studentId != studentId) continue;
      final guardian = guardianById(link.guardianId);
      if (guardian == null || !guardian.isActive) continue;
      if (guardian.schoolId != sid) continue;
      return guardian;
    }
    return null;
  }

  /// Whether the authenticated learner may view [studentId] in the active school.
  bool canViewLearnerStudent(String studentId) {
    final role = _activeContext.role ?? selectedDevelopmentRole;
    final schoolId = activeSchoolId;
    if (schoolId == null) return false;
    final student = studentById(studentId);
    if (student == null) return false;
    final classOk = _schoolClasses.any(
      (c) => c.id == student.className && c.schoolId == schoolId,
    );
    if (!classOk) return false;

    if (role == AppRole.student) {
      final ownId = _activeContext.studentId ?? authenticatedUser?.studentId;
      return ownId != null && ownId == studentId;
    }
    if (role == AppRole.guardian) {
      final guardianId =
          _activeContext.guardianId ?? authenticatedUser?.guardianId;
      if (guardianId == null) return false;
      return _guardianStudentLinks.any(
        (l) => l.guardianId == guardianId && l.studentId == studentId,
      );
    }
    return false;
  }

  /// Creates pending login accounts for an existing student (admin-only).
  ///
  /// Allocates a student code when missing. Never sets or overwrites a PIN.
  Future<Student> provisionLoginForExistingStudent({
    required String studentId,
    String? schoolId,
  }) async {
    _ensureCanManageStudents();
    final sid = schoolId ?? _effectiveSchoolId;
    final student = studentById(studentId);
    if (student == null) throw ArgumentError('STUDENT_NOT_FOUND');
    if (accountForStudentId(studentId) != null) {
      throw ArgumentError('STUDENT_ACCOUNT_EXISTS');
    }

    var code = student.studentCode?.trim() ?? '';
    var updatedStudent = student;
    if (code.isEmpty) {
      final allocated = await _repository.allocateNextStudentCode(sid);
      _replaceSchool(allocated.school);
      code = allocated.code;
      updatedStudent = student.copyWith(studentCode: code);
    } else {
      await _repository.reserveStudentCode(schoolId: sid, code: code);
    }

    final username = StudentLoginIds.usernameFor(schoolId: sid, code: code);
    if (userByUsername(username) != null) {
      throw ArgumentError('DUPLICATE_STUDENT_CODE');
    }

    final guardian = primaryGuardianForStudent(studentId, schoolId: sid);
    UserAccount? newGuardianAccount;
    UserSchoolMembership? newGuardianMembership;
    if (guardian != null) {
      final existing = findGuardianAccountByNormalizedPhone(guardian.phone);
      if (existing == null) {
        final phone = PhoneNormalizer.normalize(guardian.phone);
        if (phone.isEmpty) throw ArgumentError('EMPTY_GUARDIAN_PHONE');
        if (userByUsername(phone) != null) {
          throw ArgumentError('DUPLICATE_USERNAME');
        }
        newGuardianAccount = UserAccount(
          id: nextUserId(),
          username: phone,
          passwordHash: '',
          role: AppRole.guardian,
          guardianId: guardian.id,
          status: AccountStatus.pendingActivation,
          createdAt: DateTime.now(),
        );
        newGuardianMembership = UserSchoolMembership(
          id: nextMembershipId(),
          userId: newGuardianAccount.id,
          schoolId: sid,
          role: AppRole.guardian,
          guardianId: guardian.id,
        );
      } else {
        final hasMembership = _memberships.any(
          (m) => m.userId == existing.id && m.schoolId == sid && m.isActive,
        );
        if (!hasMembership) {
          newGuardianMembership = UserSchoolMembership(
            id: nextMembershipId(),
            userId: existing.id,
            schoolId: sid,
            role: AppRole.guardian,
            guardianId: guardian.id,
          );
        }
      }
    }

    final studentAccount = UserAccount(
      id: nextUserId(),
      username: username,
      passwordHash: '',
      role: AppRole.student,
      studentId: studentId,
      status: AccountStatus.pendingActivation,
      createdAt: DateTime.now(),
    );
    final studentMembership = UserSchoolMembership(
      id: nextMembershipId(),
      userId: studentAccount.id,
      schoolId: sid,
      role: AppRole.student,
      studentId: studentId,
    );

    await _repository.provisionStudentLoginTxn(
      student: updatedStudent,
      studentAccount: studentAccount,
      studentMembership: studentMembership,
      newGuardianAccount: newGuardianAccount,
      newGuardianMembership: newGuardianMembership,
    );

    final list = _studentsByClass[updatedStudent.className];
    if (list != null) {
      final index = list.indexWhere((s) => s.id == updatedStudent.id);
      if (index >= 0) list[index] = updatedStudent;
    }
    _userAccounts = [..._userAccounts, studentAccount]
      ..sort((a, b) => a.username.compareTo(b.username));
    if (newGuardianAccount != null) {
      _userAccounts = [..._userAccounts, newGuardianAccount]
        ..sort((a, b) => a.username.compareTo(b.username));
    }
    _memberships = [..._memberships, studentMembership];
    if (newGuardianMembership != null) {
      _memberships = [..._memberships, newGuardianMembership];
    }
    notifyListeners();
    return updatedStudent;
  }

  /// Whether the current user may view [studentId]'s generated login code.
  bool canViewStudentCode(String studentId) {
    if (hasAdminPermissionForActiveSchool) return true;
    final role = _activeContext.role ?? selectedDevelopmentRole;
    if (role == AppRole.student) {
      final ownId = _activeContext.studentId ?? authenticatedUser?.studentId;
      return ownId == studentId;
    }
    if (role == AppRole.guardian) {
      return canViewLearnerStudent(studentId);
    }
    return false;
  }

  /// Validates guardian first-time activation identity (phone + child code).
  ({ActivationLookupResult result, UserAccount? account})
  lookupGuardianActivation({
    required String phone,
    required String studentCode,
  }) {
    final normalizedPhone = PhoneNormalizer.normalize(phone);
    final codeKey = StudentLoginIds.compareKey(studentCode);
    if (normalizedPhone.isEmpty || codeKey.isEmpty) {
      return (result: ActivationLookupResult.mismatch, account: null);
    }

    final account = findGuardianAccountByNormalizedPhone(normalizedPhone);
    if (account == null || account.role != AppRole.guardian) {
      return (result: ActivationLookupResult.mismatch, account: null);
    }
    if (account.status == AccountStatus.active &&
        account.passwordHash.isNotEmpty) {
      return (result: ActivationLookupResult.alreadyActive, account: account);
    }

    final student = findStudentByCode(studentCode);
    if (student == null) {
      return (result: ActivationLookupResult.mismatch, account: null);
    }
    final guardian = guardianById(account.guardianId);
    if (guardian == null || !guardian.isActive) {
      return (result: ActivationLookupResult.mismatch, account: null);
    }
    final studentSchool = schoolIdForStudent(student);
    if (studentSchool == null || studentSchool != guardian.schoolId) {
      return (result: ActivationLookupResult.mismatch, account: null);
    }
    final linked = _guardianStudentLinks.any(
      (l) => l.guardianId == guardian.id && l.studentId == student.id,
    );
    if (!linked) {
      return (result: ActivationLookupResult.mismatch, account: null);
    }
    if (account.status != AccountStatus.pendingActivation) {
      return (result: ActivationLookupResult.mismatch, account: null);
    }
    return (result: ActivationLookupResult.ok, account: account);
  }

  /// Validates student first-time activation identity (code + guardian phone).
  ({ActivationLookupResult result, UserAccount? account})
  lookupStudentActivation({
    required String studentCode,
    required String guardianPhone,
  }) {
    final normalizedPhone = PhoneNormalizer.normalize(guardianPhone);
    final codeKey = StudentLoginIds.compareKey(studentCode);
    if (normalizedPhone.isEmpty || codeKey.isEmpty) {
      return (result: ActivationLookupResult.mismatch, account: null);
    }

    final student = findStudentByCode(studentCode);
    if (student == null) {
      return (result: ActivationLookupResult.mismatch, account: null);
    }
    final account = accountForStudentId(student.id);
    if (account == null || account.role != AppRole.student) {
      return (result: ActivationLookupResult.mismatch, account: null);
    }
    if (account.status == AccountStatus.active &&
        account.passwordHash.isNotEmpty) {
      return (result: ActivationLookupResult.alreadyActive, account: account);
    }
    if (account.status != AccountStatus.pendingActivation) {
      return (result: ActivationLookupResult.mismatch, account: null);
    }

    final studentSchool = schoolIdForStudent(student);
    if (studentSchool == null) {
      return (result: ActivationLookupResult.mismatch, account: null);
    }
    final guardian = findGuardianByPhoneInSchool(
      normalizedPhone,
      schoolId: studentSchool,
    );
    if (guardian == null) {
      return (result: ActivationLookupResult.mismatch, account: null);
    }
    final linked = _guardianStudentLinks.any(
      (l) => l.guardianId == guardian.id && l.studentId == student.id,
    );
    if (!linked) {
      return (result: ActivationLookupResult.mismatch, account: null);
    }
    return (result: ActivationLookupResult.ok, account: account);
  }

  /// Sets a self-created PIN and marks the account active.
  Future<void> activateAccountWithPin({
    required String userId,
    required String pin,
  }) async {
    final error = PinRules.validateNewPin(pin, pin);
    if (error != null) throw ArgumentError('INVALID_PIN');

    final user = userById(userId);
    if (user == null) throw ArgumentError('NOT_FOUND');
    if (user.status == AccountStatus.active && user.passwordHash.isNotEmpty) {
      throw ArgumentError('ALREADY_ACTIVE');
    }
    if (user.status != AccountStatus.pendingActivation) {
      throw ArgumentError('NOT_PENDING');
    }

    final updated = user.copyWith(
      passwordHash: PasswordHasher.hashPassword(pin),
      status: AccountStatus.active,
      isActive: true,
    );
    await _repository.updateUserAccount(updated);
    _userAccounts = [
      for (final item in _userAccounts)
        if (item.id == updated.id) updated else item,
    ]..sort((a, b) => a.username.compareTo(b.username));
    notifyListeners();
  }

  Student? findStudentByCode(String code) {
    final key = StudentLoginIds.compareKey(code);
    if (key.isEmpty) return null;
    for (final student in allStudents) {
      final existing = student.studentCode;
      if (existing == null || existing.isEmpty) continue;
      if (StudentLoginIds.compareKey(existing) == key) return student;
    }
    return null;
  }

  String? schoolIdForStudent(Student student) {
    for (final schoolClass in _schoolClasses) {
      if (schoolClass.id == student.className) return schoolClass.schoolId;
    }
    return null;
  }

  /// Backfills missing student codes and reserves existing ones (idempotent).
  Future<void> backfillStudentCodesIfNeeded() async {
    for (final school in List<School>.from(_schools)) {
      var maxSeq = school.studentCodeSeq;
      final classIds = _schoolClasses
          .where((c) => c.schoolId == school.id)
          .map((c) => c.id)
          .toSet();
      final schoolStudents = allStudents
          .where((s) => classIds.contains(s.className))
          .toList();

      for (final student in schoolStudents) {
        final code = student.studentCode?.trim() ?? '';
        if (code.isEmpty) continue;
        await _repository.reserveStudentCode(schoolId: school.id, code: code);
        final seq = StudentLoginIds.sequenceFromCode(code);
        if (seq != null && seq > maxSeq) maxSeq = seq;
      }

      var updatedSchool = school;
      if (maxSeq != school.studentCodeSeq) {
        updatedSchool = school.copyWith(studentCodeSeq: maxSeq);
        await _repository.updateSchool(updatedSchool);
        _replaceSchool(updatedSchool);
      }

      for (final student in schoolStudents) {
        if (student.studentCode != null &&
            student.studentCode!.trim().isNotEmpty) {
          continue;
        }
        final allocated = await _repository.allocateNextStudentCode(school.id);
        _replaceSchool(allocated.school);
        final updated = student.copyWith(studentCode: allocated.code);
        await _repository.updateStudent(updated);
        final list = _studentsByClass[updated.className];
        if (list != null) {
          final index = list.indexWhere((s) => s.id == updated.id);
          if (index >= 0) list[index] = updated;
        }
      }
    }
  }

  Iterable<UserAccount> studentAccountsMatchingCode(String code) sync* {
    final key = StudentLoginIds.compareKey(code);
    if (key.isEmpty) return;
    for (final student in allStudents) {
      final existing = student.studentCode;
      if (existing == null || existing.isEmpty) continue;
      if (StudentLoginIds.compareKey(existing) != key) continue;
      final account = accountForStudentId(student.id);
      if (account != null) yield account;
    }
  }

  /// Creates a student and optionally links a guardian (reuse by phone in school).
  Future<Student> addStudentWithOptionalGuardian({
    required Student student,
    String? guardianFullName,
    String? guardianPhone,
    String? guardianEmail,
    String? relationship,
  }) async {
    final name = guardianFullName?.trim() ?? '';
    if (name.isEmpty) {
      await addStudent(student);
      return student;
    }

    final phone = PhoneNormalizer.normalize(guardianPhone ?? '');
    if (phone.isEmpty) {
      final savedStudent = student.copyWith(guardian: name);
      await addStudent(savedStudent);
      await linkOptionalGuardianToStudent(
        studentId: savedStudent.id,
        guardianFullName: name,
        guardianPhone: '',
        guardianEmail: guardianEmail,
        relationship: relationship,
      );
      return savedStudent;
    }

    return addStudentWithRequiredGuardian(
      student: student,
      guardianFullName: name,
      guardianPhone: phone,
      guardianEmail: guardianEmail,
      relationship: relationship ?? 'Асран хамгаалагч',
    );
  }

  /// Minimal setup complete when the school has at least one teacher and class.
  bool get isSchoolSetupIncomplete {
    return activeTeachers.isEmpty || classes.isEmpty;
  }

  bool get hasTeacherWorkspaceAccess {
    final teacherId = _activeContext.teacherId;
    if (teacherId != null && teacherId.isNotEmpty) {
      return teacherById(teacherId) != null;
    }
    final userId = _activeContext.userId ?? _selectedDevUserId;
    if (userId == null) return false;
    return _memberships.any(
      (m) =>
          m.userId == userId &&
          m.schoolId == activeSchoolId &&
          m.isActive &&
          m.role == AppRole.teacher,
    );
  }

  /// True when the signed-in user has an active admin membership for the
  /// selected school (admin, or admin who also teaches).
  ///
  /// Based on [UserSchoolMembership] / school context — not on whether a
  /// Teacher profile row exists.
  bool get hasAdminPermissionForActiveSchool {
    final schoolId = activeSchoolId;
    final userId = _activeContext.userId ?? _selectedDevUserId;
    if (schoolId == null || userId == null) return false;
    return _memberships.any(
      (m) =>
          m.userId == userId &&
          m.schoolId == schoolId &&
          m.isActive &&
          m.role == AppRole.admin,
    );
  }

  /// Admin membership for [activeSchoolId] may add/edit/delete students.
  bool get canManageStudents => hasAdminPermissionForActiveSchool;

  /// Enforces student management only for signed-in non-admin sessions.
  /// Bootstrap / seed writes (no active user) remain allowed.
  void _ensureCanManageStudents() {
    if (canManageStudents) return;
    final userId = _activeContext.userId ?? _selectedDevUserId;
    if (userId == null) return;
    throw const PermissionDeniedException();
  }

  /// Name of the active teaching subject, if [activeContext.subjectId] is set.
  String? get activeSubjectName {
    final subjectId = activeContext.subjectId;
    if (subjectId == null) return null;
    return subjectById(subjectId)?.name;
  }

  Future<void> addMembership(UserSchoolMembership membership) async {
    await _repository.insertMembership(membership);
    _memberships = [..._memberships, membership];
    notifyListeners();
  }

  Future<void> selectSchoolMembership(UserSchoolMembership membership) async {
    if (!membership.isActive) {
      throw ArgumentError('INACTIVE_MEMBERSHIP');
    }
    _activeContext = ActiveAppContext(
      userId: membership.userId,
      schoolId: membership.schoolId,
      role: membership.role,
      teacherId: membership.teacherId,
      guardianId: membership.guardianId,
      studentId: membership.studentId,
    );
    clearSchoolScopedSelections();
    await _repository.setPref(_prefLastSchoolId, membership.schoolId);
    _schoolSettings = await _repository.loadSchoolSettings(
      schoolId: membership.schoolId,
    );
    _ensureGuardianChildSelection();
    notifyListeners();
  }

  void clearSchoolScopedSelections() {
    _activeContext = _activeContext.copyWith(
      clearClassId: true,
      clearSubjectId: true,
      clearSelectedChildId: true,
    );
  }

  Future<void> setTeacherWorkspace({
    required String classId,
    int? subjectId,
  }) async {
    _activeContext = _activeContext.copyWith(
      classId: classId,
      subjectId: subjectId,
      clearSubjectId: subjectId == null,
    );
    notifyListeners();
  }

  Future<void> switchSchool(String schoolId) async {
    final userId = _selectedDevUserId ?? _activeContext.userId;
    if (userId == null) return;

    UserSchoolMembership? membership;
    for (final item in _memberships) {
      if (item.userId == userId && item.schoolId == schoolId && item.isActive) {
        membership = item;
        break;
      }
    }
    if (membership == null) {
      throw ArgumentError('NO_MEMBERSHIP');
    }
    await selectSchoolMembership(membership);
  }

  String nextMembershipId() {
    _membershipIdCounter += 1;
    return 'mem-$_membershipIdCounter';
  }

  String get _effectiveSchoolId => activeSchoolId ?? defaultSchoolId;

  static const demoTeacherId = 'DEMO-T-001';
  static const demoGuardianId = 'DEMO-G-001';
  static const demoStudentId = 'DEMO-S-001';
  static const demoAdminTeacherId = 'DEMO-T-ADMIN';
  static const demoTeacherUsername = 'teacher1';
  static const demoGuardianUsername = 'guardian1';
  static const demoStudentUsername = 'student1';
  static const demoAdminUsername = 'admin1';
  static const demoPassword = 'test123';

  /// Ensures local debug accounts including `admin1`.
  ///
  /// Idempotent: never duplicates those usernames.
  Future<void> ensureDemoAccountsIfNeeded() async {
    final needsTeacher = userByUsername(demoTeacherUsername) == null;
    final needsGuardian = userByUsername(demoGuardianUsername) == null;
    final needsStudent = userByUsername(demoStudentUsername) == null;
    final needsAdmin = userByUsername(demoAdminUsername) == null;
    if (!needsTeacher && !needsGuardian && !needsStudent && !needsAdmin) {
      // Still ensure default-school memberships for demo users.
      for (final account in _userAccounts) {
        if (account.username == demoTeacherUsername ||
            account.username == demoGuardianUsername ||
            account.username == demoStudentUsername ||
            account.username == demoAdminUsername) {
          final existing = _memberships.any(
            (m) =>
                m.userId == account.id &&
                m.schoolId == defaultSchoolId &&
                m.isActive,
          );
          if (!existing) {
            final membership = UserSchoolMembership(
              id: 'mem-${account.id}',
              userId: account.id,
              schoolId: defaultSchoolId,
              role: account.role,
              teacherId: account.teacherId,
              guardianId: account.guardianId,
              studentId: account.studentId,
            );
            await _repository.insertMembership(membership);
            _memberships = [..._memberships, membership];
          }
        }
      }
      notifyListeners();
      return;
    }

    final schoolId = defaultSchoolId;

    // --- Matching entity records ---
    var teacher = teacherById(demoTeacherId);
    if (teacher == null) {
      final created = Teacher(
        id: demoTeacherId,
        fullName: 'Д.Эрдэнэ',
        schoolId: schoolId,
        phone: '99001122',
        email: 'teacher1@edubridge.local',
      );
      await _repository.insertTeacher(created);
      teacher = created;
      _teachers = [..._teachers, created]
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
    } else if (!teacher.isActive) {
      final activated = teacher.copyWith(isActive: true, schoolId: schoolId);
      await _repository.updateTeacher(activated);
      teacher = activated;
      _teachers = [
        for (final t in _teachers)
          if (t.id == activated.id) activated else t,
      ];
    }

    final className = classes.isNotEmpty ? classes.first : '6А';
    if (!classes.contains(className)) {
      await _repository.insertClasses([className], schoolId: schoolId);
      _schoolClasses = [
        ..._schoolClasses,
        SchoolClass(id: className, name: className, schoolId: schoolId),
      ];
    }

    // Demo teacher is homeroom for the first class in the default school.
    await saveClassAssignments(
      classId: className,
      homeroomTeacherId: demoTeacherId,
      subjectTeacherIds: const {},
    );

    var student = studentById(demoStudentId);
    if (student == null) {
      final created = Student(
        id: demoStudentId,
        className: className,
        lastName: 'Бат',
        firstName: 'Болд',
        gender: StudentGender.male,
      );
      await _repository.insertStudent(created);
      student = created;
      _studentsByClass.putIfAbsent(className, () => <Student>[]).add(created);
    }

    var guardian = guardianById(demoGuardianId);
    if (guardian == null) {
      final created = Guardian(
        id: demoGuardianId,
        fullName: 'Б. Болормаа',
        schoolId: schoolId,
        phone: '99110011',
        email: 'guardian1@edubridge.local',
      );
      await _repository.insertGuardian(created);
      guardian = created;
      _guardians = [..._guardians, created]
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
    } else if (!guardian.isActive) {
      final activated = guardian.copyWith(isActive: true, schoolId: schoolId);
      await _repository.updateGuardian(activated);
      guardian = activated;
      _guardians = [
        for (final g in _guardians)
          if (g.id == activated.id) activated else g,
      ];
    }

    final alreadyLinked = _guardianStudentLinks.any(
      (l) => l.guardianId == demoGuardianId && l.studentId == demoStudentId,
    );
    if (!alreadyLinked) {
      final link = GuardianStudent(
        guardianId: demoGuardianId,
        studentId: demoStudentId,
        relationship: 'Ээж',
      );
      await _repository.insertGuardianStudentLinks([link]);
      _guardianStudentLinks = [..._guardianStudentLinks, link];
    }

    Future<void> ensureUser({
      required String id,
      required String username,
      required AppRole role,
      String? teacherId,
      String? guardianId,
      String? studentId,
    }) async {
      if (userByUsername(username) != null) return;
      final account = UserAccount(
        id: id,
        username: username,
        passwordHash: PasswordHasher.hashPassword(demoPassword),
        role: role,
        teacherId: teacherId,
        guardianId: guardianId,
        studentId: studentId,
        createdAt: DateTime.now(),
      );
      await _repository.insertUserAccount(account);
      _userAccounts = [..._userAccounts, account]
        ..sort((a, b) => a.username.compareTo(b.username));
    }

    await ensureUser(
      id: 'DEMO-U-teacher1',
      username: demoTeacherUsername,
      role: AppRole.teacher,
      teacherId: demoTeacherId,
    );
    await ensureUser(
      id: 'DEMO-U-guardian1',
      username: demoGuardianUsername,
      role: AppRole.guardian,
      guardianId: demoGuardianId,
    );
    await ensureUser(
      id: 'DEMO-U-student1',
      username: demoStudentUsername,
      role: AppRole.student,
      studentId: demoStudentId,
    );

    var adminTeacher = teacherById(demoAdminTeacherId);
    if (adminTeacher == null) {
      final created = Teacher(
        id: demoAdminTeacherId,
        fullName: 'А.Админ',
        schoolId: schoolId,
        phone: '88001100',
        email: 'admin1@edubridge.local',
      );
      await _repository.insertTeacher(created);
      _teachers = [..._teachers, created]
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
    }
    await ensureUser(
      id: 'DEMO-U-admin1',
      username: demoAdminUsername,
      role: AppRole.admin,
      teacherId: demoAdminTeacherId,
    );

    Future<void> ensureMembership(UserAccount account) async {
      final existing = _memberships.any(
        (m) => m.userId == account.id && m.schoolId == schoolId && m.isActive,
      );
      if (existing) return;
      final membership = UserSchoolMembership(
        id: 'mem-${account.id}',
        userId: account.id,
        schoolId: schoolId,
        role: account.role,
        teacherId: account.teacherId,
        guardianId: account.guardianId,
        studentId: account.studentId,
      );
      await _repository.insertMembership(membership);
      _memberships = [..._memberships, membership];
    }

    for (final account in _userAccounts) {
      if (account.id.startsWith('DEMO-U-')) {
        await ensureMembership(account);
      }
    }

    _ensureGuardianChildSelection();
    notifyListeners();
  }

  void _ensureGuardianChildSelection() {
    final guardianId =
        _activeContext.guardianId ?? selectedDevelopmentUser?.guardianId;
    // Preserve saved child id when no guardian session is active.
    if (guardianId == null) return;

    final visible = guardianPortalStudents;
    if (_guardianStudentId != null &&
        visible.every((s) => s.id != _guardianStudentId)) {
      _guardianStudentId = null;
    }
    // Auto-select only when exactly one linked child exists.
    if (_guardianStudentId == null && visible.length == 1) {
      _guardianStudentId = visible.first.id;
      _activeContext = _activeContext.copyWith(
        selectedChildId: visible.first.id,
      );
    }
  }

  UserAccount? userById(String id) {
    for (final user in _userAccounts) {
      if (user.id == id) return user;
    }
    return null;
  }

  UserAccount? userByUsername(String username) {
    final key = username.trim().toLowerCase();
    for (final user in _userAccounts) {
      if (user.username.toLowerCase() == key) return user;
    }
    return null;
  }

  Guardian? guardianById(String? id) {
    if (id == null) return null;
    for (final g in _guardians) {
      if (g.id == id) return g;
    }
    return null;
  }

  Guardian? guardianForUser(String userId) {
    final user = userById(userId);
    if (user == null || user.role != AppRole.guardian) return null;
    return guardianById(user.guardianId);
  }

  Teacher? teacherForUser(String userId) {
    final user = userById(userId);
    if (user == null || user.role != AppRole.teacher) return null;
    return teacherById(user.teacherId);
  }

  Student? studentForUser(String userId) {
    final user = userById(userId);
    if (user == null || user.role != AppRole.student) return null;
    return studentById(user.studentId ?? '');
  }

  List<Student> studentsForGuardian(String guardianId) {
    final ids = _guardianStudentLinks
        .where((l) => l.guardianId == guardianId)
        .map((l) => l.studentId)
        .toSet();
    return allStudents.where((s) => ids.contains(s.id)).toList(growable: false);
  }

  List<Guardian> guardiansForStudent(String studentId) {
    final ids = _guardianStudentLinks
        .where((l) => l.studentId == studentId)
        .map((l) => l.guardianId)
        .toSet();
    return _guardians.where((g) => ids.contains(g.id)).toList(growable: false);
  }

  List<GuardianStudent> linksForGuardian(String guardianId) {
    return _guardianStudentLinks
        .where((l) => l.guardianId == guardianId)
        .toList(growable: false);
  }

  List<UserAccount> activeUsersForRole(AppRole role) {
    return activeUserAccounts
        .where((u) => u.role == role)
        .toList(growable: false);
  }

  Student? studentById(String id) {
    for (final list in _studentsByClass.values) {
      for (final student in list) {
        if (student.id == id) return student;
      }
    }
    return null;
  }

  Future<void> setLastRole(AppRole role) async {
    _lastRole = role;
    await _repository.setPref(_prefLastRole, role.storageValue);
    notifyListeners();
  }

  Future<void> selectDevelopmentUser(
    UserAccount user, {
    bool? rememberMe,
  }) async {
    if (!user.isActive) {
      throw ArgumentError('INACTIVE');
    }
    _selectedDevUserId = user.id;
    _lastRole = user.role;
    final remember = rememberMe ?? _rememberSession;
    _rememberSession = remember;
    await _repository.setPref(_prefRememberSession, remember ? '1' : '0');
    await _repository.setPref(_prefLastRole, user.role.storageValue);
    if (remember) {
      await _repository.setPref(_prefDevUserId, user.id);
    } else {
      await _repository.clearPref(_prefDevUserId);
    }
    _ensureGuardianChildSelection();
    if (_guardianStudentId != null) {
      await _repository.setPref(_prefGuardianStudentId, _guardianStudentId!);
    }
    notifyListeners();
  }

  /// Authenticates against local [UserAccount] password/PIN hashes.
  ///
  /// [username] may be an admin/teacher username, guardian phone, or student code.
  /// Role is resolved from the matched account — never from a pre-selected role.
  Future<LoginResult> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return LoginResult.missingUsername;
    if (password.isEmpty) return LoginResult.missingPassword;

    final resolved = _resolveLoginCandidate(trimmed);
    if (resolved == null) return LoginResult.invalidCredentials;
    if (!resolved.isActive &&
        resolved.status != AccountStatus.pendingActivation) {
      return LoginResult.inactive;
    }
    if (resolved.status == AccountStatus.pendingActivation ||
        resolved.passwordHash.isEmpty) {
      return LoginResult.pendingActivation;
    }
    if (!PasswordHasher.verifyPassword(password, resolved.passwordHash)) {
      return LoginResult.invalidCredentials;
    }

    await selectDevelopmentUser(resolved, rememberMe: rememberMe);
    return LoginResult.success;
  }

  /// Resolves identifier to a candidate account without verifying the secret.
  UserAccount? _resolveLoginCandidate(String identifier) {
    final byUsername = userByUsername(identifier);
    if (byUsername != null) return byUsername;

    final byPhone = findGuardianAccountByNormalizedPhone(identifier);
    if (byPhone != null) return byPhone;

    for (final account in studentAccountsMatchingCode(identifier)) {
      return account;
    }
    return null;
  }

  Future<void> clearDevelopmentUser() async {
    _selectedDevUserId = null;
    notifyListeners();
  }

  Future<void> _clearSessionPrefs() async {
    await _repository.clearPref(_prefDevUserId);
    await _repository.clearPref(_prefLastRole);
    await _repository.clearPref(_prefLastSchoolId);
    await _repository.clearPref(_prefGuardianStudentId);
    await _repository.setPref(_prefRememberSession, '0');
  }

  /// Clears authenticated user and all school / class / child context.
  Future<void> logout() async {
    _selectedDevUserId = null;
    _lastRole = null;
    _guardianStudentId = null;
    _rememberSession = false;
    _activeContext = ActiveAppContext.empty;
    await _clearSessionPrefs();
    notifyListeners();
  }

  Future<void> setGuardianStudentId(String studentId) async {
    _guardianStudentId = studentId;
    _activeContext = _activeContext.copyWith(selectedChildId: studentId);
    await _repository.setPref(_prefGuardianStudentId, studentId);
    notifyListeners();
  }

  String nextGuardianId() {
    _guardianIdCounter += 1;
    return 'grd-$_guardianIdCounter';
  }

  String nextUserId() {
    _userIdCounter += 1;
    return 'usr-$_userIdCounter';
  }

  void _validateUserLinks(UserAccount user) {
    final username = user.username.trim();
    if (username.isEmpty) throw ArgumentError('EMPTY_USERNAME');
    final duplicate = _userAccounts.any(
      (u) =>
          u.id != user.id && u.username.toLowerCase() == username.toLowerCase(),
    );
    if (duplicate) throw ArgumentError('DUPLICATE_USERNAME');

    switch (user.role) {
      case AppRole.admin:
        if (user.guardianId != null || user.studentId != null) {
          throw ArgumentError('ROLE_LINK_MISMATCH');
        }
        if (user.teacherId != null &&
            user.teacherId!.isNotEmpty &&
            teacherById(user.teacherId) == null) {
          throw ArgumentError('INVALID_LINK');
        }
      case AppRole.teacher:
        if (user.teacherId == null || user.teacherId!.isEmpty) {
          throw ArgumentError('MISSING_LINK');
        }
        if (teacherById(user.teacherId) == null) {
          throw ArgumentError('INVALID_LINK');
        }
        if (user.guardianId != null || user.studentId != null) {
          throw ArgumentError('ROLE_LINK_MISMATCH');
        }
      case AppRole.guardian:
        if (user.guardianId == null || user.guardianId!.isEmpty) {
          throw ArgumentError('MISSING_LINK');
        }
        if (guardianById(user.guardianId) == null) {
          throw ArgumentError('INVALID_LINK');
        }
        if (user.teacherId != null || user.studentId != null) {
          throw ArgumentError('ROLE_LINK_MISMATCH');
        }
      case AppRole.student:
        if (user.studentId == null || user.studentId!.isEmpty) {
          throw ArgumentError('MISSING_LINK');
        }
        if (studentById(user.studentId!) == null) {
          throw ArgumentError('INVALID_LINK');
        }
        if (user.teacherId != null || user.guardianId != null) {
          throw ArgumentError('ROLE_LINK_MISMATCH');
        }
    }
  }

  Future<void> addUserAccount(
    UserAccount user, {
    required String plainPassword,
  }) async {
    final cleaned = UserAccount(
      id: user.id,
      username: user.username.trim(),
      passwordHash: PasswordHasher.hashPassword(plainPassword),
      role: user.role,
      teacherId: user.role == AppRole.teacher || user.role == AppRole.admin
          ? user.teacherId
          : null,
      guardianId: user.role == AppRole.guardian ? user.guardianId : null,
      studentId: user.role == AppRole.student ? user.studentId : null,
      isActive: user.isActive,
      status: AccountStatus.active,
      createdAt: user.createdAt,
    );
    _validateUserLinks(cleaned);
    await _repository.insertUserAccount(cleaned);
    _userAccounts = [..._userAccounts, cleaned]
      ..sort((a, b) => a.username.compareTo(b.username));

    final membership = UserSchoolMembership(
      id: nextMembershipId(),
      userId: cleaned.id,
      schoolId: _effectiveSchoolId,
      role: cleaned.role,
      teacherId: cleaned.teacherId,
      guardianId: cleaned.guardianId,
      studentId: cleaned.studentId,
    );
    await _repository.insertMembership(membership);
    _memberships = [..._memberships, membership];
    notifyListeners();
  }

  Future<void> updateUserAccount(UserAccount user) async {
    final cleaned = UserAccount(
      id: user.id,
      username: user.username.trim(),
      passwordHash: user.passwordHash,
      role: user.role,
      teacherId: user.role == AppRole.teacher || user.role == AppRole.admin
          ? user.teacherId
          : null,
      guardianId: user.role == AppRole.guardian ? user.guardianId : null,
      studentId: user.role == AppRole.student ? user.studentId : null,
      isActive: user.isActive,
      status: user.status,
      createdAt: user.createdAt,
    );
    _validateUserLinks(cleaned);
    await _repository.updateUserAccount(cleaned);
    _userAccounts = [
      for (final u in _userAccounts)
        if (u.id == cleaned.id) cleaned else u,
    ]..sort((a, b) => a.username.compareTo(b.username));
    notifyListeners();
  }

  /// Returns the temporary plain password (show once).
  Future<String> resetUserPassword(
    String userId, {
    String? temporaryPassword,
  }) async {
    final user = userById(userId);
    if (user == null) throw ArgumentError('NOT_FOUND');
    final plain = temporaryPassword ?? 'test123';
    final updated = user.copyWith(
      passwordHash: PasswordHasher.hashPassword(plain),
    );
    await _repository.updateUserAccount(updated);
    _userAccounts = [
      for (final u in _userAccounts)
        if (u.id == updated.id) updated else u,
    ];
    notifyListeners();
    return plain;
  }

  Future<void> deactivateUserAccount(String userId) async {
    final user = userById(userId);
    if (user == null) return;
    await updateUserAccount(user.copyWith(isActive: false));
  }

  Future<void> addGuardian(Guardian guardian) async {
    final name = guardian.fullName.trim();
    if (name.isEmpty) throw ArgumentError('EMPTY');
    final schoolId = guardian.schoolId.isNotEmpty
        ? guardian.schoolId
        : _effectiveSchoolId;
    final saved = guardian.copyWith(fullName: name, schoolId: schoolId);
    await _repository.insertGuardian(saved);
    _guardians = [..._guardians, saved]
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    notifyListeners();
  }

  Future<void> updateGuardian(Guardian guardian) async {
    final name = guardian.fullName.trim();
    if (name.isEmpty) throw ArgumentError('EMPTY');
    final saved = guardian.copyWith(fullName: name);
    await _repository.updateGuardian(saved);
    _guardians = [
      for (final g in _guardians)
        if (g.id == saved.id) saved else g,
    ]..sort((a, b) => a.fullName.compareTo(b.fullName));
    notifyListeners();
  }

  Future<void> deactivateGuardian(String guardianId) async {
    final g = guardianById(guardianId);
    if (g == null) return;
    await updateGuardian(g.copyWith(isActive: false));
  }

  Future<void> saveGuardianStudentLinks({
    required String guardianId,
    required List<GuardianStudent> links,
  }) async {
    await _repository.replaceGuardianStudentLinks(
      guardianId: guardianId,
      links: links,
    );
    _guardianStudentLinks = [
      for (final l in _guardianStudentLinks)
        if (l.guardianId != guardianId) l,
      ...links,
    ];
    _ensureGuardianChildSelection();
    notifyListeners();
  }

  List<Grade> gradesForStudent(Student student) {
    return _grades
        .where((g) => g.studentId == student.id)
        .toList(growable: false);
  }

  List<Homework> homeworkForStudentClass(Student student) {
    return homeworkFor(student.className);
  }

  List<Announcement> announcementsForStudentClass(Student student) {
    return announcementsFor(student.className);
  }

  /// Per-day attendance rows for one student (newest first where possible).
  List<({AttendanceRecord record, AttendanceStatus status})>
  attendanceEntriesForStudent(Student student) {
    final records = attendanceFor(student.className);
    final result = <({AttendanceRecord record, AttendanceStatus status})>[];
    for (final record in records) {
      final entries = record.entries;
      if (entries == null) continue;
      for (final entry in entries) {
        if (entry.studentName == student.fullName) {
          result.add((record: record, status: entry.status));
          break;
        }
      }
    }
    return result;
  }

  AttendanceStatus? todaysAttendanceStatus(Student student) {
    final today = DateTime.now();
    for (final row in attendanceEntriesForStudent(student)) {
      if (row.record.isOnCalendarDay(today)) return row.status;
    }
    return null;
  }

  double? averageGradeForStudent(Student student) {
    return averageScore(gradesForStudent(student));
  }

  int pendingHomeworkCountForStudent(Student student) {
    return homeworkForStudentClass(
      student,
    ).where((h) => h.status == HomeworkStatus.pending).length;
  }

  bool isGuardianAnnouncementRead(String announcementId) {
    return _guardianReadAnnouncementIds.contains(announcementId);
  }

  int unreadGuardianAnnouncementCount(Student student) {
    return announcementsForStudentClass(
      student,
    ).where((a) => !_guardianReadAnnouncementIds.contains(a.id)).length;
  }

  Future<void> markGuardianAnnouncementRead(String announcementId) async {
    if (_guardianReadAnnouncementIds.contains(announcementId)) return;
    await _repository.markGuardianAnnouncementRead(announcementId);
    _guardianReadAnnouncementIds.add(announcementId);
    notifyListeners();
  }

  Future<void> saveSchoolSettings(SchoolSettings settings) async {
    final scoped = settings.copyWith(
      schoolId: settings.schoolId.isEmpty
          ? _effectiveSchoolId
          : settings.schoolId,
    );
    await _repository.saveSchoolSettings(scoped);
    _schoolSettings = scoped;
    _schools = [
      for (final school in _schools)
        if (school.id == scoped.schoolId)
          school.copyWith(name: scoped.schoolName)
        else
          school,
    ];
    _settings = _settings.copyWith(
      schoolName: scoped.schoolName,
      academicYear: scoped.academicYear,
      currentSemester: scoped.currentSemester,
    );
    notifyListeners();
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _repository.saveSettings(settings);
    _settings = settings;
    _schoolSettings = SchoolSettings(
      schoolId: _effectiveSchoolId,
      schoolName: settings.schoolName,
      academicYear: settings.academicYear,
      currentSemester: settings.currentSemester,
    );
    notifyListeners();
  }

  String nextTeacherId() {
    _teacherIdCounter += 1;
    return 'tch-$_teacherIdCounter';
  }

  Future<void> addTeacher(
    Teacher teacher, {
    bool allowDuplicate = false,
  }) async {
    final name = teacher.fullName.trim();
    if (name.isEmpty) throw ArgumentError('EMPTY');
    final schoolId = teacher.schoolId.isNotEmpty
        ? teacher.schoolId
        : _effectiveSchoolId;
    if (!allowDuplicate &&
        _teachers.any(
          (t) => t.schoolId == schoolId && t.fullName.trim() == name,
        )) {
      throw ArgumentError('DUPLICATE');
    }
    final saved = teacher.copyWith(fullName: name, schoolId: schoolId);
    await _repository.insertTeacher(saved);
    _teachers = [..._teachers, saved]
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    notifyListeners();
  }

  Future<void> updateTeacher(
    Teacher teacher, {
    bool allowDuplicate = false,
  }) async {
    final name = teacher.fullName.trim();
    if (name.isEmpty) throw ArgumentError('EMPTY');
    final duplicate = _teachers.any(
      (t) =>
          t.id != teacher.id &&
          t.schoolId == teacher.schoolId &&
          t.fullName.trim() == name,
    );
    if (duplicate && !allowDuplicate) {
      throw ArgumentError('DUPLICATE');
    }
    final saved = teacher.copyWith(fullName: name);
    await _repository.updateTeacher(saved);
    _teachers = [
      for (final t in _teachers)
        if (t.id == saved.id) saved else t,
    ]..sort((a, b) => a.fullName.compareTo(b.fullName));
    notifyListeners();
  }

  Future<void> deactivateTeacher(String teacherId) async {
    final teacher = teacherById(teacherId);
    if (teacher == null) return;
    await updateTeacher(
      teacher.copyWith(isActive: false),
      allowDuplicate: true,
    );
  }

  Future<void> addSubject(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      throw ArgumentError('EMPTY');
    }
    final schoolId = _effectiveSchoolId;
    if (_subjectModels.any(
      (s) =>
          s.schoolId == schoolId && s.name.toLowerCase() == name.toLowerCase(),
    )) {
      throw ArgumentError('DUPLICATE');
    }
    final created = await _repository.insertSubject(
      name,
      sortOrder: allSubjects.length,
      schoolId: schoolId,
    );
    _subjectModels = [..._subjectModels, created];
    notifyListeners();
  }

  /// Reloads subject models from SQLite (active school filtering stays in getters).
  Future<void> reloadSubjectsForActiveSchool() async {
    _subjectModels = await _repository.loadSubjectModels();
    notifyListeners();
  }

  Future<void> renameSubject(String oldName, String rawNewName) async {
    final newName = rawNewName.trim();
    if (newName.isEmpty) {
      throw ArgumentError('EMPTY');
    }
    final current = subjectByName(oldName);
    if (current == null) return;
    if (newName != oldName &&
        _subjectModels.any(
          (s) =>
              s.schoolId == current.schoolId &&
              s.name.toLowerCase() == newName.toLowerCase(),
        )) {
      throw ArgumentError('DUPLICATE');
    }
    final updated = current.copyWith(name: newName);
    await _repository.updateSubject(updated);
    _subjectModels = [
      for (final s in _subjectModels)
        if (s.id == updated.id) updated else s,
    ];
    for (final entry in _journalSubjectByClass.entries.toList()) {
      if (entry.value == oldName) {
        _journalSubjectByClass[entry.key] = newName;
      }
    }
    notifyListeners();
  }

  Future<void> deleteSubject(String name) async {
    final current = subjectByName(name);
    if (current == null) return;
    if (await _repository.subjectIsAssigned(current.id)) {
      await _repository.updateSubject(current.copyWith(isActive: false));
      _subjectModels = [
        for (final s in _subjectModels)
          if (s.id == current.id) s.copyWith(isActive: false) else s,
      ];
    } else {
      await _repository.deleteSubject(name);
      _subjectModels = [
        for (final s in _subjectModels)
          if (s.id != current.id) s,
      ];
    }
    for (final entry in _journalSubjectByClass.entries.toList()) {
      if (entry.value == name) {
        _journalSubjectByClass[entry.key] = null;
      }
    }
    notifyListeners();
  }

  Future<void> saveClassAssignments({
    required String classId,
    required String? homeroomTeacherId,
    required Map<int, String?> subjectTeacherIds,
  }) async {
    final assignments = <ClassSubjectTeacher>[
      for (final entry in subjectTeacherIds.entries)
        if (entry.value != null && entry.value!.isNotEmpty)
          ClassSubjectTeacher(
            classId: classId,
            subjectId: entry.key,
            teacherId: entry.value!,
          ),
    ];
    await _repository.replaceClassAssignments(
      classId: classId,
      homeroomTeacherId: homeroomTeacherId,
      assignments: assignments,
    );
    _schoolClasses = [
      for (final c in _schoolClasses)
        if (c.id == classId)
          c.copyWith(
            homeroomTeacherId: homeroomTeacherId,
            clearHomeroom: homeroomTeacherId == null,
          )
        else
          c,
    ];
    _assignments = [
      for (final a in _assignments)
        if (a.classId != classId) a,
      ...assignments,
    ];
    notifyListeners();
  }

  Future<void> assignHomeroomToAllSubjects(String classId) async {
    final homeId = schoolClassById(classId)?.homeroomTeacherId;
    if (homeId == null) {
      throw ArgumentError('NO_HOMEROOM');
    }
    final map = <int, String?>{
      for (final subject in activeSubjects) subject.id: homeId,
    };
    await saveClassAssignments(
      classId: classId,
      homeroomTeacherId: homeId,
      subjectTeacherIds: map,
    );
  }

  void _syncCountersFromLoadedData() {
    for (final list in _studentsByClass.values) {
      for (final student in list) {
        final n = int.tryParse(student.id.split('-').last);
        if (n != null && n > _studentIdCounter) _studentIdCounter = n;
      }
    }
    for (final teacher in _teachers) {
      final n = int.tryParse(teacher.id.replaceFirst('tch-', ''));
      if (n != null && n > _teacherIdCounter) _teacherIdCounter = n;
      final testN = int.tryParse(teacher.id.replaceFirst('TEST-T-', ''));
      if (testN != null && testN > _teacherIdCounter) {
        _teacherIdCounter = testN;
      }
    }
    for (final guardian in _guardians) {
      final n = int.tryParse(guardian.id.replaceFirst('grd-', ''));
      if (n != null && n > _guardianIdCounter) _guardianIdCounter = n;
    }
    for (final user in _userAccounts) {
      final n = int.tryParse(user.id.replaceFirst('usr-', ''));
      if (n != null && n > _userIdCounter) _userIdCounter = n;
    }
    for (final item in _announcements) {
      final n = int.tryParse(item.id.replaceFirst('ann-', ''));
      if (n != null && n > _announcementIdCounter) {
        _announcementIdCounter = n;
      }
    }
    for (final item in _homework) {
      final n = int.tryParse(item.id.replaceFirst('hw-', ''));
      if (n != null && n > _homeworkIdCounter) _homeworkIdCounter = n;
    }
    for (final item in _grades) {
      final n = int.tryParse(item.id.replaceFirst('gr-', ''));
      if (n != null && n > _gradeIdCounter) _gradeIdCounter = n;
    }
    for (final item in _teacherNotes) {
      final n = int.tryParse(item.id.replaceFirst('note-', ''));
      if (n != null && n > _teacherNoteIdCounter) _teacherNoteIdCounter = n;
    }
    for (final item in _lessonPeriods) {
      final n = int.tryParse(item.id.replaceFirst('per-', ''));
      if (n != null && n > _lessonPeriodIdCounter) _lessonPeriodIdCounter = n;
    }
    for (final item in _classTimetable) {
      final n = int.tryParse(item.id.replaceFirst('tt-', ''));
      if (n != null && n > _classTimetableIdCounter) {
        _classTimetableIdCounter = n;
      }
    }
    for (final membership in _memberships) {
      final n = int.tryParse(membership.id.replaceFirst('mem-', ''));
      if (n != null && n > _membershipIdCounter) _membershipIdCounter = n;
    }
    for (final list in _attendanceByClass.values) {
      for (final item in list) {
        final n = int.tryParse(item.id.replaceFirst('att-', ''));
        if (n != null && n > _attendanceIdCounter) {
          _attendanceIdCounter = n;
        }
      }
    }
  }

  List<Announcement> announcementsFor(String className) {
    return _announcements
        .where(
          (item) =>
              item.className == className &&
              _matchesActiveSchool(item.schoolId),
        )
        .toList(growable: false);
  }

  /// Homework for [className], optionally limited to one subject.
  ///
  /// Prefer [subjectId] (ActiveAppContext) over a loose name. Subject matching
  /// is trimmed. When [activeSchoolId] is set, [className] must belong to that
  /// school or the result is empty (no cross-school rows).
  ///
  /// If [subjectId] is set but cannot be resolved, returns empty (never falls
  /// back to unfiltered class homework).
  List<Homework> homeworkFor(
    String className, {
    String? subjectName,
    int? subjectId,
  }) {
    if (activeSchoolId != null && !classes.contains(className)) {
      return const <Homework>[];
    }

    final String? filterSubject;
    if (subjectId != null) {
      final name = subjectById(subjectId)?.name.trim();
      if (name == null || name.isEmpty) return const <Homework>[];
      filterSubject = name;
    } else {
      final trimmed = subjectName?.trim();
      filterSubject = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    }

    return _homework
        .where((item) {
          if (item.className != className) return false;
          if (filterSubject != null && item.subject.trim() != filterSubject) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<Grade> gradesFor(String className) {
    return gradesForClass(className);
  }

  /// Grades scoped to the selected class roster (and optional filters).
  ///
  /// Class names are unique within the active school workspace. Only students
  /// currently in [className] are included, so orphaned rows are ignored.
  List<Grade> gradesForClass(
    String className, {
    String? subjectName,
    String? studentId,
    String? term,
  }) {
    return gradesForStudentContext(
      className: className,
      studentId: studentId,
      subjectName: subjectName,
      term: term,
    );
  }

  /// Shared grade filter for student summary + grade detail screens.
  ///
  /// Source of truth for the student key: [Grade.studentId] == [Student.id]
  /// (not userAccountId / guardian link id).
  ///
  /// Optional [subjectId] / [subjectName] / [term] are applied only when
  /// non-null and non-empty — never as `subject = NULL` style matches.
  List<Grade> gradesForStudentContext({
    required String className,
    String? studentId,
    int? subjectId,
    String? subjectName,
    String? term,
  }) {
    if (activeSchoolId != null && !classes.contains(className)) {
      return const <Grade>[];
    }

    final rosterIds = studentsFor(className).map((s) => s.id).toSet();

    String? filterSubject;
    if (subjectId != null) {
      final name = subjectById(subjectId)?.name.trim();
      if (name == null || name.isEmpty) return const <Grade>[];
      filterSubject = name;
    } else {
      final trimmed = subjectName?.trim();
      filterSubject = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    }

    final trimmedTerm = term?.trim();
    final filterTerm = (trimmedTerm == null || trimmedTerm.isEmpty)
        ? null
        : trimmedTerm;

    return _grades
        .where((item) {
          if (item.className != className) return false;
          if (!rosterIds.contains(item.studentId)) return false;
          if (studentId != null && item.studentId != studentId) return false;
          if (filterSubject != null && item.subject.trim() != filterSubject) {
            return false;
          }
          if (filterTerm != null && item.term.trim() != filterTerm) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  /// Average of parseable numeric scores.
  ///
  /// Missing-grade rule: students (or subject groups) with no valid numeric
  /// scores return `null`. The UI shows “Дүн оруулаагүй”. Non-numeric score
  /// strings are ignored. Grades removed from storage are not included.
  double? averageScore(Iterable<Grade> grades) {
    final scores = <double>[];
    for (final grade in grades) {
      final value = double.tryParse(grade.score.trim());
      if (value != null) scores.add(value);
    }
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  /// One-decimal display, or “Дүн оруулаагүй” when [average] is null.
  String formatGradeAverage(double? average) {
    if (average == null) return 'Дүн оруулаагүй';
    return average.toStringAsFixed(1);
  }

  double? averageGradeForClassStudent({
    required String className,
    required String studentId,
    String? subjectName,
    int? subjectId,
    String? term,
  }) {
    return averageScore(
      gradesForStudentContext(
        className: className,
        studentId: studentId,
        subjectName: subjectName,
        subjectId: subjectId,
        term: term,
      ),
    );
  }

  List<AttendanceRecord> attendanceFor(String className) {
    return List<AttendanceRecord>.unmodifiable(
      _attendanceByClass[className] ?? const <AttendanceRecord>[],
    );
  }

  List<Student> studentsFor(String className) {
    return List<Student>.unmodifiable(
      _studentsByClass[className] ?? const <Student>[],
    );
  }

  String? journalSubjectFor(String className) =>
      _journalSubjectByClass[className];

  String? journalTermFor(String className) => _journalTermByClass[className];

  void setJournalSubject(String className, String? subject) {
    if (_journalSubjectByClass[className] == subject) return;
    _journalSubjectByClass[className] = subject;
    notifyListeners();
  }

  void setJournalTerm(String className, String? term) {
    if (_journalTermByClass[className] == term) return;
    _journalTermByClass[className] = term;
    notifyListeners();
  }

  bool hasUnreadAnnouncements(String className) {
    return _announcements.any(
      (item) =>
          item.className == className &&
          _matchesActiveSchool(item.schoolId) &&
          _unreadAnnouncementIds.contains(item.id),
    );
  }

  int unreadAnnouncementCount(String className) {
    return _announcements
        .where(
          (item) =>
              item.className == className &&
              _matchesActiveSchool(item.schoolId) &&
              _unreadAnnouncementIds.contains(item.id),
        )
        .length;
  }

  void markAnnouncementsViewed(String className) {
    final ids = _announcements
        .where(
          (item) =>
              item.className == className &&
              _matchesActiveSchool(item.schoolId),
        )
        .map((item) => item.id)
        .toSet();
    final before = _unreadAnnouncementIds.length;
    _unreadAnnouncementIds.removeWhere(ids.contains);
    if (_unreadAnnouncementIds.length != before) {
      notifyListeners();
    }
  }

  String nextStudentId(String className) {
    _studentIdCounter += 1;
    return '$className-$_studentIdCounter';
  }

  String nextAnnouncementId() {
    _announcementIdCounter += 1;
    return 'ann-$_announcementIdCounter';
  }

  String nextHomeworkId() {
    _homeworkIdCounter += 1;
    return 'hw-$_homeworkIdCounter';
  }

  String nextGradeId() {
    _gradeIdCounter += 1;
    return 'gr-$_gradeIdCounter';
  }

  String nextAttendanceId() {
    _attendanceIdCounter += 1;
    return 'att-$_attendanceIdCounter';
  }

  String nextTeacherNoteId() {
    _teacherNoteIdCounter += 1;
    return 'note-$_teacherNoteIdCounter';
  }

  String nextLessonPeriodId() {
    _lessonPeriodIdCounter += 1;
    return 'per-$_lessonPeriodIdCounter';
  }

  String nextClassTimetableId() {
    _classTimetableIdCounter += 1;
    return 'tt-$_classTimetableIdCounter';
  }

  List<LessonPeriod> get lessonPeriods {
    final schoolId = activeSchoolId;
    final copy = schoolId == null
        ? [..._lessonPeriods]
        : _lessonPeriods.where((p) => p.schoolId == schoolId).toList();
    copy.sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
    return List.unmodifiable(copy);
  }

  LessonPeriod? periodById(String id) {
    for (final period in _lessonPeriods) {
      if (period.id == id) return period;
    }
    return null;
  }

  List<ClassTimetable> get classTimetableEntries =>
      List.unmodifiable(_classTimetable);

  List<ClassTimetable> timetableForClass(String classId) {
    return _classTimetable
        .where((e) => e.classId == classId)
        .toList(growable: false);
  }

  List<ClassTimetable> timetableForClassWeekday(String classId, int weekday) {
    return _classTimetable
        .where((e) => e.classId == classId && e.weekday == weekday)
        .toList(growable: false);
  }

  List<ClassTimetable> timetableEntriesForWeekday(int weekday) {
    return _classTimetable
        .where((e) => e.weekday == weekday)
        .toList(growable: false);
  }

  ClassTimetable? timetableSlot({
    required String classId,
    required int weekday,
    required String periodId,
  }) {
    for (final entry in _classTimetable) {
      if (entry.classId == classId &&
          entry.weekday == weekday &&
          entry.periodId == periodId) {
        return entry;
      }
    }
    return null;
  }

  Future<void> addLessonPeriod(LessonPeriod period) async {
    final schoolId = period.schoolId.isNotEmpty
        ? period.schoolId
        : _effectiveSchoolId;
    final saved = period.copyWith(schoolId: schoolId);
    await _repository.insertLessonPeriod(saved);
    _lessonPeriods = [..._lessonPeriods, saved];
    notifyListeners();
  }

  Future<void> updateLessonPeriod(LessonPeriod period) async {
    await _repository.updateLessonPeriod(period);
    final index = _lessonPeriods.indexWhere((item) => item.id == period.id);
    if (index >= 0) {
      _lessonPeriods[index] = period;
      notifyListeners();
    }
  }

  Future<void> deleteLessonPeriod(String id) async {
    await _repository.deleteLessonPeriod(id);
    _lessonPeriods.removeWhere((item) => item.id == id);
    _classTimetable.removeWhere((item) => item.periodId == id);
    notifyListeners();
  }

  Future<void> addClassTimetable(ClassTimetable entry) async {
    final existing = timetableSlot(
      classId: entry.classId,
      weekday: entry.weekday,
      periodId: entry.periodId,
    );
    if (existing != null) {
      throw ArgumentError('SLOT_TAKEN');
    }
    await _repository.insertClassTimetable(entry);
    _classTimetable = [..._classTimetable, entry];
    notifyListeners();
  }

  Future<void> updateClassTimetable(ClassTimetable entry) async {
    final conflict = timetableSlot(
      classId: entry.classId,
      weekday: entry.weekday,
      periodId: entry.periodId,
    );
    if (conflict != null && conflict.id != entry.id) {
      throw ArgumentError('SLOT_TAKEN');
    }
    await _repository.updateClassTimetable(entry);
    final index = _classTimetable.indexWhere((item) => item.id == entry.id);
    if (index >= 0) {
      _classTimetable[index] = entry;
      notifyListeners();
    }
  }

  Future<void> deleteClassTimetable(String id) async {
    await _repository.deleteClassTimetable(id);
    _classTimetable.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  /// Prefer the selected teacher account; fall back to class homeroom.
  String? resolveAuthorTeacherId(String className) {
    final linked = selectedDevelopmentUser?.teacherId;
    if (linked != null && linked.isNotEmpty && teacherById(linked) != null) {
      return linked;
    }
    return homeroomTeacherForClass(className)?.id;
  }

  List<TeacherNote> teacherNotesForClass(String className) {
    final ids = studentsFor(className).map((s) => s.id).toSet();
    final notes = _teacherNotes
        .where((note) => ids.contains(note.studentId))
        .toList(growable: false);
    return _sortedNewestFirst(notes);
  }

  List<TeacherNote> teacherNotesForStudent(
    Student student, {
    required bool forGuardian,
    required bool forStudent,
  }) {
    final notes = _teacherNotes
        .where((note) {
          if (note.studentId != student.id) return false;
          if (forGuardian && !note.isVisibleToGuardian) return false;
          if (forStudent && !note.isVisibleToStudent) return false;
          return true;
        })
        .toList(growable: false);
    return _sortedNewestFirst(notes);
  }

  List<TeacherNote> notesVisibleToStudent(Student student) {
    return teacherNotesForStudent(
      student,
      forGuardian: false,
      forStudent: true,
    );
  }

  List<TeacherNote> notesVisibleToGuardian(Student student) {
    return teacherNotesForStudent(
      student,
      forGuardian: true,
      forStudent: false,
    );
  }

  int newTeacherNoteCountForClass(String className) {
    return teacherNotesForClass(className).length;
  }

  List<TeacherNote> _sortedNewestFirst(List<TeacherNote> notes) {
    final copy = [...notes];
    copy.sort((a, b) {
      final ad = a.createdAtDate;
      final bd = b.createdAtDate;
      if (ad != null && bd != null) return bd.compareTo(ad);
      return b.createdAt.compareTo(a.createdAt);
    });
    return copy;
  }

  Future<void> addAnnouncement(Announcement announcement) async {
    final schoolId = announcement.schoolId.isNotEmpty
        ? announcement.schoolId
        : _effectiveSchoolId;
    final saved = announcement.copyWith(schoolId: schoolId);
    await _repository.insertAnnouncement(saved);
    _announcements.insert(0, saved);
    _unreadAnnouncementIds.add(saved.id);
    notifyListeners();
  }

  Future<void> updateAnnouncement(Announcement announcement) async {
    await _repository.updateAnnouncement(announcement);
    final index = _announcements.indexWhere(
      (item) => item.id == announcement.id,
    );
    if (index >= 0) {
      _announcements[index] = announcement;
      notifyListeners();
    }
  }

  Future<void> deleteAnnouncement(String id) async {
    await _repository.deleteAnnouncement(id);
    _announcements.removeWhere((item) => item.id == id);
    _unreadAnnouncementIds.remove(id);
    notifyListeners();
  }

  Future<void> addHomework(Homework homework) async {
    await _repository.insertHomework(homework);
    _homework.insert(0, homework);
    notifyListeners();
  }

  Future<void> updateHomework(Homework homework) async {
    await _repository.updateHomework(homework);
    final index = _homework.indexWhere((item) => item.id == homework.id);
    if (index >= 0) {
      _homework[index] = homework;
      notifyListeners();
    }
  }

  Future<void> deleteHomework(String id) async {
    await _repository.deleteHomework(id);
    _homework.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  Future<void> addTeacherNote(TeacherNote note) async {
    await _repository.insertTeacherNote(note);
    _teacherNotes = _sortedNewestFirst([..._teacherNotes, note]);
    notifyListeners();
  }

  Future<void> updateTeacherNote(TeacherNote note) async {
    await _repository.updateTeacherNote(note);
    final index = _teacherNotes.indexWhere((item) => item.id == note.id);
    if (index >= 0) {
      _teacherNotes[index] = note;
      _teacherNotes = _sortedNewestFirst(_teacherNotes);
      notifyListeners();
    }
  }

  Future<void> deleteTeacherNote(String id) async {
    await _repository.deleteTeacherNote(id);
    _teacherNotes.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  Future<void> addGrade(Grade grade) async {
    await _repository.insertGrade(grade);
    _grades.insert(0, grade);
    notifyListeners();
  }

  Future<void> addGrades(List<Grade> grades) async {
    if (grades.isEmpty) return;
    await _repository.insertGrades(grades);
    _grades.insertAll(0, grades);
    notifyListeners();
  }

  Future<void> updateGrade(Grade grade) async {
    await _repository.updateGrade(grade);
    final index = _grades.indexWhere((item) => item.id == grade.id);
    if (index >= 0) {
      _grades[index] = grade;
      notifyListeners();
    }
  }

  Future<void> deleteGrade(String id) async {
    await _repository.deleteGrade(id);
    _grades.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  Future<void> addAttendance(String className, AttendanceRecord record) async {
    await _repository.insertAttendance(record);
    final records = _attendanceByClass.putIfAbsent(
      className,
      () => <AttendanceRecord>[],
    );
    records.insert(0, record);
    notifyListeners();
  }

  Future<void> updateAttendance(AttendanceRecord record) async {
    await _repository.updateAttendance(record);
    final records = _attendanceByClass[record.className];
    if (records == null) return;
    final index = records.indexWhere((item) => item.id == record.id);
    if (index < 0) return;
    records[index] = record;
    notifyListeners();
  }

  Future<void> deleteAttendance(String className, String id) async {
    await _repository.deleteAttendance(id);
    _attendanceByClass[className]?.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  Future<void> addStudent(Student student) async {
    _ensureCanManageStudents();
    await _repository.insertStudent(student);
    final students = _studentsByClass.putIfAbsent(
      student.className,
      () => <Student>[],
    );
    students.add(student);
    notifyListeners();
  }

  Future<void> updateStudent(Student student) async {
    _ensureCanManageStudents();
    await _repository.updateStudent(student);
    final students = _studentsByClass[student.className];
    if (students == null) return;

    final index = students.indexWhere((item) => item.id == student.id);
    if (index < 0) return;

    students[index] = student;

    for (var i = 0; i < _grades.length; i++) {
      final grade = _grades[i];
      if (grade.studentId == student.id) {
        final updated = grade.copyWith(studentName: student.fullName);
        _grades[i] = updated;
        await _repository.updateGrade(updated);
      }
    }

    notifyListeners();
  }

  Future<void> deleteStudent(String className, String studentId) async {
    _ensureCanManageStudents();
    final student = studentById(studentId);
    final code = student?.studentCode?.trim() ?? '';
    final sid = student == null ? null : schoolIdForStudent(student);
    if (code.isNotEmpty && sid != null) {
      await _repository.reserveStudentCode(schoolId: sid, code: code);
    }
    await _repository.deleteStudent(studentId);
    _studentsByClass[className]?.removeWhere((item) => item.id == studentId);
    _guardianStudentLinks = [
      for (final link in _guardianStudentLinks)
        if (link.studentId != studentId) link,
    ];
    _userAccounts = [
      for (final user in _userAccounts)
        if (user.studentId != studentId) user,
    ];
    _memberships = [
      for (final membership in _memberships)
        if (membership.studentId != studentId) membership,
    ];
    notifyListeners();
  }
}

/// Thrown when a non-admin tries to manage students.
class PermissionDeniedException implements Exception {
  const PermissionDeniedException([
    this.message = 'Энэ үйлдлийг хийх эрхгүй байна.',
  ]);

  final String message;

  @override
  String toString() => message;
}
