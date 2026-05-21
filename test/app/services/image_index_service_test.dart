import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_label/app/database/database.dart';
import 'package:flutter_label/app/models/image_annotation_status.dart';
import 'package:flutter_label/app/services/image_index_service.dart';
import 'package:flutter_label/app/services/image_scan_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ImageIndexService', () {
    late Directory tempDir;
    late AppDatabase database;
    late ImageIndexService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('image_index_service_');
      database = AppDatabase(NativeDatabase.memory());
      service = ImageIndexService(database: database);
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('可以建立缓存并再次读取', () async {
      final paths = await _createDataset(tempDir);
      final updates = <ImageIndexUpdate>[];

      await service.refreshIndex(
        paths: paths,
        scanMode: ImageIndexScanMode.datasetRoot,
        classCount: 1,
        completedImages: const {},
        isCancelled: () => false,
        onUpdate: updates.add,
      );

      expect(updates, isNotEmpty);
      final snapshot = await service.loadCachedSnapshot(
        paths: paths,
        scanMode: ImageIndexScanMode.datasetRoot,
      );
      expect(snapshot.images, hasLength(1));
      expect(snapshot.images.first.width, 640);
      expect(snapshot.images.first.height, 480);
      expect(
        snapshot.statuses[snapshot.images.first.relativePath],
        ImageAnnotationStatus.labeled,
      );
    });

    test('缺失文件会从缓存中移除', () async {
      final paths = await _createDataset(tempDir);

      await service.refreshIndex(
        paths: paths,
        scanMode: ImageIndexScanMode.datasetRoot,
        classCount: 1,
        completedImages: const {},
        isCancelled: () => false,
        onUpdate: (_) {},
      );
      await File(p.join(paths.imageDir, 'train', 'sample.png')).delete();

      await service.refreshIndex(
        paths: paths,
        scanMode: ImageIndexScanMode.datasetRoot,
        classCount: 1,
        completedImages: const {},
        isCancelled: () => false,
        onUpdate: (_) {},
      );

      final snapshot = await service.loadCachedSnapshot(
        paths: paths,
        scanMode: ImageIndexScanMode.datasetRoot,
      );
      expect(snapshot.images, isEmpty);
    });
  });
}

Future<DatasetPaths> _createDataset(Directory root) async {
  final datasetRoot = Directory(p.join(root.path, 'dataset'));
  await Directory(
    p.join(datasetRoot.path, 'images', 'train'),
  ).create(recursive: true);
  await Directory(
    p.join(datasetRoot.path, 'labels', 'train'),
  ).create(recursive: true);
  await File(p.join(datasetRoot.path, 'data.yaml')).writeAsString('''
path: .
train: images/train
val: images/val
test: images/test
names:
  0: class0
''');
  await File(
    p.join(datasetRoot.path, 'labels', 'train', 'sample.txt'),
  ).writeAsString('0 0.5 0.5 0.4 0.4');
  await File(
    p.join(datasetRoot.path, 'images', 'train', 'sample.png'),
  ).writeAsBytes(_pngHeader(width: 640, height: 480));

  final service = const ImageScanService();
  return service.validateDatasetRoot(datasetRoot.path);
}

Uint8List _pngHeader({required int width, required int height}) {
  final bytes = Uint8List(24)
    ..setAll(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final data = ByteData.sublistView(bytes);
  data.setUint32(16, width, Endian.big);
  data.setUint32(20, height, Endian.big);
  return bytes;
}
