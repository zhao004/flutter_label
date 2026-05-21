import 'package:drift/drift.dart';

/// 首页历史记录的动作类型，用字符串入库以保持数据可读且便于后续迁移。
enum HistoryActionType {
  openImagesDirectory,
  openProjectFile,
  openDatasetProject,
  createDatasetProject,
  openFeaturePage;

  String get label {
    return switch (this) {
      HistoryActionType.openImagesDirectory => '打开图片目录',
      HistoryActionType.openProjectFile => '打开项目文件',
      HistoryActionType.openDatasetProject => '打开数据集项目',
      HistoryActionType.createDatasetProject => '新建数据集项目',
      HistoryActionType.openFeaturePage => '进入功能页面',
    };
  }
}

/// 将历史动作枚举映射为稳定字符串，遇到未知值时回退到功能入口类型以兼容旧数据。
class HistoryActionTypeConverter
    extends TypeConverter<HistoryActionType, String> {
  const HistoryActionTypeConverter();

  @override
  HistoryActionType fromSql(String fromDb) {
    return HistoryActionType.values.firstWhere(
      (type) => type.name == fromDb,
      orElse: () => HistoryActionType.openFeaturePage,
    );
  }

  @override
  String toSql(HistoryActionType value) => value.name;
}
