import 'package:drift/drift.dart';

/// 运行日志等级，目前先持久化用户可见错误，预留后续扩展普通信息与警告。
enum RunLogLevel {
  error;

  String get label {
    return switch (this) {
      RunLogLevel.error => '错误',
    };
  }
}

/// 将运行日志等级映射为稳定字符串，避免数据库中保存依赖显示文案的值。
class RunLogLevelConverter extends TypeConverter<RunLogLevel, String> {
  const RunLogLevelConverter();

  @override
  RunLogLevel fromSql(String fromDb) {
    return RunLogLevel.values.firstWhere(
      (level) => level.name == fromDb,
      orElse: () => RunLogLevel.error,
    );
  }

  @override
  String toSql(RunLogLevel value) => value.name;
}
