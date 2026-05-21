import 'dart:io';

import 'package:flutter/material.dart';

import '../models/detection_result.dart';
import '../utils/image_utils.dart';
import 'detection_overlay.dart';

class DetectionPreview extends StatefulWidget {
  const DetectionPreview({
    required this.imagePath,
    required this.detections,
    this.showImage = true,
    this.imageWidth,
    this.imageHeight,
    super.key,
  });

  final String imagePath;
  final List<DetectionResult> detections;
  final bool showImage;
  final int? imageWidth;
  final int? imageHeight;

  @override
  State<DetectionPreview> createState() => _DetectionPreviewState();
}

class _DetectionPreviewState extends State<DetectionPreview> {
  ImageSize? _imageSize;
  String? _loadedPath;

  @override
  void didUpdateWidget(covariant DetectionPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath ||
        oldWidget.imageWidth != widget.imageWidth ||
        oldWidget.imageHeight != widget.imageHeight) {
      _imageSize = null;
      _loadedPath = null;
      _loadImageSize();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  Widget build(BuildContext context) {
    final size = _imageSize;
    if (widget.imagePath.isEmpty) {
      return const Center(child: Text('请选择验证源'));
    }
    if (size == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        if (maxWidth <= 0 || maxHeight <= 0) {
          return const SizedBox.shrink();
        }
        final scale = [
          maxWidth / size.width,
          maxHeight / size.height,
        ].reduce((left, right) => left < right ? left : right);
        if (!scale.isFinite || scale <= 0) {
          return const SizedBox.shrink();
        }
        final drawSize = Size(size.width * scale, size.height * scale);
        return Center(
          child: SizedBox(
            width: drawSize.width,
            height: drawSize.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.showImage)
                  Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.fill,
                    errorBuilder: (context, error, stackTrace) {
                      return ColoredBox(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: const Center(child: Text('图片预览加载失败')),
                      );
                    },
                  ),
                CustomPaint(
                  painter: DetectionOverlayPainter(
                    detections: widget.detections,
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

  Future<void> _loadImageSize() async {
    final path = widget.imagePath;
    final imageWidth = widget.imageWidth;
    final imageHeight = widget.imageHeight;
    if (imageWidth != null && imageHeight != null) {
      if (imageWidth <= 0 || imageHeight <= 0) {
        setState(() => _imageSize = null);
        return;
      }
      setState(
        () => _imageSize = ImageSize(width: imageWidth, height: imageHeight),
      );
      return;
    }
    if (path.isEmpty || path == _loadedPath) {
      return;
    }
    _loadedPath = path;
    try {
      final size = await ImageUtils.readImageSize(File(path));
      if (mounted && _loadedPath == path) {
        setState(() => _imageSize = size);
      }
    } catch (_) {
      if (mounted && _loadedPath == path) {
        setState(() => _imageSize = null);
      }
    }
  }
}
