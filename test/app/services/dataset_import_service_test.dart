import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_label/app/models/dataset_split.dart';
import 'package:flutter_label/app/services/dataset_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DatasetImportService', () {
    late Directory tempDir;
    late DatasetImportService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'dataset_import_service_test_',
      );
      service = const DatasetImportService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('可以导入文件到指定 split 并自动改名', () async {
      final datasetDir = await _createDatasetRoot(tempDir);
      final sourceDir = Directory('${tempDir.path}/source');
      final image = File('${sourceDir.path}/a/image.png');
      final duplicate = File('${sourceDir.path}/b/image.png');
      await _writePng(image, const ui.Color(0xFFFFFFFF));
      await _writePng(duplicate, const ui.Color(0xFF000000));

      final result = await service.importFiles(
        datasetDir: datasetDir.path,
        filePaths: [image.path, duplicate.path],
        split: DatasetSplit.val,
      );

      expect(result.importedCount, 2);
      expect(
        Directory(
          '${datasetDir.path}/images/val',
        ).listSync(recursive: true).whereType<File>().length,
        2,
      );
      expect(
        File('${datasetDir.path}/images/val/image.png').existsSync(),
        isTrue,
      );
      expect(
        File('${datasetDir.path}/images/val/image_1.png').existsSync(),
        isTrue,
      );
    });

    test('可以递归导入目录图片到 train split', () async {
      final datasetDir = await _createDatasetRoot(tempDir);
      final sourceDir = Directory('${tempDir.path}/nested');
      await _writePng(
        File('${sourceDir.path}/sub/a.png'),
        const ui.Color(0xFF00FF00),
      );
      await _writePng(
        File('${sourceDir.path}/b.png'),
        const ui.Color(0xFF0000FF),
      );

      final result = await service.importDirectory(
        datasetDir: datasetDir.path,
        sourceDir: sourceDir.path,
        split: DatasetSplit.train,
      );

      expect(result.importedCount, 2);
      expect(
        File('${datasetDir.path}/images/train/b.png').existsSync(),
        isTrue,
      );
      expect(
        File('${datasetDir.path}/images/train/sub/a.png').existsSync(),
        isTrue,
      );
    });

    test('空输入会被拒绝', () async {
      final datasetDir = await _createDatasetRoot(tempDir);

      expect(
        () => service.importFiles(
          datasetDir: datasetDir.path,
          filePaths: const [],
          split: DatasetSplit.test,
        ),
        throwsFormatException,
      );
    });
  });
}

Future<Directory> _createDatasetRoot(Directory root) async {
  final datasetDir = Directory('${root.path}/dataset');
  await datasetDir.create(recursive: true);
  await File('${datasetDir.path}/data.yaml').writeAsString('''
path: .
train: images/train
val: images/val
test: images/test
names: []
''');
  for (final split in ['train', 'val', 'test']) {
    await Directory('${datasetDir.path}/images/$split').create(recursive: true);
    await Directory('${datasetDir.path}/labels/$split').create(recursive: true);
  }
  return datasetDir;
}

Future<void> _writePng(File file, ui.Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 10, 10),
    ui.Paint()..color = color,
  );
  final image = await recorder.endRecording().toImage(10, 10);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (byteData == null) {
    throw StateError('测试图片编码失败');
  }
  await file.parent.create(recursive: true);
  await file.writeAsBytes(Uint8List.view(byteData.buffer));
}
