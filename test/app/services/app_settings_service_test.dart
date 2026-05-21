import 'dart:io';

import 'package:flutter_label/app/models/app_settings.dart';
import 'package:flutter_label/app/services/app_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('AppSettingsService', () {
    late Directory directory;
    late File settingsFile;
    late AppSettingsService service;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'flutter_label_settings_service_test_',
      );
      settingsFile = File(p.join(directory.path, 'app_settings.json'));
      service = AppSettingsService(fileResolver: () async => settingsFile);
    });

    tearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('配置文件不存在时返回默认值', () async {
      final settings = await service.load();

      expect(settings.spaceCompletesAndSelectsNext, isFalse);
    });

    test('保存后可以重新读取空格自动完成配置', () async {
      await service.save(const AppSettings(spaceCompletesAndSelectsNext: true));

      final settings = await service.load();

      expect(settings.spaceCompletesAndSelectsNext, isTrue);
    });

    test('非法配置类型会抛出格式错误', () async {
      await settingsFile.writeAsString(
        '{"${AppSettings.spaceCompletesAndSelectsNextKey}": "yes"}',
      );

      expect(service.load(), throwsA(isA<FormatException>()));
    });
  });
}
