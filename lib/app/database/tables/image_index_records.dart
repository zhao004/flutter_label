import 'package:drift/drift.dart';

/// 缓存数据集图片索引，避免每次打开项目都重新解码全部图片。
class ImageIndexRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get datasetRoot => text()();

  TextColumn get scanMode => text()();

  TextColumn get imagePath => text()();

  TextColumn get relativePath => text()();

  TextColumn get labelPath => text()();

  IntColumn get fileSize => integer()();

  IntColumn get modifiedAtMillis => integer()();

  IntColumn get width => integer().nullable()();

  IntColumn get height => integer().nullable()();

  TextColumn get annotationStatus => text().nullable()();

  TextColumn get errorMessage => text().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  /// 同一项目和扫描模式下，relativePath 是稳定的图片身份。
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {datasetRoot, scanMode, relativePath},
  ];
}
