import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfi, databaseFactoryFfiNoIsolate, sqfliteFfiInit;

/// Opens and migrates the local SQLite database for EduBridge.
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const _dbName = 'edubridge.db';
  static const _dbVersion = 21;

  /// Default school for single-school installs and migrated data.
  static const defaultSchoolId = 'sch-default';

  Database? _database;

  /// Call once at app start (and in tests) before using [database].
  ///
  /// Widget tests must use [forWidgetTest] so FFI runs without a separate
  /// isolate (otherwise `pumpWidget` can deadlock).
  static Future<void> initializeFactory({bool forWidgetTest = false}) async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = forWidgetTest
          ? databaseFactoryFfiNoIsolate
          : databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    _database = await _open();
    return _database!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Opens an isolated in-memory database for widget/unit tests.
  @visibleForTesting
  Future<Database> openInMemoryForTest() async {
    await initializeFactory(forWidgetTest: true);
    return databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        // Allow parallel test isolates / sequential suites to open fresh DBs.
        singleInstance: false,
        onOpen: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
  }

  /// Creates a v3-shaped DB then applies migrations up to the current version.
  @visibleForTesting
  Future<Database> openInMemoryUpgradingFrom(int fromVersion) async {
    await initializeFactory(forWidgetTest: true);
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: fromVersion,
        onCreate: (db, version) async {
          await _onCreateLegacy(db, version);
        },
        singleInstance: false,
        onOpen: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
    await _onUpgrade(db, fromVersion, _dbVersion);
    await db.execute('PRAGMA user_version = $_dbVersion');
    return db;
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createSettingsAndSubjects(db);
    }
    if (oldVersion < 3) {
      await _migrateSettingsV3(db);
    }
    if (oldVersion < 4) {
      await _migrateSchoolStructureV4(db);
    }
    if (oldVersion < 5) {
      await _migrateGuardianV5(db);
    }
    if (oldVersion < 6) {
      await _migrateUserAccountsV6(db);
    }
    if (oldVersion < 7) {
      await _migrateTeacherNotesV7(db);
    }
    if (oldVersion < 8) {
      await _migrateTimetableV8(db);
    }
    if (oldVersion < 9) {
      await _migrateSchoolContextV9(db);
    }
    if (oldVersion < 10) {
      await _migrateSchoolSettingsV10(db);
    }
    if (oldVersion < 11) {
      await _migrateStudentCodeV11(db);
    }
    if (oldVersion < 12) {
      await _migrateAccountActivationV12(db);
    }
    if (oldVersion < 13) {
      await _migrateStabilizationV13(db);
    }
    if (oldVersion < 14) {
      await _migrateRequirePasswordChangeV14(db);
    }
    if (oldVersion < 15) {
      await _migrateLessonOccurrencesV15(db);
    }
    if (oldVersion < 16) {
      await _migrateAttendanceDateKeyV16(db);
    }
    if (oldVersion < 17) {
      await _migrateAttendanceSubjectIdV17(db);
    }
    if (oldVersion < 18) {
      await _migrateAttendanceHistoryMetaV18(db);
    }
    if (oldVersion < 19) {
      await _migrateTeacherAuthUidV19(db);
    }
    if (oldVersion < 20) {
      await _migrateClassGradeSectionV20(db);
    }
    if (oldVersion < 21) {
      await _migrateRecordOwnershipV21(db);
    }
  }

  /// Create schema as of version 3 (for migration tests).
  Future<void> _onCreateLegacy(Database db, int version) async {
    await db.execute('''
      CREATE TABLE classes (
        name TEXT PRIMARY KEY
      )
    ''');
    await db.execute('''
      CREATE TABLE students (
        id TEXT PRIMARY KEY,
        class_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        first_name TEXT NOT NULL,
        gender TEXT NOT NULL,
        register TEXT,
        phone TEXT,
        guardian TEXT,
        FOREIGN KEY (class_name) REFERENCES classes(name)
      )
    ''');
    await db.execute('''
      CREATE TABLE attendance (
        id TEXT PRIMARY KEY,
        class_name TEXT NOT NULL,
        date TEXT NOT NULL,
        present_count INTEGER NOT NULL,
        late_count INTEGER NOT NULL,
        absent_count INTEGER NOT NULL,
        entries_json TEXT,
        legacy_status TEXT,
        FOREIGN KEY (class_name) REFERENCES classes(name)
      )
    ''');
    await db.execute('''
      CREATE TABLE grades (
        id TEXT PRIMARY KEY,
        class_name TEXT NOT NULL,
        student_id TEXT NOT NULL,
        student_name TEXT NOT NULL,
        subject TEXT NOT NULL,
        score TEXT NOT NULL,
        term TEXT NOT NULL,
        letter_grade TEXT,
        FOREIGN KEY (class_name) REFERENCES classes(name)
      )
    ''');
    await db.execute('''
      CREATE TABLE homework (
        id TEXT PRIMARY KEY,
        class_name TEXT NOT NULL,
        subject TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        due_date TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (class_name) REFERENCES classes(name)
      )
    ''');
    await db.execute('''
      CREATE TABLE announcements (
        id TEXT PRIMARY KEY,
        class_name TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        date TEXT NOT NULL,
        is_featured INTEGER NOT NULL,
        FOREIGN KEY (class_name) REFERENCES classes(name)
      )
    ''');
    await _createSettingsAndSubjects(db);
    if (version >= 3) {
      // Columns already in _createSettingsAndSubjects for fresh v3+ create path.
    }
    await db.insert('classes', {'name': '6А'});
    await db.insert('classes', {'name': '7А'});
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE classes (
        name TEXT PRIMARY KEY,
        homeroom_teacher_id TEXT,
        school_id TEXT NOT NULL DEFAULT '$defaultSchoolId',
        grade_level INTEGER,
        section TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE students (
        id TEXT PRIMARY KEY,
        class_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        first_name TEXT NOT NULL,
        gender TEXT NOT NULL,
        register TEXT,
        phone TEXT,
        guardian TEXT,
        student_code TEXT,
        FOREIGN KEY (class_name) REFERENCES classes(name)
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        id TEXT PRIMARY KEY,
        class_name TEXT NOT NULL,
        date TEXT NOT NULL,
        present_count INTEGER NOT NULL,
        late_count INTEGER NOT NULL,
        absent_count INTEGER NOT NULL,
        entries_json TEXT,
        legacy_status TEXT,
        date_key TEXT,
        school_id TEXT,
        recorded_at TEXT,
        subject_id INTEGER,
        recorded_by_teacher_id TEXT,
        note TEXT,
        created_by_uid TEXT,
        updated_by_uid TEXT,
        FOREIGN KEY (class_name) REFERENCES classes(name)
      )
    ''');

    await db.execute('''
      CREATE TABLE grades (
        id TEXT PRIMARY KEY,
        class_name TEXT NOT NULL,
        student_id TEXT NOT NULL,
        student_name TEXT NOT NULL,
        subject TEXT NOT NULL,
        score TEXT NOT NULL,
        term TEXT NOT NULL,
        letter_grade TEXT,
        grade_date TEXT,
        created_by_uid TEXT,
        updated_by_uid TEXT,
        FOREIGN KEY (class_name) REFERENCES classes(name)
      )
    ''');

    await db.execute('''
      CREATE TABLE homework (
        id TEXT PRIMARY KEY,
        class_name TEXT NOT NULL,
        subject TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        due_date TEXT NOT NULL,
        status TEXT NOT NULL,
        school_id TEXT,
        subject_id INTEGER,
        created_by_uid TEXT,
        created_by_teacher_id TEXT,
        created_at TEXT,
        updated_at TEXT,
        updated_by_uid TEXT,
        FOREIGN KEY (class_name) REFERENCES classes(name)
      )
    ''');

    await db.execute('''
      CREATE TABLE announcements (
        id TEXT PRIMARY KEY,
        class_name TEXT NOT NULL,
        school_id TEXT NOT NULL DEFAULT '$defaultSchoolId',
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        date TEXT NOT NULL,
        is_featured INTEGER NOT NULL,
        created_by_uid TEXT,
        created_by_teacher_id TEXT,
        created_at TEXT,
        updated_at TEXT,
        updated_by_uid TEXT,
        FOREIGN KEY (class_name) REFERENCES classes(name)
      )
    ''');

    await _createSettingsAndSubjects(db);
    await _createSchoolStructureTables(db);
    await _createGuardianTables(db);
    await _createUserAccountTables(db);
    await _createTeacherNotesTable(db);
    await _createTimetableTables(db);
    await _createSchoolContextTables(db);
    await _createStabilizationV13Tables(db);
    await _createLessonOccurrencesTable(db);
    await _insertDefaultSchool(db);

    const classNames = [
      '6А',
      '6Б',
      '7А',
      '7Б',
      '8А',
      '8Б',
      '9А',
      '9Б',
      '10А',
      '10Б',
      '11А',
      '11Б',
      '12А',
      '12Б',
    ];
    final batch = db.batch();
    for (final name in classNames) {
      batch.insert('classes', {'name': name, 'school_id': defaultSchoolId});
    }
    await batch.commit(noResult: true);
    await _migrateSchoolSettingsV10(db);
  }

  Future<void> _createSettingsAndSubjects(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        school_name TEXT NOT NULL DEFAULT '',
        school_code TEXT NOT NULL DEFAULT '',
        teacher_name TEXT NOT NULL DEFAULT '',
        teacher_phone TEXT NOT NULL DEFAULT '',
        teacher_email TEXT NOT NULL DEFAULT '',
        theme_mode TEXT NOT NULL DEFAULT 'light',
        language_code TEXT NOT NULL DEFAULT 'mn',
        academic_year TEXT NOT NULL DEFAULT '2025–2026',
        current_semester TEXT NOT NULL DEFAULT '1-р улирал'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        school_id TEXT NOT NULL DEFAULT '$defaultSchoolId',
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.insert('settings', {
      'id': 1,
      'school_name': '',
      'school_code': '',
      'teacher_name': '',
      'teacher_phone': '',
      'teacher_email': '',
      'theme_mode': 'light',
      'language_code': 'mn',
      'academic_year': '2025–2026',
      'current_semester': '1-р улирал',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _createSchoolStructureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS school_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        school_name TEXT NOT NULL DEFAULT '',
        academic_year TEXT NOT NULL DEFAULT '2025–2026',
        current_semester TEXT NOT NULL DEFAULT '1-р улирал'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS teachers (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        school_id TEXT NOT NULL DEFAULT '$defaultSchoolId',
        phone TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1,
        auth_uid TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS class_subject_teachers (
        class_id TEXT NOT NULL,
        subject_id INTEGER NOT NULL,
        teacher_id TEXT NOT NULL,
        PRIMARY KEY (class_id, subject_id),
        FOREIGN KEY (class_id) REFERENCES classes(name),
        FOREIGN KEY (subject_id) REFERENCES subjects(id),
        FOREIGN KEY (teacher_id) REFERENCES teachers(id)
      )
    ''');

    // Seed school_settings from legacy settings when empty.
    final existing = await db.query(
      'school_settings',
      where: 'id = ?',
      whereArgs: [1],
    );
    if (existing.isEmpty) {
      final legacy = await db.query(
        'settings',
        where: 'id = ?',
        whereArgs: [1],
      );
      if (legacy.isNotEmpty) {
        final row = legacy.first;
        await db.insert('school_settings', {
          'id': 1,
          'school_name': row['school_name'] ?? '',
          'academic_year': row['academic_year'] ?? '2025–2026',
          'current_semester': row['current_semester'] ?? '1-р улирал',
        });
      } else {
        await db.insert('school_settings', {
          'id': 1,
          'school_name': '',
          'academic_year': '2025–2026',
          'current_semester': '1-р улирал',
        });
      }
    }
  }

  Future<void> _migrateSettingsV3(Database db) async {
    Future<void> addColumn(String sql) async {
      try {
        await db.execute(sql);
      } catch (_) {}
    }

    await addColumn(
      "ALTER TABLE settings ADD COLUMN school_code TEXT NOT NULL DEFAULT ''",
    );
    await addColumn(
      "ALTER TABLE settings ADD COLUMN teacher_phone TEXT NOT NULL DEFAULT ''",
    );
    await addColumn(
      "ALTER TABLE settings ADD COLUMN teacher_email TEXT NOT NULL DEFAULT ''",
    );
    await addColumn(
      "ALTER TABLE settings ADD COLUMN theme_mode TEXT NOT NULL DEFAULT 'light'",
    );
    await addColumn(
      "ALTER TABLE settings ADD COLUMN language_code TEXT NOT NULL DEFAULT 'mn'",
    );
  }

  Future<void> _migrateSchoolStructureV4(Database db) async {
    Future<void> addColumn(String sql) async {
      try {
        await db.execute(sql);
      } catch (_) {}
    }

    await addColumn('ALTER TABLE classes ADD COLUMN homeroom_teacher_id TEXT');
    await addColumn(
      'ALTER TABLE subjects ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
    );

    await _createSchoolStructureTables(db);
  }

  Future<void> _createGuardianTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS guardian_read_announcements (
        announcement_id TEXT PRIMARY KEY,
        read_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_prefs (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _migrateGuardianV5(Database db) async {
    await _createGuardianTables(db);
  }

  Future<void> _createUserAccountTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS guardians (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        school_id TEXT NOT NULL DEFAULT '$defaultSchoolId',
        phone TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS guardian_students (
        guardian_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        relationship TEXT NOT NULL,
        PRIMARY KEY (guardian_id, student_id),
        FOREIGN KEY (guardian_id) REFERENCES guardians(id),
        FOREIGN KEY (student_id) REFERENCES students(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_accounts (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        teacher_id TEXT,
        guardian_id TEXT,
        student_id TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        account_status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        failed_pin_attempts INTEGER NOT NULL DEFAULT 0,
        pin_locked_until TEXT,
        require_password_change INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_user_accounts_username '
      'ON user_accounts(username)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS used_student_codes (
        school_id TEXT NOT NULL,
        code_key TEXT NOT NULL,
        PRIMARY KEY (school_id, code_key)
      )
    ''');
  }

  Future<void> _migrateUserAccountsV6(Database db) async {
    await _createUserAccountTables(db);
  }

  Future<void> _createTeacherNotesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS teacher_notes (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        teacher_id TEXT NOT NULL,
        subject_id INTEGER,
        created_at TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        priority TEXT NOT NULL,
        is_visible_to_guardian INTEGER NOT NULL,
        is_visible_to_student INTEGER NOT NULL,
        school_id TEXT,
        class_id TEXT,
        created_by_uid TEXT,
        updated_at TEXT,
        updated_by_uid TEXT,
        FOREIGN KEY (student_id) REFERENCES students(id),
        FOREIGN KEY (teacher_id) REFERENCES teachers(id),
        FOREIGN KEY (subject_id) REFERENCES subjects(id)
      )
    ''');
  }

  Future<void> _migrateTeacherNotesV7(Database db) async {
    await _createTeacherNotesTable(db);
  }

  Future<void> _createTimetableTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lesson_periods (
        id TEXT PRIMARY KEY,
        school_id TEXT NOT NULL DEFAULT '$defaultSchoolId',
        period_number INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS class_timetable (
        id TEXT PRIMARY KEY,
        class_id TEXT NOT NULL,
        weekday INTEGER NOT NULL,
        period_id TEXT NOT NULL,
        subject_id INTEGER NOT NULL,
        FOREIGN KEY (class_id) REFERENCES classes(name),
        FOREIGN KEY (period_id) REFERENCES lesson_periods(id),
        FOREIGN KEY (subject_id) REFERENCES subjects(id)
      )
    ''');

    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_class_timetable_slot '
      'ON class_timetable(class_id, weekday, period_id)',
    );
  }

  Future<void> _migrateTimetableV8(Database db) async {
    await _createTimetableTables(db);
  }

  Future<void> _createSchoolContextTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schools (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT,
        address TEXT,
        is_active INTEGER NOT NULL,
        login_prefix TEXT,
        student_code_seq INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_school_memberships (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        school_id TEXT NOT NULL,
        role TEXT NOT NULL,
        teacher_id TEXT,
        guardian_id TEXT,
        student_id TEXT,
        is_active INTEGER NOT NULL
      )
    ''');
  }

  Future<String> _defaultSchoolName(Database db) async {
    try {
      final rows = await db.query(
        'school_settings',
        where: 'school_id = ?',
        whereArgs: [defaultSchoolId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final name = rows.first['school_name'] as String?;
        if (name != null && name.trim().isNotEmpty) return name.trim();
      }
    } catch (_) {}
    try {
      final rows = await db.query(
        'school_settings',
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final name = rows.first['school_name'] as String?;
        if (name != null && name.trim().isNotEmpty) return name.trim();
      }
    } catch (_) {}
    try {
      final rows = await db.query(
        'settings',
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final name = rows.first['school_name'] as String?;
        if (name != null && name.trim().isNotEmpty) return name.trim();
      }
    } catch (_) {}
    return 'EduBridge сургууль';
  }

  Future<void> _insertDefaultSchool(Database db) async {
    final existing = await db.query(
      'schools',
      where: 'id = ?',
      whereArgs: [defaultSchoolId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    final settings = await db.query(
      'settings',
      where: 'id = ?',
      whereArgs: [1],
    );
    String? code;
    if (settings.isNotEmpty) {
      final raw = settings.first['school_code'] as String?;
      if (raw != null && raw.trim().isNotEmpty) code = raw.trim();
    }

    await db.insert('schools', {
      'id': defaultSchoolId,
      'name': await _defaultSchoolName(db),
      'code': code,
      'address': null,
      'is_active': 1,
    });
  }

  Future<void> _migrateSchoolContextV9(Database db) async {
    Future<void> addColumn(String sql) async {
      try {
        await db.execute(sql);
      } catch (_) {}
    }

    await _createSchoolContextTables(db);

    final schoolName = await _defaultSchoolName(db);
    await db.insert('schools', {
      'id': defaultSchoolId,
      'name': schoolName,
      'code': null,
      'address': null,
      'is_active': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await addColumn(
      "ALTER TABLE classes ADD COLUMN school_id TEXT DEFAULT '$defaultSchoolId'",
    );
    await addColumn(
      "ALTER TABLE teachers ADD COLUMN school_id TEXT DEFAULT '$defaultSchoolId'",
    );
    await addColumn(
      "ALTER TABLE subjects ADD COLUMN school_id TEXT DEFAULT '$defaultSchoolId'",
    );
    await addColumn(
      "ALTER TABLE guardians ADD COLUMN school_id TEXT DEFAULT '$defaultSchoolId'",
    );
    await addColumn(
      "ALTER TABLE lesson_periods ADD COLUMN school_id TEXT DEFAULT '$defaultSchoolId'",
    );
    await addColumn(
      "ALTER TABLE announcements ADD COLUMN school_id TEXT DEFAULT '$defaultSchoolId'",
    );

    for (final table in const [
      'classes',
      'teachers',
      'subjects',
      'guardians',
      'lesson_periods',
      'announcements',
    ]) {
      try {
        await db.update(table, {
          'school_id': defaultSchoolId,
        }, where: 'school_id IS NULL');
      } catch (_) {
        // Table may not exist on incomplete legacy upgrade paths used in tests.
      }
    }

    try {
      final users = await db.query('user_accounts');
      for (final row in users) {
        final userId = row['id']! as String;
        await db.insert('user_school_memberships', {
          'id': 'mem-$userId',
          'user_id': userId,
          'school_id': defaultSchoolId,
          'role': row['role'],
          'teacher_id': row['teacher_id'],
          'guardian_id': row['guardian_id'],
          'student_id': row['student_id'],
          'is_active': row['is_active'] ?? 1,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    } catch (_) {}
  }

  /// Moves school_settings from single-row `id=1` to per-school `school_id`.
  Future<void> _migrateSchoolSettingsV10(Database db) async {
    final info = await db.rawQuery('PRAGMA table_info(school_settings)');
    final cols = info.map((r) => r['name'] as String).toSet();
    if (cols.contains('school_id') && !cols.contains('id')) {
      // Already migrated — ensure every school has a settings row.
      await _ensureSettingsForAllSchools(db);
      return;
    }

    await db.execute('''
      CREATE TABLE school_settings_v10 (
        school_id TEXT PRIMARY KEY,
        school_name TEXT NOT NULL DEFAULT '',
        academic_year TEXT NOT NULL DEFAULT '2025–2026',
        current_semester TEXT NOT NULL DEFAULT '1-р улирал'
      )
    ''');

    var copied = false;
    try {
      final rows = await db.query('school_settings');
      if (rows.isNotEmpty) {
        final row = rows.first;
        await db.insert('school_settings_v10', {
          'school_id': defaultSchoolId,
          'school_name': row['school_name'] ?? await _defaultSchoolName(db),
          'academic_year': row['academic_year'] ?? '2025–2026',
          'current_semester': row['current_semester'] ?? '1-р улирал',
        });
        copied = true;
      }
    } catch (_) {}

    if (!copied) {
      await db.insert('school_settings_v10', {
        'school_id': defaultSchoolId,
        'school_name': await _defaultSchoolName(db),
        'academic_year': '2025–2026',
        'current_semester': '1-р улирал',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    try {
      await db.execute('DROP TABLE school_settings');
    } catch (_) {}
    await db.execute(
      'ALTER TABLE school_settings_v10 RENAME TO school_settings',
    );
    await _ensureSettingsForAllSchools(db);
  }

  Future<void> _ensureSettingsForAllSchools(Database db) async {
    try {
      final schools = await db.query('schools');
      for (final school in schools) {
        final schoolId = school['id']! as String;
        await db.insert('school_settings', {
          'school_id': schoolId,
          'school_name': school['name'] ?? '',
          'academic_year': '2025–2026',
          'current_semester': '1-р улирал',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    } catch (_) {}
  }

  /// Adds optional school-scoped student login codes.
  Future<void> _migrateStudentCodeV11(Database db) async {
    final info = await db.rawQuery('PRAGMA table_info(students)');
    final cols = info.map((r) => r['name'] as String).toSet();
    if (cols.contains('student_code')) return;
    await db.execute('ALTER TABLE students ADD COLUMN student_code TEXT');
  }

  /// Account activation status, school code sequences, used-code registry.
  Future<void> _migrateAccountActivationV12(Database db) async {
    Future<void> addColumn(String sql) async {
      try {
        await db.execute(sql);
      } catch (_) {}
    }

    await addColumn(
      "ALTER TABLE user_accounts ADD COLUMN account_status TEXT NOT NULL DEFAULT 'active'",
    );
    await addColumn('ALTER TABLE schools ADD COLUMN login_prefix TEXT');
    await addColumn(
      'ALTER TABLE schools ADD COLUMN student_code_seq INTEGER NOT NULL DEFAULT 0',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS used_student_codes (
        school_id TEXT NOT NULL,
        code_key TEXT NOT NULL,
        PRIMARY KEY (school_id, code_key)
      )
    ''');

    // Existing accounts with a password hash remain active.
    try {
      await db.update('user_accounts', {
        'account_status': 'active',
      }, where: "account_status IS NULL OR account_status = ''");
    } catch (_) {}
  }

  /// Homework check status, announcement read receipts, PIN lockout columns.
  Future<void> _createStabilizationV13Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS student_homework_status (
        id TEXT PRIMARY KEY,
        school_id TEXT NOT NULL,
        class_id TEXT NOT NULL,
        homework_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        status TEXT NOT NULL,
        checked_by_teacher_id TEXT,
        checked_at TEXT,
        teacher_comment TEXT,
        updated_at TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_student_homework_status_unique '
      'ON student_homework_status(school_id, homework_id, student_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_student_homework_status_student '
      'ON student_homework_status(student_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_student_homework_status_homework '
      'ON student_homework_status(homework_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_student_homework_status_status '
      'ON student_homework_status(status)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS announcement_read_receipts (
        id TEXT PRIMARY KEY,
        school_id TEXT NOT NULL,
        announcement_id TEXT NOT NULL,
        user_account_id TEXT NOT NULL,
        role TEXT NOT NULL,
        student_id TEXT,
        read_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_announcement_read_receipts_unique '
      'ON announcement_read_receipts(school_id, announcement_id, user_account_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_announcement_read_receipts_announcement '
      'ON announcement_read_receipts(announcement_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_announcement_read_receipts_user '
      'ON announcement_read_receipts(user_account_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_announcement_read_receipts_student '
      'ON announcement_read_receipts(student_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_announcement_read_receipts_read_at '
      'ON announcement_read_receipts(read_at)',
    );
  }

  Future<void> _migrateStabilizationV13(Database db) async {
    await _createStabilizationV13Tables(db);

    Future<void> addColumn(String sql) async {
      try {
        await db.execute(sql);
      } catch (_) {}
    }

    await addColumn(
      'ALTER TABLE user_accounts ADD COLUMN failed_pin_attempts '
      'INTEGER NOT NULL DEFAULT 0',
    );
    await addColumn(
      'ALTER TABLE user_accounts ADD COLUMN pin_locked_until TEXT',
    );
  }

  /// Teacher temporary-password must-change flag.
  Future<void> _migrateRequirePasswordChangeV14(Database db) async {
    try {
      await db.execute(
        'ALTER TABLE user_accounts ADD COLUMN require_password_change '
        'INTEGER NOT NULL DEFAULT 0',
      );
    } catch (_) {}
  }

  Future<void> _createLessonOccurrencesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lesson_occurrences (
        id TEXT PRIMARY KEY,
        school_id TEXT NOT NULL,
        class_id TEXT NOT NULL,
        subject_id INTEGER NOT NULL,
        teacher_id TEXT NOT NULL,
        lesson_date TEXT NOT NULL,
        period_id TEXT NOT NULL,
        timetable_entry_id TEXT,
        topic TEXT,
        note TEXT,
        created_at TEXT NOT NULL,
        UNIQUE(school_id, class_id, subject_id, lesson_date, period_id)
      )
    ''');
  }

  /// Schedule-driven class journal occurrences.
  Future<void> _migrateLessonOccurrencesV15(Database db) async {
    await _createLessonOccurrencesTable(db);
  }

  /// Stable local dateKey (+ school/recorded metadata) for attendance matching.
  Future<void> _migrateAttendanceDateKeyV16(Database db) async {
    await db.execute('ALTER TABLE attendance ADD COLUMN date_key TEXT');
    await db.execute('ALTER TABLE attendance ADD COLUMN school_id TEXT');
    await db.execute('ALTER TABLE attendance ADD COLUMN recorded_at TEXT');

    final rows = await db.query('attendance', columns: ['id', 'date']);
    for (final row in rows) {
      final id = row['id'] as String?;
      final date = (row['date'] as String?)?.trim() ?? '';
      if (id == null || id.isEmpty) continue;

      String? key;
      final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(date);
      if (iso != null) {
        key = date;
      } else {
        final mongolian = RegExp(
          r'^(\d+)\s*оны\s*(\d+)\s*сарын\s*(\d+)$',
        ).firstMatch(date);
        if (mongolian != null) {
          final y = mongolian.group(1)!.padLeft(4, '0');
          final m = mongolian.group(2)!.padLeft(2, '0');
          final d = mongolian.group(3)!.padLeft(2, '0');
          key = '$y-$m-$d';
        }
      }
      if (key == null) continue;
      await db.update(
        'attendance',
        {'date_key': key},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Subject scope for attendance uniqueness (school/class/subject/date).
  Future<void> _migrateAttendanceSubjectIdV17(Database db) async {
    await db.execute('ALTER TABLE attendance ADD COLUMN subject_id INTEGER');
  }

  /// Append-only history metadata: who recorded + optional note.
  Future<void> _migrateAttendanceHistoryMetaV18(Database db) async {
    await db.execute(
      'ALTER TABLE attendance ADD COLUMN recorded_by_teacher_id TEXT',
    );
    await db.execute('ALTER TABLE attendance ADD COLUMN note TEXT');
  }

  /// Firebase Auth uid link on local teacher rows (canonical: authUid).
  Future<void> _migrateTeacherAuthUidV19(Database db) async {
    try {
      await db.execute('ALTER TABLE teachers ADD COLUMN auth_uid TEXT');
    } catch (_) {
      // Column already present when teachers were created by a newer
      // `_createSchoolStructureTables` during an earlier upgrade step.
    }
  }

  /// Grade level (1–12) + optional section for class naming.
  Future<void> _migrateClassGradeSectionV20(Database db) async {
    try {
      await db.execute('ALTER TABLE classes ADD COLUMN grade_level INTEGER');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE classes ADD COLUMN section TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE grades ADD COLUMN grade_date TEXT');
    } catch (_) {}

    final rows = await db.query('classes');
    for (final row in rows) {
      final name = (row['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      if (row['grade_level'] != null) continue;
      final parsed = _tryParseClassName(name);
      if (parsed == null) {
        if (kDebugMode) {
          debugPrint('LEGACY_CLASS_UNPARSED name=$name');
        }
        continue;
      }
      await db.update(
        'classes',
        {
          'grade_level': parsed.$1,
          'section': parsed.$2,
        },
        where: 'name = ?',
        whereArgs: [name],
      );
    }
  }

  /// Lightweight parse for migration (mirrors [ClassNaming.tryParse]).
  (int, String?)? _tryParseClassName(String name) {
    final numbered = RegExp(
      r'^(\d{1,2})\s*[-–]?\s*р\s*анги$',
      caseSensitive: false,
    ).firstMatch(name);
    if (numbered != null) {
      final grade = int.tryParse(numbered.group(1)!);
      if (grade != null && grade >= 1 && grade <= 12) return (grade, null);
      return null;
    }
    final withSuffix = RegExp(
      r'^(\d{1,2})\s*([а-яёөүa-z0-9]{1,3})\s*анги$',
      caseSensitive: false,
    ).firstMatch(name);
    if (withSuffix != null) {
      final grade = int.tryParse(withSuffix.group(1)!);
      final section = withSuffix.group(2)?.trim().toLowerCase();
      if (grade != null &&
          grade >= 1 &&
          grade <= 12 &&
          section != null &&
          section.isNotEmpty) {
        return (grade, section);
      }
      return null;
    }
    final compact = RegExp(
      r'^(\d{1,2})([а-яёөүa-zА-ЯЁӨҮA-Z]{1,3})$',
    ).firstMatch(name);
    if (compact != null) {
      final grade = int.tryParse(compact.group(1)!);
      final section = compact.group(2)?.trim().toLowerCase();
      if (grade != null &&
          grade >= 1 &&
          grade <= 12 &&
          section != null &&
          section.isNotEmpty) {
        return (grade, section);
      }
    }
    final digitsOnly = RegExp(r'^(\d{1,2})$').firstMatch(name);
    if (digitsOnly != null) {
      final grade = int.tryParse(digitsOnly.group(1)!);
      if (grade != null && grade >= 1 && grade <= 12) return (grade, null);
    }
    return null;
  }

  /// Ownership columns for advice / announcements / homework / grades / attendance.
  Future<void> _migrateRecordOwnershipV21(Database db) async {
    Future<void> add(String sql) async {
      try {
        await db.execute(sql);
      } catch (_) {}
    }

    await add('ALTER TABLE teacher_notes ADD COLUMN school_id TEXT');
    await add('ALTER TABLE teacher_notes ADD COLUMN class_id TEXT');
    await add('ALTER TABLE teacher_notes ADD COLUMN created_by_uid TEXT');
    await add('ALTER TABLE teacher_notes ADD COLUMN updated_at TEXT');
    await add('ALTER TABLE teacher_notes ADD COLUMN updated_by_uid TEXT');

    await add('ALTER TABLE announcements ADD COLUMN created_by_uid TEXT');
    await add(
      'ALTER TABLE announcements ADD COLUMN created_by_teacher_id TEXT',
    );
    await add('ALTER TABLE announcements ADD COLUMN created_at TEXT');
    await add('ALTER TABLE announcements ADD COLUMN updated_at TEXT');
    await add('ALTER TABLE announcements ADD COLUMN updated_by_uid TEXT');

    await add('ALTER TABLE homework ADD COLUMN school_id TEXT');
    await add('ALTER TABLE homework ADD COLUMN subject_id INTEGER');
    await add('ALTER TABLE homework ADD COLUMN created_by_uid TEXT');
    await add('ALTER TABLE homework ADD COLUMN created_by_teacher_id TEXT');
    await add('ALTER TABLE homework ADD COLUMN created_at TEXT');
    await add('ALTER TABLE homework ADD COLUMN updated_at TEXT');
    await add('ALTER TABLE homework ADD COLUMN updated_by_uid TEXT');

    await add('ALTER TABLE grades ADD COLUMN created_by_uid TEXT');
    await add('ALTER TABLE grades ADD COLUMN updated_by_uid TEXT');

    await add('ALTER TABLE attendance ADD COLUMN created_by_uid TEXT');
    await add('ALTER TABLE attendance ADD COLUMN updated_by_uid TEXT');
  }
}

/// Encode attendance entries for SQLite storage.
String encodeAttendanceEntries(List<Map<String, String>> entries) {
  return jsonEncode(entries);
}

List<Map<String, dynamic>> decodeAttendanceEntries(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  final decoded = jsonDecode(raw);
  if (decoded is! List) return const [];
  return decoded.cast<Map<String, dynamic>>();
}
