import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/annotation_controller.dart';
import 'bbox_painter.dart';

enum _CanvasDragMode { none, drawing, moving, resizing, panning }

class ImageCanvas extends StatefulWidget {
  const ImageCanvas({required this.controller, super.key});

  final AnnotationController controller;

  @override
  State<ImageCanvas> createState() => _ImageCanvasState();
}

class _ImageCanvasState extends State<ImageCanvas> {
  ui.Image? _image;
  String? _loadedPath;
  String? _loadingPath;
  String? _fittedPath;
  Rect? _draftRect;
  Offset? _dragStartImagePoint;
  Offset? _lastCanvasPoint;
  Size? _viewportSize;
  Rect? _startBoxRect;
  ResizeHandle _resizeHandle = ResizeHandle.none;
  _CanvasDragMode _dragMode = _CanvasDragMode.none;

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final item = widget.controller.currentImage.value;
      final boxes = widget.controller.boxes.toList(growable: false);
      final selectedBoxId = widget.controller.selectedBoxId.value;
      final transform = widget.controller.transform.value;
      _ensureImageLoaded(item?.path);

      return LayoutBuilder(
        builder: (context, constraints) {
          final viewportSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          _viewportSize = viewportSize;
          if (item != null &&
              _fittedPath != item.path &&
              viewportSize.width > 0 &&
              viewportSize.height > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _fittedPath != item.path) {
                widget.controller.fitToViewport(viewportSize);
                _fittedPath = item.path;
              }
            });
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                widget.controller.clampViewToViewport(viewportSize);
              }
            });
          }

          return Listener(
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerUp,
            onPointerCancel: (_) => _clearDrag(),
            onPointerSignal: _handlePointerSignal,
            child: ClipRect(
              clipBehavior: Clip.hardEdge,
              child: MouseRegion(
                cursor: _cursorForMode(),
                child: CustomPaint(
                  painter: BboxPainter(
                    image: _image,
                    imageItem: item,
                    boxes: boxes,
                    selectedBoxId: selectedBoxId,
                    transform: transform,
                    classNameOf: widget.controller.classNameOf,
                    draftRect: _draftRect,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  MouseCursor _cursorForMode() {
    return switch (_dragMode) {
      _CanvasDragMode.panning => SystemMouseCursors.grabbing,
      _CanvasDragMode.moving => SystemMouseCursors.move,
      _CanvasDragMode.resizing => SystemMouseCursors.resizeUpLeftDownRight,
      _ => SystemMouseCursors.precise,
    };
  }

  Future<void> _ensureImageLoaded(String? path) async {
    if (path == null || path == _loadedPath || path == _loadingPath) {
      return;
    }

    _loadingPath = path;
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      if (!mounted || _loadingPath != path) {
        image.dispose();
        codec.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = image;
        _loadedPath = path;
      });
      codec.dispose();
    } catch (_) {
      if (mounted && _loadingPath == path) {
        setState(() {
          _image?.dispose();
          _image = null;
          _loadedPath = null;
        });
      }
    } finally {
      if (_loadingPath == path) {
        _loadingPath = null;
      }
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    final item = widget.controller.currentImage.value;
    if (item == null) {
      return;
    }

    _lastCanvasPoint = event.localPosition;
    if ((event.buttons & kSecondaryMouseButton) != 0) {
      _dragMode = _CanvasDragMode.panning;
      setState(() {});
      return;
    }
    if ((event.buttons & kPrimaryMouseButton) == 0) {
      return;
    }

    final imagePoint = widget.controller.canvasPointToImage(
      event.localPosition,
    );
    final handle = widget.controller.hitTestHandle(imagePoint);
    if (handle != ResizeHandle.none) {
      widget.controller.captureUndoSnapshot();
      _resizeHandle = handle;
      _dragMode = _CanvasDragMode.resizing;
      setState(() {});
      return;
    }

    final hitBoxId = widget.controller.hitTestBox(imagePoint);
    if (hitBoxId != null) {
      widget.controller.selectBox(hitBoxId);
      widget.controller.captureUndoSnapshot();
      _dragStartImagePoint = imagePoint;
      _startBoxRect = widget.controller.boxById(hitBoxId)?.rect;
      _dragMode = _CanvasDragMode.moving;
      setState(() {});
      return;
    }

    widget.controller.selectBox(null);
    _dragStartImagePoint = imagePoint;
    _draftRect = widget.controller.rectFromPoints(imagePoint, imagePoint);
    _dragMode = _CanvasDragMode.drawing;
    setState(() {});
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final lastPoint = _lastCanvasPoint;
    _lastCanvasPoint = event.localPosition;
    switch (_dragMode) {
      case _CanvasDragMode.panning:
        final viewportSize = _viewportSize;
        if (lastPoint != null && viewportSize != null) {
          widget.controller.panCanvas(
            event.localPosition - lastPoint,
            viewportSize,
          );
        }
      case _CanvasDragMode.drawing:
        final start = _dragStartImagePoint;
        if (start != null) {
          setState(() {
            _draftRect = widget.controller.rectFromPoints(
              start,
              widget.controller.canvasPointToImage(event.localPosition),
            );
          });
        }
      case _CanvasDragMode.moving:
        final start = _dragStartImagePoint;
        final startRect = _startBoxRect;
        if (start != null && startRect != null) {
          final current = widget.controller.canvasPointToImage(
            event.localPosition,
          );
          widget.controller.moveSelectedBoxFromStart(
            startRect,
            current - start,
          );
        }
      case _CanvasDragMode.resizing:
        widget.controller.resizeSelectedBox(
          _resizeHandle,
          widget.controller.canvasPointToImage(event.localPosition),
        );
      case _CanvasDragMode.none:
        return;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_dragMode == _CanvasDragMode.drawing && _draftRect != null) {
      widget.controller.createBox(_draftRect!);
    }
    _clearDrag();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final viewportSize = _viewportSize;
      if (viewportSize == null) {
        return;
      }
      widget.controller.zoomAt(
        event.localPosition,
        event.scrollDelta.dy,
        viewportSize,
      );
      _fittedPath = widget.controller.currentImage.value?.path;
    }
  }

  void _clearDrag() {
    setState(() {
      _draftRect = null;
      _dragStartImagePoint = null;
      _lastCanvasPoint = null;
      _startBoxRect = null;
      _resizeHandle = ResizeHandle.none;
      _dragMode = _CanvasDragMode.none;
    });
  }
}
