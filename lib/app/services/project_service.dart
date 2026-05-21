import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/dataset_split.dart';
import '../models/project_config.dart';
import 'data_yaml_service.dart';

class ProjectService {
  const ProjectService({
    DataYamlService dataYamlService = const DataYamlService(),
  }) : _dataYamlService = dataYamlService;

  final DataYamlService _dataYamlService;

  String defaultProjectPath(String datasetDir) {
    return p.join(datasetDir, 'project.json');
  }

  String defaultDataYamlPath(String datasetDir) {
    return _dataYamlService.defaultDataYamlPath(datasetDir);
  }

  Future<ProjectConfig> createDatasetProject(String datasetDir) async {
    final normalized = _normalizeDirectory(datasetDir, '数据集目录');
    final root = Directory(normalized);
    final dataYaml = File(defaultDataYamlPath(normalized));
    if (await dataYaml.exists()) {
      throw FileSystemException('data.yaml 已存在，请改用打开数据集项目', dataYaml.path);
    }

    await root.create(recursive: true);
    await _ensureStandardDirectories(normalized);
    final config = ProjectConfig.fromDataset(
      datasetDir: normalized,
      imageDir: p.join(normalized, 'images'),
      labelDir: p.join(normalized, 'labels'),
      classes: const [],
      projectFilePath: defaultProjectPath(normalized),
    );
    return writeProject(config);
  }

  Future<ProjectConfig> readDatasetProject(String datasetDir) async {
    final normalized = _normalizeDirectory(datasetDir, '数据集目录');
    final root = Directory(normalized);
    if (!await root.exists()) {
      throw FileSystemException('数据集目录不存在', normalized);
    }

    final classes = await _dataYamlService.readClassNames(
      defaultDataYamlPath(normalized),
    );
    await _ensureStandardDirectories(normalized);

    final cacheFile = File(defaultProjectPath(normalized));
    var completedImages = const <String>[];
    if (await cacheFile.exists()) {
      try {
        completedImages = (await readProject(cacheFile.path)).completedImages;
      } catch (_) {
        // project.json 是内部缓存，损坏时以 data.yaml 为准并在保存时重建。
        completedImages = const <String>[];
      }
    }

    final config = ProjectConfig.fromDataset(
      datasetDir: normalized,
      imageDir: p.join(normalized, 'images'),
      labelDir: p.join(normalized, 'labels'),
      classes: classes,
      projectFilePath: cacheFile.path,
    ).copyWith(completedImages: completedImages);
    return writeProject(config);
  }

  Future<ProjectConfig> readProject(String projectFilePath) async {
    final file = File(projectFilePath);
    if (!await file.exists()) {
      throw FileSystemException('项目配置文件不存在', projectFilePath);
    }

    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) {
        throw const FormatException('project.json 根节点必须是对象');
      }
      return ProjectConfig.fromJson(json, projectFilePath: projectFilePath);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('project.json 解析失败：$error');
    }
  }

  Future<ProjectConfig> writeProject(ProjectConfig config) async {
    final projectFilePath =
        config.projectFilePath ?? defaultProjectPath(config.datasetDir);
    final file = File(projectFilePath);
    await file.parent.create(recursive: true);
    await _ensureStandardDirectories(config.datasetDir);
    await _dataYamlService.writeClasses(
      dataYamlPath: defaultDataYamlPath(config.datasetDir),
      classNames: config.classes,
    );
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(config.toJson())}\n');
    return config.copyWith(projectFilePath: projectFilePath);
  }

  Future<void> _ensureStandardDirectories(String datasetDir) async {
    for (final split in DatasetSplit.values) {
      await Directory(
        p.join(datasetDir, 'images', split.directoryName),
      ).create(recursive: true);
      await Directory(
        p.join(datasetDir, 'labels', split.directoryName),
      ).create(recursive: true);
    }
  }

  String _normalizeDirectory(String value, String fieldName) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw FormatException('$fieldName 不能为空');
    }
    return p.normalize(trimmed);
  }
}
