import 'package:drift/native.dart';
import 'package:flutter_label/app/database/database.dart';
import 'package:flutter_label/app/services/app_toast_service.dart';
import 'package:flutter_label/app/services/app_run_log_service.dart';
import 'package:get/get.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    Get.testMode = true;
    database = AppDatabase(NativeDatabase.memory());
    Get.put<AppDatabase>(database);
    Get.put<AppRunLogService>(AppRunLogService(database: database));
  });

  tearDown(() async {
    await database.close();
    Get.reset();
  });

  test('空提示会回退到默认文案', () {
    expect(AppToast.normalizeMessage('  ', '默认文案'), '默认文案');
    expect(AppToast.normalizeMessage(null, '默认文案'), '默认文案');
    expect(AppToast.normalizeMessage(' 已完成 ', '默认文案'), '已完成');
  });

  test('成功和错误颜色符合全局约定', () {
    expect(AppToast.successColor.toARGB32(), 0xFF2E7D32);
    expect(AppToast.errorColor.toARGB32(), 0xFFC62828);
  });

  test('成功提示缺少 Overlay 时不会影响主流程', () {
    expect(() => AppToast.success('保存完成'), returnsNormally);
  });

  test('错误提示缺少 Overlay 时不会影响主流程', () {
    expect(() => AppToast.error('识别失败'), returnsNormally);
  });

  test('错误提示会写入统一运行日志', () async {
    AppToast.error('识别失败', source: '自动预标注', details: '模型加载异常');
    final logs = await database
        .watchRecentRunLogs(limit: 10)
        .firstWhere((logs) => logs.isNotEmpty);
    expect(logs, hasLength(1));
    expect(logs.single.source, '自动预标注');
    expect(logs.single.message, '识别失败');
    expect(logs.single.details, '模型加载异常');
  });
}
