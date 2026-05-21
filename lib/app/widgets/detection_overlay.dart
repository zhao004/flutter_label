import 'package:flutter/material.dart';

import '../models/detection_result.dart';

String detectionLabelText(DetectionResult detection) {
  final confidence = (detection.confidence * 100).toStringAsFixed(1);
  return '${detection.className} (#${detection.classId}) $confidence%';
}

/// 在图片或视频画面上绘制检测框。
///
/// 调用方负责保证画布尺寸与原始媒体尺寸等比例缩放后的位置一致，
/// 这样图片预览和视频预览可以复用同一套框选逻辑。
class DetectionOverlayPainter extends CustomPainter {
  const DetectionOverlayPainter({
    required this.detections,
    required this.scale,
  });

  final List<DetectionResult> detections;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final detection in detections) {
      final rect = Rect.fromLTWH(
        detection.left * scale,
        detection.top * scale,
        detection.width * scale,
        detection.height * scale,
      );
      canvas.drawRect(rect, paint);
      _drawLabel(canvas, rect, detection);
    }
  }

  void _drawLabel(Canvas canvas, Rect rect, DetectionResult detection) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: detectionLabelText(detection),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelTop = rect.top - textPainter.height - 4;
    final labelRect = Rect.fromLTWH(
      rect.left,
      labelTop < 0 ? rect.top : labelTop,
      textPainter.width + 8,
      textPainter.height + 4,
    );
    canvas.drawRect(labelRect, Paint()..color = const Color(0xFFFFD54F));
    textPainter.paint(canvas, labelRect.topLeft + const Offset(4, 2));
  }

  @override
  bool shouldRepaint(covariant DetectionOverlayPainter oldDelegate) {
    return oldDelegate.detections != detections || oldDelegate.scale != scale;
  }
}
