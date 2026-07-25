import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../repositories/edubridge_repository.dart';
import '../state/app_store.dart';
import '../theme/app_spacing.dart';
import 'test_data_generator.dart';

/// Debug-only tools for generating large SQLite datasets.
///
/// Not reachable in release builds (`kDebugMode == false`).
class DeveloperToolsScreen extends StatefulWidget {
  const DeveloperToolsScreen({
    super.key,
    required this.store,
    required this.repository,
  });

  final AppStore store;
  final EduBridgeRepository repository;

  @override
  State<DeveloperToolsScreen> createState() => _DeveloperToolsScreenState();
}

class _DeveloperToolsScreenState extends State<DeveloperToolsScreen> {
  late final TestDataGenerator _generator = TestDataGenerator(
    repository: widget.repository,
    store: widget.store,
  );

  bool _busy = false;
  String _status = 'Бэлэн';
  double? _progress;

  @override
  void initState() {
    super.initState();
    // Extra safety: never keep this screen open in release.
    if (!kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  void _setProgress(String message, double? progress) {
    if (!mounted) return;
    setState(() {
      _status = message;
      _progress = progress;
    });
  }

  Future<bool> _confirmReplace() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Тест өгөгдөл байна'),
        content: const Text(
          'TEST өгөгдөл аль хэдийн байна. Сольж дахин үүсгэх үү?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Солих'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<bool> _confirmDelete() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Устгах'),
        content: const Text('Тестийн бүх өгөгдлийг устгах уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      await action();
    } on StateError catch (e) {
      if (e.message == 'NO_TEST_STUDENTS') {
        _snack('Эхлээд 1000 сурагчийн тест өгөгдөл үүсгэнэ үү.');
        _setProgress('Сурагчдын тест өгөгдөл олдсонгүй', null);
      } else {
        _snack(e.message);
      }
    } catch (e) {
      _snack('Алдаа: $e');
      _setProgress('Алдаа гарлаа', null);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _generateStudents() async {
    await _run(() async {
      var replace = false;
      if (await _generator.hasTestData()) {
        replace = await _confirmReplace();
        if (!replace) return;
      }
      await _generator.generateStudents(
        onProgress: _setProgress,
        replaceExisting: replace,
      );
      _snack('1000 сурагчийн тест өгөгдөл амжилттай үүслээ');
    });
  }

  Future<void> _generateAttendance() async {
    await _run(() async {
      final result = await _generator.generateAttendance(
        onProgress: _setProgress,
      );
      _snack(
        '${result.attendanceEntries} ирцийн бүртгэл амжилттай үүслээ '
        '(${result.attendanceRecords} өдөр)',
      );
    });
  }

  Future<void> _generateExtras() async {
    await _run(() async {
      final result = await _generator.generateGradesHomeworkAnnouncements(
        onProgress: _setProgress,
      );
      _snack(
        'Дүн ${result.grades}, даалгавар ${result.homework}, '
        'зарлал ${result.announcements} үүслээ',
      );
    });
  }

  Future<void> _deleteAll() async {
    await _run(() async {
      final ok = await _confirmDelete();
      if (!ok) return;
      await _generator.deleteAllTestData(onProgress: _setProgress);
      _snack('Тестийн өгөгдөл амжилттай устгалаа.');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Тест хэрэгсэл'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Text(
            'Зөвхөн хөгжүүлэлт / гүйцэтгэлийн тестэд зориулсан. '
            'Release build-д харагдахгүй.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sectionSm),
          if (_busy) ...[
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: AppSpacing.gap),
          ],
          Text(_status, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.section),
          FilledButton(
            onPressed: _busy ? null : _generateStudents,
            child: const Text('1000 сурагчийн тест өгөгдөл үүсгэх'),
          ),
          const SizedBox(height: AppSpacing.gap),
          FilledButton.tonal(
            onPressed: _busy ? null : _generateAttendance,
            child: const Text('5000 ирцийн бүртгэл үүсгэх'),
          ),
          const SizedBox(height: AppSpacing.gap),
          FilledButton.tonal(
            onPressed: _busy ? null : _generateExtras,
            child: const Text('Олон дүн, даалгавар, зарлал үүсгэх'),
          ),
          const SizedBox(height: AppSpacing.sectionSm),
          OutlinedButton(
            onPressed: _busy ? null : _deleteAll,
            child: const Text('Бүх тест өгөгдлийг устгах'),
          ),
        ],
      ),
    );
  }
}
