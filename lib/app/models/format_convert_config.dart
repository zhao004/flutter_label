enum AnnotationFormat { yolo, coco, voc }

extension AnnotationFormatText on AnnotationFormat {
  String get label {
    return switch (this) {
      AnnotationFormat.yolo => 'YOLO',
      AnnotationFormat.coco => 'COCO',
      AnnotationFormat.voc => 'VOC',
    };
  }
}

class FormatConvertConfig {
  const FormatConvertConfig({
    required this.inputFormat,
    required this.outputFormat,
    required this.inputDir,
    required this.outputDir,
    required this.dataYamlPath,
  });

  final AnnotationFormat inputFormat;
  final AnnotationFormat outputFormat;
  final String inputDir;
  final String outputDir;
  final String dataYamlPath;
}

class FormatConvertResult {
  const FormatConvertResult({
    required this.convertedCount,
    required this.skippedCount,
    required this.logs,
  });

  final int convertedCount;
  final int skippedCount;
  final List<String> logs;
}
