import 'dart:io';

import 'package:flutter_label/app/services/image_scan_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ImageScanService', () {
    late Directory tempDir;
    late ImageScanService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'image_scan_service_test_',
      );
      service = const ImageScanService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('可以从数据集根目录推断 images labels 和 data.yaml', () async {
      final datasetRoot = Directory(p.join(tempDir.path, 'dataset'));
      await Directory(
        p.join(datasetRoot.path, 'images'),
      ).create(recursive: true);

      final paths = service.validateDatasetImagesDir(datasetRoot.path);

      expect(paths.datasetRoot, p.normalize(datasetRoot.path));
      expect(paths.imageDir, p.join(datasetRoot.path, 'images'));
      expect(paths.labelDir, p.join(datasetRoot.path, 'labels'));
      expect(paths.dataYamlPath, p.join(datasetRoot.path, 'data.yaml'));
    });

    test('可以从 images 目录推断数据集根目录', () async {
      final imageDir = Directory(p.join(tempDir.path, 'dataset', 'images'));
      await imageDir.create(recursive: true);

      final paths = service.validateDatasetImagesDir(imageDir.path);

      expect(paths.datasetRoot, p.dirname(p.normalize(imageDir.path)));
      expect(paths.imageDir, p.normalize(imageDir.path));
      expect(paths.labelDir, p.join(paths.datasetRoot, 'labels'));
      expect(paths.dataYamlPath, p.join(paths.datasetRoot, 'data.yaml'));
    });

    test('非数据集根目录会给出明确提示', () {
      expect(
        () => service.validateDatasetImagesDir(p.join(tempDir.path, 'other')),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            '请选择数据集根目录或 images 目录',
          ),
        ),
      );
    });
  });
}
