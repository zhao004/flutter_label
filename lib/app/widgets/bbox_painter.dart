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

  static const _classColors = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFDD835),
    Color(0xFF8E24AA),
    Color(0xFFFF8F00),
    Color(0xFF00ACC1),
    Color(0xFF6D4C41),
    Color(0xFFD81B60),
  ];

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
    final color = _classColors[box.classId % _classColors.length];
    final stroke = Paint()
      ..color = selected ? Colors.white : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 2.4 : 1.8;
    canvas.drawRect(canvasRect, stroke);
    canvas.drawRect(
      canvasRect.deflate(1),
      Paint()
        ..color = color.withValues(alpha: selected ? 0.16 : 0.08)
        ..style = PaintingStyle.fill,
    );
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
      canvasRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawHandles(Canvas canvas, Rect rect) {
    const size = 8.0;
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
    final paint = Paint()..color = Colors.white;
    for (final point in points) {
      canvas.drawRect(
        Rect.fromCenter(center: point, width: size, height: size),
        paint,
      );
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
    final labelRect = Rect.fromLTWH(
      rect.left,
      rect.top - painter.height - 4,
      painter.width + 8,
      painter.height + 4,
    );
    canvas.drawRect(labelRect, Paint()..color = color.withValues(alpha: 0.92));
    painter.paint(canvas, labelRect.topLeft + const Offset(4, 2));
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
