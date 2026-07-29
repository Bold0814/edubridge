import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/firebase_connection_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingBackend implements FirebaseConnectionBackend {
  int writeCount = 0;
  int readCount = 0;
  int deleteCount = 0;
  String? lastWritePathHint;
  Map<String, Object?>? lastData;
  bool existsAfterWrite = true;
  Object? writeError;
  Object? readError;
  Object? deleteError;
  Duration? writeDelay;
  Duration? readDelay;
  Duration? deleteDelay;

  @override
  Future<void> writeCheck(Map<String, Object?> data) async {
    if (writeDelay != null) await Future<void>.delayed(writeDelay!);
    writeCount++;
    lastWritePathHint = FirebaseConnectionService.documentPath;
    lastData = data;
    if (writeError != null) throw writeError!;
  }

  @override
  Future<bool> readCheckExists() async {
    if (readDelay != null) await Future<void>.delayed(readDelay!);
    readCount++;
    if (readError != null) throw readError!;
    return existsAfterWrite;
  }

  @override
  Future<void> deleteCheck() async {
    if (deleteDelay != null) await Future<void>.delayed(deleteDelay!);
    deleteCount++;
    if (deleteError != null) throw deleteError!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirebaseConnectionService', () {
    test('uses exact Firestore document path', () {
      expect(
        FirebaseConnectionService.documentPath,
        'system_checks/flutter_connection',
      );
    });

    test('release mode refuses to invoke debug write', () async {
      final backend = _RecordingBackend();
      final service = FirebaseConnectionService(
        forceDebugMode: false,
        backend: backend,
      );

      final result = await service.runDebugConnectionCheck();

      expect(result.success, isFalse);
      expect(result.message, FirebaseConnectionService.failureMessage);
      expect(backend.writeCount, 0);
      expect(backend.readCount, 0);
      expect(backend.deleteCount, 0);
    });

    test('debug mode writes, reads, deletes and returns success', () async {
      final backend = _RecordingBackend();
      final service = FirebaseConnectionService(
        forceDebugMode: true,
        backend: backend,
      );

      final result = await service.runDebugConnectionCheck();

      expect(result.success, isTrue);
      expect(result.message, 'Firebase холболт амжилттай.');
      expect(backend.writeCount, 1);
      expect(backend.readCount, 1);
      expect(backend.deleteCount, 1);
      expect(backend.lastWritePathHint, 'system_checks/flutter_connection');
      expect(backend.lastData?['appName'], 'EduBridge');
      expect(backend.lastData?['platform'], defaultTargetPlatform.name);
      expect(backend.lastData?.containsKey('checkedAt'), isTrue);
    });

    test('returns failure when read finds no document', () async {
      final backend = _RecordingBackend()..existsAfterWrite = false;
      final service = FirebaseConnectionService(
        forceDebugMode: true,
        backend: backend,
      );

      final result = await service.runDebugConnectionCheck();
      expect(result.success, isFalse);
      expect(result.message, FirebaseConnectionService.failureMessage);
      expect(backend.deleteCount, 0);
    });

    test('permission-denied maps to Mongolian rules message', () async {
      final backend = _RecordingBackend()
        ..writeError = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Missing or insufficient permissions.',
        );
      final service = FirebaseConnectionService(
        forceDebugMode: true,
        backend: backend,
      );

      final result = await service.runDebugConnectionCheck();
      expect(result.success, isFalse);
      expect(result.message, 'Firestore Rules зөвшөөрөхгүй байна.');
      expect(backend.readCount, 0);
    });

    test('unavailable maps to network message', () async {
      final backend = _RecordingBackend()
        ..writeError = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        );
      final service = FirebaseConnectionService(
        forceDebugMode: true,
        backend: backend,
      );

      final result = await service.runDebugConnectionCheck();
      expect(result.success, isFalse);
      expect(result.message, 'Сүлжээний алдаа.');
    });

    test('operation timeout returns Mongolian timeout message', () async {
      final backend = _RecordingBackend()
        ..writeDelay = const Duration(milliseconds: 80);
      final service = FirebaseConnectionService(
        forceDebugMode: true,
        backend: backend,
        operationTimeout: const Duration(milliseconds: 20),
      );

      final result = await service.runDebugConnectionCheck();
      expect(result.success, isFalse);
      expect(result.message, 'Firebase хугацаа хэтэрлээ.');
    });

    test('future always completes even when backend hangs briefly', () async {
      final backend = _RecordingBackend()
        ..readDelay = const Duration(milliseconds: 100);
      final service = FirebaseConnectionService(
        forceDebugMode: true,
        backend: backend,
        operationTimeout: const Duration(milliseconds: 30),
      );

      final result = await service.runDebugConnectionCheck().timeout(
        const Duration(seconds: 2),
      );
      expect(result.success, isFalse);
      expect(result.message, FirebaseConnectionService.timeoutMessage);
    });

    test('maps every known FirebaseException code', () {
      const codes = <String, String>{
        'permission-denied': FirebaseConnectionService.permissionDeniedMessage,
        'unavailable': FirebaseConnectionService.networkMessage,
        'network-request-failed': FirebaseConnectionService.networkMessage,
        'deadline-exceeded': FirebaseConnectionService.timeoutMessage,
        'cancelled': 'Холболт цуцлагдлаа.',
        'unknown': 'Тодорхойгүй алдаа.',
        'invalid-argument': 'Буруу параметр.',
        'not-found': 'Баримт олдсонгүй.',
        'already-exists': 'Баримт аль хэдийн байна.',
        'resource-exhausted': 'Нөөц хэтэрсэн.',
        'failed-precondition': 'Нөхцөл хангагдаагүй.',
        'aborted': 'Үйлдэл тасалдлаа.',
        'out-of-range': 'Хязгаараас хэтэрсэн.',
        'unimplemented': 'Дэмжигдээгүй үйлдэл.',
        'internal': 'Дотоод алдаа.',
        'data-loss': 'Өгөгдөл алдагдсан.',
        'unauthenticated': 'Нэвтрээгүй байна.',
        'something-new': FirebaseConnectionService.failureMessage,
      };

      for (final entry in codes.entries) {
        expect(
          FirebaseConnectionService.messageForFirebaseCode(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('success and failure messages are Mongolian', () {
      expect(
        FirebaseConnectionService.successMessage,
        'Firebase холболт амжилттай.',
      );
      expect(
        FirebaseConnectionService.failureMessage,
        'Firebase холболт амжилтгүй.',
      );
      expect(
        FirebaseConnectionService.timeoutMessage,
        'Firebase хугацаа хэтэрлээ.',
      );
      expect(
        FirebaseConnectionService.permissionDeniedMessage,
        'Firestore Rules зөвшөөрөхгүй байна.',
      );
      expect(FirebaseConnectionService.networkMessage, 'Сүлжээний алдаа.');
    });

    test('SQLite open path remains available (behavior unchanged)', () async {
      final db = await DatabaseService.instance.openInMemoryForTest();
      expect(db.isOpen, isTrue);
      await db.close();
    });
  });
}
