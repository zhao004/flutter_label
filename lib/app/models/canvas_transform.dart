import 'dart:ui';

class CanvasTransform {
  const CanvasTransform({required this.scale, required this.offset});

  final double scale;
  final Offset offset;

  static const initial = CanvasTransform(scale: 1, offset: Offset.zero);

  CanvasTransform copyWith({double? scale, Offset? offset}) {
    return CanvasTransform(
      scale: scale ?? this.scale,
      offset: offset ?? this.offset,
    );
  }
}
