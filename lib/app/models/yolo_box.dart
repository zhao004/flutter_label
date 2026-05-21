class YoloBox {
  const YoloBox({
    required this.classId,
    required this.xCenter,
    required this.yCenter,
    required this.width,
    required this.height,
  });

  final int classId;
  final double xCenter;
  final double yCenter;
  final double width;
  final double height;
}
