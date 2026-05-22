import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/format_convert_config.dart';
import '../utils/image_utils.dart';
import 'data_yaml_service.dart';

typedef FormatConvertCancelChecker = bool Function();

class FormatConvertCancelledException implements Exception {
  const FormatConvertCancelledException();

  @override
  String toString() => '格式转换已停止';
}

void _throwIfFormatConvertCancelled(FormatConvertCancelChecker? isCancelled) {
  if (isCancelled?.call() ?? false) {
    throw const FormatConvertCancelledException();
  }
}

Future<void> _yieldForFormatConvertCancellation(
  FormatConvertCancelChecker? isCancelled,
) async {
  _throwIfFormatConvertCancelled(isCancelled);
  await Future<void>.delayed(Duration.zero);
  _throwIfFormatConvertCancelled(isCancelled);
}

class _BoxRecord {
  const _BoxRecord({
    required this.classId,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int classId;
  final double left;
  final double top;
  final double width;
  final double height;
}

class FormatConvertService {
  const FormatConvertService({
    DataYamlService dataYamlService = const DataYamlService(),
  }) : _dataYamlService = dataYamlService;

  static const imageExtensions = {'.jpg', '.jpeg', '.png', '.bmp', '.webp'};

  final DataYamlService _dataYamlService;

  Future<FormatConvertResult> convert(
    FormatConvertConfig config, {
    FormatConvertCancelChecker? isCancelled,
  }) async {
    _validateConfig(config);
    if (config.inputFormat == config.outputFormat) {
      throw const FormatException('输入格式和输出格式不能相同');
    }

    _throwIfFormatConvertCancelled(isCancelled);
    final classes = await _readClasses(config.dataYamlPath);
    _throwIfFormatConvertCancelled(isCancelled);
    return switch ((config.inputFormat, config.outputFormat)) {
      (AnnotationFormat.yolo, AnnotationFormat.coco) => _yoloToCoco(
        config,
        classes,
        isCancelled,
      ),
      (AnnotationFormat.yolo, AnnotationFormat.voc) => _yoloToVoc(
        config,
        classes,
        isCancelled,
      ),
      (AnnotationFormat.coco, AnnotationFormat.yolo) => _cocoToYolo(
        config,
        classes,
        isCancelled,
      ),
      (AnnotationFormat.voc, AnnotationFormat.yolo) => _vocToYolo(
        config,
        classes,
        isCancelled,
      ),
      _ => throw const FormatException('暂不支持该格式转换'),
    };
  }

  Future<FormatConvertResult> _yoloToCoco(
    FormatConvertConfig config,
    List<String> classes,
    FormatConvertCancelChecker? isCancelled,
  ) async {
    final logs = <String>[];
    final imagesDir = Directory(p.join(config.inputDir, 'images'));
    final labelsDir = Directory(p.join(config.inputDir, 'labels'));
    final imageFiles = await _listImages(imagesDir.path, isCancelled);
    _throwIfFormatConvertCancelled(isCancelled);
    await Directory(config.outputDir).create(recursive: true);

    final cocoImages = <Map<String, Object>>[];
    final annotations = <Map<String, Object>>[];
    var annotationId = 1;
    var skipped = 0;

    for (var imageIndex = 0; imageIndex < imageFiles.length; imageIndex++) {
      await _yieldForFormatConvertCancellation(isCancelled);
      final image = imageFiles[imageIndex];
      final size = await ImageUtils.readImageSize(image);
      final imageId = imageIndex + 1;
      final relativePath = _relativePathFrom(image, imagesDir);
      cocoImages.add({
        'id': imageId,
        'file_name': _portableRelativePath(relativePath),
        'width': size.width,
        'height': size.height,
      });

      final labelFile = File(
        p.join(labelsDir.path, p.setExtension(relativePath, '.txt')),
      );
      final boxes = await _readYoloBoxes(
        labelFile: labelFile,
        imageWidth: size.width,
        imageHeight: size.height,
        classCount: classes.length,
        logs: logs,
        isCancelled: isCancelled,
      );
      for (final box in boxes) {
        annotations.add({
          'id': annotationId++,
          'image_id': imageId,
          'category_id': box.classId,
          'bbox': [box.left, box.top, box.width, box.height],
          'area': box.width * box.height,
          'iscrowd': 0,
        });
      }
      if (!await labelFile.exists()) {
        skipped++;
      }
    }

    final categories = [
      for (var index = 0; index < classes.length; index++)
        {'id': index, 'name': classes[index], 'supercategory': 'object'},
    ];
    final outputFile = File(p.join(config.outputDir, 'annotations.json'));
    _throwIfFormatConvertCancelled(isCancelled);
    await outputFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'images': cocoImages,
        'annotations': annotations,
        'categories': categories,
      }),
    );
    logs.add('已生成 COCO：${outputFile.path}');
    return FormatConvertResult(
      convertedCount: imageFiles.length,
      skippedCount: skipped,
      logs: logs,
    );
  }

  Future<FormatConvertResult> _yoloToVoc(
    FormatConvertConfig config,
    List<String> classes,
    FormatConvertCancelChecker? isCancelled,
  ) async {
    final logs = <String>[];
    final imagesDir = Directory(p.join(config.inputDir, 'images'));
    final labelsDir = Directory(p.join(config.inputDir, 'labels'));
    final annotationsDir = Directory(p.join(config.outputDir, 'Annotations'));
    final jpegImagesDir = Directory(p.join(config.outputDir, 'JPEGImages'));
    await annotationsDir.create(recursive: true);
    await jpegImagesDir.create(recursive: true);

    final imageFiles = await _listImages(imagesDir.path, isCancelled);
    var skipped = 0;
    for (final image in imageFiles) {
      await _yieldForFormatConvertCancellation(isCancelled);
      final size = await ImageUtils.readImageSize(image);
      final relativePath = _relativePathFrom(image, imagesDir);
      final labelFile = File(
        p.join(labelsDir.path, p.setExtension(relativePath, '.txt')),
      );
      final boxes = await _readYoloBoxes(
        labelFile: labelFile,
        imageWidth: size.width,
        imageHeight: size.height,
        classCount: classes.length,
        logs: logs,
        isCancelled: isCancelled,
      );
      if (!await labelFile.exists()) {
        skipped++;
      }
      await _copyFilePreservingRelativePath(
        sourceFile: image,
        outputRoot: jpegImagesDir.path,
        relativePath: relativePath,
        isCancelled: isCancelled,
      );
      await _writeStringPreservingRelativePath(
        outputRoot: annotationsDir.path,
        relativePath: p.setExtension(relativePath, '.xml'),
        content: _buildVocXml(
          fileName: _portableRelativePath(relativePath),
          size: size,
          boxes: boxes,
          classes: classes,
        ),
        isCancelled: isCancelled,
      );
    }
    logs.add('已生成 VOC：${config.outputDir}');
    return FormatConvertResult(
      convertedCount: imageFiles.length,
      skippedCount: skipped,
      logs: logs,
    );
  }

  Future<FormatConvertResult> _cocoToYolo(
    FormatConvertConfig config,
    List<String> classes,
    FormatConvertCancelChecker? isCancelled,
  ) async {
    final logs = <String>[];
    final file = File(p.join(config.inputDir, 'annotations.json'));
    if (!await file.exists()) {
      throw FileSystemException('未找到 annotations.json', file.path);
    }
    final content = await file.readAsString();
    _throwIfFormatConvertCancelled(isCancelled);
    final json = jsonDecode(content);
    _throwIfFormatConvertCancelled(isCancelled);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('COCO JSON 根节点必须是对象');
    }
    final images = (json['images'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final annotations = (json['annotations'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final categories = (json['categories'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final categoryIdToClassId = _buildCocoCategoryMapping(
      categories: categories,
      classes: classes,
      logs: logs,
    );
    final outputImagesDir = Directory(p.join(config.outputDir, 'images'));
    final outputLabelsDir = Directory(p.join(config.outputDir, 'labels'));
    await outputImagesDir.create(recursive: true);
    await outputLabelsDir.create(recursive: true);
    await _writeDataYaml(config.outputDir, classes);

    final annotationsByImage = <int, List<Map>>{};
    for (final annotation in annotations) {
      final imageId = (annotation['image_id'] as num?)?.toInt();
      if (imageId == null) {
        continue;
      }
      annotationsByImage.putIfAbsent(imageId, () => []).add(annotation);
    }

    var converted = 0;
    var skipped = 0;
    for (final image in images) {
      await _yieldForFormatConvertCancellation(isCancelled);
      final imageId = (image['id'] as num?)?.toInt();
      final fileName = image['file_name']?.toString();
      final relativePath = fileName == null
          ? null
          : _safeRelativePath(fileName);
      final width = (image['width'] as num?)?.toDouble();
      final height = (image['height'] as num?)?.toDouble();
      if (imageId == null ||
          relativePath == null ||
          width == null ||
          height == null ||
          width <= 0 ||
          height <= 0) {
        if (fileName != null && relativePath == null) {
          logs.add('COCO file_name 非法，已跳过：$fileName');
        }
        skipped++;
        continue;
      }
      final sourceImage = File(p.join(config.inputDir, 'images', relativePath));
      if (await sourceImage.exists()) {
        await _copyFilePreservingRelativePath(
          sourceFile: sourceImage,
          outputRoot: outputImagesDir.path,
          relativePath: relativePath,
          isCancelled: isCancelled,
        );
      }
      final yoloLines = <String>[];
      for (final annotation in annotationsByImage[imageId] ?? const <Map>[]) {
        _throwIfFormatConvertCancelled(isCancelled);
        final categoryId = (annotation['category_id'] as num?)?.toInt();
        final classId = categoryId == null
            ? null
            : categoryIdToClassId[categoryId];
        final bbox = _readNumberList(annotation['bbox'], expectedLength: 4);
        if (classId == null || bbox == null) {
          skipped++;
          continue;
        }
        final left = bbox[0];
        final top = bbox[1];
        final boxWidth = bbox[2];
        final boxHeight = bbox[3];
        if (!_isValidPixelBox(left, top, boxWidth, boxHeight, width, height)) {
          skipped++;
          continue;
        }
        yoloLines.add(
          _pixelToYoloLine(
            classId,
            left,
            top,
            boxWidth,
            boxHeight,
            width,
            height,
          ),
        );
      }
      await _writeStringPreservingRelativePath(
        outputRoot: outputLabelsDir.path,
        relativePath: p.setExtension(relativePath, '.txt'),
        content: yoloLines.join('\n'),
        isCancelled: isCancelled,
      );
      converted++;
    }
    logs.add('COCO 已转换为 YOLO：${config.outputDir}');
    return FormatConvertResult(
      convertedCount: converted,
      skippedCount: skipped,
      logs: logs,
    );
  }

  Map<int, int> _buildCocoCategoryMapping({
    required List<Map> categories,
    required List<String> classes,
    required List<String> logs,
  }) {
    final classIndexByName = {
      for (var index = 0; index < classes.length; index++)
        classes[index]: index,
    };
    final mapping = <int, int>{};
    for (final category in categories) {
      final categoryId = (category['id'] as num?)?.toInt();
      final categoryName = category['name']?.toString();
      if (categoryId == null ||
          categoryName == null ||
          categoryName.trim().isEmpty) {
        logs.add('COCO categories 存在非法类别，已跳过');
        continue;
      }
      final classId = classIndexByName[categoryName.trim()];
      if (classId == null) {
        logs.add('COCO 类别未在 data.yaml 中找到：$categoryName，相关标注将跳过');
        continue;
      }
      mapping[categoryId] = classId;
    }
    if (mapping.isEmpty) {
      logs.add('COCO categories 未建立有效类别映射，标注将全部跳过');
    }
    return mapping;
  }

  Future<FormatConvertResult> _vocToYolo(
    FormatConvertConfig config,
    List<String> classes,
    FormatConvertCancelChecker? isCancelled,
  ) async {
    final logs = <String>[];
    final annotationsDir = Directory(p.join(config.inputDir, 'Annotations'));
    final imagesDir = Directory(p.join(config.inputDir, 'JPEGImages'));
    final outputImagesDir = Directory(p.join(config.outputDir, 'images'));
    final outputLabelsDir = Directory(p.join(config.outputDir, 'labels'));
    await outputImagesDir.create(recursive: true);
    await outputLabelsDir.create(recursive: true);
    await _writeDataYaml(config.outputDir, classes);

    final xmlFiles = await annotationsDir
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => p.extension(file.path).toLowerCase() == '.xml')
        .toList();
    xmlFiles.sort((left, right) => left.path.compareTo(right.path));

    var converted = 0;
    var skipped = 0;
    for (final xmlFile in xmlFiles) {
      await _yieldForFormatConvertCancellation(isCancelled);
      final xml = await xmlFile.readAsString();
      final xmlRelativePath = _relativePathFrom(xmlFile, annotationsDir);
      final rawFileName = _xmlValue(xml, 'filename');
      final fallbackFileName = p.setExtension(xmlRelativePath, '.jpg');
      var relativeImagePath = _safeRelativePath(
        rawFileName ?? fallbackFileName,
      );
      final width = double.tryParse(_xmlValue(xml, 'width') ?? '');
      final height = double.tryParse(_xmlValue(xml, 'height') ?? '');
      if (relativeImagePath == null ||
          width == null ||
          height == null ||
          width <= 0 ||
          height <= 0) {
        if (rawFileName != null && relativeImagePath == null) {
          logs.add('VOC filename 非法，已跳过：$rawFileName');
        }
        skipped++;
        continue;
      }
      var sourceImage = File(p.join(imagesDir.path, relativeImagePath));
      final xmlParent = p.dirname(xmlRelativePath);
      if (!await sourceImage.exists() &&
          rawFileName != null &&
          p.dirname(relativeImagePath) == '.' &&
          xmlParent != '.') {
        final inferredPath = p.normalize(p.join(xmlParent, relativeImagePath));
        final inferredImage = File(p.join(imagesDir.path, inferredPath));
        if (await inferredImage.exists()) {
          relativeImagePath = inferredPath;
          sourceImage = inferredImage;
        }
      }
      if (await sourceImage.exists()) {
        await _copyFilePreservingRelativePath(
          sourceFile: sourceImage,
          outputRoot: outputImagesDir.path,
          relativePath: relativeImagePath,
          isCancelled: isCancelled,
        );
      }
      final lines = <String>[];
      for (final objectXml in _xmlBlocks(xml, 'object')) {
        _throwIfFormatConvertCancelled(isCancelled);
        final className = _xmlValue(objectXml, 'name');
        final classId = className == null ? -1 : classes.indexOf(className);
        final xmin = double.tryParse(_xmlValue(objectXml, 'xmin') ?? '');
        final ymin = double.tryParse(_xmlValue(objectXml, 'ymin') ?? '');
        final xmax = double.tryParse(_xmlValue(objectXml, 'xmax') ?? '');
        final ymax = double.tryParse(_xmlValue(objectXml, 'ymax') ?? '');
        if (classId < 0) {
          skipped++;
          logs.add('${xmlFile.path} 类别未在 data.yaml 中找到，已跳过');
          continue;
        }
        if (xmin == null || ymin == null || xmax == null || ymax == null) {
          skipped++;
          logs.add('${xmlFile.path} VOC 标注字段异常，已跳过');
          continue;
        }
        final boxWidth = xmax - xmin;
        final boxHeight = ymax - ymin;
        if (!_isValidPixelBox(xmin, ymin, boxWidth, boxHeight, width, height)) {
          skipped++;
          logs.add('${xmlFile.path} VOC 标注框越界，已跳过');
          continue;
        }
        lines.add(
          _pixelToYoloLine(
            classId,
            xmin,
            ymin,
            boxWidth,
            boxHeight,
            width,
            height,
          ),
        );
      }
      await _writeStringPreservingRelativePath(
        outputRoot: outputLabelsDir.path,
        relativePath: p.setExtension(relativeImagePath, '.txt'),
        content: lines.join('\n'),
        isCancelled: isCancelled,
      );
      converted++;
    }
    logs.add('VOC 已转换为 YOLO：${config.outputDir}');
    return FormatConvertResult(
      convertedCount: converted,
      skippedCount: skipped,
      logs: logs,
    );
  }

  Future<List<_BoxRecord>> _readYoloBoxes({
    required File labelFile,
    required int imageWidth,
    required int imageHeight,
    required int classCount,
    required List<String> logs,
    required FormatConvertCancelChecker? isCancelled,
  }) async {
    if (!await labelFile.exists()) {
      return const [];
    }
    final boxes = <_BoxRecord>[];
    final lines = await labelFile.readAsLines();
    for (var index = 0; index < lines.length; index++) {
      if (index % 32 == 0) {
        await _yieldForFormatConvertCancellation(isCancelled);
      }
      final parts = lines[index].trim().split(RegExp(r'\s+'));
      if (parts.length != 5) {
        logs.add('${labelFile.path}:${index + 1} 标签字段数错误，已跳过');
        continue;
      }
      final classId = int.tryParse(parts[0]);
      final xCenter = double.tryParse(parts[1]);
      final yCenter = double.tryParse(parts[2]);
      final width = double.tryParse(parts[3]);
      final height = double.tryParse(parts[4]);
      if (classId == null ||
          xCenter == null ||
          yCenter == null ||
          width == null ||
          height == null ||
          classId < 0 ||
          classId >= classCount ||
          xCenter < 0 ||
          xCenter > 1 ||
          yCenter < 0 ||
          yCenter > 1 ||
          width <= 0 ||
          width > 1 ||
          height <= 0 ||
          height > 1) {
        logs.add('${labelFile.path}:${index + 1} 标签值异常，已跳过');
        continue;
      }
      final left = xCenter - width / 2;
      final top = yCenter - height / 2;
      if (!_isValidUnitBox(left, top, width, height)) {
        logs.add('${labelFile.path}:${index + 1} 标签值异常，已跳过');
        continue;
      }
      final pixelWidth = width * imageWidth;
      final pixelHeight = height * imageHeight;
      boxes.add(
        _BoxRecord(
          classId: classId,
          left: left * imageWidth,
          top: top * imageHeight,
          width: pixelWidth,
          height: pixelHeight,
        ),
      );
    }
    return boxes;
  }

  String _buildVocXml({
    required String fileName,
    required ImageSize size,
    required List<_BoxRecord> boxes,
    required List<String> classes,
  }) {
    final buffer = StringBuffer()
      ..writeln('<annotation>')
      ..writeln('  <filename>${_escapeXml(fileName)}</filename>')
      ..writeln('  <size>')
      ..writeln('    <width>${size.width}</width>')
      ..writeln('    <height>${size.height}</height>')
      ..writeln('    <depth>3</depth>')
      ..writeln('  </size>');
    for (final box in boxes) {
      buffer
        ..writeln('  <object>')
        ..writeln('    <name>${_escapeXml(classes[box.classId])}</name>')
        ..writeln('    <bndbox>')
        ..writeln('      <xmin>${box.left.round()}</xmin>')
        ..writeln('      <ymin>${box.top.round()}</ymin>')
        ..writeln('      <xmax>${(box.left + box.width).round()}</xmax>')
        ..writeln('      <ymax>${(box.top + box.height).round()}</ymax>')
        ..writeln('    </bndbox>')
        ..writeln('  </object>');
    }
    buffer.writeln('</annotation>');
    return buffer.toString();
  }

  Future<List<File>> _listImages(
    String imagesDir,
    FormatConvertCancelChecker? isCancelled,
  ) async {
    final directory = Directory(imagesDir);
    if (!await directory.exists()) {
      throw FileSystemException('图片目录不存在', imagesDir);
    }
    final files = await directory
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .where(
          (file) =>
              imageExtensions.contains(p.extension(file.path).toLowerCase()),
        )
        .toList();
    _throwIfFormatConvertCancelled(isCancelled);
    files.sort((left, right) => left.path.compareTo(right.path));
    return files;
  }

  Future<List<String>> _readClasses(String dataYamlPath) async {
    final classes = await _dataYamlService.readClassNames(dataYamlPath);
    if (classes.isEmpty) {
      throw const FormatException('data.yaml 的 names 不能为空');
    }
    return classes;
  }

  Future<void> _writeDataYaml(String outputDir, List<String> classes) async {
    await _dataYamlService.writeClasses(
      dataYamlPath: p.join(outputDir, 'data.yaml'),
      classNames: classes,
    );
  }

  String _pixelToYoloLine(
    int classId,
    double left,
    double top,
    double width,
    double height,
    double imageWidth,
    double imageHeight,
  ) {
    return [
      classId.toString(),
      ((left + width / 2) / imageWidth).toStringAsFixed(6),
      ((top + height / 2) / imageHeight).toStringAsFixed(6),
      (width / imageWidth).toStringAsFixed(6),
      (height / imageHeight).toStringAsFixed(6),
    ].join(' ');
  }

  List<double>? _readNumberList(Object? value, {required int expectedLength}) {
    if (value is! List || value.length < expectedLength) {
      return null;
    }
    final numbers = <double>[];
    for (var index = 0; index < expectedLength; index++) {
      final item = value[index];
      if (item is! num) {
        return null;
      }
      numbers.add(item.toDouble());
    }
    return numbers;
  }

  bool _isValidPixelBox(
    double left,
    double top,
    double width,
    double height,
    double imageWidth,
    double imageHeight,
  ) {
    return left >= 0 &&
        top >= 0 &&
        width > 0 &&
        height > 0 &&
        left + width <= imageWidth &&
        top + height <= imageHeight;
  }

  bool _isValidUnitBox(double left, double top, double width, double height) {
    return left >= 0 &&
        top >= 0 &&
        width > 0 &&
        height > 0 &&
        left + width <= 1 &&
        top + height <= 1;
  }

  String? _xmlValue(String xml, String tag) {
    final match = RegExp('<$tag>(.*?)</$tag>', dotAll: true).firstMatch(xml);
    final value = match?.group(1)?.trim();
    return value == null ? null : _unescapeXml(value);
  }

  List<String> _xmlBlocks(String xml, String tag) {
    return [
      for (final match in RegExp(
        '<$tag>(.*?)</$tag>',
        dotAll: true,
      ).allMatches(xml))
        match.group(1) ?? '',
    ];
  }

  String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _unescapeXml(String value) {
    return value
        .replaceAll('&apos;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll('&amp;', '&');
  }

  String _relativePathFrom(File file, Directory root) {
    return p.normalize(p.relative(file.path, from: root.path));
  }

  String _portableRelativePath(String relativePath) {
    return relativePath.replaceAll('\\', '/');
  }

  String? _safeRelativePath(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || p.isAbsolute(trimmed)) {
      return null;
    }
    final normalized = p.normalize(
      trimmed.replaceAll('\\', p.separator).replaceAll('/', p.separator),
    );
    final parts = p.split(normalized);
    if (normalized == '.' || parts.any((part) => part == '..')) {
      return null;
    }
    return normalized;
  }

  Future<void> _copyFilePreservingRelativePath({
    required File sourceFile,
    required String outputRoot,
    required String relativePath,
    required FormatConvertCancelChecker? isCancelled,
  }) async {
    _throwIfFormatConvertCancelled(isCancelled);
    final outputFile = File(p.join(outputRoot, relativePath));
    await outputFile.parent.create(recursive: true);
    await sourceFile.copy(outputFile.path);
    _throwIfFormatConvertCancelled(isCancelled);
  }

  Future<void> _writeStringPreservingRelativePath({
    required String outputRoot,
    required String relativePath,
    required String content,
    required FormatConvertCancelChecker? isCancelled,
  }) async {
    _throwIfFormatConvertCancelled(isCancelled);
    final outputFile = File(p.join(outputRoot, relativePath));
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(content);
    _throwIfFormatConvertCancelled(isCancelled);
  }

  void _validateConfig(FormatConvertConfig config) {
    if (config.inputDir.trim().isEmpty ||
        !Directory(config.inputDir).existsSync()) {
      throw FileSystemException('输入目录不存在', config.inputDir);
    }
    if (config.outputDir.trim().isEmpty) {
      throw const FormatException('输出目录不能为空');
    }
    if (config.dataYamlPath.trim().isEmpty ||
        !File(config.dataYamlPath).existsSync()) {
      throw FileSystemException('data.yaml 不存在', config.dataYamlPath);
    }
  }
}
