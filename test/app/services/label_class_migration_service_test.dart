import 'dart:io';

import 'package:flutter_label/app/services/label_class_migration_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LabelClassMigrationService', () {
    late Directory tempDir;
    late LabelClassMigrationService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('label_migration_test_');
      service = const LabelClassMigrationService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<File> writeLabel(String content) async {
      final file = File('${tempDir.path}/a.txt');
      await file.writeAsString(content);
      return file;
    }

    test('类别排序会同步重写 YOLO class_id', () async {
      final labelFile = await writeLabel(
        '0 0.5 0.5 0.2 0.2\n1 0.3 0.3 0.1 0.1',
      );

      await service.remapClasses(
        labelDir: tempDir.path,
        oldToNewClassId: const {0: 1, 1: 0},
      );

      expect(
        await labelFile.readAsString(),
        '1 0.5 0.5 0.2 0.2\n0 0.3 0.3 0.1 0.1',
      );
    });

    test('删除未使用类别会下移后续 class_id', () async {
      final labelFile = await writeLabel('2 0.5 0.5 0.2 0.2');

      await service.deleteUnusedClass(
        labelDir: tempDir.path,
        deletedClassId: 1,
      );

      expect(await labelFile.readAsString(), '1 0.5 0.5 0.2 0.2');
    });

    test('删除已使用类别会阻止迁移', () async {
      await writeLabel('1 0.5 0.5 0.2 0.2');

      expect(
        () => service.deleteUnusedClass(
          labelDir: tempDir.path,
          deletedClassId: 1,
        ),
        throwsStateError,
      );
    });
  });
}
