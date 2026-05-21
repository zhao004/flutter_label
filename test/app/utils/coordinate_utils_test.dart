import 'dart:ui';

import 'package:flutter_label/app/utils/coordinate_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoordinateUtils', () {
    test('像素坐标和 YOLO 坐标可以稳定往返', () {
      final source = Rect.fromLTWH(10, 20, 30, 40);

      final yolo = CoordinateUtils.pixelToYolo(
        source,
        classId: 1,
        imageWidth: 100,
        imageHeight: 200,
      );
      final restored = CoordinateUtils.yoloToPixel(
        xCenter: yolo.xCenter,
        yCenter: yolo.yCenter,
        width: yolo.width,
        height: yolo.height,
        imageWidth: 100,
        imageHeight: 200,
      );

      expect(restored.left, closeTo(source.left, 0.0001));
      expect(restored.top, closeTo(source.top, 0.0001));
      expect(restored.width, closeTo(source.width, 0.0001));
      expect(restored.height, closeTo(source.height, 0.0001));
    });

    test('画布坐标和原图坐标按缩放平移转换', () {
      final imageRect = Rect.fromLTWH(5, 10, 20, 30);
      final canvasRect = CoordinateUtils.imageToCanvas(
        imageRect,
        scale: 2,
        offset: const Offset(100, 50),
      );

      expect(canvasRect, Rect.fromLTWH(110, 70, 40, 60));
      expect(
        CoordinateUtils.canvasToImage(
          canvasRect,
          scale: 2,
          offset: const Offset(100, 50),
        ),
        imageRect,
      );
    });

    test('标注框会被裁剪到图片范围内', () {
      final clamped = CoordinateUtils.clampRectToImage(
        Rect.fromLTWH(-10, -20, 140, 180),
        imageWidth: 100,
        imageHeight: 120,
      );

      expect(clamped, Rect.fromLTWH(0, 0, 100, 120));
    });

    test('非法归一化坐标会抛出异常', () {
      expect(
        () => CoordinateUtils.yoloToPixel(
          xCenter: 1.2,
          yCenter: 0.5,
          width: 0.2,
          height: 0.2,
          imageWidth: 100,
          imageHeight: 100,
        ),
        throwsRangeError,
      );
    });
  });
}
