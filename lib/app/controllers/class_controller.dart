import 'package:get/get.dart';

import '../models/annotation_class.dart';
import '../services/data_yaml_service.dart';
import '../services/label_class_migration_service.dart';

class ClassController extends GetxController {
  ClassController({
    DataYamlService dataYamlService = const DataYamlService(),
    LabelClassMigrationService labelClassMigrationService =
        const LabelClassMigrationService(),
  }) : _dataYamlService = dataYamlService,
       _labelClassMigrationService = labelClassMigrationService;

  final DataYamlService _dataYamlService;
  final LabelClassMigrationService _labelClassMigrationService;

  final classes = <AnnotationClass>[].obs;
  final errorMessage = RxnString();
  String? _dataYamlPath;
  String? _labelDir;

  int get classCount => classes.length;
  List<String> get classNames =>
      classes.map((item) => item.name).toList(growable: false);

  Future<void> loadClasses(String dataYamlPath, {String? labelDir}) async {
    errorMessage.value = null;
    try {
      _dataYamlPath = dataYamlPath;
      _labelDir = labelDir;
      classes.assignAll(await _dataYamlService.readClasses(dataYamlPath));
    } catch (error) {
      classes.clear();
      errorMessage.value = error.toString();
      rethrow;
    }
  }

  Future<void> addClass(String name) async {
    final normalized = _normalizeClassName(name);
    _ensureEditable();
    final nextNames = [...classNames, normalized];
    await _writeAndReload(nextNames);
  }

  Future<void> renameClass(int classId, String name) async {
    _ensureClassId(classId);
    final normalized = _normalizeClassName(name, exceptClassId: classId);
    _ensureEditable();
    final nextNames = classNames;
    nextNames[classId] = normalized;
    await _writeAndReload(nextNames);
  }

  Future<void> deleteClass(int classId) async {
    _ensureClassId(classId);
    _ensureEditable();
    final labelDir = _labelDir;
    if (labelDir == null) {
      throw StateError('标签目录未初始化');
    }
    if (await _labelClassMigrationService.isClassUsed(
      labelDir: labelDir,
      classId: classId,
    )) {
      throw StateError('类别已被标签使用，不能删除');
    }

    final nextNames = classNames..removeAt(classId);
    if (nextNames.isEmpty) {
      throw StateError('至少需要保留一个类别');
    }
    await _labelClassMigrationService.deleteUnusedClass(
      labelDir: labelDir,
      deletedClassId: classId,
    );
    await _writeAndReload(nextNames);
  }

  Future<void> moveClass(int classId, int direction) async {
    _ensureClassId(classId);
    _ensureEditable();
    final target = classId + direction;
    _ensureClassId(target);
    final labelDir = _labelDir;
    if (labelDir == null) {
      throw StateError('标签目录未初始化');
    }

    final nextNames = classNames;
    final moving = nextNames.removeAt(classId);
    nextNames.insert(target, moving);
    await _labelClassMigrationService.remapClasses(
      labelDir: labelDir,
      oldToNewClassId: {classId: target, target: classId},
    );
    await _writeAndReload(nextNames);
  }

  String classNameOf(int classId) {
    if (classId < 0 || classId >= classes.length) {
      return '未知类别';
    }
    return classes[classId].name;
  }

  String _normalizeClassName(String name, {int? exceptClassId}) {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw const FormatException('类别名称不能为空');
    }
    final names = classNames;
    final duplicateIndex = names.indexOf(normalized);
    if (duplicateIndex >= 0 && duplicateIndex != exceptClassId) {
      throw const FormatException('类别名称不能重复');
    }
    return normalized;
  }

  void _ensureEditable() {
    if (_dataYamlPath == null) {
      throw StateError('data.yaml 未初始化');
    }
  }

  void _ensureClassId(int classId) {
    if (classId < 0 || classId >= classes.length) {
      throw RangeError.range(
        classId,
        0,
        classes.length - 1,
        'classId',
        '类别编号越界',
      );
    }
  }

  Future<void> _writeAndReload(List<String> nextNames) async {
    final path = _dataYamlPath;
    if (path == null) {
      throw StateError('data.yaml 未初始化');
    }
    await _dataYamlService.writeClasses(
      dataYamlPath: path,
      classNames: nextNames,
    );
    classes.assignAll([
      for (var index = 0; index < nextNames.length; index++)
        AnnotationClass(id: index, name: nextNames[index]),
    ]);
  }
}
