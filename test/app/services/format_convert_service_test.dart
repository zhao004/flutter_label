import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_label/app/models/format_convert_config.dart';
import 'package:flutter_label/app/services/format_convert_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FormatConvertService', () {
    late Directory tempDir;
    late FormatConvertService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'format_convert_service_test_',
      );
      service = const FormatConvertService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('YOLO 可以转换为 COCO annotations.json', () async {
      final inputDir = await _createYoloDataset(tempDir);
      final outputDir = Directory('${tempDir.path}/coco_out');

      final result = await service.convert(
        FormatConvertConfig(
          inputFormat: AnnotationFormat.yolo,
          outputFormat: AnnotationFormat.coco,
          inputDir: inputDir.path,
          outputDir: outputDir.path,
          dataYamlPath: '${inputDir.path}/data.yaml',
        ),
      );

      final json =
          jsonDecode(
                await File('${outputDir.path}/annotations.json').readAsString(),
              )
              as Map<String, dynamic>;
      final annotations = json['annotations'] as List<dynamic>;
      final bbox = (annotations.first as Map<String, dynamic>)['bbox'] as List;

      expect(result.convertedCount, 1);
      expect(json['images'], hasLength(1));
      expect(json['categories'], hasLength(1));
      expect(bbox[0], closeTo(4, 0.001));
      expect(bbox[1], closeTo(3, 0.001));
      expect(bbox[2], closeTo(2, 0.001));
      expect(bbox[3], closeTo(4, 0.001));
    });

    test('YOLO 可以转换为 VOC XML 并复制图片', () async {
      final inputDir = await _createYoloDataset(tempDir);
      final outputDir = Directory('${tempDir.path}/voc_out');

      final result = await service.convert(
        FormatConvertConfig(
          inputFormat: AnnotationFormat.yolo,
          outputFormat: AnnotationFormat.voc,
          inputDir: inputDir.path,
          outputDir: outputDir.path,
          dataYamlPath: '${inputDir.path}/data.yaml',
        ),
      );

      final xml = await File(
        '${outputDir.path}/Annotations/a.xml',
      ).readAsString();

      expect(result.convertedCount, 1);
      expect(File('${outputDir.path}/JPEGImages/a.png').existsSync(), isTrue);
      expect(xml, contains('<name>enemy</name>'));
      expect(xml, contains('<xmin>4</xmin>'));
      expect(xml, contains('<ymin>3</ymin>'));
      expect(xml, contains('<xmax>6</xmax>'));
      expect(xml, contains('<ymax>7</ymax>'));
    });

    test('YOLO 转 VOC 会保留嵌套相对路径，避免同名图片覆盖', () async {
      final inputDir = await _createNestedYoloDataset(tempDir);
      final outputDir = Directory('${tempDir.path}/nested_voc_out');

      final result = await service.convert(
        FormatConvertConfig(
          inputFormat: AnnotationFormat.yolo,
          outputFormat: AnnotationFormat.voc,
          inputDir: inputDir.path,
          outputDir: outputDir.path,
          dataYamlPath: '${inputDir.path}/data.yaml',
        ),
      );

      expect(result.convertedCount, 2);
      expect(
        File('${outputDir.path}/JPEGImages/a/img.png').existsSync(),
        isTrue,
      );
      expect(
        File('${outputDir.path}/JPEGImages/b/img.png').existsSync(),
        isTrue,
      );
      expect(
        File('${outputDir.path}/Annotations/a/img.xml').existsSync(),
        isTrue,
      );
      expect(
        File('${outputDir.path}/Annotations/b/img.xml').existsSync(),
        isTrue,
      );
    });

    test('YOLO 越界框会被跳过，不生成负数 COCO bbox', () async {
      final inputDir = await _createYoloDataset(
        tempDir,
        label: '0 0.100000 0.100000 0.400000 0.400000',
      );
      final outputDir = Directory('${tempDir.path}/invalid_yolo_coco_out');

      final result = await service.convert(
        FormatConvertConfig(
          inputFormat: AnnotationFormat.yolo,
          outputFormat: AnnotationFormat.coco,
          inputDir: inputDir.path,
          outputDir: outputDir.path,
          dataYamlPath: '${inputDir.path}/data.yaml',
        ),
      );

      final json =
          jsonDecode(
                await File('${outputDir.path}/annotations.json').readAsString(),
              )
              as Map<String, dynamic>;

      expect(result.convertedCount, 1);
      expect(result.logs.join('\n'), contains('标签值异常'));
      expect(json['annotations'], isEmpty);
    });

    test('COCO 可以转换为 YOLO 标签', () async {
      final inputDir = await _createCocoDataset(tempDir);
      final outputDir = Directory('${tempDir.path}/yolo_from_coco');

      final result = await service.convert(
        FormatConvertConfig(
          inputFormat: AnnotationFormat.coco,
          outputFormat: AnnotationFormat.yolo,
          inputDir: inputDir.path,
          outputDir: outputDir.path,
          dataYamlPath: '${inputDir.path}/data.yaml',
        ),
      );

      final label = await File('${outputDir.path}/labels/a.txt').readAsString();

      expect(result.convertedCount, 1);
      expect(label, '0 0.500000 0.500000 0.200000 0.400000');
      expect(File('${outputDir.path}/images/a.png').existsSync(), isTrue);
    });

    test('COCO 转 YOLO 会保留 file_name 子目录，避免标签覆盖', () async {
      final inputDir = await _createNestedCocoDataset(tempDir);
      final outputDir = Directory('${tempDir.path}/nested_yolo_from_coco');

      final result = await service.convert(
        FormatConvertConfig(
          inputFormat: AnnotationFormat.coco,
          outputFormat: AnnotationFormat.yolo,
          inputDir: inputDir.path,
          outputDir: outputDir.path,
          dataYamlPath: '${inputDir.path}/data.yaml',
        ),
      );

      expect(result.convertedCount, 2);
      expect(File('${outputDir.path}/images/a/img.png').existsSync(), isTrue);
      expect(File('${outputDir.path}/images/b/img.png').existsSync(), isTrue);
      expect(
        await File('${outputDir.path}/labels/a/img.txt').readAsString(),
        '0 0.500000 0.500000 0.200000 0.400000',
      );
      expect(
        await File('${outputDir.path}/labels/b/img.txt').readAsString(),
        '0 0.400000 0.400000 0.200000 0.200000',
      );
    });

    test('COCO 非连续 category_id 会按 categories 名称映射到 YOLO class_id', () async {
      final inputDir = await _createCocoDatasetWithSparseCategoryIds(tempDir);
      final outputDir = Directory('${tempDir.path}/yolo_from_sparse_coco');

      final result = await service.convert(
        FormatConvertConfig(
          inputFormat: AnnotationFormat.coco,
          outputFormat: AnnotationFormat.yolo,
          inputDir: inputDir.path,
          outputDir: outputDir.path,
          dataYamlPath: '${inputDir.path}/data.yaml',
        ),
      );

      final label = await File('${outputDir.path}/labels/a.txt').readAsString();

      expect(result.convertedCount, 1);
      expect(label, '1 0.500000 0.500000 0.200000 0.400000');
    });

    test('VOC 可以转换为 YOLO 标签', () async {
      final inputDir = await _createVocDataset(tempDir);
      final outputDir = Directory('${tempDir.path}/yolo_from_voc');

      final result = await service.convert(
        FormatConvertConfig(
          inputFormat: AnnotationFormat.voc,
          outputFormat: AnnotationFormat.yolo,
          inputDir: inputDir.path,
          outputDir: outputDir.path,
          dataYamlPath: '${inputDir.path}/data.yaml',
        ),
      );

      final label = await File('${outputDir.path}/labels/a.txt').readAsString();

      expect(result.convertedCount, 1);
      expect(label, '0 0.500000 0.500000 0.200000 0.400000');
      expect(File('${outputDir.path}/images/a.png').existsSync(), isTrue);
    });

    test('VOC 越界框会被跳过，不生成非法 YOLO 标签', () async {
      final inputDir = await _createVocDataset(
        tempDir,
        boxXml: '''
        <xmin>-5</xmin>
        <ymin>1</ymin>
        <xmax>8</xmax>
        <ymax>9</ymax>
''',
      );
      final outputDir = Directory('${tempDir.path}/invalid_voc_yolo_out');

      final result = await service.convert(
        FormatConvertConfig(
          inputFormat: AnnotationFormat.voc,
          outputFormat: AnnotationFormat.yolo,
          inputDir: inputDir.path,
          outputDir: outputDir.path,
          dataYamlPath: '${inputDir.path}/data.yaml',
        ),
      );

      final label = await File('${outputDir.path}/labels/a.txt').readAsString();

      expect(result.convertedCount, 1);
      expect(result.skippedCount, 1);
      expect(label, isEmpty);
    });

    test('VOC XML entity 会反解，特殊字符类别名不丢标注', () async {
      final inputDir = await _createYoloDataset(tempDir, className: 'a&b');
      final vocDir = Directory('${tempDir.path}/special_voc_out');
      final yoloDir = Directory('${tempDir.path}/special_yolo_out');

      await service.convert(
        FormatConvertConfig(
          inputFormat: AnnotationFormat.yolo,
          outputFormat: AnnotationFormat.voc,
          inputDir: inputDir.path,
          outputDir: vocDir.path,
          dataYamlPath: '${inputDir.path}/data.yaml',
        ),
      );
      final result = await service.convert(
        FormatConvertConfig(
          inputFormat: AnnotationFormat.voc,
          outputFormat: AnnotationFormat.yolo,
          inputDir: vocDir.path,
          outputDir: yoloDir.path,
          dataYamlPath: '${inputDir.path}/data.yaml',
        ),
      );

      final label = await File('${yoloDir.path}/labels/a.txt').readAsString();

      expect(result.skippedCount, 0);
      expect(label, '0 0.500000 0.500000 0.200000 0.400000');
    });
  });
}

Future<Directory> _createYoloDataset(
  Directory root, {
  String label = '0 0.500000 0.500000 0.200000 0.400000',
  String className = 'enemy',
}) async {
  final inputDir = Directory('${root.path}/yolo_in');
  final imagesDir = Directory('${inputDir.path}/images');
  final labelsDir = Directory('${inputDir.path}/labels');
  await imagesDir.create(recursive: true);
  await labelsDir.create(recursive: true);
  await _writePng(File('${imagesDir.path}/a.png'));
  await File('${labelsDir.path}/a.txt').writeAsString(label);
  await _writeDataYaml(inputDir, [className]);
  return inputDir;
}

Future<Directory> _createNestedYoloDataset(Directory root) async {
  final inputDir = Directory('${root.path}/nested_yolo_in');
  final imagesDir = Directory('${inputDir.path}/images');
  final labelsDir = Directory('${inputDir.path}/labels');
  await Directory('${imagesDir.path}/a').create(recursive: true);
  await Directory('${imagesDir.path}/b').create(recursive: true);
  await Directory('${labelsDir.path}/a').create(recursive: true);
  await Directory('${labelsDir.path}/b').create(recursive: true);
  await _writePng(File('${imagesDir.path}/a/img.png'));
  await _writePng(File('${imagesDir.path}/b/img.png'));
  await File(
    '${labelsDir.path}/a/img.txt',
  ).writeAsString('0 0.500000 0.500000 0.200000 0.400000');
  await File(
    '${labelsDir.path}/b/img.txt',
  ).writeAsString('0 0.400000 0.400000 0.200000 0.200000');
  await _writeDataYaml(inputDir, const ['enemy']);
  return inputDir;
}

Future<Directory> _createCocoDataset(Directory root) async {
  final inputDir = Directory('${root.path}/coco_in');
  final imagesDir = Directory('${inputDir.path}/images');
  await imagesDir.create(recursive: true);
  await _writePng(File('${imagesDir.path}/a.png'));
  await _writeDataYaml(inputDir, const ['enemy']);
  await File('${inputDir.path}/annotations.json').writeAsString(
    jsonEncode({
      'images': [
        {'id': 1, 'file_name': 'a.png', 'width': 10, 'height': 10},
      ],
      'annotations': [
        {
          'id': 1,
          'image_id': 1,
          'category_id': 0,
          'bbox': [4, 3, 2, 4],
        },
      ],
      'categories': [
        {'id': 0, 'name': 'enemy'},
      ],
    }),
  );
  return inputDir;
}

Future<Directory> _createCocoDatasetWithSparseCategoryIds(
  Directory root,
) async {
  final inputDir = Directory('${root.path}/coco_sparse_in');
  final imagesDir = Directory('${inputDir.path}/images');
  await imagesDir.create(recursive: true);
  await _writePng(File('${imagesDir.path}/a.png'));
  await _writeDataYaml(inputDir, const ['enemy', 'teammate']);
  await File('${inputDir.path}/annotations.json').writeAsString(
    jsonEncode({
      'images': [
        {'id': 1, 'file_name': 'a.png', 'width': 10, 'height': 10},
      ],
      'annotations': [
        {
          'id': 1,
          'image_id': 1,
          'category_id': 20,
          'bbox': [4, 3, 2, 4],
        },
      ],
      'categories': [
        {'id': 10, 'name': 'enemy'},
        {'id': 20, 'name': 'teammate'},
      ],
    }),
  );
  return inputDir;
}

Future<Directory> _createNestedCocoDataset(Directory root) async {
  final inputDir = Directory('${root.path}/nested_coco_in');
  final imagesDir = Directory('${inputDir.path}/images');
  await Directory('${imagesDir.path}/a').create(recursive: true);
  await Directory('${imagesDir.path}/b').create(recursive: true);
  await _writePng(File('${imagesDir.path}/a/img.png'));
  await _writePng(File('${imagesDir.path}/b/img.png'));
  await _writeDataYaml(inputDir, const ['enemy']);
  await File('${inputDir.path}/annotations.json').writeAsString(
    jsonEncode({
      'images': [
        {'id': 1, 'file_name': 'a/img.png', 'width': 10, 'height': 10},
        {'id': 2, 'file_name': 'b/img.png', 'width': 10, 'height': 10},
      ],
      'annotations': [
        {
          'id': 1,
          'image_id': 1,
          'category_id': 0,
          'bbox': [4, 3, 2, 4],
        },
        {
          'id': 2,
          'image_id': 2,
          'category_id': 0,
          'bbox': [3, 3, 2, 2],
        },
      ],
      'categories': [
        {'id': 0, 'name': 'enemy'},
      ],
    }),
  );
  return inputDir;
}

Future<Directory> _createVocDataset(
  Directory root, {
  String boxXml = '''
      <xmin>4</xmin>
      <ymin>3</ymin>
      <xmax>6</xmax>
      <ymax>7</ymax>
''',
}) async {
  final inputDir = Directory('${root.path}/voc_in');
  final annotationsDir = Directory('${inputDir.path}/Annotations');
  final imagesDir = Directory('${inputDir.path}/JPEGImages');
  await annotationsDir.create(recursive: true);
  await imagesDir.create(recursive: true);
  await _writePng(File('${imagesDir.path}/a.png'));
  await _writeDataYaml(inputDir, const ['enemy']);
  await File('${annotationsDir.path}/a.xml').writeAsString('''
<annotation>
  <filename>a.png</filename>
  <size>
    <width>10</width>
    <height>10</height>
    <depth>3</depth>
  </size>
  <object>
    <name>enemy</name>
    <bndbox>
      $boxXml
    </bndbox>
  </object>
</annotation>
''');
  return inputDir;
}

Future<void> _writePng(File file) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 10, 10),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  final image = await recorder.endRecording().toImage(10, 10);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (byteData == null) {
    throw StateError('测试图片编码失败');
  }
  await file.writeAsBytes(Uint8List.view(byteData.buffer));
}

Future<void> _writeDataYaml(Directory inputDir, List<String> classNames) async {
  final buffer = StringBuffer()
    ..writeln('path: .')
    ..writeln('names:');
  for (var index = 0; index < classNames.length; index++) {
    final escapedName = classNames[index].replaceAll("'", "''");
    buffer.writeln("  $index: '$escapedName'");
  }
  await File('${inputDir.path}/data.yaml').writeAsString(buffer.toString());
}
