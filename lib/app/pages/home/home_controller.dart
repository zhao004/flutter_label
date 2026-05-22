import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

import '../../database/database.dart';
import '../../database/type/history_action_type.dart';
import '../../models/project_config.dart';
import '../../routes/app_pages.dart';
import '../../services/app_toast_service.dart';
import '../../services/project_service.dart';

class HomeController extends GetxController {
  static const int _historyLimit = 20;

  HomeController({ProjectService projectService = const ProjectService()})
    : _projectService = projectService;

  final ProjectService _projectService;
  final errorMessage = RxnString();
  final isPicking = false.obs;

  AppDatabase? get _database =>
      Get.isRegistered<AppDatabase>() ? Get.find<AppDatabase>() : null;

  Stream<List<HistoryRecord>> get recentHistoryStream {
    final database = _database;
    if (database == null) {
      return Stream.value(const <HistoryRecord>[]);
    }
    return database.watchRecentHistory(limit: _historyLimit);
  }

  bool isProjectHistoryRecord(HistoryRecord record) {
    return switch (record.actionType) {
      HistoryActionType.openDatasetProject ||
      HistoryActionType.createDatasetProject ||
      HistoryActionType.openProjectFile => true,
      HistoryActionType.openImagesDirectory ||
      HistoryActionType.openFeaturePage => false,
    };
  }

  String? historyProjectPath(HistoryRecord record) {
    final payload = record.payload?.trim();
    if (payload != null && payload.isNotEmpty) {
      return payload;
    }

    final description = record.description?.trim();
    if (description != null && description.isNotEmpty) {
      return description;
    }
    return null;
  }

  bool historyProjectExists(HistoryRecord record) {
    final targetPath = historyProjectPath(record);
    if (!isProjectHistoryRecord(record) || targetPath == null) {
      return false;
    }

    try {
      return switch (record.actionType) {
        HistoryActionType.openDatasetProject ||
        HistoryActionType.createDatasetProject => Directory(
          targetPath,
        ).existsSync(),
        HistoryActionType.openProjectFile => File(targetPath).existsSync(),
        HistoryActionType.openImagesDirectory ||
        HistoryActionType.openFeaturePage => false,
      };
    } on FileSystemException {
      return false;
    } on ArgumentError {
      return false;
    }
  }

  Future<void> createDatasetProject() async {
    if (isPicking.value) {
      return;
    }

    isPicking.value = true;
    errorMessage.value = null;
    try {
      final directory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '请选择新的数据集项目根目录',
      );
      final normalizedDirectory = directory?.trim();
      if (normalizedDirectory == null || normalizedDirectory.isEmpty) {
        return;
      }

      await _projectService.createDatasetProject(normalizedDirectory);

      await _recordHistory(
        actionType: HistoryActionType.createDatasetProject,
        title: '新建数据集项目',
        description: normalizedDirectory,
        targetRoute: Routes.annotation,
        payload: normalizedDirectory,
      );

      await Get.toNamed(
        Routes.annotation,
        arguments: AnnotationOpenRequest(datasetDir: normalizedDirectory),
      );
    } catch (error) {
      errorMessage.value = '新建数据集项目失败：$error';
      AppToast.error(errorMessage.value, source: '首页');
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> openDatasetProject() async {
    if (isPicking.value) {
      return;
    }

    isPicking.value = true;
    errorMessage.value = null;
    try {
      final directory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '请选择数据集项目根目录（包含 data.yaml）',
      );
      final datasetDir = directory?.trim();
      if (datasetDir == null || datasetDir.isEmpty) {
        return;
      }
      await _projectService.readDatasetProject(datasetDir);

      await _recordHistory(
        actionType: HistoryActionType.openDatasetProject,
        title: '打开数据集项目',
        description: datasetDir,
        targetRoute: Routes.annotation,
        payload: datasetDir,
      );

      await Get.toNamed(
        Routes.annotation,
        arguments: AnnotationOpenRequest(datasetDir: datasetDir),
      );
    } catch (error) {
      errorMessage.value = '打开数据集项目失败：$error';
      AppToast.error(errorMessage.value, source: '首页');
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> openVideoExtractPage() async {
    await _openFeaturePage(route: Routes.videoExtract, title: '进入视频抽帧');
  }

  Future<void> openAutoLabelPage() async {
    await _openFeaturePage(route: Routes.autoLabel, title: '进入自动预标注');
  }

  Future<void> openModelVerifyPage() async {
    await _openFeaturePage(route: Routes.modelVerify, title: '进入模型验证');
  }

  Future<void> openFormatConvertPage() async {
    await _openFeaturePage(route: Routes.formatConvert, title: '进入格式转换');
  }

  Future<void> openDatasetExportPage() async {
    await _openFeaturePage(route: Routes.datasetExport, title: '进入数据集导出');
  }

  Future<void> openRunLogPage() async {
    await _openFeaturePage(route: Routes.runLog, title: '打开运行日志');
  }

  Future<void> openSettingsPage() async {
    await _openFeaturePage(route: Routes.settings, title: '打开配置页');
  }

  Future<void> clearHistory() async {
    final database = _database;
    if (database == null) {
      return;
    }

    try {
      await database.clearHistory();
      AppToast.success('历史记录已清空');
    } catch (error) {
      errorMessage.value = '清空历史失败：$error';
      AppToast.error(errorMessage.value, source: '首页');
    }
  }

  Future<void> deleteHistoryRecord(HistoryRecord record) async {
    final database = _database;
    if (database == null) {
      return;
    }

    try {
      await database.deleteHistoryRecord(record.id);
      AppToast.success('历史记录已删除');
    } catch (error) {
      errorMessage.value = '删除历史失败：$error';
      AppToast.error(errorMessage.value, source: '首页');
    }
  }

  Future<void> openHistoryProject(HistoryRecord record) async {
    if (!isProjectHistoryRecord(record)) {
      return;
    }
    if (isPicking.value) {
      return;
    }

    isPicking.value = true;
    errorMessage.value = null;
    try {
      final targetPath = historyProjectPath(record);
      if (targetPath == null) {
        throw const FormatException('历史记录缺少项目路径');
      }

      switch (record.actionType) {
        case HistoryActionType.openDatasetProject:
        case HistoryActionType.createDatasetProject:
          await _openHistoryDatasetProject(targetPath);
        case HistoryActionType.openProjectFile:
          await _openHistoryProjectFile(targetPath);
        case HistoryActionType.openImagesDirectory:
        case HistoryActionType.openFeaturePage:
          throw const FormatException('该历史记录不是项目入口');
      }
    } catch (error) {
      errorMessage.value = '打开历史项目失败：$error';
      AppToast.error(errorMessage.value, source: '首页');
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> _openFeaturePage({
    required String route,
    required String title,
  }) async {
    try {
      await _recordHistory(
        actionType: HistoryActionType.openFeaturePage,
        title: title,
        description: route,
        targetRoute: route,
      );
      await Get.toNamed(route);
    } catch (error) {
      errorMessage.value = '打开页面失败：$error';
      AppToast.error(errorMessage.value, source: '首页');
    }
  }

  Future<void> _recordHistory({
    required HistoryActionType actionType,
    required String title,
    String? description,
    String? targetRoute,
    String? payload,
  }) async {
    final database = _database;
    if (database == null) {
      return;
    }

    await database.addHistoryRecord(
      actionType: actionType,
      title: title,
      description: description,
      targetRoute: targetRoute,
      payload: payload,
    );
  }

  Future<void> _openHistoryDatasetProject(String datasetDir) async {
    if (!Directory(datasetDir).existsSync()) {
      throw FileSystemException('项目文件夹不存在', datasetDir);
    }

    await _projectService.readDatasetProject(datasetDir);
    await Get.toNamed(
      Routes.annotation,
      arguments: AnnotationOpenRequest(datasetDir: datasetDir),
    );
  }

  Future<void> _openHistoryProjectFile(String projectFilePath) async {
    if (!File(projectFilePath).existsSync()) {
      throw FileSystemException('项目配置文件不存在', projectFilePath);
    }

    await _projectService.readProject(projectFilePath);
    await Get.toNamed(
      Routes.annotation,
      arguments: AnnotationOpenRequest(projectFilePath: projectFilePath),
    );
  }
}
