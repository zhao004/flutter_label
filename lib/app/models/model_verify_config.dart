enum ModelVerifyMode { image, window }

class ModelVerifyConfig {
  const ModelVerifyConfig({
    required this.modelPath,
    required this.sourcePath,
    required this.mode,
    required this.imgsz,
    required this.conf,
    required this.iou,
    this.classCount = 0,
    this.windowHandle = 0,
    this.windowTitle = '',
  });

  final String modelPath;
  final String sourcePath;
  final ModelVerifyMode mode;
  final int imgsz;
  final double conf;
  final double iou;
  final int classCount;
  final int windowHandle;
  final String windowTitle;
}

class WindowSelectionInfo {
  const WindowSelectionInfo({
    required this.handle,
    required this.title,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int handle;
  final String title;
  final int left;
  final int top;
  final int width;
  final int height;

  bool get isValid => handle > 0 && width > 0 && height > 0;
}
