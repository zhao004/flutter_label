import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/annotation_box.dart';
import '../models/canvas_transform.dart';
import '../models/image_item.dart';
import '../utils/coordinate_utils.dart';

class BboxPainter extends CustomPainter {
  BboxPainter({
    required this.image,
    required this.imageItem,
    required this.boxes,
    required this.selectedBoxId,
    required this.transform,
    required this.classNameOf,
    this.draftRect,
  });

  final ui.Image? image;
  final ImageItem? imageItem;
  final List<AnnotationBox> boxes;
  final String? selectedBoxId;
  final CanvasTransform transform;
  final String Function(int classId) classNameOf;
  final Rect? draftRect;

  static const List<Color> classColors = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFDD835),
    Color(0xFF8E24AA),
    Color(0xFFFF8F00),
    Color(0xFF00ACC1),
    Color(0xFF6D4C41),
    Color(0xFFD81B60),
    Color(0xFF3949AB),
    Color(0xFF7CB342),
    Color(0xFFFF7043),
  ];

  static Color colorForClass(int classId) {
    final normalizedIndex = classId % classColors.length;
    return classColors[normalizedIndex < 0
        ? normalizedIndex + classColors.length
        : normalizedIndex];
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF101817),
    );
    final item = imageItem;
    final decodedImage = image;
    if (item == null || decodedImage == null || !item.hasDimensions) {
      _drawEmptyHint(canvas, size);
      return;
    }
    final imageWidth = item.width!;
    final imageHeight = item.height!;

    final imageRect = Rect.fromLTWH(
      transform.offset.dx,
      transform.offset.dy,
      imageWidth * transform.scale,
      imageHeight * transform.scale,
    );
    canvas.drawRect(imageRect, Paint()..color = Colors.black);
    canvas.drawImageRect(
      decodedImage,
      Rect.fromLTWH(
        0,
        0,
        decodedImage.width.toDouble(),
        decodedImage.height.toDouble(),
      ),
      imageRect,
      Paint()..filterQuality = FilterQuality.medium,
    );

    for (final box in boxes) {
      _drawBox(canvas, box, selected: box.id == selectedBoxId);
    }

    final draft = draftRect;
    if (draft != null) {
      _drawDraft(canvas, draft);
    }
  }

  void _drawBox(Canvas canvas, AnnotationBox box, {required bool selected}) {
    final canvasRect = CoordinateUtils.imageToCanvas(
      box.rect,
      scale: transform.scale,
      offset: transform.offset,
    );
    final color = colorForClass(box.classId);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 2.8 : 1.8;
    canvas.drawRect(
      canvasRect.deflate(1),
      Paint()
        ..color = color.withValues(alpha: selected ? 0.16 : 0.08)
        ..style = PaintingStyle.fill,
    );
    if (selected) {
      canvas.drawRect(
        canvasRect,
        stroke..color = color.withValues(alpha: 0.72),
      );
      _drawDashedRect(
        canvas,
        canvasRect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.2,
        dashLength: 8,
        gapLength: 5,
      );
    } else {
      canvas.drawRect(canvasRect, stroke);
    }
    _drawLabel(
      canvas,
      canvasRect,
      color,
      '${box.classId}: ${classNameOf(box.classId)}',
    );
    if (selected) {
      _drawHandles(canvas, canvasRect);
    }
  }

  void _drawDraft(Canvas canvas, Rect draft) {
    final canvasRect = CoordinateUtils.imageToCanvas(
      draft,
      scale: transform.scale,
      offset: transform.offset,
    );
    canvas.drawRect(
      canvasRect.deflate(1),
      Paint()..color = Colors.white.withValues(alpha: 0.04),
    );
    _drawDashedRect(
      canvas,
      canvasRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.6,
      dashLength: 7,
      gapLength: 5,
    );
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    canvas.drawLine(canvasRect.topLeft, canvasRect.bottomRight, guidePaint);
    canvas.drawLine(canvasRect.topRight, canvasRect.bottomLeft, guidePaint);
  }

  void _drawHandles(Canvas canvas, Rect rect) {
    const radius = 5.0;
    final points = [
      rect.topLeft,
      Offset(rect.center.dx, rect.top),
      rect.topRight,
      Offset(rect.right, rect.center.dy),
      rect.bottomRight,
      Offset(rect.center.dx, rect.bottom),
      rect.bottomLeft,
      Offset(rect.left, rect.center.dy),
    ];
    final fillPaint = Paint()..color = Colors.white;
    final strokePaint = Paint()
      ..color = const Color(0xFF005FB8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final point in points) {
      canvas.drawCircle(point, radius, fillPaint);
      canvas.drawCircle(point, radius, strokePaint);
    }
  }

  void _drawLabel(Canvas canvas, Rect rect, Color color, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    const labelRadius = Radius.circular(6);
    const labelPadding = EdgeInsets.fromLTRB(10, 4, 8, 4);
    const stripeWidth = 3.0;
    final top = rect.top - painter.height - labelPadding.vertical - 6;
    final labelTop = top >= 0 ? top : rect.top + 5;
    final labelRect = Rect.fromLTWH(
      rect.left,
      labelTop,
      painter.width + labelPadding.horizontal + stripeWidth,
      painter.height + labelPadding.vertical,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, labelRadius),
      Paint()..color = const Color(0xDD111111),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          labelRect.left,
          labelRect.top,
          stripeWidth,
          labelRect.height,
        ),
        labelRadius,
      ),
      Paint()..color = color,
    );
    painter.paint(
      canvas,
      labelRect.topLeft +
          Offset(labelPadding.left + stripeWidth, labelPadding.top),
    );
  }

  void _drawDashedRect(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    final path = Path()..addRect(rect);
    _drawDashedPath(
      canvas,
      path,
      paint,
      dashLength: dashLength,
      gapLength: gapLength,
    );
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final nextDistance = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, nextDistance), paint);
        distance = nextDistance + gapLength;
      }
    }
  }

  void _drawEmptyHint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: const TextSpan(
        text: '请选择包含图片的 dataset/images 目录',
        style: TextStyle(color: Colors.white70, fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    painter.paint(
      canvas,
      Offset(
        (size.width - painter.width) / 2,
        (size.height - painter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant BboxPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.imageItem != imageItem ||
        oldDelegate.boxes != boxes ||
        oldDelegate.selectedBoxId != selectedBoxId ||
        oldDelegate.transform != transform ||
        oldDelegate.draftRect != draftRect;
  }
}
