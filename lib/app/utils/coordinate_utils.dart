import 'dart:math' as math;
import 'dart:ui';

import 'package:uuid/uuid.dart';

import '../models/annotation_box.dart';
import '../models/yolo_box.dart';

class CoordinateUtils {
  CoordinateUtils._();

  static const _uuid = Uuid();

  static YoloBox pixelToYolo(
    Rect rect, {
    required int classId,
    required int imageWidth,
    required int imageHeight,
  }) {
    _validateImageSize(imageWidth, imageHeight);
    final normalized = clampRectToImage(
      rect,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
    if (normalized.width <= 0 || normalized.height <= 0) {
      throw ArgumentError('标注框尺寸必须大于 0');
    }

    return YoloBox(
      classId: classId,
      xCenter: normalized.center.dx / imageWidth,
      yCenter: normalized.center.dy / imageHeight,
      width: normalized.width / imageWidth,
      height: normalized.height / imageHeight,
    );
  }

  static Rect yoloToPixel({
    required double xCenter,
    required double yCenter,
    required double width,
    required double height,
    required int imageWidth,
    required int imageHeight,
  }) {
    _validateImageSize(imageWidth, imageHeight);
    for (final value in [xCenter, yCenter, width, height]) {
      if (value < 0 || value > 1) {
        throw RangeError.range(value, 0, 1, 'YOLO 坐标', '归一化坐标越界');
      }
    }
    if (width == 0 || height == 0) {
      throw ArgumentError('YOLO 宽高必须大于 0');
    }

    final pixelWidth = width * imageWidth;
    final pixelHeight = height * imageHeight;
    final left = xCenter * imageWidth - pixelWidth / 2;
    final top = yCenter * imageHeight - pixelHeight / 2;
    return clampRectToImage(
      Rect.fromLTWH(left, top, pixelWidth, pixelHeight),
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  static AnnotationBox yoloLineToPixelBox({
    required String line,
    required int imageWidth,
    required int imageHeight,
    required int classCount,
  }) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length != 5) {
      throw const FormatException('YOLO 标签必须包含 5 个字段');
    }

    final classId = int.parse(parts[0]);
    if (classId < 0 || classId >= classCount) {
      throw RangeError.range(classId, 0, classCount - 1, 'classId', '类别编号越界');
    }

    return AnnotationBox(
      id: _uuid.v4(),
      classId: classId,
      rect: yoloToPixel(
        xCenter: double.parse(parts[1]),
        yCenter: double.parse(parts[2]),
        width: double.parse(parts[3]),
        height: double.parse(parts[4]),
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      ),
    );
  }

  static Rect imageToCanvas(
    Rect imageRect, {
    required double scale,
    required Offset offset,
  }) {
    _validateScale(scale);
    return Rect.fromLTWH(
      imageRect.left * scale + offset.dx,
      imageRect.top * scale + offset.dy,
      imageRect.width * scale,
      imageRect.height * scale,
    );
  }

  static Rect canvasToImage(
    Rect canvasRect, {
    required double scale,
    required Offset offset,
  }) {
    _validateScale(scale);
    return Rect.fromLTWH(
      (canvasRect.left - offset.dx) / scale,
      (canvasRect.top - offset.dy) / scale,
      canvasRect.width / scale,
      canvasRect.height / scale,
    );
  }

  static Offset canvasPointToImage(
    Offset point, {
    required double scale,
    required Offset offset,
  }) {
    _validateScale(scale);
    return Offset(
      (point.dx - offset.dx) / scale,
      (point.dy - offset.dy) / scale,
    );
  }

  static Rect clampRectToImage(
    Rect rect, {
    required int imageWidth,
    required int imageHeight,
  }) {
    _validateImageSize(imageWidth, imageHeight);
    final normalized = Rect.fromLTRB(
      math.min(rect.left, rect.right),
      math.min(rect.top, rect.bottom),
      math.max(rect.left, rect.right),
      math.max(rect.top, rect.bottom),
    );
    final left = normalized.left.clamp(0.0, imageWidth.toDouble());
    final top = normalized.top.clamp(0.0, imageHeight.toDouble());
    final right = normalized.right.clamp(0.0, imageWidth.toDouble());
    final bottom = normalized.bottom.clamp(0.0, imageHeight.toDouble());
    return Rect.fromLTRB(
      left,
      top,
      math.max(left, right),
      math.max(top, bottom),
    );
  }

  static void _validateImageSize(int imageWidth, int imageHeight) {
    if (imageWidth <= 0 || imageHeight <= 0) {
      throw ArgumentError('图片尺寸必须大于 0');
    }
  }

  static void _validateScale(double scale) {
    if (scale <= 0) {
      throw ArgumentError('缩放比例必须大于 0');
    }
  }
}
