import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/annotation_box.dart';
import '../models/image_annotation_status.dart';
import '../utils/coordinate_utils.dart';

class LabelLoadResult {
  const LabelLoadResult({required this.boxes, required this.warnings});

  final List<AnnotationBox> boxes;
  final List<String> warnings;
}

class YoloLabelService {
  const YoloLabelService();

  static const minBoxSize = 2.0;

  Future<ImageAnnotationStatus> inspectLabelStatus({
    required String labelPath,
    required int classCount,
    required bool isCompleted,
  }) async {
    if (isCompleted) {
      return ImageAnnotationStatus.completed;
    }

    final file = File(labelPath);
    if (!await file.exists()) {
      return ImageAnnotationStatus.unlabeled;
    }

    final lines = await file.readAsLines();
    final nonEmptyLines = lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (nonEmptyLines.isEmpty) {
      return ImageAnnotationStatus.emptyLabel;
    }

    for (final line in nonEmptyLines) {
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length != 5) {
        return ImageAnnotationStatus.labelError;
      }
      final classId = int.tryParse(parts[0]);
      if (classId == null || classId < 0 || classId >= classCount) {
        return ImageAnnotationStatus.labelError;
      }
      final values = parts.skip(1).map(double.tryParse).toList();
      if (values.any((value) => value == null || value < 0 || value > 1)) {
        return ImageAnnotationStatus.labelError;
      }
      if (values[2] == 0 || values[3] == 0) {
        return ImageAnnotationStatus.labelError;
      }
    }

    return ImageAnnotationStatus.labeled;
  }

  Future<LabelLoadResult> loadLabels({
    required String labelPath,
    required int imageWidth,
    required int imageHeight,
    required int classCount,
  }) async {
    _validateImageSize(imageWidth, imageHeight);
    final file = File(labelPath);
    if (!await file.exists()) {
      return const LabelLoadResult(boxes: [], warnings: []);
    }

    final boxes = <AnnotationBox>[];
    final warnings = <String>[];
    final lines = await file.readAsLines();
    for (var index = 0; index < lines.length; index++) {
      final lineNumber = index + 1;
      final line = lines[index].trim();
      if (line.isEmpty) {
        continue;
      }

      try {
        final box = CoordinateUtils.yoloLineToPixelBox(
          line: line,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          classCount: classCount,
        );
        if (box.rect.width < minBoxSize || box.rect.height < minBoxSize) {
          warnings.add('第 $lineNumber 行标注框过小，已跳过');
          continue;
        }
        boxes.add(box);
      } catch (error) {
        warnings.add('第 $lineNumber 行标签异常，已跳过：$error');
      }
    }

    return LabelLoadResult(boxes: boxes, warnings: warnings);
  }

  Future<void> saveLabels({
    required String labelPath,
    required List<AnnotationBox> boxes,
    required int imageWidth,
    required int imageHeight,
    required int classCount,
  }) async {
    _validateImageSize(imageWidth, imageHeight);
    final file = File(labelPath);
    await Directory(p.dirname(labelPath)).create(recursive: true);

    final lines = <String>[];
    for (final box in boxes) {
      if (box.classId < 0 || box.classId >= classCount) {
        throw RangeError.range(
          box.classId,
          0,
          classCount - 1,
          'classId',
          '类别编号越界',
        );
      }
      final rect = CoordinateUtils.clampRectToImage(
        box.rect,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
      if (rect.width < minBoxSize || rect.height < minBoxSize) {
        continue;
      }
      final yolo = CoordinateUtils.pixelToYolo(
        rect,
        classId: box.classId,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
      lines.add(
        '${yolo.classId} '
        '${yolo.xCenter.toStringAsFixed(6)} '
        '${yolo.yCenter.toStringAsFixed(6)} '
        '${yolo.width.toStringAsFixed(6)} '
        '${yolo.height.toStringAsFixed(6)}',
      );
    }

    await file.writeAsString(lines.join('\n'));
  }

  void _validateImageSize(int imageWidth, int imageHeight) {
    if (imageWidth <= 0 || imageHeight <= 0) {
      throw ArgumentError('图片尺寸必须大于 0');
    }
  }
}
