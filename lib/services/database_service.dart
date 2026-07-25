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
  static const _dbVersion = 12;

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
        school_id TEXT NOT NULL DEFAULT '$defaultSchoolId'
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
        school_id TEXT NOT NULL DEFAULT '$defaultSchoolId',
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        date TEXT NOT NULL,
        is_featured INTEGER NOT NULL,
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
        is_active INTEGER NOT NULL DEFAULT 1
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
        created_at TEXT NOT NULL
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
