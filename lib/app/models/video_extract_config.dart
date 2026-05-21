enum VideoExtractMode { fps, interval }

enum VideoExtractConflictStrategy { skipExisting, overwriteExisting }

extension VideoExtractConflictStrategyText on VideoExtractConflictStrategy {
  String get label {
    return switch (this) {
      VideoExtractConflictStrategy.skipExisting => '跳过已有文件',
      VideoExtractConflictStrategy.overwriteExisting => '覆盖已有文件',
    };
  }
}

class VideoExtractConfig {
  const VideoExtractConfig({
    required this.videoPath,
    required this.outputDir,
    required this.mode,
    required this.fps,
    required this.frameInterval,
    required this.conflictStrategy,
  });

  final String videoPath;
  final String outputDir;
  final VideoExtractMode mode;
  final double fps;
  final int frameInterval;
  final VideoExtractConflictStrategy conflictStrategy;
}
