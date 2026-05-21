import 'dart:ui';

class AnnotationBox {
  const AnnotationBox({
    required this.id,
    required this.classId,
    required this.rect,
  });

  final String id;
  final int classId;
  final Rect rect;

  AnnotationBox copyWith({int? classId, Rect? rect}) {
    return AnnotationBox(
      id: id,
      classId: classId ?? this.classId,
      rect: rect ?? this.rect,
    );
  }
}
