import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/detection_result.dart';
import 'detection_overlay.dart';

/// 显示 native 捕获的窗口 BGRA 帧，并叠加实时检测框。
class WindowDetectionPreview extends StatefulWidget {
  const WindowDetectionPreview({required this.result, super.key});

  final RealtimeDetectionResult? result;

  @override
  State<WindowDetectionPreview> createState() => _WindowDetectionPreviewState();
}

class _WindowDetectionPreviewState extends State<WindowDetectionPreview> {
  ui.Image? _image;
  Object? _lastFrameIdentity;

  @override
  void didUpdateWidget(covariant WindowDetectionPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(_decodeFrameIfNeeded());
  }

  @override
  void initState() {
    super.initState();
    unawaited(_decodeFrameIfNeeded());
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final image = _image;
    if (result == null || image == null) {
      return const Center(child: Text('启动窗口验证后显示实时画面'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final displaySize = _fitSize(
          constraints,
          result.frameWidth / result.frameHeight,
        );
        final scale = displaySize.width / result.frameWidth;
        return Center(
          child: SizedBox(
            width: displaySize.width,
            height: displaySize.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RawImage(image: image, fit: BoxFit.fill),
                CustomPaint(
                  painter: DetectionOverlayPainter(
                    detections: result.detections,
                    scale: scale,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _decodeFrameIfNeeded() async {
    final result = widget.result;
    final bytes = result?.frameBytes;
    if (result == null || bytes == null || bytes.isEmpty) {
      return;
    }
    if (_lastFrameIdentity == bytes) {
      return;
    }
    _lastFrameIdentity = bytes;
    final decoded = await _decodeBgraFrame(
      bytes: bytes,
      width: result.frameWidth,
      height: result.frameHeight,
      stride: result.frameStride,
    );
    if (!mounted || _lastFrameIdentity != bytes) {
      decoded.dispose();
      return;
    }
    final oldImage = _image;
    setState(() => _image = decoded);
    oldImage?.dispose();
  }

  Future<ui.Image> _decodeBgraFrame({
    required List<int> bytes,
    required int width,
    required int height,
    required int stride,
  }) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      Uint8List.fromList(bytes),
      width,
      height,
      ui.PixelFormat.bgra8888,
      completer.complete,
      rowBytes: stride,
    );
    return completer.future;
  }

  Size _fitSize(BoxConstraints constraints, double aspectRatio) {
    final safeAspectRatio = aspectRatio.isFinite && aspectRatio > 0
        ? aspectRatio
        : 16 / 9;
    final maxWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : 420.0;
    final maxHeight = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : maxWidth / safeAspectRatio;
    var width = maxWidth;
    var height = width / safeAspectRatio;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * safeAspectRatio;
    }
    return Size(width.clamp(1.0, maxWidth), height.clamp(1.0, maxHeight));
  }
}
