import 'dart:io';

import 'package:path/path.dart' as p;

class LabelClassMigrationService {
  const LabelClassMigrationService();

  Future<bool> isClassUsed({
    required String labelDir,
    required int classId,
  }) async {
    final files = await _labelFiles(labelDir);
    for (final file in files) {
      final lines = await file.readAsLines();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final parts = trimmed.split(RegExp(r'\s+'));
        final parsedClassId = int.tryParse(parts.first);
        if (parsedClassId == classId) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> deleteUnusedClass({
    required String labelDir,
    required int deletedClassId,
  }) async {
    await _rewriteClassIds(
      labelDir: labelDir,
      mapClassId: (classId) {
        if (classId == deletedClassId) {
          throw StateError('类别已被标签使用，不能删除');
        }
        if (classId > deletedClassId) {
          return classId - 1;
        }
        return classId;
      },
    );
  }

  Future<void> remapClasses({
    required String labelDir,
    required Map<int, int> oldToNewClassId,
  }) async {
    await _rewriteClassIds(
      labelDir: labelDir,
      mapClassId: (classId) => oldToNewClassId[classId] ?? classId,
    );
  }

  Future<void> _rewriteClassIds({
    required String labelDir,
    required int Function(int classId) mapClassId,
  }) async {
    final files = await _labelFiles(labelDir);
    for (final file in files) {
      final lines = await file.readAsLines();
      final nextLines = <String>[];
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length != 5) {
          nextLines.add(line);
          continue;
        }
        final classId = int.tryParse(parts.first);
        if (classId == null) {
          nextLines.add(line);
          continue;
        }
        parts[0] = mapClassId(classId).toString();
        nextLines.add(parts.join(' '));
      }
      await file.writeAsString(nextLines.join('\n'));
    }
  }

  Future<List<File>> _labelFiles(String labelDir) async {
    final directory = Directory(labelDir);
    if (!await directory.exists()) {
      return [];
    }
    final files = await directory
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => p.extension(file.path).toLowerCase() == '.txt')
        .toList();
    files.sort((left, right) => left.path.compareTo(right.path));
    return files;
  }
}
