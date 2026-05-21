import 'package:path/path.dart' as p;

class ProjectConfig {
  const ProjectConfig({
    required this.projectName,
    required this.datasetDir,
    required this.imageDir,
    required this.labelDir,
    required this.classes,
    required this.completedImages,
    this.projectFilePath,
  });

  final String projectName;
  final String datasetDir;
  final String imageDir;
  final String labelDir;
  final List<String> classes;
  final List<String> completedImages;
  final String? projectFilePath;

  factory ProjectConfig.fromDataset({
    required String datasetDir,
    required String imageDir,
    required String labelDir,
    required List<String> classes,
    String? projectFilePath,
  }) {
    return ProjectConfig(
      projectName: p.basename(datasetDir),
      datasetDir: datasetDir,
      imageDir: imageDir,
      labelDir: labelDir,
      classes: List.unmodifiable(classes),
      completedImages: const [],
      projectFilePath: projectFilePath,
    );
  }

  factory ProjectConfig.fromJson(
    Map<String, dynamic> json, {
    String? projectFilePath,
  }) {
    final classes = _stringListFromJson(json['classes'], 'classes');
    final completedImages = json.containsKey('completed_images')
        ? _stringListFromJson(json['completed_images'], 'completed_images')
        : <String>[];
    return ProjectConfig(
      projectName: _stringFromJson(json['project_name'], 'project_name'),
      datasetDir: _stringFromJson(json['dataset_dir'], 'dataset_dir'),
      imageDir: _stringFromJson(json['image_dir'], 'image_dir'),
      labelDir: _stringFromJson(json['label_dir'], 'label_dir'),
      classes: List.unmodifiable(classes),
      completedImages: List.unmodifiable(completedImages),
      projectFilePath: projectFilePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project_name': projectName,
      'dataset_dir': datasetDir,
      'image_dir': imageDir,
      'label_dir': labelDir,
      'classes': classes,
      'completed_images': completedImages,
    };
  }

  ProjectConfig copyWith({
    String? projectName,
    String? datasetDir,
    String? imageDir,
    String? labelDir,
    List<String>? classes,
    List<String>? completedImages,
    String? projectFilePath,
  }) {
    return ProjectConfig(
      projectName: projectName ?? this.projectName,
      datasetDir: datasetDir ?? this.datasetDir,
      imageDir: imageDir ?? this.imageDir,
      labelDir: labelDir ?? this.labelDir,
      classes: List.unmodifiable(classes ?? this.classes),
      completedImages: List.unmodifiable(
        completedImages ?? this.completedImages,
      ),
      projectFilePath: projectFilePath ?? this.projectFilePath,
    );
  }

  static String _stringFromJson(Object? value, String fieldName) {
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw FormatException('$fieldName 必须是非空字符串');
  }

  static List<String> _stringListFromJson(Object? value, String fieldName) {
    if (value is! List) {
      throw FormatException('$fieldName 必须是字符串数组');
    }
    final result = <String>[];
    for (final item in value) {
      if (item is! String || item.trim().isEmpty) {
        throw FormatException('$fieldName 包含非法字符串');
      }
      result.add(item.trim());
    }
    return result;
  }
}

class AnnotationOpenRequest {
  const AnnotationOpenRequest({
    this.datasetDir,
    this.imageDir,
    this.projectFilePath,
  }) : assert(
         datasetDir != null || imageDir != null || projectFilePath != null,
         '必须提供数据集目录、图片目录或项目文件路径',
       );

  final String? datasetDir;
  final String? imageDir;
  final String? projectFilePath;
}
