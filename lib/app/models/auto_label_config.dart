import 'dataset_split.dart';

enum AutoLabelOverwriteStrategy {
  skipExisting,
  overwriteExisting,
  mergeExisting,
}

extension AutoLabelOverwriteStrategyText on AutoLabelOverwriteStrategy {
  String get label {
    return switch (this) {
      AutoLabelOverwriteStrategy.skipExisting => '跳过已有标签',
      AutoLabelOverwriteStrategy.overwriteExisting => '覆盖已有标签',
      AutoLabelOverwriteStrategy.mergeExisting => '合并已有标签',
    };
  }
}

class AutoLabelConfig {
  const AutoLabelConfig({
    required this.modelPath,
    required this.imageDir,
    required this.labelDir,
    required this.imgsz,
    required this.conf,
    required this.iou,
    required this.classCount,
    required this.strategy,
    this.folderFilter = DatasetFolderFilter.all,
    this.dataYamlPath = '',
  });

  final String modelPath;
  final String imageDir;
  final String labelDir;
  final int imgsz;
  final double conf;
  final double iou;
  final int classCount;
  final AutoLabelOverwriteStrategy strategy;
  final DatasetFolderFilter folderFilter;
  final String dataYamlPath;
}

class AutoLabelResult {
  const AutoLabelResult({
    required this.writtenCount,
    required this.skippedCount,
    required this.mergedCount,
    required this.logs,
    required this.usedNative,
    this.classCount = 0,
  });

  final int writtenCount;
  final int skippedCount;
  final int mergedCount;
  final List<String> logs;
  final bool usedNative;
  final int classCount;
}
