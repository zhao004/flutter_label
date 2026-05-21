class DatasetExportConfig {
  const DatasetExportConfig({
    required this.projectDir,
    required this.outputDir,
    required this.trainRatio,
    required this.valRatio,
    required this.testRatio,
    required this.shuffle,
    required this.includeEmptyLabels,
    required this.createZip,
  });

  final String projectDir;
  final String outputDir;
  final double trainRatio;
  final double valRatio;
  final double testRatio;
  final bool shuffle;
  final bool includeEmptyLabels;
  final bool createZip;
}

class DatasetExportResult {
  const DatasetExportResult({
    required this.trainCount,
    required this.valCount,
    required this.testCount,
    required this.skippedCount,
    required this.emptyLabelCount,
    required this.duplicateCount,
    required this.logs,
    this.zipPath,
  });

  final int trainCount;
  final int valCount;
  final int testCount;
  final int skippedCount;
  final int emptyLabelCount;
  final int duplicateCount;
  final List<String> logs;
  final String? zipPath;

  int get exportedCount => trainCount + valCount + testCount;
}
