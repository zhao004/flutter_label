import 'dart:typed_data';

class DetectionResult {
  const DetectionResult({
    required this.classId,
    required this.className,
    required this.confidence,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.sourceWidth,
    this.sourceHeight,
  });

  final int classId;
  final String className;
  final double confidence;
  final double left;
  final double top;
  final double width;
  final double height;
  final int? sourceWidth;
  final int? sourceHeight;
}

class RealtimeDetectionResult {
  const RealtimeDetectionResult({
    required this.fps,
    required this.inferMs,
    required this.captureMs,
    required this.detections,
    this.frameBytes,
    this.frameWidth = 0,
    this.frameHeight = 0,
    this.frameStride = 0,
    this.sourceTitle = '',
  });

  final double fps;
  final double inferMs;
  final double captureMs;
  final List<DetectionResult> detections;
  final Uint8List? frameBytes;
  final int frameWidth;
  final int frameHeight;
  final int frameStride;
  final String sourceTitle;
}
