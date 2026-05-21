class ImageItem {
  const ImageItem({
    required this.path,
    required this.labelPath,
    required this.fileName,
    required this.relativePath,
    this.width,
    this.height,
  });

  final String path;
  final String labelPath;
  final String fileName;
  final String relativePath;
  final int? width;
  final int? height;

  bool get hasDimensions => width != null && height != null;

  String get dimensionText {
    if (!hasDimensions) {
      return '读取中';
    }
    return '$width x $height';
  }

  ImageItem copyWith({
    String? path,
    String? labelPath,
    String? fileName,
    String? relativePath,
    int? width,
    int? height,
  }) {
    return ImageItem(
      path: path ?? this.path,
      labelPath: labelPath ?? this.labelPath,
      fileName: fileName ?? this.fileName,
      relativePath: relativePath ?? this.relativePath,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}
